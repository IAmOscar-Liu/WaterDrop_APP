import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_ad_ecommerce/constants/app_constants.dart';
import 'package:flutter_ad_ecommerce/provider/account_provider.dart';
import 'package:flutter_ad_ecommerce/provider/app_badge_provider.dart';
import 'package:flutter_ad_ecommerce/provider/chat_sync_provider.dart';
import 'package:flutter_ad_ecommerce/provider/chatroom_list_provider.dart';
import 'package:flutter_ad_ecommerce/provider/message_stats_provider.dart';
import 'package:flutter_ad_ecommerce/provider/treasure_box_provider.dart';

class AppBadgeHost extends ConsumerStatefulWidget {
  const AppBadgeHost({
    super.key,
    required this.loggedIn,
    required this.sessionReady,
    required this.child,
  });
  final bool loggedIn, sessionReady;
  final Widget child;
  @override
  ConsumerState<AppBadgeHost> createState() => _AppBadgeHostState();
}

class _AppBadgeHostState extends ConsumerState<AppBadgeHost>
    with WidgetsBindingObserver {
  late AppBadgeController _controller;
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    _controller = ref.read(appBadgeProvider);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  void _configure() {
    if (!mounted || !widget.sessionReady) return;
    final account = ref.read(accountNotifierProvider);
    _controller.configureSession(
      widget.loggedIn && account.oauthId.isNotEmpty ? account.id : null,
      foreground: _foreground,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _configure();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(accountNotifierProvider.select((a) => a.id));
    WidgetsBinding.instance.addPostFrameCallback((_) => _configure());
    if (AppConstants.chatSseEnabled) {
      ref.listen(
        chatSyncProvider.select((c) => c.listVersion),
        (_, _) => _controller.invalidate(),
      );
    } else {
      ref.listen(chatroomListNotifierProvider, (_, value) {
        if (value.isDone) _controller.invalidate();
      });
    }
    ref.listen(messageStatsNotifierProvider, (old, value) {
      if (value.isDone &&
          (value.data?.version != old?.data?.version ||
              value.data?.total != old?.data?.total)) {
        _controller.invalidate();
      }
    });
    ref.listen(treasureBoxNotifierProvider, (old, value) {
      if (value.isDone && old != value) _controller.invalidate();
    });
    return widget.child;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.configureSession(_controller.userId, foreground: false);
    super.dispose();
  }
}
