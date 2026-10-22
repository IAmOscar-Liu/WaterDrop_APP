import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ad_ecommerce/service/local_notification_service.dart';

/// Android retains normal launcher notification dots. No synthetic notification
/// or vendor-specific numeric counter is created to represent the aggregate.
class AppBadgeService {
  Future<void> clearSession() async {
    try {
      await LocalNotificationService.instance().clearSessionNotifications();
    } finally {
      await setCount(0);
    }
  }

  static const channel = MethodChannel('waterdrop/app_badge');
  Future<void> setCount(int count) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await channel.invokeMethod<void>('setCount', {'count': count});
    }
  }
}
