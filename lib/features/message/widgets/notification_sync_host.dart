import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/provider/account_provider.dart';
import 'package:flutter_ad_ecommerce/provider/notification_sync_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mounted above navigation, so changing routes never owns the transport.
class NotificationSyncHost extends ConsumerStatefulWidget {
  const NotificationSyncHost({
    super.key,
    required this.loggedIn,
    required this.child,
  });
  final bool loggedIn;
  final Widget child;
  @override
  ConsumerState<NotificationSyncHost> createState() =>
      _NotificationSyncHostState();
}

class _NotificationSyncHostState extends ConsumerState<NotificationSyncHost>
    with WidgetsBindingObserver {
  bool _foreground = true;
  String? _user;
  late NotificationSyncController _controller;
  @override
  void initState() {
    super.initState();
    _controller = ref.read(notificationSyncProvider);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _controller.configureSession(_user, foreground: _foreground);
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountNotifierProvider);
    final user = widget.loggedIn && account.oauthId.isNotEmpty
        ? account.id
        : null;
    if (user != _user) {
      _user = user;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.configureSession(_user, foreground: _foreground);
        }
      });
    }
    return widget.child;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.configureSession(null, foreground: false);
    super.dispose();
  }
}
