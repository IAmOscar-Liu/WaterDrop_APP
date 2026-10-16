import 'package:flutter/foundation.dart';
import 'package:flutter_ad_ecommerce/app_flavor.dart';

class AppConstants {
  static const paginationPageSize = 20;

  // SSE is the default; set CHAT_SSE_ENABLED=false for legacy polling.
  static const chatSseEnabled = bool.fromEnvironment(
    'CHAT_SSE_ENABLED',
    defaultValue: true,
  );

  // Independent rollback for Message Center synchronization.
  static const notificationSseEnabled = bool.fromEnvironment(
    'NOTIFICATION_SSE_ENABLED',
    defaultValue: true,
  );

  static const _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (!kReleaseMode && _apiBaseUrlOverride.isNotEmpty) {
      return _apiBaseUrlOverride;
    }

    switch (AppFlavor.current) {
      case AppFlavor.dev:
        return 'https://dev-api.waterdropping.com/';
      case AppFlavor.stg:
        return 'https://stg-api.waterdropping.com/';
    }
  }

  static int dailyAvailableVideoCount = 20;
  static int videoCountForClaimingTreasureBox = 2;

  static String logisticsSubType = "C2C"; // B2C or C2C
}
