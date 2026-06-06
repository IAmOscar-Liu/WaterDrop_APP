import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/models/chatroom.dart';
import 'package:flutter_ad_ecommerce/provider/chatroom_list_provider.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:flutter_ad_ecommerce/utils/formatter.dart';
import 'package:flutter_ad_ecommerce/widgets/initial_image.dart';
import 'package:flutter_ad_ecommerce/widgets/page_status.dart';
import 'package:flutter_ad_ecommerce/widgets/simple_app_bar.dart';
import 'package:flutter_masonry_view/flutter_masonry_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:visibility_detector/visibility_detector.dart';

class ChatroomListPage extends ConsumerStatefulWidget {
  const ChatroomListPage({super.key});

  @override
  ConsumerState<ChatroomListPage> createState() => _ChatroomListPageState();
}

class _ChatroomListPageState extends ConsumerState<ChatroomListPage> {
  @override
  void initState() {
    super.initState();
    _loadChatRooms();
  }

  void _loadChatRooms() {
    Future.delayed(Duration.zero, () {
      ref.read(chatroomListNotifierProvider.notifier).loadChatRooms();
    });
  }

  String _buildLastMessageContent(
    ChatMessage message, {
    bool isSupportChat = false,
  }) {
    if (message.content.isNotEmpty) {
      return "${message.senderType == "user"
          ? "你"
          : isSupportChat
          ? "客服"
          : "賣家"}: ${message.content}";
    } else if (message.attachments != null && message.attachments!.isNotEmpty) {
      return "${message.senderType == "user"
          ? "你"
          : isSupportChat
          ? "客服"
          : "賣家"}: ${message.attachments!.length}個附件";
    }
    return "";
  }

  String _buildDeliveryStatusText(String status) {
    switch (status) {
      case "pending":
        return "待出貨";
      case "shipped":
        return "已出貨";
      case "delivered":
        return "已送達";
      case "ready_for_pickup":
        return "已送達";
      case "returned":
        return "已退回";
      case "cancelled":
        return "已取消";
      case "exception":
        return "發生異常";
      case "unknown":
        return "未知狀態";
      default:
        return status;
    }
  }

  Widget _buildLayout({required Widget child}) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBgColor,
      appBar: SimpleAppBar(
        title: '聊天室',
        actions: [
          IconButton(
            onPressed: () => _loadChatRooms(),
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: SafeArea(child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatRoomProvider = ref.watch(chatroomListNotifierProvider);
    if (chatRoomProvider.isInitial || chatRoomProvider.isLoading) {
      return _buildLayout(child: PageLoading('載入聊天室中......'));
    }

    final List<Chatroom> chatRooms = chatRoomProvider.data?.rooms ?? [];

    return _buildLayout(
      child: Padding(
        padding: EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: chatRoomProvider.hasError
                  ? PageError(
                      "Failed to load chatRooms: ${chatRoomProvider.error}",
                    )
                  : chatRoomProvider.data!.rooms.isEmpty
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
                          Text(
                            "目前沒有聊天室",
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.only(left: 8, right: 8, bottom: 16),
                      child: Column(
                        children: [
                          MasonryView(
                            listOfItem: chatRooms,
                            itemPadding: 2,
                            numberOfColumn: 1,
                            itemBuilder: (item) {
                              final Chatroom chatRoom = item;
                              final bool isSupportChat =
                                  chatRoom.accountId == null;
                              final String chatTitle = isSupportChat
                                  ? "水滴客服"
                                  : chatRoom.product?.name ?? "未知商品";

                              final chatroomCard = GestureDetector(
                                onTap:
                                    !isSupportChat && chatRoom.product == null
                                    ? null
                                    : () {
                                        context
                                            .push(
                                              Routes.chatroomPage,
                                              extra: {
                                                "title": chatTitle,
                                                "chatRoom": chatRoom,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 60,
                                        height: 60,
                                        clipBehavior: Clip.antiAlias,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          color: Colors.grey[800],
                                        ),
                                        child: isSupportChat
                                            ? Image.asset(
                                                "assets/icons/appstore.png",
                                                fit: BoxFit.cover,
                                              )
                                            : (chatRoom.product?.images !=
                                                      null &&
                                                  chatRoom
                                                      .product!
                                                      .images!
                                                      .isNotEmpty)
                                            ? FadeInImage.assetNetwork(
                                                placeholder:
                                                    "assets/images/photo_loading.gif",
                                                image: chatRoom
                                                    .product!
                                                    .images![0],
                                                fit: BoxFit.cover,
                                                imageErrorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) {
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
                                                      color: AppColors
                                                          .primaryTextColor,
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if ((chatRoom.totalUnread ??
                                                        0) >
                                                    0)
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                          left: 8,
                                                        ),
                                                    padding:
                                                        const EdgeInsets.all(6),
                                                    decoration:
                                                        const BoxDecoration(
                                                          color: Colors.red,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                    child: Text(
                                                      chatRoom.totalUnread
                                                          .toString(),
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            if (chatRoom.order?.delivery !=
                                                null) ...[
                                              const SizedBox(height: 2),
                                              Builder(
                                                builder: (context) {
                                                  final delivery =
                                                      chatRoom.order!.delivery!;
                                                  final deliveryText =
                                                      delivery.rtnMsg.isNotEmpty
                                                      ? delivery.rtnMsg
                                                      : "訂單${_buildDeliveryStatusText(delivery.status)}";
                                                  return Text(
                                                    deliveryText,
                                                    style: const TextStyle(
                                                      color:
                                                          AppColors.infoColor,
                                                      fontSize: 12,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  );
                                                },
                                              ),
                                            ],
                                            if (chatRoom.lastMessage !=
                                                null) ...[
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      _buildLastMessageContent(
                                                        chatRoom.lastMessage!,
                                                        isSupportChat:
                                                            isSupportChat,
                                                      ),
                                                      style: const TextStyle(
                                                        color: AppColors
                                                            .secondaryTextColor,
                                                        fontSize: 14,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    Formatter.formatDateTime(
                                                      chatRoom
                                                          .lastMessage!
                                                          .createdAt,
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

                              if (chatRoom.id == chatRooms.last.id) {
                                return VisibilityDetector(
                                  key: Key(chatRoom.id),
                                  onVisibilityChanged: (visibilityInfo) {
                                    if (visibilityInfo.visibleFraction > 0.2) {
                                      ref
                                          .read(
                                            chatroomListNotifierProvider
                                                .notifier,
                                          )
                                          .fetchMoreChatRooms();
                                    }
                                  },
                                  child: chatroomCard,
                                );
                              }
                              return chatroomCard;
                            },
                          ),
                          if (chatRoomProvider.isFetching)
                            Center(child: CircularProgressIndicator()),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
