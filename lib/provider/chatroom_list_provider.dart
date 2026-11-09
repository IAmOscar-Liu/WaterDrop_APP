import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/constants/app_constants.dart';
import 'package:flutter_ad_ecommerce/models/chatroom.dart';
import 'package:flutter_ad_ecommerce/models/chatroom_list.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/utils/custom_async_value.dart';
import 'package:flutter_ad_ecommerce/utils/exception_handler.dart';
import 'package:flutter_ad_ecommerce/utils/parse_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'chatroom_list_provider.g.dart';

const _chatroomLimit = AppConstants.paginationPageSize;

@Riverpod(
  keepAlive: true,
) // `keepAlive: true` makes the provider persist across hot restarts
class ChatroomListNotifier extends _$ChatroomListNotifier {
  int _page = 1;
  int _generation = 0;
  int _limit = _chatroomLimit;

  @override
  CustomAsyncValue<ChatRoomPagination> build() {
    ref.onDispose(() => _generation++);
    return CustomAsyncValue.initial();
  }

  Future<void> loadChatRooms() async {
    final generation = ++_generation;
    final previousData = state.data;
    try {
      _page = 1;
      _limit = _chatroomLimit;

      state = previousData == null
          ? CustomAsyncValue.loading()
          : CustomAsyncValue.fetching(previousData);
      final response = await ref
          .read(dioProvider)
          .get(
            "/api/chatroom/list",
            queryParameters: {"page": _page, "limit": _limit},
          );

      if (generation != _generation) return;
      final data = response.data;
      if (data['success'] != true || data['data']?['rooms'] is! List) {
        throw Exception("Failed to get response data");
      }
      final rooms = List.generate(data['data']['rooms'].length, (index) {
        final map = data['data']['rooms'][index];
        return Chatroom.fromApiResponseMap(map);
      });
      state = CustomAsyncValue.done(
        ChatRoomPagination(
          rooms: rooms,
          total: data['data']['total'],
          page: data['data']['page'],
          limit: data['data']['limit'],
          totalPages: data['data']['totalPages'],
        ),
      );
    } on DioException catch (e) {
      if (generation != _generation) return;
      log('Error loading chatRooms: $e');
      state = previousData == null
          ? CustomAsyncValue.error(AppFailure.from(e))
          : CustomAsyncValue.retained(previousData, e);
    } catch (e) {
      if (generation != _generation) return;
      log('Error loading orders: $e');
      state = previousData == null
          ? CustomAsyncValue.error(AppFailure.from(e))
          : CustomAsyncValue.retained(previousData, e);
    }
  }

  Future<void> fetchMoreChatRooms() async {
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
            "/api/chatroom/list",
            queryParameters: {"page": nextPage, "limit": _limit},
          );

      if (generation != _generation) return;
      final data = response.data;
      if (data['success'] != true || data['data']?['rooms'] is! List) {
        throw Exception("Failed to get response data");
      }
      final chatRooms = List.generate(data['data']['rooms'].length, (index) {
        final map = data['data']['rooms'][index];
        return Chatroom.fromApiResponseMap(map);
      });

      _page = nextPage;
      state = CustomAsyncValue.done(
        ChatRoomPagination(
          rooms: [...(state.data?.rooms ?? []), ...chatRooms],
          total: ParseUtils.parseInt(data['data']['total']) ?? _limit,
          page: ParseUtils.parseInt(data['data']['page']) ?? 1,
          limit: ParseUtils.parseInt(data['data']['limit']) ?? _limit,
          totalPages: ParseUtils.parseInt(data['data']['totalPages']) ?? 1,
        ),
      );
    } catch (e) {
      if (generation != _generation) return;
      log('Error loading chatRooms: $e');
      state = state.data != null
          ? CustomAsyncValue.retained(state.data!, e, pagination: true)
          : CustomAsyncValue.error(
              e is DioException
                  ? getDioExceptionMessage(e)
                  : AppFailure.from(e),
            );
    }
  }
}
