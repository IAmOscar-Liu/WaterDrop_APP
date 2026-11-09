import 'package:flutter_ad_ecommerce/utils/app_failure.dart';
import 'package:dio/dio.dart';

/// Only the explicit synchronous BE result can unlock checkout.
class LogisticsVerificationResult {
  const LogisticsVerificationResult({
    this.validated = false,
    required this.message,
    this.retryAfterSeconds = 0,
  });

  final bool validated;
  final String message;
  final int retryAfterSeconds;

  factory LogisticsVerificationResult.fromResponse(Response<dynamic> response) {
    final body = response.data;
    final data = body is Map ? body['data'] : null;
    if (response.statusCode == 200 &&
        body is Map &&
        body['success'] == true &&
        data is Map &&
        data['success'] == true &&
        data['code'] == 'VALIDATED') {
      return const LogisticsVerificationResult(
        validated: true,
        message: '物流資料驗證成功',
      );
    }
    if (response.statusCode == 429) {
      final now = DateTime.now();
      final deadline = AppFailure.parseRetryAfter(
        response.headers.value('retry-after'),
        now,
      );
      final seconds = deadline == null
          ? null
          : (deadline.difference(now).inMilliseconds / 1000).ceil();
      return LogisticsVerificationResult(
        message: '物流驗證請求過於頻繁，請稍後重試。',
        retryAfterSeconds: seconds != null && seconds > 0 ? seconds : 60,
      );
    }
    if (response.statusCode == 400) {
      final failure = AppFailure.from(body);
      return LogisticsVerificationResult(
        message: failure.fieldErrors.isNotEmpty
            ? failure.message
            : '收件資料不完整或格式不正確，請確認後再試。',
      );
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      return const LogisticsVerificationResult(
        message: '無法確認登入狀態，請返回並重新登入後再試。',
      );
    }
    if (response.statusCode == 504) {
      return const LogisticsVerificationResult(
        message: '物流驗證逾時，尚無法確認結果，請稍後重試。',
      );
    }
    if (response.statusCode == 200 &&
        body is Map &&
        body['success'] == true &&
        data is Map &&
        data['success'] == false &&
        data['code'] == 'PROVIDER_REJECTED') {
      return const LogisticsVerificationResult(
        message: '綠界未接受測試物流資料，請確認收件資訊或稍後重試。',
      );
    }
    // Do not expose raw provider/network payloads or infer which receiver field is wrong.
    return const LogisticsVerificationResult(message: '目前無法完成物流驗證，請稍後重試。');
  }

  factory LogisticsVerificationResult.fromError(Object error) {
    if (error is DioException) {
      if (error.response != null) {
        final result = LogisticsVerificationResult.fromResponse(
          error.response!,
        );
        if (!result.validated) return result;
        return const LogisticsVerificationResult(message: '目前無法完成物流驗證，請稍後重試。');
      }
      if (error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.connectionTimeout) {
        return const LogisticsVerificationResult(
          message: '物流驗證逾時，尚無法確認結果，請稍後重試。',
        );
      }
    }
    return const LogisticsVerificationResult(message: '無法連線完成物流驗證，請確認網路後重試。');
  }
}
