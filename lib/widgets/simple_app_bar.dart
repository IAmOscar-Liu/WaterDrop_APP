import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';

class SimpleAppBar extends StatelessWidget implements PreferredSizeWidget {
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

  const SimpleAppBar({
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
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor ?? AppColors.appbarBgColor,
      centerTitle: centerTitle,
      title: Text(
        title,
        style:
            titleTextStyle ??
            const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryTextColor,
            ),
      ),
      iconTheme:
          iconTheme ??
          IconThemeData(color: foregroundColor ?? AppColors.primaryTextColor),
      actions: actions,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      elevation: elevation,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
