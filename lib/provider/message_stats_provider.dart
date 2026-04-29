import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/models/message.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/utils/custom_async_value.dart';
import 'package:flutter_ad_ecommerce/utils/exception_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'message_stats_provider.g.dart';

@Riverpod(keepAlive: true)
class MessageStatsNotifier extends _$MessageStatsNotifier {
  @override
  CustomAsyncValue<MessageStats> build() {
    // Start with an empty list - message will be loaded from API
    return CustomAsyncValue.initial();
  }

  void reset() {
    state = CustomAsyncValue.initial();
  }

  Future<void> loadMessageStats() async {
    try {
      state = CustomAsyncValue.loading();
      final response = await ref
          .read(dioProvider)
          .get("/api/notification/stats");

      final data = response.data;
      if (data['success'] != true || data['data'] is! Map) {
        throw Exception("Failed to get response data");
      }

      MessageStats stats = MessageStats.fromApiResponseMap(data['data']);

      state = CustomAsyncValue.done(stats);
    } on DioException catch (e) {
      log('Error loading messages: $e');
      state = CustomAsyncValue.error(getDioExceptionMessage(e));
    } catch (e) {
      state = CustomAsyncValue.error('Error loading message stats: $e');
    }
  }
}
