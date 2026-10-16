import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:flutter_ad_ecommerce/shared/layouts/app_scaffold.dart';
import 'package:flutter_ad_ecommerce/service/notification_tap_service.dart';
import 'package:go_router/go_router.dart';

class RootLayout extends StatefulWidget {
  const RootLayout({
    super.key,
    required this.isLoggedIn,
    required this.isLoading,
    required this.error,
    required this.navigationShell,
  });
  final bool isLoggedIn;
  final bool isLoading;
  final dynamic error;
  final Widget navigationShell;

  @override
  State<RootLayout> createState() => _RootLayoutState();
}

class _RootLayoutState extends State<RootLayout> {
  bool _tapScheduled = false;

  @override
  void initState() {
    super.initState();
    pendingNotificationTap.addListener(_schedulePendingTap);
    _schedulePendingTap();
  }

  @override
  void didUpdateWidget(covariant RootLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedulePendingTap();
  }

  void _schedulePendingTap() {
    if (_tapScheduled || pendingNotificationTap.value == null) return;
    _tapScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tapScheduled = false;
      if (!mounted ||
          !widget.isLoggedIn ||
          widget.isLoading ||
          widget.error != null) {
        return;
      }
      final event = pendingNotificationTap.value;
      if (event == null) return;
      pendingNotificationTap.value = null;
      final data = event.data!;
      switch (data['command']) {
        case 'explore':
          context.go(Routes.explorePage);
        case 'message':
          final id = data['notificationId'];
          if (id is String && id.trim().isNotEmpty) {
            context.push(
              Routes.singleMessageDetails,
              extra: {'messageId': id.trim(), 'openedFromNotification': true},
            );
          } else {
            context.push(Routes.messagePage);
          }
        case 'chat_message':
          context.push(
            Routes.chatroomPage,
            extra: {'chatRoomId': data['chatRoomId']},
          );
        case 'order_completed':
        case 'delivery_updated':
          context.push(
            Routes.singleOrderDetails,
            extra: {'orderId': data['orderId']},
          );
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    pendingNotificationTap.removeListener(_schedulePendingTap);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return AppScaffold(
        backgroundColor: AppColors.primaryColor,
        body: Center(child: CircularProgressIndicator()),
      );
    } else if (widget.error != null) {
      return AppScaffold(
        backgroundColor: AppColors.primaryColor,
        body: Center(
          child: Text(
            "Failed to login ${widget.error}",
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    return widget.navigationShell;
  }
}
