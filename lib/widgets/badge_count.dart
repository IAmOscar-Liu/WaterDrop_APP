import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';

class BadgeCount extends StatelessWidget {
  const BadgeCount({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.dangerButtonColor,
        borderRadius: BorderRadius.circular(10),
      ),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      child: Text(
        count.toString(),
        style: const TextStyle(
          color: AppColors.primaryTextColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
