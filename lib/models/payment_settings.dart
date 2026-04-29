// ignore_for_file: non_constant_identifier_names

import 'package:flutter_ad_ecommerce/utils/parse_utils.dart';

class PaymentSettings {
  final double transactionFeeRate;
  final double? homeDelivery;
  final double? homeDeliveryRefrig;
  final double? FAMI;
  final double? UNIMART;
  final double? FAMIC2C;
  final double? UNIMARTC2C;
  final double? HILIFEC2C;
  final double? OKMARTC2C;
  final double? OKMART_LOW_TMP_C2C;

  const PaymentSettings({
    required this.transactionFeeRate,
    required this.homeDelivery,
    required this.homeDeliveryRefrig,
    required this.FAMI,
    required this.UNIMART,
    required this.FAMIC2C,
    required this.UNIMARTC2C,
    required this.HILIFEC2C,
    required this.OKMARTC2C,
    required this.OKMART_LOW_TMP_C2C,
  });

  factory PaymentSettings.fromJson(Map<String, dynamic> json) {
    return PaymentSettings(
      transactionFeeRate:
          ParseUtils.parseDouble(json['transactionFeeRate']) ?? 0.0,
      homeDelivery: ParseUtils.parseDouble(json['homeDelivery']),
      homeDeliveryRefrig: ParseUtils.parseDouble(json['homeDeliveryRefrig']),
      FAMI: ParseUtils.parseDouble(json['FAMI']),
      UNIMART: ParseUtils.parseDouble(json['UNIMART']),
      FAMIC2C: ParseUtils.parseDouble(json['FAMIC2C']),
      UNIMARTC2C: ParseUtils.parseDouble(json['UNIMARTC2C']),
      HILIFEC2C: ParseUtils.parseDouble(json['HILIFEC2C']),
      OKMARTC2C: ParseUtils.parseDouble(json['OKMARTC2C']),
      OKMART_LOW_TMP_C2C: ParseUtils.parseDouble(json['OKMART_LOW_TMP_C2C']),
    );
  }
}
