// lib/treasure_box_provider.dart
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/models/treasure_box.dart';
import 'package:flutter_ad_ecommerce/provider/account_provider.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/utils/custom_async_value.dart';
import 'package:flutter_ad_ecommerce/utils/exception_handler.dart';
import 'package:flutter_ad_ecommerce/utils/list_utils.dart';
import 'package:flutter_ad_ecommerce/utils/parse_utils.dart';
import 'package:flutter_ad_ecommerce/utils/result.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'treasure_box_provider.g.dart';

@Riverpod()
class TreasureBoxNotifier extends _$TreasureBoxNotifier {
  // bool _isOpeningTreasureBox = false;

  @override
  CustomAsyncValue<List<TreasureBox>> build() {
    // This is the initial state of our boxes
    return CustomAsyncValue.initial();
  }

  void loadTreasureBoxes({bool keepPreviousData = true}) async {
    try {
      state = (state.isDone && keepPreviousData)
          ? CustomAsyncValue.fetching(state.data)
          : CustomAsyncValue.loading();
      final response = await ref.read(dioProvider).get("/api/treasureBox/list");
      if (response.statusCode != 200) {
        throw Exception("Failed to treasureBoxes");
      }
      final data = response.data;
      if (data['success'] != true || data['data'] is! List) {
        throw Exception("Failed to get response data");
      }
      final treasureBoxes = List.generate(10, (index) {
        if (index < data['data'].length) {
          return TreasureBox.fromMap(data['data'][index]);
        }
        return TreasureBox.zero();
      });

      state = CustomAsyncValue.done(treasureBoxes);
    } on DioException catch (e) {
      log('Error loading treasureBoxes: $e');
      state = CustomAsyncValue.error(getDioExceptionMessage(e));
    } catch (e) {
      log('Error loading treasureBoxes: $e');
      state = CustomAsyncValue.error('Error loading treasureBoxes: $e');
    }
  }

  /// Opens a treasure box if it's claimable.
  /// This method is the "update" functionality for the state.
  Future<Result<double>> openBox(String boxId) async {
    if (state.isProcessing || state.data == null) {
      return Result.failure('processing');
    }

    final target = state.data!.firstWhereOrNull((box) => box.id == boxId);
    if (target == null || !target.isClaimable || target.isOpened) {
      return Result.failure('target not available');
    }
    try {
      state = CustomAsyncValue.processing(
        state.data!
            .map((box) => box.id == boxId ? box.copyWith(isOpened: true) : box)
            .toList(),
      );

      final response = await ref
          .read(dioProvider)
          .post("/api/treasureBox/open/$boxId");
      if (response.data['success'] != true) {
        throw Exception('Request failed');
      }

      ref.read(accountNotifierProvider.notifier).refreshAccountInfo();

      state = CustomAsyncValue.done(
        state.data!
            .map(
              (box) => box.id == boxId
                  ? TreasureBox.fromMap(response.data['data'])
                  : box,
            )
            .toList(),
      );
      return Result.success(
        ParseUtils.parseDouble(response.data['data']['coinsAwarded']) ?? 0,
      );
    } catch (e) {
      log('Failed to open treasure box: $e');
      state = CustomAsyncValue.done(
        state.data!
            .map((box) => box.id == boxId ? box.copyWith(isOpened: false) : box)
            .toList(),
      );
      return Result.failure(
        e is DioException ? getDioExceptionMessage(e) : '$e',
      );
    } finally {
      state = CustomAsyncValue.done(state.data!);
    }
  }
}

/// Computed provider that calculates the number of claimable treasure boxes
@riverpod
int claimableTreasureBoxCount(ClaimableTreasureBoxCountRef ref) {
  final treasureBoxes = ref.watch(treasureBoxNotifierProvider).data ?? [];
  return treasureBoxes.where((box) => box.isClaimable && !box.isOpened).length;
}

/// Computed provider that calculates the total amount of all opened treasure boxes
@riverpod
double totalOpenedBoxAmount(TotalOpenedBoxAmountRef ref) {
  final treasureBoxes = ref.watch(treasureBoxNotifierProvider).data ?? [];
  return treasureBoxes
      .where((box) => box.isOpened)
      .fold(0, (sum, box) => sum + (box.coinsAwarded ?? 0));
}

/// Computed provider that calculates the number of empty treasure boxes
@riverpod
int emptyTreasureBoxCount(EmptyTreasureBoxCountRef ref) {
  final treasureBoxes = ref.watch(treasureBoxNotifierProvider).data ?? [];
  return treasureBoxes.where((box) => !box.isClaimable).length;
}
