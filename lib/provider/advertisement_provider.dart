// lib/provider/advertisement_provider.dart
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/models/advertisement.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/provider/system_provider.dart';
import 'package:flutter_ad_ecommerce/provider/treasure_box_provider.dart';
import 'package:flutter_ad_ecommerce/utils/custom_async_value.dart';
import 'package:flutter_ad_ecommerce/utils/exception_handler.dart';
import 'package:flutter_ad_ecommerce/utils/list_utils.dart';
import 'package:flutter_ad_ecommerce/utils/parse_utils.dart';
import 'package:flutter_ad_ecommerce/utils/result.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'advertisement_provider.g.dart';

@Riverpod()
class AdvertisementNotifier extends _$AdvertisementNotifier {
  // bool _isMarkingAdvertisementAsCompleted = false;

  @override
  CustomAsyncValue<List<Advertisement>> build() {
    // Start with an empty list - advertisements will be loaded from API
    return CustomAsyncValue.initial();
  }

  void reset() {
    state = CustomAsyncValue.initial();
  }

  /// Loads advertisements from the API
  Future<void> loadAdvertisements({required int limit}) async {
    try {
      state = CustomAsyncValue.loading();
      final response = await ref
          .read(dioProvider)
          .get("/api/advertisement/list", queryParameters: {"limit": limit});

      final data = response.data;
      if (data['success'] != true || data['data']?['advertisements'] is! List) {
        throw Exception("Failed to get response data");
      }
      final advertisements = List.generate(
        data['data']['advertisements'].length,
        (index) {
          final map = data['data']['advertisements'][index];
          return Advertisement.fromApiResponse(map, index: index);
        },
      );

      //// just for test empty list
      // final List<Advertisement> advertisements = [];

      state = CustomAsyncValue.done(advertisements);
    } on DioException catch (e) {
      log('Error loading advertisements: $e');
      state = CustomAsyncValue.error(getDioExceptionMessage(e));
    } catch (e) {
      log('Error loading advertisements: $e');
      state = CustomAsyncValue.error('Error loading advertisements: $e');
    }
  }

  void setAdvertisementDuration(String advertisementId, Duration duration) {
    if (state.data == null) return;
    final advertisements = [
      for (final advertisement in state.data!)
        if (advertisement.id == advertisementId)
          advertisement.copyWith(duration: duration)
        else
          advertisement,
    ];
    state = CustomAsyncValue.done(advertisements);
  }

  void setAdvertisementIsLandscape(String advertisementId, bool isLandscape) {
    if (state.data == null) return;
    final advertisements = [
      for (final advertisement in state.data!)
        if (advertisement.id == advertisementId)
          advertisement.copyWith(isLandscape: isLandscape)
        else
          advertisement,
    ];
    state = CustomAsyncValue.done(advertisements);
  }

  Future<Result<bool>> markAdvertisementAsCompleted(
    String advertisementId,
  ) async {
    if (state.isProcessing || state.data == null) {
      return Result.failure('processing');
    }

    final target = state.data!.firstWhereOrNull((p) => p.id == advertisementId);
    if (target == null || target.isCompleted) {
      return Result.failure('target not available');
    }
    try {
      // state = CustomAsyncValue.processing(state.data!);
      state = CustomAsyncValue.processing(
        state.data!
            .map(
              (advertisement) => advertisement.id == advertisementId
                  ? advertisement.copyWith(isCompleted: true)
                  : advertisement,
            )
            .toList(),
      );

      if (!ref.read(systemNotifierProvider).canWatchMoreVideo) {
        throw Exception("Cannot watch more video");
      }

      final response = await ref
          .read(dioProvider)
          .post(
            "/api/treasureBox/video-complete",
            data: {"advertisementId": advertisementId},
          );
      if (response.data['success'] != true) {
        throw Exception('Request failed');
      }

      ref
          .read(systemNotifierProvider.notifier)
          .setDailyVideoStats(
            watchedVideoCount:
                ParseUtils.parseInt(response.data['data']['totalViews']) ?? 0,
            remainingVideoCount:
                ParseUtils.parseInt(response.data['data']['remainingViews']) ??
                0,
            canWatchMoreVideo: response.data['data']['canWatchMore'] == true,
          );

      if (response.data['data']['isAwarded'] == true) {
        ref.read(treasureBoxNotifierProvider.notifier).loadTreasureBoxes();
      }
      return Result.success(response.data['data']['isAwarded'] == true);
    } catch (e) {
      log('Failed to mark advertisement as completed: $e');
      // state = CustomAsyncValue.done(state.data!
      //     .map(
      //       (advertisement) => advertisement.id == advertisementId
      //           ? advertisement.copyWith(isCompleted: false)
      //           : advertisement,
      //     )
      //     .toList());
      return Result.failure(
        e is DioException ? getDioExceptionMessage(e) : '$e',
      );
    } finally {
      state = CustomAsyncValue.done(state.data!);
    }
  }
}

/// Computed provider that returns advertisements filtered by completion status
@riverpod
List<Advertisement> completedAdvertisements(CompletedAdvertisementsRef ref) {
  final advertisements = ref.watch(advertisementNotifierProvider).data ?? [];
  return advertisements
      .where((advertisement) => advertisement.isCompleted)
      .toList();
}

/// Computed provider that returns advertisements that are not completed
@riverpod
List<Advertisement> pendingAdvertisements(PendingAdvertisementsRef ref) {
  final advertisements = ref.watch(advertisementNotifierProvider).data ?? [];
  return advertisements
      .where((advertisement) => !advertisement.isCompleted)
      .toList();
}

/// Computed provider that calculates the total value of all advertisements
@riverpod
double totalAdvertisementsValue(TotalAdvertisementsValueRef ref) {
  final advertisements = ref.watch(advertisementNotifierProvider).data ?? [];
  return advertisements.fold(
    0.0,
    (sum, advertisement) => sum + advertisement.price,
  );
}
