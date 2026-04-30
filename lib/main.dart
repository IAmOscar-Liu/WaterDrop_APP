import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:math' show min;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ad_ecommerce/app_flavor.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/provider/account_provider.dart';
import 'package:flutter_ad_ecommerce/provider/advertisement_provider.dart';
import 'package:flutter_ad_ecommerce/provider/cart_provider.dart';
import 'package:flutter_ad_ecommerce/provider/message_stats_provider.dart';
import 'package:flutter_ad_ecommerce/provider/product_category_provider.dart';
import 'package:flutter_ad_ecommerce/provider/system_provider.dart';
import 'package:flutter_ad_ecommerce/router/router.dart';
import 'package:flutter_ad_ecommerce/service/firebase_messaging_service.dart';
import 'package:flutter_ad_ecommerce/service/local_notification_service.dart';
import 'package:flutter_ad_ecommerce/utils/api_call_manager.dart';
import 'package:flutter_ad_ecommerce/utils/device_info.dart';
import 'package:flutter_ad_ecommerce/utils/events.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

Future<void> main() => bootstrap(AppFlavor.current);

Future<void> bootstrap(AppFlavor flavor) async {
  AppFlavor.configure(flavor);

  // WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Set preferred orientations to portrait only and initialize Firebase concurrently
  await Future.wait([
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]),
    Firebase.initializeApp(options: flavor.firebaseOptions),
  ]);

  final localNotificationService = LocalNotificationService.instance();
  await localNotificationService.init();

  final firebaseMessagingService = FirebaseMessagingService.instance();
  await firebaseMessagingService.init(
    localNotificationService: localNotificationService,
  );

  runApp(ProviderScope(child: const MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  static void loadAdDailyStats(BuildContext context) {
    _MyAppState? state = context.findAncestorStateOfType<_MyAppState>();
    state?._loadAdDailyStats();
  }

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  bool isLoggedIn = false;
  bool isLoading = true;
  dynamic error;
  late final Stream<User?> _authStateChanges;
  late StreamSubscription _tokenChangeSubscription;
  bool _initialMessageHandled = false;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 1500), () {
      FlutterNativeSplash.remove();
    });

    _authStateChanges = FirebaseAuth.instance.authStateChanges();
    _authStateChanges.listen((user) async {
      log("authStateChanges");
      final accountNotifier = ref.read(accountNotifierProvider.notifier);
      if (user != null) {
        log(user.toString());
        // use user.uid
        final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
        log("current timezone: $currentTimeZone");
        final result = await accountNotifier.loadAccountInfo(
          user,
          timezone: currentTimeZone,
        );
        if (result.isSuccess) {
          setState(() {
            isLoggedIn = true;
            isLoading = false;
          });
          _handleLoginAftermath();
        } else {
          setState(() {
            isLoggedIn = false;
            isLoading = false;
            error = result.error;
          });
        }
      } else {
        accountNotifier.reset();
        String? deviceId = await getDeviceId();
        ref.read(systemNotifierProvider.notifier).clearFcmToken(deviceId);
        setState(() {
          isLoggedIn = false;
          isLoading = false;
        });
      }
    });

    _tokenChangeSubscription = eventBus.on<TokenChangeEvent>().listen((
      event,
    ) async {
      if (event.token != null) {
        String? deviceId = await getDeviceId();
        ref
            .read(systemNotifierProvider.notifier)
            .sendFcmToken(event.token!, deviceId: deviceId);
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    _tokenChangeSubscription.cancel();
  }

  Future<void> _handleLoginAftermath() async {
    final String? fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      String? deviceId = await getDeviceId();
      ref
          .read(systemNotifierProvider.notifier)
          .sendFcmToken(fcmToken, deviceId: deviceId);
    }

    FirebaseMessaging.onMessage.listen((message) {
      final notificationData = message.notification;
      if (notificationData != null) {
        final system = ref.read(systemNotifierProvider);
        if ((message.data['command'] == "explore" && system.isInExplorePage) ||
            (message.data['command'] == "message" && system.isInMessagePage) ||
            (message.data['command'] == "chat_message" &&
                system.currentChatRoomId == message.data['chatRoomId'])) {
          return;
        }
        LocalNotificationService.instance().showNotification(
          notificationData.title,
          notificationData.body,
          jsonEncode(message.data),
        );
      }
    });

    if (!_initialMessageHandled) {
      FirebaseMessaging.instance.getInitialMessage().then((message) {
        if (message != null && message.notification != null) {
          _initialMessageHandled = true;
          // Delay to ensure RootLayout has rebuilt with isLoggedIn = true
          Future.delayed(const Duration(milliseconds: 500), () {
            eventBus.fire(
              NotificationTappedEvent(
                title: message.notification!.title,
                body: message.notification!.body,
                data: message.data,
              ),
            );
          });
        }
      });
    }

    ref.read(productCategoryProvider.notifier).loadProductCategory();
    ref.read(cartProvider.notifier).loadCartItems();
    ref.read(messageStatsNotifierProvider.notifier).loadMessageStats();

    _loadAdDailyStats();
  }

  Future<void> _loadAdDailyStats() async {
    ApiCallManager.updateApiCallTimestamp("advertisements");
    final result = await ref
        .read(systemNotifierProvider.notifier)
        .getAdDailyStats();
    log("remaining videos: ${result.data?.remainingVideoCount ?? 0}");
    if (result.isSuccess && result.data!.canWatchMoreVideo) {
      ref
          .read(advertisementNotifierProvider.notifier)
          .loadAdvertisements(limit: min(20, result.data!.remainingVideoCount));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: getRouter(
        isLoading: isLoading,
        isLoggedIn: isLoggedIn,
        error: error,
      ),
      debugShowCheckedModeBanner: false,
      theme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.navbarIndicatorColor,
        ),
      ),
    );
  }
}
