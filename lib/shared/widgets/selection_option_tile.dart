import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';

/// Selectable option with a title, two supporting values, and optional action.
/// Selection state and value formatting remain with the caller.
class SelectionOptionTile extends StatelessWidget {
  const SelectionOptionTile({
    super.key,
    required this.title,
    required this.primaryText,
    required this.secondaryText,
    required this.isSelected,
    required this.onTap,
    this.trailing,
    this.detailsSpacing = 12,
    this.strikeThroughTitle = false,
  });

  final String title;
  final String primaryText;
  final String secondaryText;
  final bool isSelected;
  final VoidCallback? onTap;
  final Widget? trailing;
  final double detailsSpacing;
  final bool strikeThroughTitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.navbarIndicatorColor.withValues(alpha: 0.18)
                : AppColors.tileColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? AppColors.selectedBorderColor
                  : AppColors.borderColor,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isSelected
                    ? AppColors.infoColor
                    : AppColors.secondaryTextColor,
                size: 22,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: onTap == null
                        ? AppColors.secondaryTextColor
                        : AppColors.primaryTextColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    decoration: strikeThroughTitle
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: onTap == null
                        ? AppColors.secondaryTextColor
                        : AppColors.primaryTextColor,
                  ),
                ),
              ),
              SizedBox(width: detailsSpacing),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    primaryText,
                    style: TextStyle(
                      color: onTap == null
                          ? AppColors.secondaryTextColor
                          : AppColors.goldColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    secondaryText,
                    style: const TextStyle(
                      color: AppColors.secondaryTextColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}
