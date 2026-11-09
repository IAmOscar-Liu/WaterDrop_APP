// lib/message_provider.dart
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/constants/app_constants.dart';
import 'package:flutter_ad_ecommerce/models/api_enums.dart';
import 'package:flutter_ad_ecommerce/models/message.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/provider/notification_cache_provider.dart';
import 'package:flutter_ad_ecommerce/provider/message_stats_provider.dart';
import 'package:flutter_ad_ecommerce/utils/custom_async_value.dart';
import 'package:flutter_ad_ecommerce/utils/exception_handler.dart';
import 'package:flutter_ad_ecommerce/utils/parse_utils.dart';
import 'package:flutter_ad_ecommerce/utils/result.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'message_provider.g.dart';

const _customLimit = AppConstants.paginationPageSize;

@Riverpod(keepAlive: true)
class MessageNotifier extends _$MessageNotifier {
  int _page = 1;
  int _generation = 0;
  int _limit = _customLimit;
  String? _search;
  NotificationType? _type;
  bool? _onlyUnread;
  void invalidateCache() => _cache.clear();
  final _cache =
      <NotificationQueryKey, ({DateTime fetchedAt, MessagePagination data})>{};
  NotificationQueryKey get _query =>
      (type: _type, search: _search ?? '', onlyUnread: _onlyUnread == true);
  void _remember(MessagePagination data, {DateTime? fetchedAt}) {
    _cache.remove(_query);
    _cache[_query] = (
      fetchedAt: fetchedAt ?? ref.read(notificationCacheClockProvider)(),
      data: data,
    );
    while (_cache.length > 30) {
      _cache.remove(_cache.keys.first);
    }
  }

  @override
  CustomAsyncValue<MessagePagination> build() {
    ref.onDispose(() => _generation++);
    // Start with an empty list - message will be loaded from API
    return CustomAsyncValue.initial();
  }

  void reset() {
    _generation++;
    _cache.clear();
    _page = 1;
    state = CustomAsyncValue.initial();
  }

  Future<void> loadMessages({
    String? search,
    NotificationType? type,
    bool? onlyUnread,
    int? minPrice,
    int? maxPrice,
    bool reuseExisting = false,
  }) async {
    final previousData =
        (search ?? '') == (_search ?? '') &&
            type == _type &&
            (onlyUnread == true) == (_onlyUnread == true)
        ? state.data
        : null;
    final generation = ++_generation;
    try {
      _page = 1;
      _limit = _customLimit;
      _search = search;
      _type = type;
      _onlyUnread = onlyUnread;

      final cached = _cache[_query];
      if (reuseExisting && cached != null) {
        final age = ref
            .read(notificationCacheClockProvider)()
            .difference(cached.fetchedAt);
        if (!age.isNegative && age < notificationCacheDuration) {
          _page = cached.data.page;
          state = CustomAsyncValue.done(cached.data);
          return;
        }
      }
      _cache.remove(_query);

      state = previousData == null
          ? CustomAsyncValue.loading()
          : CustomAsyncValue.fetching(previousData);
      final response = await ref
          .read(dioProvider)
          .get(
            "/api/notification/list",
            queryParameters: {
              "page": _page,
              "limit": _limit,
              "search": _search,
              "types": _type == null ? null : [_type!.wireValue],
              "onlyUnread": _onlyUnread == true,
            },
          );

      if (generation != _generation) return;
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
      _remember(state.data!);
    } on DioException catch (e) {
      if (generation != _generation) return;
      log('Error loading messages: $e');
      state = previousData == null
          ? CustomAsyncValue.error(AppFailure.from(e))
          : CustomAsyncValue.retained(previousData, e);
    } catch (e) {
      if (generation != _generation) return;
      log('Error loading messages: $e');
      state = previousData == null
          ? CustomAsyncValue.error(AppFailure.from(e))
          : CustomAsyncValue.retained(previousData, e);
    }
  }

  Future<void> fetchMoreMessages() async {
    if (!state.isDone || _page >= (state.data?.totalPages ?? double.infinity)) {
      return;
    }
    final generation = _generation;
    final nextPage = _page + 1;
    try {
      state = CustomAsyncValue.fetching(state.data);
      final response = await ref
          .read(dioProvider)
          .get(
            "/api/notification/list",
            queryParameters: {
              "page": nextPage,
              "limit": _limit,
              "search": _search,
              "types": _type == null ? null : [_type!.wireValue],
              "onlyUnread": _onlyUnread == true,
            },
          );

      if (generation != _generation) return;
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

      _page = nextPage;
      state = CustomAsyncValue.done(
        MessagePagination(
          messages: [...(state.data?.messages ?? []), ...messages],
          total: ParseUtils.parseInt(data['data']['total']) ?? _limit,
          page: ParseUtils.parseInt(data['data']['page']) ?? 1,
          limit: ParseUtils.parseInt(data['data']['limit']) ?? _limit,
          totalPages: ParseUtils.parseInt(data['data']['totalPages']) ?? 1,
        ),
      );
      _remember(state.data!, fetchedAt: _cache[_query]?.fetchedAt);
    } catch (e) {
      if (generation != _generation) return;
      log('Error loading collections: $e');
      state = state.data != null
          ? CustomAsyncValue.retained(state.data!, e, pagination: true)
          : CustomAsyncValue.error(
              e is DioException
                  ? getDioExceptionMessage(e)
                  : AppFailure.from(e),
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

      _cache.clear();

      ref.read(messageStatsNotifierProvider.notifier).loadMessageStats();
      final refreshedMessages = await _handleUpdateAftermath();

      state = CustomAsyncValue.done(refreshedMessages);
      _remember(refreshedMessages);
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
        e is DioException ? getDioExceptionMessage(e) : AppFailure.from(e),
      );
    }
  }

  Future<Result<bool>> deleteMessage(String messageId) =>
      deleteMessages([messageId]);

  Future<Result<bool>> deleteMessages(Iterable<String> messageIds) async {
    if (state.isProcessing || state.data == null) {
      return Result.failure('processing');
    }
    final ids = messageIds.toSet();
    if (ids.isEmpty || ids.length > 200) {
      return Result.failure('請選取 1 至 200 則訊息');
    }
    final previous = state.data!;
    final remaining = previous.copyWith(
      messages: previous.messages
          .where((message) => !ids.contains(message.id))
          .toList(),
      total: (previous.total - ids.length).clamp(0, previous.total),
    );
    state = CustomAsyncValue.processing(remaining);
    try {
      final response = await ref
          .read(dioProvider)
          .delete('/api/notification', data: {'notificationIds': ids.toList()});
      if (response.data['success'] != true) throw Exception('Request failed');
      _cache.clear();
    } catch (e) {
      state = CustomAsyncValue.done(previous);
      return Result.failure(
        e is DioException ? getDioExceptionMessage(e) : AppFailure.from(e),
      );
    }
    ref.read(messageStatsNotifierProvider.notifier).loadMessageStats();
    try {
      state = CustomAsyncValue.done(await _handleUpdateAftermath());
      _remember(state.data!);
    } catch (_) {
      // Deletion already committed; a refresh failure must not restore deleted rows.
      state = CustomAsyncValue.done(remaining);
    }
    return Result.success(true);
  }

  Future<MessagePagination> _handleUpdateAftermath() async {
    if (state.data == null) throw Exception('no data');

    // Refresh the loaded pages without increasing the size of any request.
    final loadedPages = _page;
    final messages = <Message>[];
    MessagePagination? refreshed;
    for (var page = 1; page <= loadedPages; page++) {
      final response = await ref
          .read(dioProvider)
          .get(
            '/api/notification/list',
            queryParameters: {
              'page': page,
              'limit': _limit,
              'search': _search,
              'types': _type == null ? null : [_type!.wireValue],
              'onlyUnread': _onlyUnread == true,
            },
          );
      final data = response.data;
      if (data['success'] != true || data['data']?['notifications'] is! List) {
        throw Exception('Failed to get response data');
      }
      final payload = data['data'];
      messages.addAll([
        for (final map in payload['notifications'])
          Message.fromApiResponseMap(map),
      ]);
      refreshed = MessagePagination(
        messages: messages,
        total: ParseUtils.parseInt(payload['total']) ?? messages.length,
        page: page,
        limit: ParseUtils.parseInt(payload['limit']) ?? _limit,
        totalPages: ParseUtils.parseInt(payload['totalPages']) ?? 1,
      );
      if (page >= refreshed.totalPages) break;
    }
    _page = refreshed!.page;
    return refreshed;
  }
}
