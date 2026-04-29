import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:flutter_ad_ecommerce/utils/events.dart';
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
  late StreamSubscription _notificationTappedSubscription;

  @override
  initState() {
    super.initState();

    _notificationTappedSubscription = eventBus
        .on<NotificationTappedEvent>()
        .listen((event) {
          if (event.data != null && widget.isLoggedIn) {
            if (event.data!['command'] == "explore") {
              // ignore: use_build_context_synchronously
              context.go(Routes.explorePage);
            } else if (event.data!['command'] == "message") {
              // ignore: use_build_context_synchronously
              context.push(Routes.messagePage);
            } else if (event.data!['command'] == "chat_message") {
              // ignore: use_build_context_synchronously
              context.push(
                Routes.chatroomPage,
                extra: {"chatRoomId": event.data!['chatRoomId']},
              );
            } else if (event.data!['command'] == "order_completed" ||
                event.data!['command'] == "delivery_updated") {
              // ignore: use_build_context_synchronously
              context.push(
                Routes.singleOrderDetails,
                extra: {"orderId": event.data!['orderId']},
              );
            }
          }
        });
  }

  @override
  void dispose() {
    super.dispose();
    _notificationTappedSubscription.cancel();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.primaryColor,
        body: Center(child: CircularProgressIndicator()),
      );
    } else if (widget.error != null) {
      return Scaffold(
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
