import 'package:flutter_ad_ecommerce/shared/widgets/app_snackbar.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/app_dialog.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/pagination_footer.dart';
import 'dart:async';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/features/message/widgets/message_swipe_actions.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/anchored_list_scroll_controller.dart';
import 'package:flutter_ad_ecommerce/constants/app_constants.dart';
import 'package:flutter_ad_ecommerce/provider/notification_sync_provider.dart';
import 'package:flutter_ad_ecommerce/router/chat_route_observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/features/message/widgets/message_card.dart';
import 'package:flutter_ad_ecommerce/models/api_enums.dart';
import 'package:flutter_ad_ecommerce/models/message.dart';
import 'package:flutter_ad_ecommerce/provider/message_provider.dart';
import 'package:flutter_ad_ecommerce/provider/message_stats_provider.dart';
import 'package:flutter_ad_ecommerce/provider/system_provider.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:flutter_ad_ecommerce/shared/layouts/app_scaffold.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/filter_button.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/page_status.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/search_filter_button.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/simple_app_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:visibility_detector/visibility_detector.dart';

enum MessageType {
  all(null, "全部"),
  systemAlert(NotificationType.systemAlert, "系統通知"),
  orderStatus(NotificationType.orderStatus, "訂單狀態"),
  promotion(NotificationType.promotion, "促銷優惠"),
  coinsEarned(NotificationType.coinsEarned, "賺取金幣"),
  chatMessage(NotificationType.chatMessage, "聊天訊息"),
  other(NotificationType.other, "其他");

  const MessageType(this.notificationType, this.label);

  final NotificationType? notificationType;
  final String label;
}

class MessagePage extends ConsumerStatefulWidget {
  const MessagePage({super.key});

  @override
  ConsumerState<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends ConsumerState<MessagePage> with RouteAware {
  NotificationSyncController? _sync;
  NotificationQuery? _query;
  ModalRoute<dynamic>? _route;
  final _scroll = AnchoredListScrollController();
  final _viewportKey = GlobalKey();
  final _messageKeys = <String, GlobalKey>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_route != route && route != null) {
      chatRouteObserver.unsubscribe(this);
      _route = route;
      chatRouteObserver.subscribe(this, route);
    }
    _updateVisibility();
  }

  void _updateVisibility() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _query == null) return;
      _sync!.setQueryVisible(
        _query!,
        _route?.isCurrent ?? true,
        nearTop: !_scroll.hasClients || _scroll.offset < 60,
      );
    });
  }

  @override
  void didPush() => _updateVisibility();
  @override
  void didPushNext() {
    if (_query != null) _sync!.setQueryVisible(_query!, false);
  }

  @override
  void didPop() {
    if (_query != null) _sync!.setQueryVisible(_query!, false);
  }

  @override
  void didPopNext() => _updateVisibility();

  @override
  void dispose() {
    chatRouteObserver.unsubscribe(this);
    if (_query != null) _sync!.closeQuery(_query!);
    _scroll.dispose();
    super.dispose();
  }

  void _fetchMore() {
    if (_query != null) {
      _sync!.loadList(_query!, more: true);
    } else {
      ref.read(messageNotifierProvider.notifier).fetchMoreMessages();
    }
  }

  Widget _listFooter({bool allowManualLoadMore = false}) {
    final q = _query;
    if (q == null) return const SizedBox.shrink();
    if (!allowManualLoadMore &&
        !q.loading &&
        q.error == null &&
        !q.dirty &&
        q.hasMore) {
      // Infinite scrolling needs no idle button before the loading indicator.
      // Recheck each page even if snapshot holes leave the last row unchanged.
      return VisibilityDetector(
        key: ValueKey(('notification-next-page', q, q.page)),
        onVisibilityChanged: (info) {
          if (mounted &&
              identical(_query, q) &&
              info.visibleFraction > 0 &&
              q.error == null) {
            _fetchMore();
          }
        },
        child: const SizedBox(height: 1, width: double.infinity),
      );
    }
    return PaginationFooter(
      loading: q.loading,
      hasError: q.error != null,
      error: q.failure,
      label: q.dirty ? '更新搜尋結果' : '載入更多',
      onLoadMore:
          q.error != null || q.dirty || (allowManualLoadMore && q.hasMore)
          ? () => _sync!.loadList(
              q,
              more: q.error != null ? q.retryMore : !q.dirty && q.hasMore,
            )
          : null,
    );
  }

  MessageType _type = MessageType.all;
  String _textSearch = '';
  bool _onlyUnread = false;
  bool _selectionMode = false;
  bool _busy = false;
  bool _confirmingDelete = false;
  final _selectedIds = <String>{};
  String? _openMessageId;

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    if (_busy) return;
    if (!_selectedIds.contains(id) && _selectedIds.length >= 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBar(
          kind: AppSnackBarKind.info,
          content: Text('一次最多可選取 200 則訊息'),
        ),
      );
      return;
    }
    setState(() {
      _selectionMode = true;
      _openMessageId = null;
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
    });
  }

  Future<void> _deleteMessages(
    Iterable<String> messageIds, {
    bool requireConfirmation = true,
  }) async {
    if (_busy || _confirmingDelete) return;
    final ids = messageIds.toSet();
    if (ids.isEmpty) return;
    if (requireConfirmation) {
      _confirmingDelete = true;
      final confirmed = await showAppDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.dialogBgColor,
          title: const Text(
            '刪除訊息',
            style: TextStyle(color: AppColors.primaryTextColor),
          ),
          content: Text(
            '確定要刪除這 ${ids.length} 則訊息嗎？',
            style: const TextStyle(color: AppColors.primaryTextColor),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryTextColor,
              ),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.dangerButtonColor,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('刪除'),
            ),
          ],
        ),
      );
      _confirmingDelete = false;
      if (!mounted || confirmed != true) return;
    }
    if (_sync != null) ids.removeWhere(_sync!.unavailable);
    if (ids.isEmpty) return;
    setState(() {
      _busy = true;
      _openMessageId = null;
    });
    final result = _sync != null
        ? await _sync!.deleteMany(ids)
        : await ref.read(messageNotifierProvider.notifier).deleteMessages(ids);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.isSuccess) {
        _selectedIds.clear();
        _selectionMode = false;
      }
    });
    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBar(
          kind: AppSnackBarKind.success,
          content: Text(ids.length == 1 ? '訊息已刪除' : '已刪除 ${ids.length} 則訊息'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBar(
          kind: AppSnackBarKind.error,
          content: Text(result.error ?? '刪除訊息失敗，請稍後再試'),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    if (AppConstants.notificationSseEnabled) {
      _sync = ref.read(notificationSyncProvider);
      _query = _sync!.openQuery();
      _scroll.addListener(_updateVisibility);
    }
    _loadMessages(loadStats: true);
  }

  void _loadMessages({bool loadStats = false, bool forceRefresh = false}) {
    if (forceRefresh && _sync == null) {
      ref.read(messageNotifierProvider.notifier).invalidateCache();
    }
    _selectedIds.clear();
    _openMessageId = null;
    Future.delayed(Duration.zero, () {
      if (!mounted) return;
      if (_sync != null) {
        final old = _query!;
        if (old.type != _type.notificationType ||
            old.search != _textSearch ||
            old.onlyUnread != _onlyUnread) {
          _sync!.closeQuery(old);
          _query = _sync!.openQuery(
            type: _type.notificationType,
            search: _textSearch,
            onlyUnread: _onlyUnread,
          );
          if (_scroll.hasClients) _scroll.jumpTo(0);
        }
        _sync!.setQueryVisible(_query!, _route?.isCurrent ?? true);
        unawaited(_sync!.loadList(_query!, reuseExisting: !forceRefresh));
        if (loadStats) unawaited(_sync!.loadStats());
        setState(() {});
        return;
      }
      if (loadStats) {
        ref.read(messageStatsNotifierProvider.notifier).loadMessageStats();
      }
      ref
          .read(messageNotifierProvider.notifier)
          .loadMessages(
            reuseExisting: !forceRefresh,
            type: _type.notificationType,
            search: _textSearch.isEmpty ? null : _textSearch,
            onlyUnread: _onlyUnread,
          );
      ref.read(systemNotifierProvider.notifier).setIsInMessagePage(true);
    });
  }

  Widget _buildTypeButton(
    MessageType type, {
    required bool isSelected,
    required void Function(MessageType) onSelect,
    required int count,
  }) {
    Widget buttonChild = count > 0
        ? Row(
            children: [
              Text(type.label),
              SizedBox(width: 4),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          )
        : Text(type.label);
    return FilterButton(
      preserveStyleWhenDisabled: true,
      isSelected: isSelected,
      onPressed: _busy ? null : () => onSelect(type),
      child: buttonChild,
    );
  }

  Widget _buildOnlyUnreadButton({required ValueChanged<bool> onSelect}) {
    return FilterButton(
      preserveStyleWhenDisabled: true,
      isSelected: _onlyUnread,
      onPressed: _busy ? null : () => onSelect(!_onlyUnread),
      icon: _onlyUnread ? const Icon(Icons.check, size: 18) : null,
      child: const Text("僅顯示未讀"),
    );
  }

  void _handleMarkAsRead(String messageId) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _openMessageId = null;
    });
    final result = _sync != null
        ? await _sync!.markRead(messageId)
        : await ref
              .read(messageNotifierProvider.notifier)
              .markAsRead(messageId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.isFailure) {
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(
        AppSnackBar(
          content: Text('標為已讀失敗，請稍後再試！'),
          kind: AppSnackBarKind.error,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildLayout({required Widget child}) {
    return PopScope(
      canPop: !_selectionMode && !_busy,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (_selectionMode && !_busy) _exitSelection();
          return;
        }
        if (_sync == null) {
          ref.read(systemNotifierProvider.notifier).setIsInMessagePage(false);
        }
      },
      child: AppScaffold(
        appBar: SimpleAppBar(
          title: _selectionMode ? '選取訊息' : '訊息中心',
          leading: _selectionMode
              ? IconButton(
                  tooltip: '取消選取',
                  onPressed: _busy ? null : _exitSelection,
                  icon: const BackButtonIcon(),
                )
              : null,
          subtitle: _sync != null && !_sync!.connected ? '訊息正在重新連線……' : null,
          actions: [
            if (_selectionMode) ...[
              IconButton(
                tooltip: '刪除所選訊息',
                disabledColor: _selectedIds.isNotEmpty
                    ? AppColors.primaryTextColor
                    : null,
                onPressed: _busy || _selectedIds.isEmpty
                    ? null
                    : () => _deleteMessages(_selectedIds.toList()),
                icon: const Icon(Icons.delete_outline),
              ),
            ] else
              IconButton(
                tooltip: '編輯訊息',
                disabledColor: AppColors.primaryTextColor,
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _selectionMode = true;
                        _openMessageId = null;
                      }),
                icon: const Icon(Icons.edit_outlined),
              ),
            if (_sync == null)
              IconButton(
                onPressed: _busy
                    ? null
                    : () => _loadMessages(forceRefresh: true),
                icon: const Icon(Icons.refresh, color: Colors.white),
              ),
          ],
        ),
        useSafeArea: true,
        body: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sync = AppConstants.notificationSseEnabled
        ? ref.watch(notificationSyncProvider)
        : null;
    final messageProvider = sync != null
        ? sync.listValue(_query!)
        : ref.watch(messageNotifierProvider);

    final List<Message> messages = messageProvider.data?.messages ?? [];
    if (!_busy) _selectedIds.retainAll(messages.map((message) => message.id));
    final allSelected =
        messages.isNotEmpty &&
        messages
            .take(200)
            .every((message) => _selectedIds.contains(message.id));
    _scroll.preserveItems(
      messages.map((m) => m.id),
      _messageKeys,
      _viewportKey,
    );
    final indices = {
      for (var i = 0; i < messages.length; i++) messages[i].id: i,
    };
    if (!_busy) _messageKeys.removeWhere((id, _) => !indices.containsKey(id));
    final keyIndices = {
      for (final entry in _messageKeys.entries)
        if (indices.containsKey(entry.key)) entry.value: indices[entry.key]!,
    };
    final MessageStats? messageStats = ref
        .watch(messageStatsNotifierProvider)
        .data;

    return _buildLayout(
      child: Padding(
        padding: EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                top: 8.0,
                bottom: 4,
              ),
              child: Builder(
                builder: (context) {
                  void onSelect(MessageType type) {
                    setState(() {
                      _type = type;
                    });
                    _loadMessages();
                  }

                  return Row(
                    children: [
                      _buildTypeButton(
                        MessageType.all,
                        isSelected: _type == MessageType.all,
                        onSelect: onSelect,
                        count: messageStats?.total ?? 0,
                      ),
                      const SizedBox(width: 8),
                      _buildTypeButton(
                        MessageType.systemAlert,
                        isSelected: _type == MessageType.systemAlert,
                        onSelect: onSelect,
                        count: messageStats?.systemAlert ?? 0,
                      ),
                      const SizedBox(width: 8),
                      _buildTypeButton(
                        MessageType.orderStatus,
                        isSelected: _type == MessageType.orderStatus,
                        onSelect: onSelect,
                        count: messageStats?.orderStatus ?? 0,
                      ),
                      const SizedBox(width: 8),
                      _buildTypeButton(
                        MessageType.promotion,
                        isSelected: _type == MessageType.promotion,
                        onSelect: onSelect,
                        count: messageStats?.promotion ?? 0,
                      ),
                      const SizedBox(width: 8),
                      // _buildTypeButton(
                      //   MessageType.coinsEarned,
                      //   isSelected: _type == MessageType.coinsEarned,
                      //   onSelect: onSelect,
                      //   count: messageStats?.coinsEarned ?? 0,
                      // ),
                      // const SizedBox(width: 8),
                      // _buildTypeButton(
                      //   MessageType.chatMessage,
                      //   isSelected: _type == MessageType.chatMessage,
                      //   onSelect: onSelect,
                      //   count: messageStats?.chatMessage ?? 0,
                      // ),
                      // const SizedBox(width: 8),
                      _buildTypeButton(
                        MessageType.other,
                        isSelected: _type == MessageType.other,
                        onSelect: onSelect,
                        count: messageStats?.other ?? 0,
                      ),
                    ],
                  );
                },
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(
                left: 16.0,
                right: 16,
                bottom: 4.0,
              ),
              child: Builder(
                builder: (context) {
                  void onSelectTextSearch(String textSearch) {
                    if (_busy) return;
                    context
                        .push(
                          Routes.textSearch,
                          extra: {
                            'textSearch': textSearch,
                            'source': 'message',
                          },
                        )
                        .then((value) {
                          if (mounted && value is String) {
                            setState(() {
                              _textSearch = value;
                            });
                            _loadMessages();
                          }
                        });
                  }

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SearchFilterButton(
                        query: _textSearch,
                        onSelect: onSelectTextSearch,
                      ),
                      const SizedBox(width: 8),
                      _buildOnlyUnreadButton(
                        onSelect: (onlyUnread) {
                          setState(() {
                            _onlyUnread = onlyUnread;
                          });
                          _loadMessages();
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
            if (_selectionMode)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Tooltip(
                      message: allSelected ? '取消所有選取' : '選取已載入訊息（最多 200 則）',
                      child: TextButton.icon(
                        onPressed: _busy || messages.isEmpty
                            ? null
                            : () {
                                final ids = messages
                                    .take(200)
                                    .map((message) => message.id)
                                    .toSet();
                                setState(() {
                                  if (ids.every(_selectedIds.contains)) {
                                    _selectedIds.clear();
                                  } else {
                                    _selectedIds
                                      ..clear()
                                      ..addAll(ids);
                                  }
                                });
                              },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryTextColor,
                        ),
                        icon: Icon(
                          allSelected ? Icons.deselect : Icons.select_all,
                        ),
                        label: Text(allSelected ? '全不選' : '全選'),
                      ),
                    ),
                    Text(
                      '已選取${_selectedIds.length}則',
                      style: const TextStyle(
                        color: AppColors.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            if (messageProvider.hasData &&
                messageProvider.failure != null &&
                !messageProvider.paginationFailed)
              DataRefreshNotice(
                error: messageProvider.failure,
                onRetry: () => _loadMessages(forceRefresh: true),
              ),
            Expanded(
              key: _viewportKey,
              child: messageProvider.isInitial || messageProvider.isLoading
                  ? PageLoading('載入訊息中......')
                  : messageProvider.hasError
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PageError(
                          messageProvider.error,
                          onRetry: () => _loadMessages(),
                        ),
                        if (_sync != null) _listFooter(),
                      ],
                    )
                  : messageProvider.data!.messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.sentiment_dissatisfied,
                            size: 48,
                            color: Colors.white,
                          ),
                          SizedBox(height: 12),
                          Text("目前沒有訊息", style: TextStyle(color: Colors.white)),
                          if (_sync != null)
                            _listFooter(allowManualLoadMore: true),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      findChildIndexCallback: (key) => keyIndices[key],
                      padding: const EdgeInsets.only(
                        left: 8,
                        right: 8,
                        bottom: 16,
                      ),
                      itemCount: messages.length + 1,
                      itemBuilder: (context, index) {
                        if (index == messages.length) {
                          return messageProvider.isFetching
                              ? const PaginationFooter(loading: true)
                              : _sync != null
                              ? _listFooter()
                              : PaginationFooter(
                                  onLoadMore:
                                      messageProvider.data!.page <
                                          messageProvider.data!.totalPages
                                      ? _fetchMore
                                      : null,
                                );
                        }
                        final message = messages[index];

                        final messageCard = MessageSwipeActions(
                          key: ValueKey(message.id),
                          open: _openMessageId == message.id,
                          enabled:
                              !_selectionMode &&
                              !_busy &&
                              !messageProvider.isProcessing,
                          isRead: message.isRead,
                          onOpenChanged: (open) => setState(
                            () => _openMessageId = open ? message.id : null,
                          ),
                          onDelete: () => _deleteMessages([
                            message.id,
                          ], requireConfirmation: false),
                          onMarkRead: () => _handleMarkAsRead(message.id),
                          child: MessageCard(
                            message: message,
                            onLongPress: () => _toggleSelection(message.id),
                            onTap: () async {
                              if (_busy) return;
                              if (_selectionMode) {
                                _toggleSelection(message.id);
                                return;
                              }
                              if (_openMessageId != null) {
                                setState(() => _openMessageId = null);
                                return;
                              }
                              if (_sync == null &&
                                  !messageProvider.isProcessing &&
                                  !message.isRead) {
                                _handleMarkAsRead(message.id);
                              }
                              context
                                  .push(
                                    Routes.singleMessageDetails,
                                    extra: {"message": message},
                                  )
                                  .then((value) {
                                    if (mounted &&
                                        _sync == null &&
                                        value is Map &&
                                        value['reload'] == true) {
                                      _loadMessages(
                                        loadStats: true,
                                        forceRefresh: true,
                                      );
                                    }
                                  });
                            },
                          ),
                        );

                        Widget card = _selectionMode
                            ? Row(
                                children: [
                                  Checkbox(
                                    value: _selectedIds.contains(message.id),
                                    onChanged: _busy
                                        ? null
                                        : (_) => _toggleSelection(message.id),
                                    side: const BorderSide(
                                      color: AppColors.secondaryTextColor,
                                    ),
                                    activeColor: AppColors.infoColor,
                                    checkColor: Colors.black,
                                    semanticLabel: '選取 ${message.title}',
                                  ),
                                  Expanded(child: messageCard),
                                ],
                              )
                            : messageCard;
                        if (index == messages.length - 1) {
                          card = VisibilityDetector(
                            key: Key(message.id),
                            onVisibilityChanged: (visibilityInfo) {
                              if (messageProvider.failure == null &&
                                  visibilityInfo.visibleFraction > 0.2) {
                                _fetchMore();
                              }
                            },
                            child: card,
                          );
                        }
                        return Padding(
                          key: _messageKeys.putIfAbsent(
                            message.id,
                            GlobalKey.new,
                          ),
                          padding: const EdgeInsets.all(2),
                          child: card,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
