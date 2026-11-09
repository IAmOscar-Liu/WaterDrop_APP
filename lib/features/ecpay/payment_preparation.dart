import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/utils/result.dart';

/// Fetch the form once so JSON errors never become payable WebView content.
Future<Result<String>> preparePaymentForm(Dio dio, Uri uri) async {
  try {
    final response = await dio.get<String>(
      uri.toString(),
      options: Options(responseType: ResponseType.plain),
    );
    final html = response.data;
    if (html == null || !html.toLowerCase().contains('<form')) {
      return Result.failure('無法載入付款表單，請先確認原訂單付款狀態。');
    }
    return Result.success(html);
  } on DioException catch (error) {
    dynamic body = error.response?.data;
    if (body is String) {
      try {
        body = jsonDecode(body);
      } catch (_) {}
    }
    final code = body is Map ? body['code'] : null;
    return Result.failure(switch (code) {
      'INSUFFICIENT_SPENDABLE_COINS' => '可使用的購物金不足，請更新帳戶及訂單，調整折抵金額後重新結帳。',
      'PAYMENT_AMOUNT_MISMATCH' ||
      'PAYMENT_METHOD_MISMATCH' => '付款金額或方式與訂單不符，請返回並重新確認訂單。',
      'PAYMENT_KEY_MISMATCH' => '此結帳已失效，請確認原訂單狀態後重新建立訂單。',
      'ORDER_NOT_PAYABLE' => '此訂單已無法付款，請確認訂單狀態。',
      'PAYMENT_ALREADY_STARTED' ||
      'PAYMENT_CONFIRMATION_PENDING' => '付款確認中，請查看原訂單狀態，避免重複付款。',
      'PRODUCT_UNAVAILABLE' ||
      'PRODUCT_PRICE_CHANGED' => '商品狀態或價格已變更，請更新商品後重新結帳。',
      'ORDER_STOCK_UNAVAILABLE' ||
      'ORDER_TOTAL_MISMATCH' => '訂單庫存或金額已變更，請更新訂單後重新結帳。',
      'INVALID_SHIPPING_INFO' => '配送資訊不完整或已變更，請返回確認配送方式及收件資料。',
      'COIN_LEDGER_REQUIRED' => '購物金折抵暫時無法使用，請稍後再試或調整折抵金額。',
      _ => '無法確認付款結果，請先查看原訂單狀態，避免重複付款。',
    });
  } catch (_) {
    return Result.failure('無法載入付款表單，請先確認原訂單付款狀態。');
  }
}
