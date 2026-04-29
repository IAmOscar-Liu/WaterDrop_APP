// lib/message_provider.dart
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/models/message.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/provider/message_stats_provider.dart';
import 'package:flutter_ad_ecommerce/utils/custom_async_value.dart';
import 'package:flutter_ad_ecommerce/utils/exception_handler.dart';
import 'package:flutter_ad_ecommerce/utils/parse_utils.dart';
import 'package:flutter_ad_ecommerce/utils/result.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'message_provider.g.dart';

final _customLimit = 10;

@Riverpod(keepAlive: true)
class MessageNotifier extends _$MessageNotifier {
  int _page = 1;
  int _limit = _customLimit;
  String? _search;
  String? _type;
  bool? _onlyUnread;

  @override
  CustomAsyncValue<MessagePagination> build() {
    // Start with an empty list - message will be loaded from API
    return CustomAsyncValue.initial();
  }

  void reset() {
    state = CustomAsyncValue.initial();
  }

  Future<void> loadMessages({
    String? search,
    String? type,
    bool? onlyUnread,
    int? minPrice,
    int? maxPrice,
  }) async {
    try {
      _page = 1;
      _limit = _customLimit;
      _search = search;
      _type = type;
      _onlyUnread = onlyUnread;

      state = CustomAsyncValue.loading();
      final response = await ref
          .read(dioProvider)
          .get(
            "/api/notification/list",
            queryParameters: {
              "page": _page,
              "limit": _limit,
              "search": _search,
              "types": _type == null ? null : [_type],
              "onlyUnread": _onlyUnread == true,
            },
          );

      final data = response.data;
      if (data['success'] != true || data['data']?['notifications'] is! List) {
        throw Exception("Failed to get response data");
      }
      final messages = List.generate(data['data']['notifications'].length, (
        index,
      ) {
        final map = data['data']['notifications'][index];
        return Message.fromApiResponseMap(map);
      });

      state = CustomAsyncValue.done(
        MessagePagination(
          messages: messages,
          total: ParseUtils.parseInt(data['data']['total']) ?? _limit,
          page: ParseUtils.parseInt(data['data']['page']) ?? 1,
          limit: ParseUtils.parseInt(data['data']['limit']) ?? _limit,
          totalPages: ParseUtils.parseInt(data['data']['totalPages']) ?? 1,
        ),
      );
    } on DioException catch (e) {
      log('Error loading messages: $e');
      state = CustomAsyncValue.error(getDioExceptionMessage(e));
    } catch (e) {
      log('Error loading messages: $e');
      state = CustomAsyncValue.error('Error loading messages: $e');
    }
  }

  Future<void> fetchMoreMessages() async {
    if (!state.isDone || _page >= (state.data?.totalPages ?? double.infinity)) {
      return;
    }
    _page++;
    try {
      state = CustomAsyncValue.fetching(state.data);
      final response = await ref
          .read(dioProvider)
          .get(
            "/api/notification/list",
            queryParameters: {
              "page": _page,
              "limit": _limit,
              "search": _search,
              "types": _type == null ? null : [_type],
              "onlyUnread": _onlyUnread == true,
            },
          );

      final data = response.data;
      if (data['success'] != true || data['data']?['notifications'] is! List) {
        throw Exception("Failed to get response data");
      }
      final messages = List.generate(data['data']['notifications'].length, (
        index,
      ) {
        final map = data['data']['notifications'][index];
        return Message.fromApiResponseMap(map);
      });

      state = CustomAsyncValue.done(
        MessagePagination(
          messages: [...(state.data?.messages ?? []), ...messages],
          total: ParseUtils.parseInt(data['data']['total']) ?? _limit,
          page: ParseUtils.parseInt(data['data']['page']) ?? 1,
          limit: ParseUtils.parseInt(data['data']['limit']) ?? _limit,
          totalPages: ParseUtils.parseInt(data['data']['totalPages']) ?? 1,
        ),
      );
    } catch (e) {
      log('Error loading collections: $e');
      state = state.data != null
          ? CustomAsyncValue.done(state.data!)
          : CustomAsyncValue.error(
              e is DioException
                  ? getDioExceptionMessage(e)
                  : 'Error loading collections: $e',
            );
    }
  }

  Future<Result<bool>> markAsRead(String messageId) async {
    if (state.isProcessing || state.data == null) {
      return Result.failure('processing');
    }
    try {
      state = CustomAsyncValue.processing(
        state.data!.copyWith(
          messages: state.data!.messages.map((message) {
            if (message.id == messageId) {
              return message.copyWith(isRead: true);
            }
            return message;
          }).toList(),
        ),
      );

      final response = await ref
          .read(dioProvider)
          .post(
            "/api/notification/mark-as-read",
            data: {
              "notificationIds": [messageId],
            },
          );
      if (response.data['success'] != true) {
        throw Exception('Request failed');
      }

      ref.read(messageStatsNotifierProvider.notifier).loadMessageStats();
      final refreshedMessages = await _handleUpdateAftermath();

      state = CustomAsyncValue.done(
        state.data!.copyWith(
          messages: refreshedMessages,
          total: refreshedMessages.length,
          totalPages: (refreshedMessages.length / _limit).ceil(),
        ),
      );
      return Result.success(true);
    } catch (e) {
      log('Failed to mark message as read: $e');
      state = CustomAsyncValue.done(
        state.data!.copyWith(
          messages: state.data!.messages.map((message) {
            if (message.id == messageId) {
              return message.copyWith(isRead: false);
            }
            return message;
          }).toList(),
        ),
      );

      return Result.failure(
        e is DioException ? getDioExceptionMessage(e) : '$e',
      );
    }
  }

  Future<Result<bool>> deleteMessage(String messageId) async {
    if (state.isProcessing || state.data == null) {
      return Result.failure('processing');
    }
    final int targetIndex = state.data!.messages.indexWhere(
      (message) => message.id == messageId,
    );
    if (targetIndex == -1) {
      return Result.failure('target not found');
    }
    final Message target = state.data!.messages.firstWhere(
      (message) => message.id == messageId,
    );
    try {
      state = CustomAsyncValue.processing(
        state.data!.copyWith(
          messages: state.data!.messages
              .where((message) => message.id != messageId)
              .toList(),
        ),
      );

      final response = await ref
          .read(dioProvider)
          .delete(
            "/api/notification",
            data: {
              "notificationIds": [messageId],
            },
          );
      if (response.data['success'] != true) {
        throw Exception('Request failed');
      }

      ref.read(messageStatsNotifierProvider.notifier).loadMessageStats();
      final refreshedMessages = await _handleUpdateAftermath();

      state = CustomAsyncValue.done(
        state.data!.copyWith(
          messages: refreshedMessages,
          total: refreshedMessages.length,
          totalPages: (refreshedMessages.length / _limit).ceil(),
        ),
      );
      return Result.success(true);
    } catch (e) {
      log('Failed to delete message: $e');
      // Revert state
      state = CustomAsyncValue.done(
        state.data!.copyWith(
          messages: [
            ...state.data!.messages.sublist(0, targetIndex),
            target,
            ...state.data!.messages.sublist(targetIndex),
          ],
        ),
      );

      return Result.failure(
        e is DioException ? getDioExceptionMessage(e) : '$e',
      );
    }
  }

  Future<List<Message>> _handleUpdateAftermath() async {
    if (state.data == null) throw Exception('no data');

    // refetch messages with current filters
    final response = await ref
        .read(dioProvider)
        .get(
          "/api/notification/list",
          queryParameters: {
            "page": 1,
            "limit": _page * _limit,
            "search": _search,
            "types": _type == null ? null : [_type],
            "onlyUnread": _onlyUnread == true,
          },
        );
    final data = response.data;
    if (data['success'] != true || data['data']?['notifications'] is! List) {
      throw Exception("Failed to get response data");
    }
    final messages = List.generate(data['data']['notifications'].length, (
      index,
    ) {
      final map = data['data']['notifications'][index];
      return Message.fromApiResponseMap(map);
    });

    return messages;
  }
}
