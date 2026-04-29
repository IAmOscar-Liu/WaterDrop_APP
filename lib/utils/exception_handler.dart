import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/utils/parse_utils.dart';

String getDioExceptionMessage(DioException e) {
  final data = e.response?.data;
  if (data is Map) {
    return ParseUtils.parseString(data['message']) ?? "$e";
  }
  return "$e";
}
