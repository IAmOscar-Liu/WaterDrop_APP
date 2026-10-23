import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/models/order.dart';
import 'package:intl/intl.dart';

class RefundEligibilityInfo extends StatelessWidget {
  const RefundEligibilityInfo({
    super.key,
    required this.item,
    this.includeConversionNote = false,
  });
  final OrderItem item;
  final bool includeConversionNote;

  static const conversionNote = '退款金額的小數部分將依 NT\$1 = 10 金幣轉換，並合併計入退還金幣。';

  @override
  Widget build(BuildContext context) {
    final deadline = item.refundDeadlineAt?.toLocal();
    final deadlineText = deadline == null
        ? null
        : '新申請截止時間：${DateFormat('yyyy-MM-dd HH:mm').format(deadline)}';
    final notes = [if (deadlineText != null) deadlineText, conversionNote];
    final reason = switch (item.refundBlockReason) {
      'ORDER_NOT_PAID' => '訂單尚未付款',
      'RECEIPT_TIME_UNKNOWN' => '無法確認取貨時間，請聯絡客服協助',
      'PAYMENT_TIME_UNKNOWN' => '無法確認付款時間，請聯絡客服協助',
      'REFUND_WINDOW_EXPIRED' => '已超過新申請期限，已受理申請不受影響',
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (includeConversionNote) ...[
          const Text(
            '注意事項',
            style: TextStyle(
              color: AppColors.warningColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          for (final entry in notes.indexed)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.$1 + 1}. ',
                    style: const TextStyle(
                      color: AppColors.warningColor,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.$2,
                      style: const TextStyle(
                        color: AppColors.warningColor,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ] else if (deadlineText != null)
          Text(
            deadlineText,
            style: const TextStyle(
              color: AppColors.secondaryTextColor,
              fontSize: 12,
            ),
          ),
        if (!item.canRefund && reason != null)
          Text(
            reason,
            style: const TextStyle(
              color: AppColors.secondaryTextColor,
              fontSize: 12,
            ),
          ),
      ],
    );
  }
}
