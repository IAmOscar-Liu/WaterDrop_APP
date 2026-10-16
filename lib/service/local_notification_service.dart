import 'dart:convert';
import 'dart:developer';

import 'package:flutter_ad_ecommerce/utils/events.dart';
import 'package:flutter_ad_ecommerce/service/notification_tap_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  // Private constructor for singleton pattern
  LocalNotificationService._internal();

  // Singleton instance
  static final LocalNotificationService _instance =
      LocalNotificationService._internal();

  // Factory constructor to return singleton instance
  factory LocalNotificationService.instance() => _instance;

  // Main plugin instance for handling notifications
  late FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;

  // Android-specific initialization setting using app launcher icon
  final _androidInitializationSettings = const AndroidInitializationSettings(
    "@mipmap/ic_launcher",
  );

  // iOS-specific intialization settings with permission request
  final _iosInitialization = const DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  // Android notification channel configuration
  final _androidChannel = const AndroidNotificationChannel(
    "channel_id",
    "Channel name",
    description: "Android push notification channel",
    importance: Importance.max,
  );

  // Flag to track intialization status
  bool _isFlutterLocalNotificationInitialized = false;

  // Counter for generating unique notification IDs
  int _notificationIdCounter = 0;

  // Initializes the local notifications plugin for Android and iOS
  Future<void> init() async {
    // Check if already initialized to prevent redundant setup
    if (_isFlutterLocalNotificationInitialized) {
      return;
    }

    // Create plugin instance
    _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    // Combine platform-specific settings
    final initializationSettings = InitializationSettings(
      android: _androidInitializationSettings,
      iOS: _iosInitialization,
    );

    // Initialize plugin with settings and callback for notification taps
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        _handleTapPayload(response.payload);
      },
    );

    final launch = await _flutterLocalNotificationsPlugin
        .getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      _handleTapPayload(launch?.notificationResponse?.payload);
    }

    // Create Android notification channel
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);

    // Mark initialization as complete
    _isFlutterLocalNotificationInitialized = true;
  }

  void _handleTapPayload(String? payload) {
    if (payload == null) return;
    try {
      final data = jsonDecode(payload);
      if (data is Map<String, dynamic>) {
        queueNotificationTap(NotificationTappedEvent(data: data));
      }
    } on FormatException {
      log('Ignoring an invalid notification tap payload');
    }
  }

  // Show a local notification with the given title, body, and payload
  Future<void> showNotification(
    String? title,
    String? body,
    String? payload,
  ) async {
    // Android specific notification details
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _androidChannel.id,
      _androidChannel.name,
      channelDescription: _androidChannel.description,
      importance: Importance.max,
      priority: Priority.high,
    );

    // iOS-specific notification details
    DarwinNotificationDetails iOSDetails = DarwinNotificationDetails();

    // Combine platform-specific details
    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    // Display the notification
    await _flutterLocalNotificationsPlugin.show(
      _notificationIdCounter++,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }
}
