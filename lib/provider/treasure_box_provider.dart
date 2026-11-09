// lib/treasure_box_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Ref;
import 'dart:developer';
import 'package:flutter_ad_ecommerce/provider/app_badge_provider.dart';

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
  Future<void> _workTail = Future.value();
  int _pendingWork = 0;
  final _pendingBoxIds = <String>{};
  List<TreasureBox>? _confirmedBoxes;
  AppFailure? _loadError;
  bool _disposed = false;
  int? _optimisticClaimableCount;
  Object? _badgeAtLastOpenCompletion;

  /// Homepage-only count. Keep the local result until a new badge snapshot
  /// arrives after the queued opens finish; never mutate the native badge.
  int? get optimisticClaimableBoxCount {
    final badge = ref.read(appBadgeProvider).snapshot;
    if (_pendingBoxIds.isEmpty &&
        badge != null &&
        !identical(badge, _badgeAtLastOpenCompletion)) {
      return null;
    }
    return _optimisticClaimableCount;
  }

  @override
  CustomAsyncValue<List<TreasureBox>> build() {
    ref.onDispose(() => _disposed = true);
    return CustomAsyncValue.initial();
  }

  Future<T> _enqueue<T>(Future<T> Function() work, {String? boxId}) {
    final keepAlive = ref.keepAlive();
    if (_pendingWork == 0) _confirmedBoxes = state.data;
    _pendingWork++;
    if (boxId != null) _pendingBoxIds.add(boxId);
    final future = _workTail.then((_) async {
      try {
        return await work();
      } finally {
        if (boxId != null) {
          _pendingBoxIds.remove(boxId);
          if (!_disposed) {
            _badgeAtLastOpenCompletion = ref.read(appBadgeProvider).snapshot;
          }
        }
        _pendingWork--;
        if (!_disposed) _publish();
        keepAlive.close();
      }
    });
    _workTail = future.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    _publish();
    return future;
  }

  void _publish() {
    if (_pendingWork == 0) {
      state = _loadError != null
          ? CustomAsyncValue.error(_loadError)
          : CustomAsyncValue.done(_confirmedBoxes ?? []);
      return;
    }
    final boxes = _confirmedBoxes;
    state = boxes == null
        ? CustomAsyncValue.loading()
        : CustomAsyncValue.processing(
            boxes
                .map(
                  (box) => _pendingBoxIds.contains(box.id)
                      ? box.copyWith(isOpened: true)
                      : box,
                )
                .toList(),
          );
  }

  // Reads share the queue with opens, preventing older lists from undoing them.
  Future<void> loadTreasureBoxes({bool keepPreviousData = true}) =>
      _enqueue(_fetchTreasureBoxes);

  Future<void> _fetchTreasureBoxes() async {
    if (_disposed) return;
    try {
      final response = await ref.read(dioProvider).get('/api/treasureBox/list');
      if (_disposed) return;
      final data = response.data;
      if (response.statusCode != 200 ||
          data['success'] != true ||
          data['data'] is! List) {
        throw Exception('Failed to get treasure boxes');
      }
      _confirmedBoxes = List.generate(
        10,
        (index) => index < data['data'].length
            ? TreasureBox.fromMap(data['data'][index])
            : TreasureBox.zero(),
      );
      _loadError = null;
    } catch (e) {
      _loadError = AppFailure.from(e);
      log('Error loading treasureBoxes: $e');
    }
  }

  /// Queue distinct boxes immediately, while suppressing duplicate opens.
  Future<Result<double>> openBox(String boxId) {
    if (_pendingBoxIds.contains(boxId)) {
      return Future.value(Result.failure('processing'));
    }
    final target = state.data?.firstWhereOrNull((box) => box.id == boxId);
    if (target == null || !target.isClaimable || target.isOpened) {
      return Future.value(Result.failure('target not available'));
    }
    final count =
        optimisticClaimableBoxCount ??
        ref.read(appBadgeProvider).snapshot?.claimableUnopenedBoxes ??
        state.data!.where((box) => box.isClaimable && !box.isOpened).length;
    final deducted = count > 0;
    _optimisticClaimableCount = deducted ? count - 1 : 0;
    return _enqueue(() async {
      if (_disposed) return Result.failure<double>('target not available');
      // A queued refresh may have found this box expired or opened elsewhere.
      final latest = _confirmedBoxes?.firstWhereOrNull(
        (box) => box.id == boxId,
      );
      if (latest == null || !latest.isClaimable || latest.isOpened) {
        return Result.failure<double>('target not available');
      }
      try {
        final response = await ref
            .read(dioProvider)
            .post('/api/treasureBox/open/$boxId');
        if (_disposed) return Result.failure<double>('target not available');
        if (response.data['success'] != true) throw Exception('Request failed');
        final opened = TreasureBox.fromMap(response.data['data']);
        _confirmedBoxes = _confirmedBoxes!
            .map((box) => box.id == boxId ? opened : box)
            .toList();
        // Await these reads so later opens cannot race earlier balance responses.
        await ref.read(accountNotifierProvider.notifier).refreshAccountInfo();
        return Result.success(
          ParseUtils.parseDouble(response.data['data']['coinsAwarded']) ?? 0,
        );
      } catch (e) {
        log('Failed to open treasure box: $e');
        if (!_disposed) {
          // Reconcile the server state, including ambiguous network failures.
          // Other queued boxes keep their optimistic appearance during this read.
          await _fetchTreasureBoxes();
          if (deducted &&
              _confirmedBoxes!.any(
                (box) => box.id == boxId && box.isClaimable && !box.isOpened,
              )) {
            _optimisticClaimableCount = (_optimisticClaimableCount ?? 0) + 1;
          }
          if (!_disposed &&
              e is DioException &&
              e.response?.statusCode == 400) {
            await ref
                .read(accountNotifierProvider.notifier)
                .refreshAccountInfo();
          }
        }
        return Result.failure<double>(
          e is DioException ? getDioExceptionMessage(e) : AppFailure.from(e),
        );
      }
    }, boxId: boxId);
  }
}

/// Computed provider that calculates the number of claimable treasure boxes
@riverpod
int claimableTreasureBoxCount(Ref ref) {
  return ref.watch(appBadgeProvider).snapshot?.claimableUnopenedBoxes ?? 0;
}

/// Computed provider that calculates the total amount of all opened treasure boxes
@riverpod
double totalOpenedBoxAmount(Ref ref) {
  final treasureBoxes = ref.watch(treasureBoxNotifierProvider).data ?? [];
  return treasureBoxes
      .where((box) => box.isOpened)
      .fold(0, (sum, box) => sum + (box.coinsAwarded ?? 0));
}

/// Computed provider that calculates the number of empty treasure boxes
@riverpod
int emptyTreasureBoxCount(Ref ref) {
  final treasureBoxes = ref.watch(treasureBoxNotifierProvider).data ?? [];
  // Opened boxes become non-claimable after accounting, but are not empty slots.
  return treasureBoxes.where((box) => !box.isClaimable && !box.isOpened).length;
}
