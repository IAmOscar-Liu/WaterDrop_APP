import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';

class OrderDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Widget? trailing;

  const OrderDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.secondaryTextColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: trailing == null
                ? Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.primaryTextColor,
                      fontSize: 14,
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(
                          value,
                          style: const TextStyle(
                            color: AppColors.primaryTextColor,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      trailing!,
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class OrderSummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const OrderSummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.secondaryTextColor,
              fontSize: 16,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.primaryTextColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
