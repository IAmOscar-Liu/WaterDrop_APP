import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart'; // Your colors file
import 'package:flutter_ad_ecommerce/models/api_enums.dart';
import 'package:flutter_ad_ecommerce/models/order.dart'; // Make sure you have this model
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/detail_rows.dart';
import 'package:flutter_ad_ecommerce/utils/coin_utils.dart';
import 'package:flutter_ad_ecommerce/utils/formatter.dart'; // Your formatter for dates
import 'package:flutter_ad_ecommerce/utils/number_formatter_extension.dart';
import 'package:go_router/go_router.dart';

class OrderCard extends StatefulWidget {
  final Order order;

  const OrderCard({super.key, required this.order});

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  @override
  Widget build(BuildContext context) {
    // final double subTotal =
    //     widget.order.totalAmount + (widget.order.discountCoin / 10);
    final double subTotal = widget.order.subTotal;
    final double discount = CoinUtils.toTwd(widget.order.discountCoin);
    final shippingCost = widget.order.shippingCost;
    final shippingCostDeduction = widget.order.shippingCostDeduction;
    final transactionFee = widget.order.transactionFee;
    final transactionFeeRateAtSale =
        widget.order.transactionFeeRateAtSale ?? 0.0;
    final orderStatus = widget.order.orderStatus;
    final orderStatusText = orderStatus.displayName;
    final orderStatusColor = orderStatus == OrderStatus.paymentProcessing
        ? AppColors.warningColor
        : AppColors.paidStatusColor;

    return Card(
      color: AppColors.containerBgColor,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Header: Date and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '訂單日期: ${Formatter.formatDateTime(widget.order.completedAt ?? widget.order.createdAt)}',
                  style: const TextStyle(
                    color: AppColors.secondaryTextColor,
                    fontSize: 14,
                  ),
                ),
                Text(
                  orderStatusText,
                  style: TextStyle(
                    color: orderStatusColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(color: AppColors.dividerColor),
            const SizedBox(height: 8),

            // Order Summary Footer
            SummaryRow(
              label: '商品總金額',
              value: subTotal.toDollarsString(prefix: "NT"),
            ),
            SummaryRow(
              label: '金幣折抵',
              value: '- ${discount.toDollarsString(prefix: "NT")}',
              valueColor: AppColors.greenColor, // Green for discount
            ),
            SummaryRow(
              label: '總運費',
              value: shippingCost.toDollarsString(prefix: "NT"),
            ),
            if (shippingCostDeduction > 0)
              SummaryRow(
                label: '運費減免',
                value:
                    '- ${shippingCostDeduction.toDollarsString(prefix: "NT")}',
                valueColor: AppColors.greenColor, // Green for discount
              ),
            if (!kReleaseMode)
              SummaryRow(
                label:
                    '手續費${transactionFeeRateAtSale == 0 ? "" : "(${transactionFeeRateAtSale * 100}%)"}',
                value: transactionFee.floor().toDollarsString(prefix: "NT"),
              ),
            const Divider(color: AppColors.dividerColor, height: 16),
            SummaryRow(
              label: '最終需支付現金',
              value: widget.order.totalAmount.floor().toDollarsString(
                prefix: "NT",
              ),
              valueColor: AppColors.goldColor, // Gold for final amount
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  context.push(
                    Routes.singleOrderDetails,
                    extra: {"orderId": widget.order.id},
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.infoColor,
                  foregroundColor: AppColors.primaryTextColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('查看詳情'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
