import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/provider/message_stats_provider.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/badge_count.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/simple_app_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class MessagingAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final TextStyle? titleTextStyle;
  final bool centerTitle;
  final double elevation;
  final IconThemeData? iconTheme;

  const MessagingAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.backgroundColor,
    this.foregroundColor,
    this.titleTextStyle,
    this.centerTitle = true,
    this.elevation = 0,
    this.iconTheme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messageStats = ref.watch(messageStatsNotifierProvider);

    // Combine the default message action with any other actions provided.
    final allActions = [
      ...?actions, // Add existing actions first
      Padding(
        padding: const EdgeInsets.only(right: 4.0),
        child: Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {
                // Navigate to the message page using go_router
                context.push(Routes.messagePage);
              },
            ),
            if (messageStats.hasData && messageStats.data!.total > 0)
              Positioned(
                right: 8,
                top: 6,
                child: BadgeCount(count: messageStats.data!.total),
              ),
          ],
        ),
      ),
    ];

    return SimpleAppBar(
      title: title,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      centerTitle: centerTitle,
      titleTextStyle: titleTextStyle,
      iconTheme: iconTheme,
      actions: allActions,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      elevation: elevation,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
