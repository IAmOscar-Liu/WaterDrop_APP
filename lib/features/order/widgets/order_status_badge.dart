import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/models/api_enums.dart';

class OrderStatusBadge extends StatelessWidget {
  final DeliveryStatus status;

  const OrderStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final style = switch (status) {
      DeliveryStatus.pending => (text: "待出貨", color: Colors.orange),
      DeliveryStatus.shipped => (text: "已出貨", color: AppColors.infoColor),
      DeliveryStatus.delivered => (text: "已送達", color: AppColors.greenColor),
      DeliveryStatus.readyForPickup => (
        text: "已送達",
        color: AppColors.greenColor,
      ),
      DeliveryStatus.returned => (text: "已退回", color: Colors.red),
      DeliveryStatus.cancelled => (text: "已取消", color: Colors.grey),
      DeliveryStatus.exception => (text: "發生異常", color: Colors.grey),
      DeliveryStatus.unknown => (text: "未知狀態", color: Colors.grey),
    };

    return _StatusBadge(text: style.text, color: style.color);
  }
}

class RefundStatusBadge extends StatelessWidget {
  final RefundStatus status;

  const RefundStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final style = switch (status) {
      RefundStatus.pending => (text: "待處理", color: Colors.orange),
      RefundStatus.processing => (text: "處理中", color: AppColors.infoColor),
      RefundStatus.completed => (text: "已完成", color: AppColors.greenColor),
      RefundStatus.cancelled => (text: "已取消", color: Colors.grey),
    };

    return _StatusBadge(text: style.text, color: style.color);
  }
}

class _StatusBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
