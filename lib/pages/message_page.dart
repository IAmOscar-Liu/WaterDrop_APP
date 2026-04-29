import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/features/message/widgets/message_card.dart';
import 'package:flutter_ad_ecommerce/models/message.dart';
import 'package:flutter_ad_ecommerce/provider/message_provider.dart';
import 'package:flutter_ad_ecommerce/provider/message_stats_provider.dart';
import 'package:flutter_ad_ecommerce/provider/system_provider.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:flutter_ad_ecommerce/widgets/page_status.dart';
import 'package:flutter_ad_ecommerce/widgets/simple_app_bar.dart';
import 'package:flutter_masonry_view/flutter_masonry_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:visibility_detector/visibility_detector.dart';

enum MessageType {
  all("all", "全部"),
  systemAlert("system_alert", "系統通知"),
  orderStatus("order_status", "訂單狀態"),
  promotion("promotion", "促銷優惠"),
  coinsEarned("coins_earned", "賺取金幣"),
  chatMessage("chat_message", "聊天訊息"),
  other("other", "其他");

  const MessageType(this.name, this.label);

  final String name;
  final String label;
}

class MessagePage extends ConsumerStatefulWidget {
  const MessagePage({super.key});

  @override
  ConsumerState<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends ConsumerState<MessagePage> {
  MessageType _type = MessageType.all;
  String _textSearch = '';
  bool _onlyUnread = false;

  @override
  void initState() {
    super.initState();
    _loadMessages(loadStats: true);
  }

  void _loadMessages({bool loadStats = false}) {
    Future.delayed(Duration.zero, () {
      if (loadStats) {
        ref.read(messageStatsNotifierProvider.notifier).loadMessageStats();
      }
      ref
          .read(messageNotifierProvider.notifier)
          .loadMessages(
            type: _type == MessageType.all ? null : _type.name,
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
    return isSelected
        ? ElevatedButton(
            onPressed: () => onSelect(type),
            style: ElevatedButton.styleFrom(
              foregroundColor: AppColors.primaryTextColor,
              backgroundColor: AppColors.navbarIndicatorColor,
              shape: StadiumBorder(),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: buttonChild,
          )
        : OutlinedButton(
            onPressed: () => onSelect(type),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.secondaryTextColor,
              side: BorderSide(color: AppColors.borderColor),
              shape: StadiumBorder(),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: buttonChild,
          );
  }

  Widget _buildSearchButton({required void Function(String) onSelect}) {
    return _textSearch.isNotEmpty
        ? ElevatedButton.icon(
            onPressed: () => onSelect(_textSearch),
            style: ElevatedButton.styleFrom(
              foregroundColor: AppColors.primaryTextColor,
              backgroundColor: AppColors.navbarIndicatorColor,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            icon: const Icon(Icons.search, size: 18),
            label: Text("搜尋：$_textSearch"),
          )
        : OutlinedButton.icon(
            onPressed: () => onSelect(_textSearch),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.secondaryTextColor,
              side: BorderSide(color: AppColors.borderColor),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            icon: const Icon(Icons.search, size: 18),
            label: const Text("關鍵字搜尋"),
          );
  }

  Widget _buildOnlyUnreadButton({required void Function(bool) onSelect}) {
    return _onlyUnread
        ? ElevatedButton.icon(
            onPressed: () => onSelect(false),
            style: ElevatedButton.styleFrom(
              foregroundColor: AppColors.primaryTextColor,
              backgroundColor: AppColors.navbarIndicatorColor,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            icon: const Icon(Icons.check, size: 18),
            label: Text("僅顯示未讀"),
          )
        : OutlinedButton.icon(
            onPressed: () => onSelect(true),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.secondaryTextColor,
              side: BorderSide(color: AppColors.borderColor),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            label: const Text("僅顯示未讀"),
          );
  }

  void _handleMarkAsRead(String messageId) async {
    final result = await ref
        .read(messageNotifierProvider.notifier)
        .markAsRead(messageId);
    if (result.isFailure) {
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(
        SnackBar(
          content: Text('標為已讀失敗，請稍後再試！'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleDeleteMessage(String messageId) async {
    final result = await ref
        .read(messageNotifierProvider.notifier)
        .deleteMessage(messageId);
    if (result.isFailure) {
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(
        SnackBar(
          content: Text('刪除訊息失敗，請稍後再試！'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildLayout({required Widget child}) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        ref.read(systemNotifierProvider.notifier).setIsInMessagePage(false);
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBgColor,
        appBar: SimpleAppBar(
          title: '訊息中心',
          actions: [
            IconButton(
              onPressed: () => _loadMessages(),
              icon: const Icon(Icons.refresh, color: Colors.white),
            ),
          ],
        ),
        body: SafeArea(child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messageProvider = ref.watch(messageNotifierProvider);
    if (messageProvider.isInitial || messageProvider.isLoading) {
      return _buildLayout(child: PageLoading('載入訊息中......'));
    }

    final List<Message> messages = messageProvider.data?.messages ?? [];
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
                    context.push(Routes.textSearch, extra: textSearch).then((
                      value,
                    ) {
                      if (value is String) {
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
                      _buildSearchButton(onSelect: onSelectTextSearch),
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
            Expanded(
              child: messageProvider.hasError
                  ? PageError(
                      "Failed to load messages: ${messageProvider.error}",
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
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.only(left: 8, right: 8, bottom: 16),
                      child: Column(
                        children: [
                          MasonryView(
                            listOfItem: messages,
                            itemPadding: 2,
                            numberOfColumn: 1,
                            itemBuilder: (item) {
                              final Message message = item;

                              final messageCard = Dismissible(
                                key: Key(message.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 4.0,
                                    horizontal: 16.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20.0),
                                  child: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                  ),
                                ),
                                onDismissed: (direction) async {
                                  if (!messageProvider.isProcessing) {
                                    _handleDeleteMessage(message.id);
                                  }
                                },
                                child: MessageCard(
                                  message: message,
                                  onTap: () async {
                                    if (!messageProvider.isProcessing &&
                                        !message.isRead) {
                                      _handleMarkAsRead(message.id);
                                    }
                                    context
                                        .push(
                                          Routes.singleMessageDetails,
                                          extra: {"message": message},
                                        )
                                        .then((value) {
                                          if (value is Map &&
                                              value['reload'] == true) {
                                            _loadMessages(loadStats: true);
                                          }
                                        });
                                  },
                                ),
                              );

                              if (message.id == messages.last.id) {
                                return VisibilityDetector(
                                  key: Key(message.id),
                                  onVisibilityChanged: (visibilityInfo) {
                                    if (visibilityInfo.visibleFraction > 0.2) {
                                      ref
                                          .read(
                                            messageNotifierProvider.notifier,
                                          )
                                          .fetchMoreMessages();
                                    }
                                  },
                                  child: messageCard,
                                );
                              }
                              return messageCard;
                            },
                          ),
                          if (messageProvider.isFetching)
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
