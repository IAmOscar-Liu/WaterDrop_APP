import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/app_panel.dart';

/// A panel with a heading and divider; feature content stays with the caller.
class SectionPanel extends StatelessWidget {
  const SectionPanel({
    super.key,
    required this.title,
    required this.child,
    this.titleIcon,
    this.titleColor = AppColors.primaryTextColor,
    this.badge,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  final String title;
  final Widget child;
  final Widget? titleIcon;
  final Color titleColor;
  final Widget? badge;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      margin: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (titleIcon != null) ...[titleIcon!, const SizedBox(width: 8)],
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: titleColor,
                ),
              ),
              if (badge != null) badge!,
            ],
          ),
          const Divider(color: AppColors.dividerColor),
          child,
        ],
      ),
    );
  }
}
