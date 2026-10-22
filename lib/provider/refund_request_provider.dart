import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/models/order.dart';
import 'package:flutter_ad_ecommerce/provider/account_provider.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/utils/exception_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

final refundRequestProvider = Provider<RefundRequestService>((ref) {
  final owner = ref.watch(accountNotifierProvider.select((value) => value.id));
  return RefundRequestService(ref.watch(dioProvider), owner);
});

final pendingRefundProvider = FutureProvider.autoDispose.family<bool, String>((
  ref,
  itemId,
) async {
  return await ref.watch(refundRequestProvider).pending(itemId) != null;
});

/// Stored before sending so a lost response or app restart cannot turn a retry
/// into a second refund. Keys and payloads are scoped to the buyer and item.
class RefundRequestService {
  RefundRequestService(this.dio, this.owner);
  final Dio dio;
  final String owner;
  final Map<String, Future<RefundSubmission>> _inFlight = {};

  String _key(String itemId) => 'refundRequest:$owner:$itemId';

  Future<Map<String, dynamic>?> pending(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key(itemId));
    return stored == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(stored));
  }

  Future<RefundSubmission> submit({
    required String itemId,
    required int quantity,
    String? reason,
    String? note,
  }) {
    return _inFlight.putIfAbsent(
      itemId,
      () =>
          _submit(
            itemId: itemId,
            quantity: quantity,
            reason: reason,
            note: note,
          ).whenComplete(() {
            _inFlight.remove(itemId);
          }),
    );
  }

  Future<RefundSubmission> _submit({
    required String itemId,
    required int quantity,
    String? reason,
    String? note,
  }) async {
    if (owner.isEmpty) return const RefundSubmission(error: '請先登入');
    // Reuse the entire original body, even after the deadline or a seller's
    // decision. The backend returns the current state for matching retries.
    try {
      final prefs = await SharedPreferences.getInstance();
      final body =
          await pending(itemId) ??
          <String, dynamic>{
            'orderItemId': itemId,
            'quantity': quantity,
            if (reason?.trim().isNotEmpty == true) 'reason': reason!.trim(),
            if (note?.trim().isNotEmpty == true) 'note': note!.trim(),
            'clientRequestId': const Uuid().v4(),
          };
      if (!await prefs.setString(_key(itemId), jsonEncode(body))) {
        return const RefundSubmission(error: '無法儲存申請，請稍後再試');
      }
      try {
        final response = await dio.post(
          '/api/refund',
          data: body,
          options: Options(extra: {'authOwner': owner}),
        );
        if (response.data is! Map ||
            response.data['success'] != true ||
            response.data['data'] is! Map) {
          return const RefundSubmission(
            uncertain: true,
            error: '無法確認申請結果，請重試原申請',
          );
        }
        final item = RefundItem.fromApiResponseMap(
          Map<String, dynamic>.from(response.data['data']),
        );
        await prefs.remove(_key(itemId));
        return RefundSubmission(item: item);
      } on DioException catch (error) {
        final status = error.response?.statusCode;
        final data = error.response?.data;
        final code = data is Map
            ? data['code'] ??
                  (data['error'] is Map ? data['error']['code'] : null)
            : null;
        final uncertain =
            ![400, 401, 403, 404, 409].contains(status) ||
            code == 'REFUND_REQUEST_CONFLICT';
        if (!uncertain) await prefs.remove(_key(itemId));
        final message = switch (code) {
          'ORDER_NOT_PAID' => '訂單尚未付款，無法申請退貨',
          'NOT_RECEIVED' => '尚未確認取貨，暫時無法申請退貨',
          'RECEIPT_TIME_UNKNOWN' => '無法確認取貨時間，請聯絡客服協助',
          'PAYMENT_TIME_UNKNOWN' => '無法確認付款時間，請聯絡客服協助',
          'REFUND_WINDOW_EXPIRED' => '已超過新申請期限；已受理的退貨申請不受影響',
          'REFUND_REQUEST_CONFLICT' => '申請內容與原申請不一致，請聯絡客服確認，避免重複申請',
          _ =>
            uncertain
                ? '無法確認申請結果，請重試原申請，避免重複送出'
                : getDioExceptionMessage(error),
        };
        return RefundSubmission(error: message, uncertain: uncertain);
      }
    } catch (_) {
      // Retain any persisted request if storage/parsing failed after dispatch.
      return const RefundSubmission(
        uncertain: true,
        error: '無法確認申請結果，請稍後重試原申請',
      );
    }
  }
}

class RefundSubmission {
  const RefundSubmission({this.item, this.error, this.uncertain = false});
  final RefundItem? item;
  final String? error;
  final bool uncertain;
  bool get isSuccess => item != null;
}
