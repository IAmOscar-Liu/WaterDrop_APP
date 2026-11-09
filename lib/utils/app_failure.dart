import 'dart:convert';
import 'dart:io' show HttpDate;
import 'package:dio/dio.dart';

enum FailureKind {
  connection,
  timeout,
  unauthenticated,
  forbidden,
  notFound,
  validation,
  conflict,
  rateLimited,
  unavailable,
  unknown,
  canceled,
}

class AppFailure implements Exception {
  const AppFailure({
    this.kind = FailureKind.unknown,
    this.code,
    this.statusCode,
    this.requestId,
    this.retryAt,
    this.fieldErrors = const {},
  });
  final FailureKind kind;
  final String? code;
  final int? statusCode;
  final String? requestId;
  final DateTime? retryAt;
  final Map<String, String> fieldErrors;
  AppFailure withRetryAt(DateTime? value) => AppFailure(
    kind: kind,
    code: code,
    statusCode: statusCode,
    requestId: requestId,
    retryAt: value,
    fieldErrors: fieldErrors,
  );

  factory AppFailure.from(Object? error, {DateTime? now}) {
    if (error is AppFailure) return error;
    final dio = error is DioException ? error : null;
    if (dio?.type == DioExceptionType.cancel) {
      return const AppFailure(kind: FailureKind.canceled);
    }
    if (dio?.type == DioExceptionType.connectionTimeout ||
        dio?.type == DioExceptionType.receiveTimeout ||
        dio?.type == DioExceptionType.sendTimeout) {
      return const AppFailure(kind: FailureKind.timeout);
    }
    if (dio?.type == DioExceptionType.connectionError ||
        dio?.type == DioExceptionType.badCertificate) {
      return const AppFailure(kind: FailureKind.connection);
    }
    dynamic body = dio?.response?.data ?? error;
    if (body is String) {
      try {
        body = jsonDecode(body);
      } catch (_) {
        body = null;
      }
    }
    final map = body is Map ? body : const {};
    final status =
        dio?.response?.statusCode == 200 || dio?.response?.statusCode == null
        ? int.tryParse('${map['statusCode']}')
        : dio!.response!.statusCode;
    final code = map['code'] is String ? map['code'] as String : null;
    final ref =
        map['requestId'] ?? dio?.response?.headers.value('x-request-id');
    final fields = <String, String>{};
    if (map['fieldErrors'] is List) {
      for (final field in map['fieldErrors']) {
        if (field is Map &&
            field['field'] is String &&
            _fieldCopy.containsKey(field['code'])) {
          // Never render arbitrary backend field paths or messages.
          fields[field['field'] as String] = _fieldCopy[field['code']]!;
        }
      }
    }
    return AppFailure(
      kind: switch (status) {
        400 || 413 || 422 => FailureKind.validation,
        401 => FailureKind.unauthenticated,
        403 => FailureKind.forbidden,
        404 || 410 => FailureKind.notFound,
        409 => FailureKind.conflict,
        429 => FailureKind.rateLimited,
        500 || 502 || 503 || 504 => FailureKind.unavailable,
        _ => FailureKind.unknown,
      },
      code: code,
      statusCode: status,
      requestId:
          ref is String &&
              RegExp(
                r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$',
              ).hasMatch(ref)
          ? ref
          : null,
      retryAt: parseRetryAfter(
        dio?.response?.headers.value('retry-after'),
        now ?? DateTime.now(),
      ),
      fieldErrors: fields,
    );
  }

  static DateTime? parseRetryAfter(String? value, DateTime now) {
    if (value == null) return null;
    final seconds = int.tryParse(value.trim());
    if (seconds != null) {
      return seconds >= 0 ? now.add(Duration(seconds: seconds)) : null;
    }
    try {
      final date = HttpDate.parse(value);
      return date.isAfter(now) ? date : null;
    } catch (_) {
      return null;
    }
  }

  bool get canceled => kind == FailureKind.canceled;
  bool get canRetry =>
      !canceled &&
      !{
        FailureKind.forbidden,
        FailureKind.notFound,
        FailureKind.validation,
        FailureKind.unauthenticated,
        FailureKind.conflict,
      }.contains(kind);
  String get title => switch (kind) {
    FailureKind.connection => '目前無法連線',
    FailureKind.timeout => '連線逾時',
    FailureKind.unauthenticated => '登入狀態已失效',
    FailureKind.notFound => '內容已不存在或無法存取',
    FailureKind.forbidden => '目前無法執行此操作',
    FailureKind.rateLimited => '操作較頻繁',
    FailureKind.validation => '請確認填寫資料',
    FailureKind.conflict => '資料狀態已變更',
    _ => '暫時無法載入',
  };
  String get message =>
      _domainCopy[code] ??
      (fieldErrors.isNotEmpty
          ? fieldErrors.values.toSet().join('\n')
          : switch (kind) {
              FailureKind.connection => '請確認網路連線後再試。',
              FailureKind.timeout => '回應時間較長，請稍後再試。',
              FailureKind.unauthenticated => '請重新登入後再試。',
              FailureKind.forbidden => '此操作目前無法使用，請返回確認。',
              FailureKind.notFound => '內容可能已移除，請返回清單確認。',
              FailureKind.validation => '資料不完整或格式不正確，請確認後再試。',
              FailureKind.conflict => '請更新資料並確認目前狀態後再試。',
              FailureKind.rateLimited => '請稍候再試。',
              FailureKind.canceled => '',
              _ => '服務暫時無法使用，請稍後再試。',
            });
  @override
  String toString() => message;
}

const _fieldCopy = {
  'INVALID_TYPE': '資料格式不正確，請重新確認。',
  'VALUE_TOO_SMALL': '填寫內容或數量不足，請重新確認。',
  'VALUE_TOO_LARGE': '填寫內容或數量超過限制，請重新確認。',
  'INVALID_FORMAT': '資料格式不正確，請重新確認。',
  'INVALID_VALUE': '填寫內容無效，請重新確認。',
  'UNRECOGNIZED_FIELDS': '部分資料不受支援，請重新確認。',
  'INVALID_MULTIPLE': '數量不符合規定，請重新確認。',
};
const _domainCopy = {
  'PRODUCT_NOT_FOUND': '商品已下架或不存在，請重新整理。',
  'CART_ITEM_NOT_FOUND': '商品已不在購物車中，請重新整理。',
  'PRODUCT_UNAVAILABLE': '商品目前無法購買，請重新確認。',
  'VARIANT_UNAVAILABLE': '所選規格目前無法購買，請重新確認。',
  'INSUFFICIENT_STOCK': '商品庫存不足，請調整數量。',
  'PRODUCT_PRICE_CHANGED': '商品價格已變更，請更新後重新確認。',
  'PAYLOAD_TOO_LARGE': '資料或附件超過限制，請減少後再試。',
  'PAYMENT_CONFIRMATION_PENDING': '付款確認中，請查看原訂單狀態，避免重複付款。',
  'PAYMENT_REVIEW_REQUIRED': '付款結果待確認，請查看原訂單或聯絡客服，避免重複付款。',
  'PAYMENT_ALREADY_STARTED': '付款已開始，請查看原訂單狀態，避免重複付款。',
  'PAYMENT_KEY_MISMATCH': '此結帳已失效，請確認原訂單狀態後重新建立訂單。',
  'INSUFFICIENT_SPENDABLE_COINS': '可使用的購物金不足，請更新帳戶並調整折抵金額。',
  'ORDER_NOT_PAYABLE': '此訂單目前無法付款，請確認訂單狀態。',
  'ORDER_STOCK_UNAVAILABLE': '訂單庫存已變更，請重新確認。',
  'ORDER_TOTAL_MISMATCH': '訂單金額已變更，請重新確認。',
  'PAYMENT_AMOUNT_MISMATCH': '付款金額與訂單不符，請重新確認。',
  'PAYMENT_METHOD_MISMATCH': '付款方式與訂單不符，請重新確認。',
  'INVALID_SHIPPING_INFO': '請確認配送方式及收件資料。',
  'COIN_LEDGER_REQUIRED': '購物金折抵暫時無法使用，請稍後再試。',
  'REFUNDS_DISABLED': '此筆商品不提供退貨申請。',
  'ORDER_NOT_PAID': '訂單尚未付款，無法申請退貨。',
  'NOT_RECEIVED': '尚未確認取貨，暫時無法申請退貨。',
  'RECEIPT_TIME_UNKNOWN': '無法確認取貨時間，請聯絡客服。',
  'PAYMENT_TIME_UNKNOWN': '無法確認付款時間，請聯絡客服。',
  'REFUND_WINDOW_EXPIRED': '已超過退貨申請期限。',
  'NO_REFUNDABLE_QUANTITY': '目前沒有可退貨數量。',
  'REFUND_REQUEST_CONFLICT': '原退貨申請內容不符，請更新訂單狀態後確認。',
  'REFUND_TERMINAL': '退貨申請已結束，請更新訂單狀態。',
  'REFUND_AGREEMENT_REQUIRED': '請先確認退貨協議。',
};
