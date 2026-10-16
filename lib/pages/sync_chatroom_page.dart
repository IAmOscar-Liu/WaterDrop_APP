import 'package:flutter_ad_ecommerce/shared/widgets/pagination_footer.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/features/chatroom/widget/chat_input_widget.dart';
import 'package:flutter_ad_ecommerce/features/chatroom/widget/chat_message_widget.dart';
import 'package:flutter_ad_ecommerce/models/api_enums.dart';
import 'package:flutter_ad_ecommerce/models/chatroom.dart';
import 'package:flutter_ad_ecommerce/provider/chat_sync_provider.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/provider/system_provider.dart';
import 'package:flutter_ad_ecommerce/router/chat_route_observer.dart';
import 'package:flutter_ad_ecommerce/shared/layouts/app_scaffold.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/simple_app_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SyncChatroomPage extends ConsumerStatefulWidget {
  const SyncChatroomPage({super.key, required this.extra});
  final dynamic extra;
  @override
  ConsumerState<SyncChatroomPage> createState() => _SyncChatroomPageState();
}

class _SyncChatroomPageState extends ConsumerState<SyncChatroomPage>
    with RouteAware {
  final _scroll = ScrollController();
  final Map<String, GlobalKey> _messageKeys = {};
  late ChatSyncController _sync;
  late SystemNotifier _system;
  Chatroom? _room;
  String? _error;
  bool _visible = true;
  bool _newMessages = false;
  String? _latestId;
  bool _adjusting = false;
  ModalRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    _sync = ref.read(chatSyncProvider);
    _system = ref.read(systemNotifierProvider.notifier);
    _sync.addListener(_preserveAnchor);
    _scroll.addListener(_fetchOlder);
    Future.microtask(_initialize);
  }

  Future<void> _initialize() async {
    try {
      final extra = widget.extra is Map
          ? widget.extra as Map
          : <String, dynamic>{};
      final supplied = extra['chatRoom'];
      final id = supplied is Chatroom
          ? supplied.id
          : extra['chatRoomId'] as String?;
      final dio = ref.read(dioProvider);
      if (id == null && extra['userId'] == null) {
        throw const FormatException('Missing chatroom parameters');
      }
      final response = id != null
          ? await dio.get('/api/chatroom/$id')
          : await dio.post(
              '/api/chatroom/create',
              data: {
                for (final key in [
                  'accountId',
                  'productId',
                  'productVariantId',
                  'orderId',
                ])
                  key: extra[key],
              },
            );
      if (!mounted) return;
      if (response.data['success'] != true) throw Exception('無法開啟聊天室');
      _room = Chatroom.fromApiResponseMap(
        Map<String, dynamic>.from(response.data['data']),
      );
      _sync.openRoom(_room!.id);
      _setVisible(_route?.isCurrent ?? true);
      setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = '無法開啟聊天室，請稍後重試';
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route != _route) {
      chatRouteObserver.unsubscribe(this);
      _route = route;
      chatRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() => _setVisible(false);
  @override
  void didPop() => _setVisible(false);
  @override
  void didPopNext() {
    _setVisible(true);
    // Product/order/delivery changes do not emit chat revisions in this release.
    unawaited(_refreshMetadata());
  }

  Future<void> _refreshMetadata() async {
    final id = _room?.id;
    if (id == null) return;
    try {
      final response = await ref.read(dioProvider).get('/api/chatroom/$id');
      if (mounted && response.data['success'] == true) {
        setState(() {
          _room = Chatroom.fromApiResponseMap(
            Map<String, dynamic>.from(response.data['data']),
          );
        });
      }
    } catch (_) {}
  }

  void _setVisible(bool value) {
    _visible = value;
    final id = _room?.id;
    if (id == null) return;
    if (value) {
      _sync.setVisibleRoom(id, owner: this);
      _system.setCurrentChatRoomId(id);
    } else if (identical(_sync.visibleOwner, this)) {
      _sync.setVisibleRoom(null, owner: this);
      _system.setCurrentChatRoomId(null);
    }
  }

  void _fetchOlder() {
    if (!_scroll.hasClients || !_visible || _room == null) return;
    final history = _sync.histories[_room!.id];
    if (history == null ||
        !history.loaded ||
        history.loading ||
        history.loadingOlder ||
        history.olderError != null) {
      return;
    }
    if (history.hasMore && _scroll.position.extentAfter < 200) {
      unawaited(_sync.loadHistory(_room!.id, older: true));
    }
  }

  void _preserveAnchor() {
    if (!mounted || !_scroll.hasClients || _adjusting) return;
    final nearLatest = _scroll.offset < 60;
    final messages = _sync.histories[_room?.id]?.sorted ?? [];
    final latest = messages.isEmpty ? null : messages.first.id;
    if (!nearLatest && _latestId != null && latest != _latestId) {
      setState(() {
        _newMessages = true;
      });
    }
    _latestId = latest;
    GlobalKey? anchor;
    double? previousY;
    if (!nearLatest) {
      final height = MediaQuery.sizeOf(context).height;
      for (final key in _messageKeys.values) {
        final box = key.currentContext?.findRenderObject();
        if (box is RenderBox && box.hasSize) {
          final y = box.localToGlobal(Offset.zero).dy;
          if (y >= 100 && y < height - 150) {
            anchor = key;
            previousY = y;
            break;
          }
        }
      }
    }
    _adjusting = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _adjusting = false;
      if (!mounted || !_scroll.hasClients) return;
      if (nearLatest) {
        _scroll.jumpTo(_scroll.position.minScrollExtent);
      } else {
        final box = anchor?.currentContext?.findRenderObject();
        if (box is RenderBox && box.hasSize && previousY != null) {
          final delta = box.localToGlobal(Offset.zero).dy - previousY;
          _scroll.jumpTo(
            (_scroll.offset - delta).clamp(
              _scroll.position.minScrollExtent,
              _scroll.position.maxScrollExtent,
            ),
          );
        }
      }
      _fetchOlder();
    });
  }

  @override
  void dispose() {
    chatRouteObserver.unsubscribe(this);
    _sync.removeListener(_preserveAnchor);
    final id = _room?.id;
    if (id != null) {
      final system = _system;
      final wasVisible = identical(_sync.visibleOwner, this);
      if (wasVisible) _sync.setVisibleRoom(null, owner: this);
      _sync.closeRoom(id);
      // Defer provider mutation until widget teardown has finished.
      if (wasVisible) {
        Future.microtask(() {
          if (!_sync.isDisposed && _sync.visibleOwner == null) {
            system.setCurrentChatRoomId(null);
          }
        });
      }
    }
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sync = ref.watch(chatSyncProvider);
    final room = _room;
    _messageKeys.removeWhere(
      (id, key) =>
          !(sync.histories[room?.id]?.messages.containsKey(id) ?? false),
    );
    final history = room == null ? null : sync.histories[room.id];
    final extra = widget.extra is Map ? widget.extra as Map : {};
    Widget content;
    if (_error != null || history?.removed == true) {
      content = Center(child: Text(_error ?? '此聊天室已無法存取'));
    } else if (room == null || history == null || !history.loaded) {
      final error = history?.error;
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (error == null) const CircularProgressIndicator(),
            Text(error ?? (sync.connected ? '載入訊息中……' : '正在連線……')),
            if (error != null)
              TextButton(
                onPressed: () => sync.loadHistory(room!.id),
                child: const Text('重試'),
              ),
            if (sync.connectionStatus == 'unauthorized' ||
                sync.connectionStatus == 'unavailable')
              const Text('聊天室連線不可用，請重新登入或稍後再試'),
          ],
        ),
      );
    } else {
      final messages = history.sorted;
      final pending = (sync.drafts[room.id] ?? []).reversed.toList();
      final keys = [
        for (final draft in pending) 'draft:${draft.id}',
        for (final message in messages) message.id,
      ];
      content = Column(
        children: [
          if (!sync.connected)
            const Padding(
              padding: EdgeInsets.all(6),
              child: Text('連線中斷，正在重新連線……'),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              reverse: true,
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: keys.length + 1,
              findChildIndexCallback: (key) {
                final i = keys.indexOf((key as ValueKey<String>).value);
                return i < 0 ? null : i;
              },
              itemBuilder: (context, index) {
                if (index == keys.length) {
                  return PaginationFooter(
                    loading: history.loadingOlder,
                    hasError: history.olderError != null,
                    label: '載入較舊訊息',
                    onLoadMore: history.hasMore || history.olderError != null
                        ? () => sync.loadHistory(room.id, older: true)
                        : null,
                  );
                }
                if (index < pending.length) {
                  final draft = pending[index];
                  return Column(
                    key: ValueKey(keys[index]),
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ChatMessageWidget(
                        deliveryStatus: draft.error == null ? '發送中' : '傳送失敗',
                        message: ChatMessage(
                          id: 'pending',
                          chatRoomId: room.id,
                          senderType: ChatMessageSenderType.user,
                          content: draft.content.isEmpty
                              ? '${draft.files.length} 個附件'
                              : draft.content,
                          isRead: false,
                          createdAt: draft.createdAt,
                        ),
                      ),
                      if (draft.error != null)
                        TextButton(
                          onPressed: draft.sending || !draft.retryable
                              ? null
                              : () => sync.retrySend(room.id, draft),
                          child: Text(
                            draft.retryable
                                ? '${draft.error}（重試）'
                                : draft.error!,
                          ),
                        ),
                    ],
                  );
                }
                final message = messages[index - pending.length];
                return Align(
                  key: ValueKey(keys[index]),
                  alignment: message.senderType == ChatMessageSenderType.user
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: SizedBox(
                    key: _messageKeys.putIfAbsent(message.id, GlobalKey.new),
                    child: ChatMessageWidget(message: message),
                  ),
                );
              },
            ),
          ),
          if (_newMessages)
            TextButton(
              onPressed: () {
                _scroll.jumpTo(0);
                setState(() {
                  _newMessages = false;
                });
              },
              child: const Text('有新訊息，回到最新'),
            ),
          ChatInputWidget(
            disabled: false,
            onSubmit: (content, files) {
              unawaited(sync.send(room.id, content, files));
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
              });
              FocusScope.of(context).unfocus();
            },
          ),
        ],
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetchOlder();
      });
    }
    return AppScaffold(
      resizeToAvoidBottomInset: true,
      appBar: SimpleAppBar(
        title: extra['title'] as String? ?? room?.product?.name ?? '聊天室',
        subtitle:
            room?.variantDisplayName ??
            (extra['chatRoom'] is Chatroom
                ? (extra['chatRoom'] as Chatroom).variantDisplayName
                : null) ??
            extra['variantName'] as String?,
      ),
      dismissKeyboardOnTap: true,
      body: SafeArea(child: content),
    );
  }
}
