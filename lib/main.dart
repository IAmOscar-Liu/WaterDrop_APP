import 'package:flutter_ad_ecommerce/shared/widgets/app_snackbar.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/app_dialog.dart';
import 'package:flutter_ad_ecommerce/features/message/widgets/notification_sync_host.dart';
import 'dart:async';
import 'package:flutter_ad_ecommerce/features/app_badge/app_badge_host.dart';
import 'package:flutter_ad_ecommerce/provider/app_badge_provider.dart';
import 'package:flutter_ad_ecommerce/provider/session_logout_provider.dart';
import 'dart:convert';
import 'dart:developer';
import 'dart:math' show min;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ad_ecommerce/app_flavor.dart';
import 'package:flutter_ad_ecommerce/constants/app_constants.dart';
import 'package:flutter_ad_ecommerce/features/chatroom/widget/chat_sync_host.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/provider/account_provider.dart';
import 'package:flutter_ad_ecommerce/provider/advertisement_provider.dart';
import 'package:flutter_ad_ecommerce/provider/cart_provider.dart';
import 'package:flutter_ad_ecommerce/provider/message_stats_provider.dart';
import 'package:flutter_ad_ecommerce/provider/product_category_provider.dart';
import 'package:flutter_ad_ecommerce/provider/product_provider.dart';
import 'package:flutter_ad_ecommerce/provider/system_provider.dart';
import 'package:flutter_ad_ecommerce/router/router.dart';
import 'package:flutter_ad_ecommerce/service/firebase_messaging_service.dart';
import 'package:flutter_ad_ecommerce/service/local_notification_service.dart';
import 'package:flutter_ad_ecommerce/utils/api_call_manager.dart';
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
  StreamSubscription<RemoteMessage>? _foregroundMessages;
  StreamSubscription<User?>? _authSubscription;
  int _authGeneration = 0;

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 1500), () {
      FlutterNativeSplash.remove();
    });

    _authStateChanges = FirebaseAuth.instance.authStateChanges();
    _authSubscription = _authStateChanges.listen((user) async {
      final generation = ++_authGeneration;
      log("authStateChanges");
      final accountNotifier = ref.read(accountNotifierProvider.notifier);
      if (user != null) {
        if (ref.read(accountNotifierProvider).oauthId.isNotEmpty &&
            ref.read(accountNotifierProvider).oauthId != user.uid) {
          ref.read(appBadgeProvider).configureSession(null, foreground: false);
        }
        // use user.uid
        final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
        log("current timezone: $currentTimeZone");
        if (!mounted || generation != _authGeneration) return;
        final result = await accountNotifier.loadAccountInfo(
          user,
          timezone: currentTimeZone,
        );
        if (!mounted || generation != _authGeneration) return;
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
        ref.read(appBadgeProvider).configureSession(null, foreground: false);
        await _foregroundMessages?.cancel();
        if (!mounted || generation != _authGeneration) return;
        _foregroundMessages = null;
        accountNotifier.reset();
        ref.invalidate(productNotifierProvider);
        // Explicit logout removes registration before Firebase credentials end.
        setState(() {
          isLoggedIn = false;
          isLoading = false;
        });
      }
    });

    _tokenChangeSubscription = eventBus.on<TokenChangeEvent>().listen((
      event,
    ) async {
      if (event.token != null &&
          isLoggedIn &&
          FirebaseAuth.instance.currentUser != null) {
        await ref.read(deviceRegistrationProvider).register(event.token!);
      }
    });
  }

  @override
  void dispose() {
    _authGeneration++;
    _authSubscription?.cancel();
    super.dispose();
    _tokenChangeSubscription.cancel();
    _foregroundMessages?.cancel();
  }

  Future<void> _handleLoginAftermath() async {
    final loginAccount = ref.read(accountNotifierProvider).id;
    final String? fcmToken = await FirebaseMessaging.instance.getToken();
    if (!mounted ||
        !isLoggedIn ||
        ref.read(accountNotifierProvider).id != loginAccount) {
      return;
    }
    if (fcmToken != null) {
      await ref.read(deviceRegistrationProvider).register(fcmToken);
    }

    await _foregroundMessages?.cancel();
    if (!mounted ||
        !isLoggedIn ||
        ref.read(accountNotifierProvider).id != loginAccount) {
      return;
    }
    _foregroundMessages = FirebaseMessaging.onMessage.listen((message) {
      final badge = ref.read(appBadgeProvider);
      badge.handlePush(message.data);
      final recipient = message.data['badgeUserId'];
      if (message.data['command'] == 'badge_sync' ||
          (recipient != null &&
              recipient != ref.read(accountNotifierProvider).id)) {
        return;
      }
      final notificationData = message.notification;
      if (notificationData != null) {
        final system = ref.read(systemNotifierProvider);
        if ((message.data['command'] == "explore" && system.isInExplorePage) ||
            (message.data['command'] == "chat_message" &&
                WidgetsBinding.instance.lifecycleState ==
                    AppLifecycleState.resumed &&
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

    ref.read(productCategoryProvider.notifier).loadProductCategory();
    ApiCallManager.updateApiCallTimestamp(productListApiCacheKey);
    unawaited(
      ref
          .read(productNotifierProvider.notifier)
          .loadProducts(reuseExisting: true),
    );
    ref.read(cartProvider.notifier).loadCartItems();
    ref.read(messageStatsNotifierProvider.notifier).loadMessageStats();
    ref.read(systemNotifierProvider.notifier).loadSystemInfo();
    ref.read(systemNotifierProvider.notifier).loadProductRecommendation();
    ref.read(systemNotifierProvider.notifier).loadCustomerSupportContent();
    ref.read(systemNotifierProvider.notifier).loadBankList();

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
      builder: (context, child) {
        Widget content = child ?? const SizedBox.shrink();
        if (AppConstants.chatSseEnabled) {
          content = ChatSyncHost(loggedIn: isLoggedIn, child: content);
        }
        if (AppConstants.notificationSseEnabled) {
          content = NotificationSyncHost(loggedIn: isLoggedIn, child: content);
        }
        return AppBadgeHost(
          loggedIn: isLoggedIn,
          sessionReady: !isLoading,
          child: content,
        );
      },
      routerConfig: getRouter(
        isLoading: isLoading,
        isLoggedIn: isLoggedIn,
        error: error,
      ),
      debugShowCheckedModeBanner: false,
      theme:
          ThemeData.from(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.navbarIndicatorColor,
            ),
          ).copyWith(
            dialogTheme: AppDialogs.theme,
            snackBarTheme: AppSnackBar.theme,
          ),
    );
  }
}
