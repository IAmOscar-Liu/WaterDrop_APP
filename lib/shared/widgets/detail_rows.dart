import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';

class DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Widget? trailing;

  const DetailRow({
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

class SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final double _fontSize;
  final EdgeInsetsGeometry _padding;

  const SummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  }) : _fontSize = 16,
       _padding = const EdgeInsets.symmetric(vertical: 4);

  const SummaryRow.compact({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  }) : _fontSize = 14,
       _padding = const EdgeInsets.symmetric(vertical: 2);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.secondaryTextColor,
              fontSize: _fontSize,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.primaryTextColor,
              fontSize: _fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
