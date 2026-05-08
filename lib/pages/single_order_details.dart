import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/main.dart';
import 'package:flutter_ad_ecommerce/models/order.dart';
import 'package:flutter_ad_ecommerce/models/product.dart';
import 'package:flutter_ad_ecommerce/provider/account_provider.dart';
import 'package:flutter_ad_ecommerce/provider/order_provider.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:flutter_ad_ecommerce/utils/formatter.dart';
import 'package:flutter_ad_ecommerce/utils/number_formatter_extension.dart';
import 'package:flutter_ad_ecommerce/utils/result.dart';
import 'package:flutter_ad_ecommerce/widgets/initial_image.dart';
import 'package:flutter_ad_ecommerce/widgets/simple_app_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SingleOrderDetails extends ConsumerStatefulWidget {
  const SingleOrderDetails({
    super.key,
    required this.extra,
    this.openedFromDeepLink = false,
  });

  final dynamic extra;
  final bool openedFromDeepLink;

  @override
  ConsumerState<SingleOrderDetails> createState() => _SingleOrderDetailsState();
}

class _SingleOrderDetailsState extends ConsumerState<SingleOrderDetails> {
  Order? _order;
  bool _isLoading = true;
  dynamic _error;

  @override
  void initState() {
    super.initState();
    if (widget.extra is Map && widget.extra['order'] is Order) {
      setState(() {
        _isLoading = false;
        _order = widget.extra['order'];
      });
    } else if (widget.extra is Map && widget.extra['orderId'] is String) {
      _loadSingleOrder(widget.extra['orderId']).then((value) {
        if (value.isSuccess) {
          setState(() {
            _isLoading = false;
            _order = value.data!;
          });
        } else {
          setState(() {
            _isLoading = false;
            _error =
                value.error ??
                "Failed to load order ${widget.extra['orderId']}";
          });
        }
      });
    } else {
      // If data is missing, pop immediately
      WidgetsBinding.instance.addPostFrameCallback((_) => context.pop());
      return;
    }
  }

  Future<Result<Order>> _loadSingleOrder(String orderId) async {
    await Future.delayed(Duration.zero);

    return await ref
        .read(orderNotifierProvider.notifier)
        .getOrder(orderId: orderId);
  }

  Widget _buildLayout({required Widget child}) {
    return Scaffold(
      backgroundColor: AppColors.primaryColor,
      appBar: SimpleAppBar(
        title: '訂單詳情',
        leading: !context.canPop() && widget.openedFromDeepLink
            ? IconButton(
                icon: const Icon(Icons.home_outlined),
                onPressed: () {
                  MyApp.loadAdDailyStats(context);
                  context.replace(Routes.homePage);
                },
              )
            : null,
      ),
      body: child,
    );
  }

  Widget _buildDetailRow(String label, String value) {
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
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.primaryTextColor,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getLogisticsName(String subType) {
    return {
          'FAMI': '全家',
          'UNIMART': '7-ELEVEN超商',
          'FAMIC2C': '全家店到店',
          'UNIMARTC2C': '7-ELEVEN交貨便',
          'HILIFEC2C': '萊爾富店到店',
          'OKMARTC2C': 'OK店到店',
          'OKMART_LOW_TMP_C2C': 'OK低溫店到店',
        }[subType] ??
        subType;
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
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

  Widget _buildStatusBadge(String status) {
    String text;
    Color color;
    switch (status) {
      case "pending":
        text = "處理中";
        color = Colors.orange;
        break;
      case "shipped":
        text = "已出貨";
        color = AppColors.infoColor;
        break;
      case "delivered":
        text = "已送達";
        color = AppColors.greenColor;
        break;
      case "ready_for_pickup":
        text = "已送達";
        color = AppColors.greenColor;
        break;
      case "returned":
        text = "已退回";
        color = Colors.red;
        break;
      case "cancelled":
        text = "已取消";
        color = Colors.grey;
        break;
      case "exception":
        text = "發生異常";
        color = Colors.grey;
        break;
      case "unknown":
        text = "未知狀態";
        color = Colors.grey;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
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

  Widget _buildSection({
    required String title,
    required Widget child,
    Widget? titleIcon,
    Color? titleColor,
    Widget? badge,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.containerBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (titleIcon != null) ...[titleIcon, const SizedBox(width: 8)],
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: titleColor ?? AppColors.primaryTextColor,
                ),
              ),
              if (badge != null) badge,
            ],
          ),
          const Divider(color: AppColors.dividerColor),
          child,
        ],
      ),
    );
  }

  void _viewProductDetails(Product product) {
    context.push(
      Routes.singleProductDetails,
      extra: {
        "productId": product.id,
        "hideAddCartItemButton": true,
        "hideAddCollectionButton": true,
      },
    );
  }

  Widget _buildProductList(List<OrderItem> items) {
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
                    : () => _viewProductDetails(item.product!),
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
                    if (item.product?.type == 'virtual')
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
                    const SizedBox(height: 2),
                    if (item.product != null)
                      InkWell(
                        onTap: () {
                          final userId = ref.read(accountNotifierProvider).id;
                          context.push(
                            Routes.chatroomPage,
                            extra: {
                              "title": item.product!.name,
                              "userId": userId,
                              "accountId": item.product!.sellerId,
                              "productId": item.product!.id,
                              "orderId": _order!.id,
                            },
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(
                            top: 6,
                            bottom: 6,
                            right: 8,
                          ),
                          child: Text(
                            '聯絡客服',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.infoColor,
                            ),
                          ),
                        ),
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

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _buildLayout(
        child: Center(
          child: Text("$_error", style: TextStyle(color: Colors.white)),
        ),
      );
    } else if (_isLoading || _order == null) {
      return _buildLayout(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('載入訂單中......', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    final safeAreaPadding = MediaQuery.of(context).padding;

    // final double subtotal = _order!.items.fold(
    //   0,
    //   (sum, item) => sum + item.lineTotal,
    // );
    final double subtotal = _order!.subTotal;
    final double discount = _order!.discountCoin / 10;
    final shippingCost = _order!.shippingCost;
    final shippingCostDeduction = _order!.shippingCostDeduction;
    final transactionFee = _order!.transactionFee;

    final List<Widget> itemSections = [];
    final Set<String> processedItemIds = {};

    for (var delivery in _order!.deliveries) {
      final deliveryItems = _order!.items.where((item) {
        return delivery.items.any((dItem) => dItem.id == item.id);
      }).toList();

      for (var item in deliveryItems) {
        processedItemIds.add(item.id);
      }

      String title;
      if (delivery.logisticsType == "CVS") {
        title = "超商取貨 - ${_getLogisticsName(delivery.logisticsSubType)}";
      } else if (delivery.logisticsType == "home_delivery") {
        title = "宅配到府";
      } else if (delivery.logisticsType == "virtual") {
        title = "虛擬商品 - 免運";
      } else {
        title = delivery.logisticsType;
      }

      itemSections.add(
        _buildSection(
          title: title,
          badge: _buildStatusBadge(delivery.status),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('物流單號:', delivery.merchantTradeNo),
              _buildDetailRow('物流狀態:', delivery.rtnMsg ?? 'N/A'),
              if (delivery.logisticsType == "CVS" &&
                  delivery.cvsStoreInfo is Map &&
                  delivery.cvsStoreInfo!["storeName"] is String)
                _buildDetailRow('取貨門市:', delivery.cvsStoreInfo!["storeName"]),
              if (delivery.logisticsType == "CVS" &&
                  delivery.cvsStoreInfo is Map &&
                  delivery.cvsStoreInfo!["storeAddress"] is String)
                _buildDetailRow(
                  '取貨地址:',
                  delivery.cvsStoreInfo!["storeAddress"],
                ),
              if (delivery.logs.isNotEmpty)
                InkWell(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: AppColors.primaryColor,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      builder: (BuildContext context) {
                        final mediaQuery = MediaQuery.of(context);
                        final maxChildSize =
                            (mediaQuery.size.height -
                                mediaQuery.padding.top -
                                kToolbarHeight) /
                            mediaQuery.size.height;
                        var sheetSize = 0.5;

                        return StatefulBuilder(
                          builder: (context, setSheetState) {
                            return NotificationListener<
                              DraggableScrollableNotification
                            >(
                              onNotification: (notification) {
                                if ((notification.extent - sheetSize).abs() >
                                    0.01) {
                                  setSheetState(() {
                                    sheetSize = notification.extent;
                                  });
                                }
                                return false;
                              },
                              child: DraggableScrollableSheet(
                                initialChildSize: 0.5,
                                minChildSize: 0.5,
                                maxChildSize: maxChildSize
                                    .clamp(0.5, 1.0)
                                    .toDouble(),
                                expand: false,
                                builder: (context, scrollController) {
                                  return Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Center(
                                          child: Icon(
                                            sheetSize <= 0.51
                                                ? Icons.keyboard_arrow_up
                                                : Icons.keyboard_arrow_down,
                                            color: AppColors.secondaryTextColor,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          '運單詳情',
                                          style: TextStyle(
                                            color: AppColors.primaryTextColor,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Expanded(
                                          child: ListView.builder(
                                            controller: scrollController,
                                            itemCount: delivery.logs.length,
                                            itemBuilder: (context, index) {
                                              final log = delivery.logs[index];
                                              return Container(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 8.0,
                                                    ),
                                                padding: const EdgeInsets.all(
                                                  12.0,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.tileColor,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        _buildStatusBadge(
                                                          log.status,
                                                        ),
                                                        Text(
                                                          Formatter.formatDateTime(
                                                            log.createdAt,
                                                          ),
                                                          style: const TextStyle(
                                                            color: AppColors
                                                                .secondaryTextColor,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            left: 8.0,
                                                          ),
                                                      child: Text(
                                                        log.rtnMsg,
                                                        style: const TextStyle(
                                                          color: AppColors
                                                              .primaryTextColor,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      "運單詳情",
                      style: TextStyle(color: AppColors.infoColor),
                    ),
                  ),
                ),
              const Divider(color: AppColors.dividerColor),
              _buildProductList(deliveryItems),
              if (delivery.logisticsType == "CVS" ||
                  delivery.logisticsType == "home_delivery") ...[
                const Divider(color: AppColors.dividerColor),
                _buildSummaryRow(
                  delivery.feeDeduction > 0 ? '運費' : '運費小計',
                  'NT\$ ${delivery.fee.formatWithCommas()}',
                ),
                if (delivery.feeDeduction > 0) ...[
                  _buildSummaryRow(
                    '運費減免(${delivery.feeDeduction >= delivery.fee ? '免運費活動中' : '運費優惠活動中'})',
                    '- NT\$ ${delivery.feeDeduction.formatWithCommas()}',
                    valueColor: AppColors.greenColor,
                  ),
                  _buildSummaryRow(
                    '運費小計',
                    'NT\$ ${(delivery.fee - delivery.feeDeduction).formatWithCommas()}',
                  ),
                ],
              ],
            ],
          ),
        ),
      );
    }

    final unassignedItems = _order!.items
        .where((item) => !processedItemIds.contains(item.id))
        .toList();

    if (unassignedItems.isNotEmpty) {
      itemSections.add(
        _buildSection(
          title: "運單未建立-請聯絡客服",
          titleIcon: const Icon(Icons.error, color: Colors.red),
          titleColor: Colors.red,
          child: _buildProductList(unassignedItems),
        ),
      );
    }

    return _buildLayout(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(top: 12, bottom: safeAreaPadding.bottom + 24),
        child: Column(
          children: [
            _buildSection(
              title: '訂單資訊',
              child: Column(
                children: [
                  _buildDetailRow('訂單編號:', _order!.merchantTradeNo),
                  _buildDetailRow(
                    '訂單日期:',
                    Formatter.formatDateTime(
                      _order!.completedAt ?? _order!.createdAt,
                    ),
                  ),
                  _buildDetailRow('訂單狀態:', _order!.orderStatus.toUpperCase()),
                ],
              ),
            ),
            ...itemSections,
            _buildSection(
              title: '訂單摘要',
              child: Column(
                children: [
                  _buildSummaryRow(
                    '商品總金額',
                    subtotal.toDollarsString(prefix: "NT"),
                  ),
                  _buildSummaryRow(
                    '金幣折抵',
                    '- ${discount.toDollarsString(prefix: "NT")}',
                    valueColor: AppColors.greenColor,
                  ),
                  _buildSummaryRow(
                    '總運費',
                    shippingCost.toDollarsString(prefix: "NT"),
                  ),
                  if (shippingCostDeduction > 0)
                    _buildSummaryRow(
                      '運費減免',
                      '- ${shippingCostDeduction.toDollarsString(prefix: "NT")}',
                      valueColor: AppColors.greenColor, // Green for discount
                    ),
                  if (!kReleaseMode)
                    _buildSummaryRow(
                      '手續費${(_order!.transactionFeeRateAtSale == null || _order!.transactionFeeRateAtSale == 0) ? "" : "(${_order!.transactionFeeRateAtSale! * 100}%)"}',
                      transactionFee.floor().toDollarsString(prefix: "NT"),
                    ),
                  const Divider(color: AppColors.dividerColor),
                  _buildSummaryRow(
                    '最終需支付現金',
                    _order!.totalAmount.floor().toDollarsString(prefix: "NT"),
                    valueColor: AppColors.goldColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
