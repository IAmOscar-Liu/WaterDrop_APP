import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_ad_ecommerce/service/local_notification_service.dart';
import 'package:flutter_ad_ecommerce/utils/events.dart';

class FirebaseMessagingService {
  // Private constructor for singleton pattern
  FirebaseMessagingService._internal();

  // Singleton instance
  static final FirebaseMessagingService _instance =
      FirebaseMessagingService._internal();

  // Factory constructor to provide singleton instance
  factory FirebaseMessagingService.instance() => _instance;

  // Reference to local notification service for displaying notifications
  LocalNotificationService? _localNotificationService;

  // Initialize Firebase Messaging and sets up all message listeners
  Future<void> init({
    required LocalNotificationService localNotificationService,
  }) async {
    // Init local notification service
    _localNotificationService = localNotificationService;

    // Handle FCM token
    _handlePushNotificationsToken();

    // Request user permission for notifications
    _requestPermission();

    // Register handler for background messages (app terminated)
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Listen for message when the app is in foreground
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Listen for notification taps when the app is in background but not terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenApp);

    // Check for initial message that opened the app from terminated stated
    // final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    // if (initialMessage != null) {
    //   _onMessageOpenApp(initialMessage);
    // }
  }

  Future<String?> getPushNotificationsToken() async {
    String? token;
    int attempt = 1;
    while (true) {
      token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        print("Push notification token: $token");
        return token;
      }

      attempt++;
      if (attempt > 5) return null;
      await Future.delayed(Duration(milliseconds: 250));
    }
  }

  // Retrieve and manage the FCM token for push notification
  Future<void> _handlePushNotificationsToken() async {
    // Get the FCM token for the device
    final token = await FirebaseMessaging.instance.getToken();
    print("Push notification token: $token");
    // eventBus.fire(TokenChangeEvent(token: token));

    // Listen for token refresh events
    FirebaseMessaging.instance.onTokenRefresh
        .listen((fcmToken) {
          print("FCM token refreshed: $fcmToken");
          eventBus.fire(TokenChangeEvent(token: fcmToken));
        })
        .onError((error) {
          // handle errors during token refresh
          print("Error refreshing FCM token: $error");
        });
  }

  // Requests notification permission from the user
  Future<void> _requestPermission() async {
    log("request permission");
    // Request permission for alert, badges and sounds
    final result = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Log the user's permission decision
    print("User granted permission: ${result.authorizationStatus}");
  }

  // Handles message received while the app is in the foreground
  void _onForegroundMessage(RemoteMessage message) {
    print("Foreground message received: ${message.data.toString()}");
    // final notificationData = message.notification;
    // if (notificationData != null) {
    //   // Display a local notification using the service
    //   _localNotificationService?.showNotification(
    //     notificationData.title,
    //     notificationData.body,
    //     jsonEncode(message.data),
    //   );
    // }
  }

  // Handles notification taps when app is opened from the background or terminated state
  void _onMessageOpenApp(RemoteMessage message) {
    // print("Notification caused the app to open: ${message.data.toString()}");
    log(
      "Notification caused the app to open: notification ${message.notification}",
    );
    // log("Notification caused the app to open: data ${message.data}");
    if (message.notification != null) {
      Future.delayed(Duration(milliseconds: 250), () {
        eventBus.fire(
          NotificationTappedEvent(
            title: message.notification!.title,
            body: message.notification!.body,
            data: message.data,
          ),
        );
      });
    }
  }
}

// Background message handler (must be top-level function or status)
// Handles message when app is fully terminated
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Background message received: ${message.data.toString()}");
}
