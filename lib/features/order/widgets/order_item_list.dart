import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/models/order.dart';
import 'package:flutter_ad_ecommerce/widgets/initial_image.dart';
import 'package:flutter_ad_ecommerce/utils/number_formatter_extension.dart';

class OrderItemList extends StatelessWidget {
  final List<OrderItem> items;
  final ValueChanged<OrderItem> onContactSupport;
  final ValueChanged<OrderItem> onCreateRefund;
  final ValueChanged<OrderItem> onShowRefundDetails;
  final ValueChanged<OrderItem> onViewProductDetails;

  const OrderItemList({
    super.key,
    required this.items,
    required this.onContactSupport,
    required this.onCreateRefund,
    required this.onShowRefundDetails,
    required this.onViewProductDetails,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: item.product == null
                    ? null
                    : () => onViewProductDetails(item),
                child: Stack(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child:
                          item.product?.images != null &&
                              item.product!.images!.isNotEmpty
                          ? FadeInImage.assetNetwork(
                              placeholder: "assets/images/photo_loading.gif",
                              image: item.product!.images![0],
                              fit: BoxFit.cover,
                              imageErrorBuilder: (context, error, stackTrace) {
                                return Image.asset(
                                  "assets/images/photo_not_found.jpg",
                                  fit: BoxFit.cover,
                                );
                              },
                            )
                          : InitialImage(name: item.productNameAtSale),
                    ),
                    if (item.product?.type == 'refrigeration')
                      const _ProductTypeBadge(label: "冷藏", color: Colors.blue),
                    if (item.product?.type == 'virtual')
                      const _ProductTypeBadge(label: "免運", color: Colors.green),
                  ],
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productNameAtSale,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.primaryTextColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (item.variantDisplayName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.variantDisplayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.secondaryTextColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (item.product != null)
                          _ActionLink(
                            label: '聯絡客服',
                            color: AppColors.infoColor,
                            onTap: () => onContactSupport(item),
                          ),
                        if (item.refundItems.isNotEmpty)
                          _ActionLink(
                            label: '退貨詳情',
                            color: AppColors.goldColor,
                            leftPadding: 4,
                            onTap: () => onShowRefundDetails(item),
                          )
                        else if (item.canRefund &&
                            item.remainingRefundQuantity > 0)
                          _ActionLink(
                            label: '申請退貨',
                            color: AppColors.goldColor,
                            leftPadding: 4,
                            onTap: () => onCreateRefund(item),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    item.unitPriceAtSale.toDollarsString(prefix: "NT"),
                    style: const TextStyle(
                      color: AppColors.primaryTextColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    '數量: ${item.quantity}',
                    style: const TextStyle(
                      color: AppColors.secondaryTextColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      separatorBuilder: (context, index) =>
          const Divider(color: AppColors.dividerColor, height: 1),
    );
  }
}

class _ActionLink extends StatelessWidget {
  final String label;
  final Color color;
  final double leftPadding;
  final VoidCallback onTap;

  const _ActionLink({
    required this.label,
    required this.color,
    required this.onTap,
    this.leftPadding = 0,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(
          top: 6,
          bottom: 6,
          right: 8,
          left: leftPadding,
        ),
        child: Text(label, style: TextStyle(fontSize: 14, color: color)),
      ),
    );
  }
}

class _ProductTypeBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _ProductTypeBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.8),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(4.0),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 2),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
