import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/models/payment_settings.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/utils/custom_async_value.dart';
import 'package:flutter_ad_ecommerce/utils/exception_handler.dart';
import 'package:flutter_ad_ecommerce/utils/result.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'payment_settings_provider.g.dart';

@Riverpod(keepAlive: true)
class PaymentSettingsNotifier extends _$PaymentSettingsNotifier {
  @override
  CustomAsyncValue<PaymentSettings> build() {
    return CustomAsyncValue.initial();
  }

  Future<void> loadPaymentSettings() async {
    try {
      state = CustomAsyncValue.loading();
      final response = await ref
          .read(dioProvider)
          .get("/api/delivery/shipping-fee-and-tax-rate");

      final data = response.data;
      state = CustomAsyncValue.done(PaymentSettings.fromJson(data['data']));
    } on DioException catch (e) {
      log('Error loading PaymentSettings: $e');
      state = CustomAsyncValue.error(getDioExceptionMessage(e));
    } catch (e) {
      log('Error loading PaymentSettings: $e');
      state = CustomAsyncValue.error('Error loading orders: $e');
    }
  }

  Future<Result<Map<String, PaymentSettings>>> loadShippingFee(
    List<String> accountIds,
  ) async {
    try {
      final response = await ref
          .read(dioProvider)
          .post("/api/delivery/shipping-fee", data: {"accountIds": accountIds});
      final data = response.data;
      if (data["success"] != true) {
        throw Exception("Failed to load Shipping fee");
      }

      final Map<String, dynamic> rawData = data["data"];
      final Map<String, PaymentSettings> result = rawData.map(
        (key, value) => MapEntry(key, PaymentSettings.fromJson(value)),
      );

      return Result.success(result);
    } catch (e) {
      log('Error loading shipping fee: $e');
      return Result.failure(e.toString());
    }
  }
}
