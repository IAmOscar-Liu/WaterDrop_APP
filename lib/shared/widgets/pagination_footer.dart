import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';

/// The same loading and retry affordance for list and older-message pagination.
class PaginationFooter extends StatelessWidget {
  const PaginationFooter({
    super.key,
    this.loading = false,
    this.onLoadMore,
    this.hasError = false,
    this.label = '載入更多',
  });
  final bool loading;
  final VoidCallback? onLoadMore;
  final bool hasError;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (!loading && onLoadMore == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: loading
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text(
                    '載入中……',
                    style: TextStyle(color: AppColors.secondaryTextColor),
                  ),
                ],
              )
            : TextButton(
                onPressed: onLoadMore,
                child: Text(hasError ? '載入失敗，點擊重試' : label),
              ),
      ),
    );
  }
}
