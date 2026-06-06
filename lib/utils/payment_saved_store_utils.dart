import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/features/ecpay/widget/checkout_delivery_section.dart';
import 'package:flutter_ad_ecommerce/models/logistics_info.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PaymentSavedStoreUtils {
  static const String _savedStorePrefsPrefix =
      'payment_settings_page.saved_store';

  static Future<Map<LogisticsSubType, LogisticsMapInfo>>
  loadValidatedSavedStores(Dio dio) async {
    final prefs = await SharedPreferences.getInstance();
    final decodedStoresBySubType = <LogisticsSubType, Map<String, dynamic>>{};

    for (final subType in LogisticsSubType.values) {
      final rawStore = prefs.getString(_savedStorePrefsKey(subType));
      if (rawStore == null) continue;

      try {
        final decoded = jsonDecode(rawStore);
        if (decoded is Map<String, dynamic>) {
          decodedStoresBySubType[subType] = decoded;
        }
      } catch (_) {
        // Ignore malformed legacy values and let the next store selection heal it.
      }
    }

    final validatedStores = await _validateSavedStores(
      dio,
      decodedStoresBySubType,
    );
    if (validatedStores == null) return {};

    final invalidSubTypes = LogisticsSubType.values
        .where(
          (subType) =>
              decodedStoresBySubType.containsKey(subType) &&
              !validatedStores.containsKey(subType),
        )
        .toList();

    for (final subType in invalidSubTypes) {
      await prefs.remove(_savedStorePrefsKey(subType));
    }
    for (final entry in validatedStores.entries) {
      await prefs.setString(
        _savedStorePrefsKey(entry.key),
        jsonEncode(entry.value),
      );
    }

    return validatedStores.map(
      (subType, store) =>
          MapEntry(subType, LogisticsMapInfo.fromApiResponseMap(store)),
    );
  }

  static Future<void> saveStoreForSubType(
    LogisticsSubType subType,
    LogisticsMapInfo store,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _savedStorePrefsKey(subType),
      jsonEncode(_storeToPrefsMap(store)),
    );
  }

  static String _savedStorePrefsKey(LogisticsSubType subType) =>
      '$_savedStorePrefsPrefix.${subType.name}';

  static Map<String, dynamic> _storeToPrefsMap(LogisticsMapInfo store) {
    return {
      'MerchantID': store.MerchantID,
      'MerchantTradeNo': store.MerchantTradeNo,
      'LogisticsSubType': store.LogisticsSubType,
      'CVSStoreID': store.CVSStoreID,
      'CVSStoreName': store.CVSStoreName,
      'CVSAddress': store.CVSAddress,
      'CVSTelephone': store.CVSTelephone,
      'CVSOutSide': store.CVSOutSide,
    };
  }

  static Future<Map<LogisticsSubType, Map<String, dynamic>>?>
  _validateSavedStores(
    Dio dio,
    Map<LogisticsSubType, Map<String, dynamic>> storesBySubType,
  ) async {
    if (storesBySubType.isEmpty) return {};

    dynamic data;
    try {
      final response = await dio.post(
        "/api/ecpay/express/validate-saved-stores",
        data: storesBySubType.map(
          (subType, store) => MapEntry(subType.name, store),
        ),
      );
      data = response.data;
    } catch (_) {
      return null;
    }
    if (data is! Map || data['success'] != true) return null;

    final payload = data['data'];
    if (payload is! Map) return {};

    final validatedStores = <LogisticsSubType, Map<String, dynamic>>{};
    for (final entry in payload.entries) {
      final subType = LogisticsSubType.values
          .where((value) => value.name == entry.key.toString())
          .firstOrNull;
      final store = entry.value;
      if (subType != null && store is Map) {
        validatedStores[subType] = Map<String, dynamic>.from(store);
      }
    }
    return validatedStores;
  }
}
