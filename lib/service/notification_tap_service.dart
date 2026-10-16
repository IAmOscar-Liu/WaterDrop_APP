import 'package:flutter/foundation.dart';
import 'package:flutter_ad_ecommerce/utils/events.dart';

/// Retains the latest explicit tap until navigation and account loading are ready.
/// Receiving an SSE event or a push alone never writes to this inbox.
final pendingNotificationTap = ValueNotifier<NotificationTappedEvent?>(null);

void queueNotificationTap(NotificationTappedEvent event) {
  if (event.data != null) pendingNotificationTap.value = event;
}
