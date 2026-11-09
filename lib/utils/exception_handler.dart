import 'package:dio/dio.dart';
import 'app_failure.dart';
export 'app_failure.dart';

String getDioExceptionMessage(DioException e) {
  return AppFailure.from(e).message;
}

String translateReferralCodeErrorMessage({
  required String submittedCode,
  String? backendMessage,
  int? statusCode,
}) {
  final message = backendMessage?.trim();
  final notFoundMatch = message == null
      ? null
      : RegExp(r'^Referral code "(.+)" not found\.$').firstMatch(message);

  if (statusCode == 404 && notFoundMatch != null) {
    return '找不到推薦碼「$submittedCode」';
  }

  return "無法提交推薦碼";
}
