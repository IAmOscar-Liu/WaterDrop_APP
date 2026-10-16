import 'package:flutter_ad_ecommerce/shared/widgets/pagination_footer.dart';
import 'package:flutter_ad_ecommerce/constants/app_constants.dart';
import 'package:flutter_ad_ecommerce/provider/chat_sync_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/anchored_list_scroll_controller.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/models/api_enums.dart';
import 'package:flutter_ad_ecommerce/models/chatroom.dart';
import 'package:flutter_ad_ecommerce/provider/chatroom_list_provider.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:flutter_ad_ecommerce/shared/layouts/app_scaffold.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/initial_image.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/page_status.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/simple_app_bar.dart';
import 'package:flutter_ad_ecommerce/utils/formatter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:visibility_detector/visibility_detector.dart';

class ChatroomListPage extends ConsumerStatefulWidget {
  const ChatroomListPage({super.key});

  @override
  ConsumerState<ChatroomListPage> createState() => _ChatroomListPageState();
}

class _ChatroomListPageState extends ConsumerState<ChatroomListPage> {
  final _scroll = AnchoredListScrollController();
  final _viewportKey = GlobalKey();
  final _roomKeys = <String, GlobalKey>{};

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadChatRooms();
  }

  void _loadChatRooms() {
    Future.delayed(Duration.zero, () {
      if (!mounted) return;
      if (AppConstants.chatSseEnabled) {
        ref.read(chatSyncProvider).loadList();
      } else {
        ref.read(chatroomListNotifierProvider.notifier).loadChatRooms();
      }
    });
  }

  String _buildLastMessageContent(
    ChatMessage message, {
    bool isSupportChat = false,
  }) {
    if (message.content.isNotEmpty) {
      return "${message.senderType == ChatMessageSenderType.user
          ? "你"
          : isSupportChat
          ? "客服"
          : "賣家"}: ${message.content}";
    } else if (message.attachments != null && message.attachments!.isNotEmpty) {
      return "${message.senderType == ChatMessageSenderType.user
          ? "你"
          : isSupportChat
          ? "客服"
          : "賣家"}: ${message.attachments!.length}個附件";
    }
    return "";
  }

  String _buildDeliveryStatusText(DeliveryStatus status) {
    switch (status) {
      case DeliveryStatus.pending:
        return "待出貨";
      case DeliveryStatus.shipped:
        return "已出貨";
      case DeliveryStatus.delivered:
        return "已送達";
      case DeliveryStatus.readyForPickup:
        return "已送達";
      case DeliveryStatus.returned:
        return "已退回";
      case DeliveryStatus.cancelled:
        return "已取消";
      case DeliveryStatus.exception:
        return "發生異常";
      case DeliveryStatus.unknown:
        return "未知狀態";
    }
  }

  String? _buildChatRoomOrderStatusText(ChatRoomOrder? order) {
    if (order == null) return null;
    if (order.delivery != null) {
      final delivery = order.delivery!;
      return delivery.rtnMsg.isNotEmpty
          ? delivery.rtnMsg
          : "訂單${_buildDeliveryStatusText(delivery.status)}";
    }

    switch (order.orderStatus) {
      case OrderStatus.paymentProcessing:
        return "待付款";
      case OrderStatus.expired:
        return "交易逾期(未付款)";
      default:
        return "交易取消";
    }
  }

  Widget _buildLayout({required Widget child}) {
    final sync = AppConstants.chatSseEnabled
        ? ref.watch(chatSyncProvider)
        : null;
    return AppScaffold(
      appBar: SimpleAppBar(
        title: '聊天室',
        // Status belongs in the fixed-height app bar, so reconnect/error
        // transitions never move the list's viewport.
        subtitle: sync != null && !sync.connected ? '聊天室正在重新連線……' : null,
        actions: [
          if (sync?.listError != null)
            IconButton(
              tooltip: '載入失敗，點擊重試',
              onPressed: () => sync!.loadList(
                more: sync.listValue.hasData && sync.hasMoreRooms,
              ),
              icon: const Icon(Icons.error_outline),
            ),
          if (!AppConstants.chatSseEnabled)
            IconButton(
              onPressed: () => _loadChatRooms(),
              icon: const Icon(Icons.refresh, color: Colors.white),
            ),
        ],
      ),
      useSafeArea: true,
      body: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatRoomProvider = AppConstants.chatSseEnabled
        ? ref.watch(chatSyncProvider).listValue
        : ref.watch(chatroomListNotifierProvider);
    if (chatRoomProvider.isInitial || chatRoomProvider.isLoading) {
      return _buildLayout(child: PageLoading('載入聊天室中......'));
    }

    final List<Chatroom> chatRooms = chatRoomProvider.data?.rooms ?? [];
    _scroll.preserveItems(
      chatRooms.map((room) => room.id),
      _roomKeys,
      _viewportKey,
    );
    final indices = {
      for (var i = 0; i < chatRooms.length; i++) chatRooms[i].id: i,
    };
    _roomKeys.removeWhere((id, _) => !indices.containsKey(id));
    final keyIndices = {
      for (final entry in _roomKeys.entries) entry.value: indices[entry.key]!,
    };

    return _buildLayout(
      child: Padding(
        padding: EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              key: _viewportKey,
              child: chatRoomProvider.hasError
                  ? PageError(
                      "Failed to load chatRooms: ${chatRoomProvider.error}",
                    )
                  : chatRoomProvider.data!.rooms.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          EmptyState("目前沒有聊天室"),
                          if (AppConstants.chatSseEnabled &&
                              ref.watch(chatSyncProvider).hasMoreRooms)
                            PaginationFooter(
                              loading: chatRoomProvider.isFetching,
                              hasError:
                                  ref.watch(chatSyncProvider).listError != null,
                              onLoadMore: () => ref
                                  .read(chatSyncProvider)
                                  .loadList(more: true),
                            ),
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
                      itemCount: chatRooms.length + 1,
                      itemBuilder: (context, index) {
                        if (index == chatRooms.length) {
                          final sync = AppConstants.chatSseEnabled
                              ? ref.watch(chatSyncProvider)
                              : null;
                          final hasMore =
                              sync?.hasMoreRooms ??
                              (chatRoomProvider.data!.page <
                                  chatRoomProvider.data!.totalPages);
                          return PaginationFooter(
                            loading: chatRoomProvider.isFetching,
                            hasError: sync?.listError != null,
                            onLoadMore: hasMore || sync?.listError != null
                                ? () => sync != null
                                      ? sync.loadList(more: hasMore)
                                      : ref
                                            .read(
                                              chatroomListNotifierProvider
                                                  .notifier,
                                            )
                                            .fetchMoreChatRooms()
                                : null,
                          );
                        }
                        final chatRoom = chatRooms[index];
                        final bool isSupportChat = chatRoom.accountId == null;
                        final String chatTitle = isSupportChat
                            ? "水滴客服"
                            : chatRoom.product?.name ?? "未知商品";
                        final variantTitle = chatRoom.variantDisplayName ?? "";
                        final productImages =
                            chatRoom.product?.images ?? const <String>[];
                        final variantImage = chatRoom.product?.variantImage
                            ?.trim();
                        final imageUrl =
                            variantImage != null && variantImage.isNotEmpty
                            ? variantImage
                            : (productImages.isNotEmpty
                                  ? productImages.first
                                  : null);
                        final orderStatusText = _buildChatRoomOrderStatusText(
                          chatRoom.order,
                        );

                        final chatroomCard = GestureDetector(
                          onTap: !isSupportChat && chatRoom.product == null
                              ? null
                              : () {
                                  context
                                      .push(
                                        Routes.chatroomPage,
                                        extra: {
                                          "title": chatTitle,
                                          "chatRoom": chatRoom,
                                          "variantName":
                                              chatRoom.variantDisplayName,
                                        },
                                      )
                                      .then((value) {
                                        _loadChatRooms();
                                      });
                                },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.containerBgColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.borderColor,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.grey[800],
                                  ),
                                  child: isSupportChat
                                      ? Image.asset(
                                          "assets/icons/appstore.png",
                                          fit: BoxFit.cover,
                                        )
                                      : imageUrl != null
                                      ? FadeInImage.assetNetwork(
                                          placeholder:
                                              "assets/images/photo_loading.gif",
                                          image: imageUrl,
                                          fit: BoxFit.cover,
                                          imageErrorBuilder:
                                              (context, error, stackTrace) {
                                                // This builder is used if the network image fails to load.
                                                return Image.asset(
                                                  "assets/images/photo_not_found.jpg",
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                );
                                              },
                                        )
                                      : InitialImage(name: chatTitle),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              chatTitle,
                                              style: const TextStyle(
                                                color:
                                                    AppColors.primaryTextColor,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if ((chatRoom.totalUnread ?? 0) > 0)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                left: 8,
                                              ),
                                              padding: const EdgeInsets.all(6),
                                              decoration: const BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Text(
                                                chatRoom.totalUnread.toString(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (variantTitle.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          variantTitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.secondaryTextColor,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                      if (orderStatusText != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          orderStatusText,
                                          style: const TextStyle(
                                            color: AppColors.infoColor,
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      if (chatRoom.lastMessage != null) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _buildLastMessageContent(
                                                  chatRoom.lastMessage!,
                                                  isSupportChat: isSupportChat,
                                                ),
                                                style: const TextStyle(
                                                  color: AppColors
                                                      .secondaryTextColor,
                                                  fontSize: 14,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              Formatter.formatDateTime(
                                                chatRoom.lastMessage!.createdAt,
                                              ),
                                              style: const TextStyle(
                                                color: AppColors
                                                    .secondaryTextColor,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );

                        Widget card = chatroomCard;
                        if (index == chatRooms.length - 1) {
                          card = VisibilityDetector(
                            key: Key(chatRoom.id),
                            onVisibilityChanged: (visibilityInfo) {
                              if (visibilityInfo.visibleFraction > 0.2) {
                                if (AppConstants.chatSseEnabled) {
                                  ref
                                      .read(chatSyncProvider)
                                      .loadList(more: true);
                                } else {
                                  ref
                                      .read(
                                        chatroomListNotifierProvider.notifier,
                                      )
                                      .fetchMoreChatRooms();
                                }
                              }
                            },
                            child: card,
                          );
                        }
                        return Padding(
                          key: _roomKeys.putIfAbsent(
                            chatRoom.id,
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
