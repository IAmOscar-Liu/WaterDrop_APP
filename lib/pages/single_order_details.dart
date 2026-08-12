import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/features/order/widgets/order_detail_rows.dart';
import 'package:flutter_ad_ecommerce/features/order/widgets/order_item_list.dart';
import 'package:flutter_ad_ecommerce/features/order/widgets/order_status_badge.dart';
import 'package:flutter_ad_ecommerce/features/order/widgets/refund_widgets.dart';
import 'package:flutter_ad_ecommerce/main.dart';
import 'package:flutter_ad_ecommerce/models/api_enums.dart';
import 'package:flutter_ad_ecommerce/models/order.dart';
import 'package:flutter_ad_ecommerce/provider/account_provider.dart';
import 'package:flutter_ad_ecommerce/provider/order_provider.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:flutter_ad_ecommerce/utils/formatter.dart';
import 'package:flutter_ad_ecommerce/utils/number_formatter_extension.dart';
import 'package:flutter_ad_ecommerce/utils/parse_utils.dart';
import 'package:flutter_ad_ecommerce/utils/result.dart';
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

  Future<void> _refreshOrder() async {
    final orderId = _order?.id;
    if (orderId == null) return;

    final result = await _loadSingleOrder(orderId);
    if (!mounted || result.isFailure) return;

    setState(() {
      _order = result.data!;
    });
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

  void _showPaymentInfoDialog(Map<dynamic, dynamic> paymentInfo) {
    final accountNumber = paymentInfo['vAccount']?.toString().trim() ?? '';

    String formatValue(String key, dynamic value) {
      final text = value?.toString().trim() ?? '';
      if (key == 'vAccount' && text.length >= 16) {
        return text
            .replaceAllMapped(
              RegExp(r'.{1,4}'),
              (match) => '${match.group(0)} ',
            )
            .trimRight();
      }
      if (key == 'TradeAmt') {
        return 'NT\$ ${(ParseUtils.parseInt(text) ?? 0).formatWithCommas()}';
      }
      return text;
    }

    final text =
        <String, String>{
              'BankName': '銀行名稱',
              'BankCode': '銀行代碼',
              'vAccount': '銀行帳號',
              'TradeAmt': '繳費金額',
              'ExpireDate': '繳費期限',
            }.entries
            .where(
              (entry) =>
                  paymentInfo.containsKey(entry.key) &&
                  paymentInfo[entry.key]?.toString().trim().isNotEmpty == true,
            )
            .map(
              (entry) =>
                  '${entry.value}: ${formatValue(entry.key, paymentInfo[entry.key])}',
            )
            .join('\n');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF262A33),
          title: const Text("ATM轉帳資訊", style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: SelectableText(
              text.isNotEmpty ? text : '無可顯示的轉帳資訊',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.8,
              ),
            ),
          ),
          actions: [
            if (accountNumber.isNotEmpty)
              TextButton.icon(
                icon: const Icon(Icons.copy, color: Colors.white, size: 18),
                label: const Text(
                  "複製帳號",
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: accountNumber));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('已複製銀行帳號'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("關閉", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
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

  Future<bool> _showCreateRefundDialog(OrderItem item) async {
    final created = await showCreateRefundDialog(context, item: item);

    if (created) {
      await _refreshOrder();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已送出退貨申請')));
      }
    }

    return created;
  }

  void _showRefundItemsBottomSheet(OrderItem item) {
    showRefundItemsBottomSheet(
      context,
      item: item,
      onCreateRefund: _showCreateRefundDialog,
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

  void _viewProductDetails(OrderItem item) {
    final product = item.product;
    if (product == null) return;

    context.push(
      Routes.singleProductDetails,
      extra: {
        "productId": product.id,
        "hideAddCartItemButton": true,
        "hideAddCollectionButton": true,
      },
    );
  }

  void _contactSupport(OrderItem item) {
    final product = item.product;
    if (product == null) return;

    final userId = ref.read(accountNotifierProvider).id;
    context.push(
      Routes.chatroomPage,
      extra: {
        "title": product.name,
        "userId": userId,
        "accountId": product.sellerId,
        "productId": product.id,
        "productVariantId": item.productVariantId,
        "orderId": _order!.id,
      },
    );
  }

  Widget _buildProductList(List<OrderItem> items) {
    return OrderItemList(
      items: items,
      onContactSupport: _contactSupport,
      onCreateRefund: _showCreateRefundDialog,
      onShowRefundDetails: _showRefundItemsBottomSheet,
      onViewProductDetails: _viewProductDetails,
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
        return delivery.items.any(
          (dItem) =>
              dItem.id == item.id ||
              (dItem.productId == item.productId &&
                  dItem.productVariantId == item.productVariantId),
        );
      }).toList();

      for (var item in deliveryItems) {
        processedItemIds.add(item.id);
      }

      String title;
      if (delivery.logisticsType == DeliveryLogisticsType.CVS) {
        title = "超商取貨 - ${_getLogisticsName(delivery.logisticsSubType)}";
      } else if (delivery.logisticsType == DeliveryLogisticsType.homeDelivery) {
        title = "宅配到府";
      } else if (delivery.logisticsType == DeliveryLogisticsType.virtual) {
        title = "虛擬商品 - 免運";
      } else {
        title = delivery.logisticsType.wireValue;
      }

      itemSections.add(
        _buildSection(
          title: title,
          badge: OrderStatusBadge(status: delivery.status),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OrderDetailRow(label: '物流單號:', value: delivery.merchantTradeNo),
              OrderDetailRow(label: '物流狀態:', value: delivery.rtnMsg ?? 'N/A'),
              if (delivery.logisticsType == DeliveryLogisticsType.CVS &&
                  delivery.cvsStoreInfo is Map &&
                  delivery.cvsStoreInfo!["storeName"] is String)
                OrderDetailRow(
                  label: '取貨門市:',
                  value: delivery.cvsStoreInfo!["storeName"],
                ),
              if (delivery.logisticsType == DeliveryLogisticsType.CVS &&
                  delivery.cvsStoreInfo is Map &&
                  delivery.cvsStoreInfo!["storeAddress"] is String)
                OrderDetailRow(
                  label: '取貨地址:',
                  value: delivery.cvsStoreInfo!["storeAddress"],
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
                                                        OrderStatusBadge(
                                                          status: log.status,
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
              if (delivery.logisticsType == DeliveryLogisticsType.CVS ||
                  delivery.logisticsType ==
                      DeliveryLogisticsType.homeDelivery) ...[
                const Divider(color: AppColors.dividerColor),
                OrderSummaryRow(
                  label: delivery.feeDeduction > 0 ? '運費' : '運費小計',
                  value: 'NT\$ ${delivery.fee.formatWithCommas()}',
                ),
                if (delivery.feeDeduction > 0) ...[
                  OrderSummaryRow(
                    label:
                        '運費減免(${delivery.feeDeduction >= delivery.fee ? '免運費活動中' : '運費優惠活動中'})',
                    value: '- NT\$ ${delivery.feeDeduction.formatWithCommas()}',
                    valueColor: AppColors.greenColor,
                  ),
                  OrderSummaryRow(
                    label: '運費小計',
                    value:
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
      if (_order!.orderPayment != OrderPayment.Credit &&
          _order!.orderStatus == OrderStatus.paymentProcessing) {
        itemSections.add(
          _buildSection(
            title: "待付款商品",
            child: _buildProductList(unassignedItems),
          ),
        );
      } else {
        itemSections.add(
          _buildSection(
            title: "運單未建立-請聯絡客服",
            titleIcon: const Icon(Icons.error, color: Colors.red),
            titleColor: Colors.red,
            child: _buildProductList(unassignedItems),
          ),
        );
      }
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
                  if (_order!.merchantTradeNo.isNotEmpty)
                    OrderDetailRow(
                      label: '訂單編號:',
                      value: _order!.merchantTradeNo,
                    ),
                  OrderDetailRow(
                    label: '訂單日期:',
                    value: Formatter.formatDateTime(
                      _order!.completedAt ?? _order!.createdAt,
                    ),
                  ),
                  OrderDetailRow(
                    label: '訂單狀態:',
                    value: _order!.orderStatus.displayName,
                  ),
                  OrderDetailRow(
                    label: '付款方式:',
                    value: _order!.orderPayment.displayName,
                    trailing:
                        _order!.orderPayment == OrderPayment.ATM &&
                            _order!.paymentInfo is Map
                        ? InkWell(
                            onTap: () => _showPaymentInfoDialog(
                              _order!.paymentInfo as Map<dynamic, dynamic>,
                            ),
                            borderRadius: BorderRadius.circular(4),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                "轉帳資訊",
                                style: TextStyle(
                                  color: AppColors.infoColor,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
            ...itemSections,
            _buildSection(
              title: '訂單摘要',
              child: Column(
                children: [
                  OrderSummaryRow(
                    label: '商品總金額',
                    value: subtotal.toDollarsString(prefix: "NT"),
                  ),
                  OrderSummaryRow(
                    label: '金幣折抵',
                    value: '- ${discount.toDollarsString(prefix: "NT")}',
                    valueColor: AppColors.greenColor,
                  ),
                  OrderSummaryRow(
                    label: '總運費',
                    value: shippingCost.toDollarsString(prefix: "NT"),
                  ),
                  if (shippingCostDeduction > 0)
                    OrderSummaryRow(
                      label: '運費減免',
                      value:
                          '- ${shippingCostDeduction.toDollarsString(prefix: "NT")}',
                      valueColor: AppColors.greenColor, // Green for discount
                    ),
                  if (!kReleaseMode)
                    OrderSummaryRow(
                      label:
                          '手續費${(_order!.transactionFeeRateAtSale == null || _order!.transactionFeeRateAtSale == 0) ? "" : "(${_order!.transactionFeeRateAtSale! * 100}%)"}',
                      value: transactionFee.floor().toDollarsString(
                        prefix: "NT",
                      ),
                    ),
                  const Divider(color: AppColors.dividerColor),
                  OrderSummaryRow(
                    label: '最終需支付現金',
                    value: _order!.totalAmount.floor().toDollarsString(
                      prefix: "NT",
                    ),
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
