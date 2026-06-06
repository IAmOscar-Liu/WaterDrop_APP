import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/features/chatroom/widget/chat_input_widget.dart';
import 'package:flutter_ad_ecommerce/features/chatroom/widget/chat_message_widget.dart';
import 'package:flutter_ad_ecommerce/models/chatroom.dart';
import 'package:flutter_ad_ecommerce/provider/chat_message_provider.dart';
import 'package:flutter_ad_ecommerce/provider/system_provider.dart';
import 'package:flutter_ad_ecommerce/utils/parse_utils.dart';
import 'package:flutter_ad_ecommerce/widgets/keyboard_dismiss_on_tap.dart';
import 'package:flutter_ad_ecommerce/widgets/page_status.dart';
import 'package:flutter_ad_ecommerce/widgets/simple_app_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ChatroomPage extends ConsumerStatefulWidget {
  const ChatroomPage({super.key, required this.extra});
  final dynamic extra;

  @override
  ConsumerState<ChatroomPage> createState() => _ChatroomPageState();
}

class _ChatroomPageState extends ConsumerState<ChatroomPage> {
  String? _errorMsg;
  Chatroom? _chatroom;

  Timer? _periodicMessagePoolingTimer;

  @override
  void initState() {
    super.initState();

    if (widget.extra["chatRoom"] != null) {
      Future.delayed(Duration.zero, () async {
        setState(() {
          _chatroom = widget.extra["chatRoom"];
        });
        ref.read(chatMessageNotifierProvider.notifier).reset();
        _loadChatMessages(chatRoomId: _chatroom!.id);
      });
    } else if (widget.extra['chatRoomId'] != null) {
      _initChatRoomByChatRoomId(widget.extra['chatRoomId']);
    } else if (widget.extra is! Map || widget.extra['userId'] == null) {
      // If data is missing, pop immediately
      WidgetsBinding.instance.addPostFrameCallback((_) => context.pop());
    } else {
      _initChatRoom(
        userId: widget.extra['userId'],
        accountId: widget.extra['accountId'],
        productId: widget.extra['productId'],
        orderId: widget.extra['orderId'],
      );
    }
  }

  Future<void> _initChatRoom({
    required String userId,
    String? accountId,
    String? productId,
    String? orderId,
  }) async {
    Future.delayed(Duration.zero, () async {
      final result = await ref
          .read(chatMessageNotifierProvider.notifier)
          .initChatroom(
            userId: userId,
            accountId: accountId,
            productId: productId,
            orderId: orderId,
          );
      if (result.isFailure) {
        setState(() {
          _errorMsg = result.error;
        });
        return;
      }
      setState(() {
        _chatroom = result.data;
      });
      _loadChatMessages(chatRoomId: result.data!.id);
    });
  }

  Future<void> _initChatRoomByChatRoomId(String chatRoomId) async {
    Future.delayed(Duration.zero, () async {
      final result = await ref
          .read(chatMessageNotifierProvider.notifier)
          .getChatroomById(chatRoomId);
      if (result.isFailure) {
        setState(() {
          _errorMsg = result.error;
        });
        return;
      }
      setState(() {
        _chatroom = result.data;
      });
      _loadChatMessages(chatRoomId: result.data!.id);
    });
  }

  void _loadChatMessages({required String chatRoomId}) {
    ref
        .read(chatMessageNotifierProvider.notifier)
        .loadMessages(
          chatRoomId: chatRoomId,
          onSuccess: () {
            _poolLatestMessages(chatRoomId: chatRoomId);
            _markMessageAsRead(chatRoomId: chatRoomId);
          },
        );
    ref.read(systemNotifierProvider.notifier).setCurrentChatRoomId(chatRoomId);
  }

  void _markMessageAsRead({required String chatRoomId}) {
    Future.delayed(Duration.zero, () async {
      ref
          .read(chatMessageNotifierProvider.notifier)
          .markMessageAsRead(chatRoomId: chatRoomId);
    });
  }

  void _poolLatestMessages({required String chatRoomId}) {
    Future.delayed(Duration.zero, () async {
      log("start pooling latest messages for roomId: $chatRoomId");
      _periodicMessagePoolingTimer?.cancel();
      _periodicMessagePoolingTimer = Timer.periodic(Duration(seconds: 15), (
        timer,
      ) {
        ref
            .read(chatMessageNotifierProvider.notifier)
            .loadLatestMessages(chatRoomId: chatRoomId);
      });
    });
  }

  Widget _buildLayout({required Widget child}) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        ref.read(systemNotifierProvider.notifier).setCurrentChatRoomId(null);
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBgColor,
        resizeToAvoidBottomInset: true,
        appBar: SimpleAppBar(
          title:
              ParseUtils.parseString(widget.extra['title']) ??
              _chatroom?.product?.name ??
              '聊天室',
        ),
        body: KeyboardDismissOnTap(child: child),
      ),
    );
  }

  @override
  void dispose() {
    _periodicMessagePoolingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatMessageProvider = ref.watch(chatMessageNotifierProvider);

    if (_errorMsg != null || chatMessageProvider.hasError) {
      return _buildLayout(
        child: PageError('${_errorMsg ?? chatMessageProvider.error}'),
      );
    }

    if (_chatroom == null ||
        chatMessageProvider.isInitial ||
        chatMessageProvider.isLoading) {
      return _buildLayout(child: PageLoading('載入訊息中......'));
    }

    final List<ChatMessage> chatMessages =
        chatMessageProvider.data?.chatMessages ?? [];

    return _buildLayout(
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.only(top: 16),
                reverse: true,
                itemCount: chatMessages.length,
                itemBuilder: (context, index) {
                  final message = chatMessages[index];
                  return Align(
                    alignment: message.senderType != 'user'
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: ChatMessageWidget(message: message),
                  );
                },
              ),
            ),
            ChatInputWidget(
              disabled:
                  chatMessageProvider.isProcessing ||
                  chatMessageProvider.isFetching,
              onSubmit: (value, files) {
                _periodicMessagePoolingTimer?.cancel();
                ref
                    .read(chatMessageNotifierProvider.notifier)
                    .sendMessage(
                      chatRoomId: _chatroom!.id,
                      senderType: "user",
                      content: value,
                      files: files,
                      onCompleted: () =>
                          _poolLatestMessages(chatRoomId: _chatroom!.id),
                    );
                FocusScope.of(context).unfocus();
              },
            ),
          ],
        ),
      ),
    );
  }
}
