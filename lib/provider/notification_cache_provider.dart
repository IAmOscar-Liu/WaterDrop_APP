import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_ad_ecommerce/models/api_enums.dart';

const notificationCacheDuration = Duration(minutes: 10);
typedef NotificationQueryKey = ({
  NotificationType? type,
  String search,
  bool onlyUnread,
});
final notificationCacheClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
