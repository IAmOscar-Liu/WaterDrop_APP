import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/utils/parse_utils.dart';

String getDioExceptionMessage(DioException e) {
  final data = e.response?.data;
  if (data is Map) {
    final message = data['message'];
    if (message is List) {
      final messages = message
          .map((entry) => entry is Map ? entry['message'] : entry)
          .whereType<String>()
          .where((text) => text.trim().isNotEmpty);
      if (messages.isNotEmpty) return messages.join('\n');
    }
    return ParseUtils.parseString(data['message']) ?? "$e";
  }
  return "$e";
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
    final referralCode = notFoundMatch.group(1)?.trim();
    return '找不到推薦碼「${referralCode?.isNotEmpty == true ? referralCode : submittedCode}」';
  }

  return message?.isNotEmpty == true ? message! : "無法提交推薦碼";
}
