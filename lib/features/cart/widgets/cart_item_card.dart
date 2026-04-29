import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/models/product.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/provider/account_provider.dart';
import 'package:flutter_ad_ecommerce/provider/collection_provider.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:flutter_ad_ecommerce/utils/number_formatter_extension.dart';
import 'package:flutter_ad_ecommerce/widgets/initial_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // Assuming you have a colors.dart

class CartItemCard extends ConsumerWidget {
  final Product product;
  final int quantity;
  final bool checked;
  final ValueChanged<bool?>? onCheckedChange;
  final void Function()? onQuantityChange;
  final void Function()? onDelete;

  const CartItemCard({
    super.key,
    required this.product,
    required this.quantity,
    required this.checked,
    required this.onCheckedChange,
    required this.onQuantityChange,
    required this.onDelete,
  });

  void _viewProductDetails(BuildContext context) {
    context.push(
      Routes.singleProductDetails,
      // extra: {"productId": product.id, "hideAddCartItemButton": true},
      extra: {"product": product, "hideAddCartItemButton": true},
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: AppColors.containerBgColor, // Dark background for the card
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4.0, right: 12.0),
                  child: SizedBox(
                    width: 24,
                    height: 80,
                    child: Center(
                      child: Checkbox(
                        value: checked,
                        onChanged: onCheckedChange,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: const BorderSide(
                          color: AppColors.secondaryTextColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _viewProductDetails(context),
                  child: Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child:
                            product.images != null && product.images!.isNotEmpty
                            ? FadeInImage.assetNetwork(
                                placeholder: "assets/images/photo_loading.gif",
                                image: product.images![0],
                                fit: BoxFit.cover,
                                imageErrorBuilder: (context, error, stackTrace) {
                                  // This builder is used if the network image fails to load.
                                  return Image.asset(
                                    "assets/images/photo_not_found.jpg",
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  );
                                },
                              )
                            : InitialImage(name: product.name),
                      ),
                      if (product.type == 'refrigeration')
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.8),
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(4.0),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            alignment: Alignment.center,
                            child: const Text(
                              "冷藏",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      if (product.type == 'virtual')
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.8),
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(4.0),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            alignment: Alignment.center,
                            child: const Text(
                              "免運",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12.0),
                // Item Name and Type
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => _viewProductDetails(context),
                        child: Text(
                          product.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6.0),
                      // Quantity Controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'NT\$ ${product.price.formatWithCommas()}',
                            style: const TextStyle(
                              color: AppColors.goldColor, // Gold for price
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          InkWell(
                            onTap: onQuantityChange,
                            child: Padding(
                              padding: EdgeInsetsGeometry.only(right: 4),
                              child: Row(
                                children: [
                                  const Text(
                                    '數量:', // Quantity label
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8.0),
                                  Text(
                                    quantity.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12.0),
            // Action Buttons
            Row(
              // mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.max,
              children: [
                TextButton(
                  onPressed: () {
                    final userId = ref.read(accountNotifierProvider).id;
                    context.push(
                      Routes.chatroomPage,
                      extra: {
                        "title": product.name,
                        "userId": userId,
                        "accountId": product.sellerId,
                        "productId": product.id,
                      },
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.infoColor,
                  ),
                  child: Text('聯絡客服', style: const TextStyle(fontSize: 14)),
                ),
                TextButton(
                  onPressed: ref.watch(collectionNotifierProvider).isProcessing
                      ? null
                      : () {
                          ref
                              .read(collectionNotifierProvider.notifier)
                              .addCollection(
                                product.id,
                                productName: product.name,
                              )
                              .then((result) {
                                final message = result.isSuccess
                                    ? result.data
                                    : result.error;
                                if (message == null) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(message),
                                    backgroundColor: Colors.green,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              });
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orangeAccent,
                  ),
                  child: const Text('加入收藏', style: TextStyle(fontSize: 14)),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: onQuantityChange,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    backgroundColor: AppColors.secondaryButtonColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                  ),
                  child: const Text('修改數量', style: TextStyle(fontSize: 14)),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onDelete,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                  ),
                  child: const Text('移除', style: TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
