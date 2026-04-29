import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/models/chatroom.dart';
import 'package:flutter_ad_ecommerce/models/chatroom_list.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/utils/custom_async_value.dart';
import 'package:flutter_ad_ecommerce/utils/exception_handler.dart';
import 'package:flutter_ad_ecommerce/utils/parse_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'chatroom_list_provider.g.dart';

final _chatroomLimit = 10;

@Riverpod(
  keepAlive: true,
) // `keepAlive: true` makes the provider persist across hot restarts
class ChatroomListNotifier extends _$ChatroomListNotifier {
  int _page = 1;
  int _limit = _chatroomLimit;

  @override
  CustomAsyncValue<ChatRoomPagination> build() {
    return CustomAsyncValue.initial();
  }

  Future<void> loadChatRooms() async {
    try {
      _page = 1;
      _limit = _chatroomLimit;

      state = CustomAsyncValue.loading();
      final response = await ref
          .read(dioProvider)
          .get(
            "/api/chatroom/list",
            queryParameters: {"page": _page, "limit": _limit},
          );

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
      log('Error loading chatRooms: $e');
      state = CustomAsyncValue.error(getDioExceptionMessage(e));
    } catch (e) {
      log('Error loading orders: $e');
      state = CustomAsyncValue.error('Error loading chatRooms: $e');
    }
  }

  Future<void> fetchMoreChatRooms() async {
    if (!state.isDone || _page >= (state.data?.totalPages ?? double.infinity)) {
      return;
    }
    _page++;
    try {
      state = CustomAsyncValue.fetching(state.data);
      final response = await ref
          .read(dioProvider)
          .get(
            "/api/chatroom/list",
            queryParameters: {"page": _page, "limit": _limit},
          );

      final data = response.data;
      if (data['success'] != true || data['data']?['rooms'] is! List) {
        throw Exception("Failed to get response data");
      }
      final chatRooms = List.generate(data['data']['rooms'].length, (index) {
        final map = data['data']['rooms'][index];
        return Chatroom.fromApiResponseMap(map);
      });

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
      log('Error loading chatRooms: $e');
      state = state.data != null
          ? CustomAsyncValue.done(state.data!)
          : CustomAsyncValue.error(
              e is DioException
                  ? getDioExceptionMessage(e)
                  : 'Error loading chatRooms: $e',
            );
    }
  }
}
