import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';

class SimpleAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
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
    this.subtitle,
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
    final subtitleText = subtitle?.trim();

    return AppBar(
      backgroundColor: backgroundColor ?? AppColors.appbarBgColor,
      centerTitle: centerTitle,
      title: subtitleText == null || subtitleText.isEmpty
          ? Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  titleTextStyle ??
                  const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryTextColor,
                  ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: centerTitle
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      titleTextStyle ??
                      const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryTextColor,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitleText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.secondaryTextColor,
                  ),
                ),
              ],
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
