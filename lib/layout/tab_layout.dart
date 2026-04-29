import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/models/destination.dart';
import 'package:flutter_ad_ecommerce/provider/cart_provider.dart';
import 'package:flutter_ad_ecommerce/provider/system_provider.dart';
import 'package:flutter_ad_ecommerce/provider/treasure_box_provider.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:flutter_ad_ecommerce/utils/events.dart';
import 'package:flutter_ad_ecommerce/widgets/badge_count.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class TabLayout extends ConsumerStatefulWidget {
  const TabLayout({
    required this.navigationShell,
    required this.matchedLocation,
    super.key,
  }); // : super(key: key ?? const ValueKey<String>('TabLayout'));

  final StatefulNavigationShell navigationShell;
  final String matchedLocation;

  @override
  ConsumerState<TabLayout> createState() => _TabLayoutState();
}

class _TabLayoutState extends ConsumerState<TabLayout> {
  // @override
  // void initState() {
  //   super.initState();
  //   print("_TabLayoutState init: ${widget.currentLocation}");
  // }

  @override
  void didUpdateWidget(oldWidget) {
    super.didUpdateWidget(oldWidget);
    final from = oldWidget.matchedLocation;
    final to = widget.matchedLocation;

    log("_TabLayoutState didUpdateWidget: old: $from, new: $to");
    if (to == Routes.explorePage && to != from) {
      // enter explore page
      Future.delayed(Duration.zero, () {
        ref.read(systemNotifierProvider.notifier).setIsInExplorePage(true);
      });
    } else if (from == Routes.explorePage && to != from) {
      // exit explore page
      Future.delayed(Duration.zero, () {
        ref.read(systemNotifierProvider.notifier).setIsInExplorePage(false);
      });
    }
    eventBus.fire(RouterChangeEvent(from: from, to: to));
  }

  Widget _buildIconWithBadge(Destination destination, bool isSelected) {
    if (destination.badgeCount > 0) {
      return Stack(
        children: [
          Icon(
            destination.icon,
            color: isSelected
                ? AppColors.primaryTextColor
                : AppColors.secondaryTextColor,
          ),
          SizedBox(height: 10, width: 30),
          Positioned(
            right: 0,
            top: 0,
            child: BadgeCount(count: destination.badgeCount),
          ),
        ],
      );
    }

    return Icon(
      destination.icon,
      color: isSelected
          ? AppColors.primaryTextColor
          : AppColors.secondaryTextColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    // ref.watch(advertisementNotifierProvider).status;

    final List<Destination> destinations = [
      Destination(
        label: '寶箱',
        icon: Icons.event,
        badgeCount: ref.watch(claimableTreasureBoxCountProvider),
      ), // or Icons.local_activity
      Destination(label: '廣告', icon: Icons.campaign), // or Icons.local_offer
      Destination(label: '市集', icon: Icons.local_mall), // or Icons.local_offer
      Destination(
        label: '購物車',
        icon: Icons.shopping_cart,
        badgeCount: ref.watch(cartTotalItemsProvider),
      ),
      // Destination(
      //   label: '通知',
      //   icon: Icons.notifications,
      //   badgeCount: ref.watch(messageUnreadCountProvider),
      // ),
      Destination(
        label: '我的',
        icon: Icons.person_outline,
      ), // or Icons.account_circle_outlined
    ];

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          navigationBarTheme: NavigationBarThemeData(
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return TextStyle(color: AppColors.primaryTextColor);
              }
              return TextStyle(color: AppColors.secondaryTextColor);
            }),
          ),
        ),
        child: NavigationBar(
          selectedIndex: widget.navigationShell.currentIndex,
          onDestinationSelected: widget.navigationShell.goBranch,
          backgroundColor: AppColors.appbarBgColor,
          indicatorColor: AppColors.navbarIndicatorColor,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: destinations
              .map(
                (destination) => NavigationDestination(
                  icon: _buildIconWithBadge(destination, false),
                  label: destination.label,
                  selectedIcon: _buildIconWithBadge(destination, true),
                ),
              )
              .toList(),
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
        ),
      ),
    );
  }
}
