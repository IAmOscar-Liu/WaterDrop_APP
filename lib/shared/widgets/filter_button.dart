import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';

/// Selected/unselected pill used by list filters. Callers own filter state.
class FilterButton extends StatelessWidget {
  const FilterButton({
    super.key,
    required this.isSelected,
    required this.onPressed,
    required this.child,
    this.icon,
  });

  final bool isSelected;
  final VoidCallback? onPressed;
  final Widget child;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    if (isSelected) {
      final style = ElevatedButton.styleFrom(
        foregroundColor: AppColors.primaryTextColor,
        backgroundColor: AppColors.navbarIndicatorColor,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      );
      return icon == null
          ? ElevatedButton(onPressed: onPressed, style: style, child: child)
          : ElevatedButton.icon(
              onPressed: onPressed,
              style: style,
              icon: icon,
              label: child,
            );
    }

    final style = OutlinedButton.styleFrom(
      foregroundColor: AppColors.secondaryTextColor,
      side: const BorderSide(color: AppColors.borderColor),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    );
    return icon == null
        ? OutlinedButton(onPressed: onPressed, style: style, child: child)
        : OutlinedButton.icon(
            onPressed: onPressed,
            style: style,
            icon: icon,
            label: child,
          );
  }
}
