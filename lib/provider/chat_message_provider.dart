import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/models/chatroom.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/utils/custom_async_value.dart';
import 'package:flutter_ad_ecommerce/utils/exception_handler.dart';
import 'package:flutter_ad_ecommerce/utils/file_utils.dart';
import 'package:flutter_ad_ecommerce/utils/parse_utils.dart';
import 'package:flutter_ad_ecommerce/utils/result.dart';
import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'chat_message_provider.g.dart';

final _customLimit = 9999;

@Riverpod()
class ChatMessageNotifier extends _$ChatMessageNotifier {
  int _page = 1;
  int _limit = _customLimit;

  @override
  CustomAsyncValue<ChatMessagePagination> build() {
    // Start with an empty list - products will be loaded from API
    return CustomAsyncValue.initial();
  }

  void reset() {
    state = CustomAsyncValue.initial();
  }

  Future<void> loadMessages({
    required String chatRoomId,
    Function()? onSuccess,
  }) async {
    try {
      _page = 1;
      _limit = _customLimit;

      state = state.isDone
          ? CustomAsyncValue.fetching(state.data)
          : CustomAsyncValue.loading();
      final response = await ref
          .read(dioProvider)
          .get(
            "/api/chatroom/history/$chatRoomId",
            queryParameters: {"page": _page, "limit": _limit},
          );

      final data = response.data;
      if (data['success'] != true || data['data']?['messages'] is! List) {
        throw Exception("Failed to get response data");
      }
      final chatMessages = List.generate(data['data']['messages'].length, (
        index,
      ) {
        final map = data['data']['messages'][index];
        return ChatMessage.fromApiResponseMap(map);
      });

      state = CustomAsyncValue.done(
        ChatMessagePagination(
          chatMessages: chatMessages,
          total: ParseUtils.parseInt(data['data']['total']) ?? _limit,
          page: ParseUtils.parseInt(data['data']['page']) ?? 1,
          limit: ParseUtils.parseInt(data['data']['limit']) ?? _limit,
          totalPages: ParseUtils.parseInt(data['data']['totalPages']) ?? 1,
        ),
      );
      if (onSuccess != null) onSuccess();
    } catch (e) {
      log('Error loading messages: $e');
      state = CustomAsyncValue.error(
        e is DioException
            ? getDioExceptionMessage(e)
            : 'Error loading messages: $e',
      );
    }
  }

  Future<void> loadLatestMessages({required String chatRoomId}) async {
    if (!state.isDone || state.data!.chatMessages.isEmpty) return;
    try {
      final latestMessageAt = state.data!.chatMessages[0].createdAt;
      final response = await ref
          .read(dioProvider)
          .get(
            "/api/chatroom/history/$chatRoomId",
            queryParameters: {
              "page": _page,
              "limit": _limit,
              "startAt": latestMessageAt
                  .add(Duration(milliseconds: 100))
                  .toIso8601String(),
            },
          );
      final data = response.data;
      if (data['success'] != true || data['data']?['messages'] is! List) {
        throw Exception("Failed to get response data");
      }
      final latestChatMessages = List.generate(
        data['data']['messages'].length,
        (index) {
          final map = data['data']['messages'][index];
          return ChatMessage.fromApiResponseMap(map);
        },
      );

      if (latestChatMessages.isEmpty) return;

      List<ChatMessage> updatedChatMessages = [
        ...latestChatMessages,
        ...state.data!.chatMessages,
      ];

      // if we get any messages sent from the other side, mark message as read
      if (latestChatMessages.any((msg) => msg.senderType != "user")) {
        markMessageAsRead(chatRoomId: chatRoomId);

        // Also, mark user's message as read
        updatedChatMessages = updatedChatMessages.map((msg) {
          if (msg.senderType == "user" && !msg.isRead) {
            return msg.copyWith(isRead: true);
          }
          return msg;
        }).toList();
      }

      state = CustomAsyncValue.done(
        state.data!.copyWith(
          chatMessages: updatedChatMessages,
          total: state.data!.total + latestChatMessages.length,
        ),
      );
    } catch (e) {
      log('Error loading latest messages: $e');
    }
  }

  Future<Result<bool>> sendMessage({
    required String chatRoomId,
    required String senderType,
    required String content,
    required List<XFile> files,
    Function()? onCompleted,
  }) async {
    if (state.isProcessing) return Result.success();

    try {
      state.data!.chatMessages.insert(
        0,
        ChatMessage.pending(content: content.isNotEmpty ? content : "上傳附件中..."),
      );
      state = CustomAsyncValue.processing(state.data!);

      List<Map<String, dynamic>>? attachments;
      if (files.isNotEmpty) {
        attachments = await _saveAttachments(files, chatRoomId);
      }

      final response = await ref
          .read(dioProvider)
          .post(
            "/api/chatroom/message/$chatRoomId",
            data: {
              "content": content.isNotEmpty ? content : null,
              "senderType": senderType,
              "attachments": attachments,
            },
          );
      if (response.data['success'] != true) {
        throw Exception('訊息發送失敗');
      }

      return Result.success(true);
    } catch (e) {
      log('Failed to send message: $e');
      return Result.failure(
        e is DioException ? getDioExceptionMessage(e) : 'Error: $e',
      );
    } finally {
      state = CustomAsyncValue.done(state.data!);
      await loadMessages(chatRoomId: chatRoomId);
      if (onCompleted != null) onCompleted();
    }
  }

  Future<List<Map<String, dynamic>>> _saveAttachments(
    List<XFile> files,
    String chatRoomId,
  ) async {
    final futures = files.map((file) async {
      String? endpoint;

      if (isXFileImage(file)) {
        endpoint = "/api/file/image/upload";
      } else if (isXFileVideo(file)) {
        endpoint = "/api/file/video/upload";
      } else {
        return null;
      }

      try {
        final formData = FormData.fromMap({
          "file": await MultipartFile.fromFile(file.path, filename: file.name),
          "path": "chat/$chatRoomId",
        });

        final response = await ref
            .read(dioProvider)
            .post(endpoint, data: formData);

        if (response.data['success'] == true) {
          return {
            "url": response.data['data'],
            "mimeType": getXFileMimeType(file),
            "name": file.name,
            "size": await file.length(),
          };
        }
      } catch (e) {
        log('Upload failed for ${file.name}: $e');
      }
      return null;
    });

    final results = await Future.wait(futures);
    return results.whereType<Map<String, dynamic>>().toList();
  }

  Future<Result<Chatroom>> initChatroom({
    required String userId,
    required String accountId,
    String? productId,
    String? orderId,
  }) async {
    reset();
    try {
      final response = await ref
          .read(dioProvider)
          .post(
            "/api/chatroom/create",
            data: {
              "accountId": accountId,
              "productId": productId,
              "orderId": orderId,
            },
          );

      final data = response.data;
      if (data['success'] != true) {
        throw Exception('建立聊天室失敗');
      }
      return Result.success(Chatroom.fromApiResponseMap(data['data']));
    } catch (e) {
      log('Failed to create chatroom: $e');
      return Result.failure(
        e is DioException
            ? getDioExceptionMessage(e)
            : 'Failed to create chatroom: $e',
      );
    }
  }

  Future<Result<Chatroom>> getChatroomById(String chatRoomId) async {
    reset();
    try {
      final response = await ref
          .read(dioProvider)
          .get("/api/chatroom/$chatRoomId");

      final data = response.data;
      if (data['success'] != true) {
        throw Exception('建立聊天室失敗');
      }
      return Result.success(Chatroom.fromApiResponseMap(data['data']));
    } catch (e) {
      log('Failed to find chatroom: $e');
      return Result.failure(
        e is DioException
            ? getDioExceptionMessage(e)
            : 'Failed to find chatroom: $e',
      );
    }
  }

  Future<Result<bool>> markMessageAsRead({
    required String chatRoomId,
    Function()? onCompleted,
  }) async {
    if (state.isProcessing) return Result.success();

    try {
      final response = await ref
          .read(dioProvider)
          .put(
            "/api/chatroom/message/$chatRoomId/read",
            data: {"readerType": "user"},
          );
      if (response.data['success'] != true) {
        throw Exception('訊息發送失敗');
      }

      return Result.success(true);
    } catch (e) {
      log('Failed to send message: $e');
      return Result.failure(
        e is DioException ? getDioExceptionMessage(e) : 'Error: $e',
      );
    } finally {
      if (onCompleted != null) onCompleted();
    }
  }
}
