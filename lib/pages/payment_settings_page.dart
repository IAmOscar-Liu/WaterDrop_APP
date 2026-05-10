// ignore_for_file: constant_identifier_names

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/app_constants.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/features/ecpay/widget/checkout_delivery_section.dart';
import 'package:flutter_ad_ecommerce/features/ecpay/widget/checkout_webview.dart';
import 'package:flutter_ad_ecommerce/models/logistics_info.dart';
import 'package:flutter_ad_ecommerce/models/order.dart';
import 'package:flutter_ad_ecommerce/models/payment_settings.dart';
import 'package:flutter_ad_ecommerce/models/product.dart';
import 'package:flutter_ad_ecommerce/provider/account_provider.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/provider/order_provider.dart';
import 'package:flutter_ad_ecommerce/provider/system_provider.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:flutter_ad_ecommerce/utils/number_formatter_extension.dart';
import 'package:flutter_ad_ecommerce/utils/parse_utils.dart';
import 'package:flutter_ad_ecommerce/widgets/page_status.dart';
import 'package:flutter_ad_ecommerce/widgets/simple_app_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum CheckoutStat { validating, settingMap, choosingMap, processingPayment }

class PaymentSettingsPage extends ConsumerStatefulWidget {
  final dynamic extra;
  const PaymentSettingsPage({super.key, required this.extra});

  @override
  ConsumerState<PaymentSettingsPage> createState() =>
      _PaymentSettingsPageState();
}

class _PaymentSettingsPageState extends ConsumerState<PaymentSettingsPage> {
  CheckoutStat _checkoutStat = CheckoutStat.validating;
  LogisticsSubType _logisticsSubType = AppConstants.logisticsSubType == "B2C"
      ? LogisticsSubType.FAMI
      : LogisticsSubType.FAMIC2C;

  // New state variables for grouped delivery by Seller
  final Map<String, DeliveryMethod?> _refrigerationMethods = {};
  final Map<String, LogisticsMapInfo?> _refrigerationStores = {};

  final Map<String, DeliveryMethod?> _normalMethods = {};
  final Map<String, LogisticsSubType?> _normalCvsTypes = {};
  final Map<String, LogisticsMapInfo?> _normalStores = {};

  String? _selectingStoreFor; // 'refrigeration' or 'normal'
  String? _selectingStoreForSellerId; // Track which seller we are selecting for
  // final Set<String> _manualPickupItemIds = {};

  @override
  void initState() {
    super.initState();

    if (widget.extra is! Map ||
        widget.extra['shippingFee'] == null ||
        widget.extra['discountCoin'] == null ||
        widget.extra['cartItems'] == null) {
      // If data is missing, pop immediately
      WidgetsBinding.instance.addPostFrameCallback((_) => context.pop());
      return;
    }
  }

  void _sendOrderCompletedNotification(Order completedOrder) async {
    ref
        .read(dioProvider)
        .post(
          "/api/order/send-notification",
          data: {"orderId": completedOrder.id},
        )
        // ignore: body_might_complete_normally_catch_error
        .catchError((e) {});
  }

  Widget _buildLayout({required Widget child, bool allowPop = true}) {
    return PopScope(
      canPop: allowPop,
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBgColor,
        appBar: SimpleAppBar(
          title: '結帳設定',
          // Hide the back button if popping is not allowed
          automaticallyImplyLeading: allowPop,
          leading: allowPop ? null : const SizedBox.shrink(),
        ),
        resizeToAvoidBottomInset: true,
        body: child,
      ),
    );
  }

  Widget _buildReceiverInfo() {
    final accountInfo = ref.watch(accountNotifierProvider);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.containerBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "收件人資訊",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppColors.primaryTextColor,
            ),
          ),
          const Divider(color: AppColors.dividerColor),
          Text(
            "姓名：${accountInfo.name.isEmpty ? "尚未填寫" : accountInfo.name}",
            style: const TextStyle(color: AppColors.secondaryTextColor),
          ),
          Text(
            "地址：${(accountInfo.address == null || accountInfo.address!.isEmpty) ? "尚未填寫" : accountInfo.address}",
            style: const TextStyle(color: AppColors.secondaryTextColor),
          ),
          Text(
            "手機號碼：${(accountInfo.phone == null || accountInfo.phone!.isEmpty) ? "尚未填寫" : accountInfo.phone}",
            style: const TextStyle(color: AppColors.secondaryTextColor),
          ),
          // Text(
          //   "Email：${accountInfo.email.isEmpty ? "尚未填寫" : accountInfo.email}",
          //   style: const TextStyle(color: AppColors.secondaryTextColor),
          // ),
        ],
      ),
    );
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

  Widget _buildOrderSummary({
    double subtotal = 0.0,
    double shippingCost = 0.0,
    double shippingCostDeduction = 0.0,
    double transactionFee = 0.0,
    int discountAmount = 0,
    double totalAmount = 0.0,
    double transactionFeeRate = 0.0,
  }) {
    // final double finalAmount = widget.extra['totalAmount'];
    // final int discountCoin = widget.extra['discountCoin'];
    // final int discountAmount = (discountCoin / 10).floor();
    // final double subtotal = widget.extra['subTotal'];
    // final double totalAmount =
    //     subtotal - discountAmount + shippingCost + transactionFee;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.containerBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "訂單摘要",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppColors.primaryTextColor,
            ),
          ),
          const Divider(color: AppColors.dividerColor),
          _buildSummaryRow('商品總金額', subtotal.toDollarsString(prefix: "NT")),
          _buildSummaryRow(
            '金幣折抵(${discountAmount * 10}金幣)',
            '- ${discountAmount.toDollarsString(prefix: "NT")}',
            valueColor: AppColors.greenColor,
          ),
          _buildSummaryRow('總運費', shippingCost.toDollarsString(prefix: "NT")),
          if (shippingCostDeduction > 0)
            _buildSummaryRow(
              '運費減免',
              '- ${shippingCostDeduction.toDollarsString(prefix: "NT")}',
              valueColor: AppColors.greenColor,
            ),
          if (!kReleaseMode)
            _buildSummaryRow(
              '手續費${transactionFeeRate == 0 ? "" : "(${transactionFeeRate * 100}%)"}',
              transactionFee.floor().toDollarsString(prefix: "NT"),
            ),
          const Divider(color: AppColors.dividerColor),
          _buildSummaryRow(
            "最終需支付現金",
            totalAmount.floor().toDollarsString(prefix: "NT"),
            valueColor: AppColors.goldColor,
          ),
        ],
      ),
    );
  }

  Map<String, List<CartItem>> _groupItemsBySeller(List<CartItem> items) {
    final Map<String, List<CartItem>> grouped = {};
    for (var item in items) {
      final sellerId = item.product.sellerId;
      if (!grouped.containsKey(sellerId)) {
        grouped[sellerId] = [];
      }
      grouped[sellerId]!.add(item);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, PaymentSettings> shippingFee =
        widget.extra["shippingFee"];
    final accountInfo = ref.watch(accountNotifierProvider);
    final currentOrder = ref.watch(systemNotifierProvider).currentOrder;
    final List<CartItem> cartItems = widget.extra['cartItems'];

    final virtualItems = cartItems
        .where((i) => i.product.type == 'virtual')
        .toList();
    final refrigerationItems = cartItems
        .where((i) => i.product.type == 'refrigeration')
        .toList();
    final normalItems = cartItems
        .where((i) => i.product.type == 'normal')
        .toList();

    // Group items by seller for validation logic
    final refrigBySeller = _groupItemsBySeller(refrigerationItems);
    final normalBySeller = _groupItemsBySeller(normalItems);

    bool isRefrigerationValid = true;
    for (var entry in refrigBySeller.entries) {
      final sellerId = entry.key;
      final items = entry.value;
      final method = _refrigerationMethods[sellerId];
      final store = _refrigerationStores[sellerId];
      final hasHome = items.any((i) => i.product.allowHomeDelivery);

      if (!hasHome) {
        // Force CVS check
        if (store == null) isRefrigerationValid = false;
      } else {
        if (method == null) isRefrigerationValid = false;
        if (method == DeliveryMethod.cvs && store == null) {
          isRefrigerationValid = false;
        }
        // Check split case: Home selected but some items don't support it -> need store
        if (method == DeliveryMethod.home) {
          final hasNonHome = items.any((i) => !i.product.allowHomeDelivery);
          if (hasNonHome && store == null) {
            isRefrigerationValid = false;
          }
        }
      }
    }

    bool isNormalValid = true;
    for (var entry in normalBySeller.entries) {
      final sellerId = entry.key;
      final items = entry.value;
      final method = _normalMethods[sellerId];
      final cvsType = _normalCvsTypes[sellerId];
      final store = _normalStores[sellerId];
      final hasHome = items.any((i) => i.product.allowHomeDelivery);

      if (!hasHome) {
        // Force CVS check
        if (cvsType == null || store == null) isNormalValid = false;
      } else {
        if (method == null) isNormalValid = false;
        if (method == DeliveryMethod.cvs &&
            (cvsType == null || store == null)) {
          isNormalValid = false;
        }
        // Check split case
        if (method == DeliveryMethod.home) {
          final hasNonHome = items.any((i) => !i.product.allowHomeDelivery);
          if (hasNonHome && (cvsType == null || store == null)) {
            isNormalValid = false;
          }
        }
      }
    }

    List<Map<String, dynamic>> generateGroup() {
      // Generate Groups
      List<Map<String, dynamic>> groups = [];

      double getDefaultPickupFee(String sellerId, LogisticsSubType type) {
        switch (type) {
          case LogisticsSubType.FAMIC2C:
            return shippingFee['default']?.FAMIC2C ?? 0;
          case LogisticsSubType.UNIMARTC2C:
            return shippingFee['default']?.UNIMARTC2C ?? 0;
          case LogisticsSubType.HILIFEC2C:
            return shippingFee['default']?.HILIFEC2C ?? 0;
          case LogisticsSubType.OKMARTC2C:
            return shippingFee['default']?.OKMARTC2C ?? 0;
          case LogisticsSubType.OKMART_LOW_TMP_C2C:
            return shippingFee['default']?.OKMART_LOW_TMP_C2C ?? 0;
          default:
            return 0.0;
        }
      }

      double getPickupFee(String sellerId, LogisticsSubType type) {
        final paymentSettings = shippingFee[sellerId];
        switch (type) {
          case LogisticsSubType.FAMIC2C:
            return paymentSettings?.FAMIC2C ??
                shippingFee['default']?.FAMIC2C ??
                0;
          case LogisticsSubType.UNIMARTC2C:
            return paymentSettings?.UNIMARTC2C ??
                shippingFee['default']?.UNIMARTC2C ??
                0;
          case LogisticsSubType.HILIFEC2C:
            return paymentSettings?.HILIFEC2C ??
                shippingFee['default']?.HILIFEC2C ??
                0;
          case LogisticsSubType.OKMARTC2C:
            return paymentSettings?.OKMARTC2C ??
                shippingFee['default']?.OKMARTC2C ??
                0;
          case LogisticsSubType.OKMART_LOW_TMP_C2C:
            return paymentSettings?.OKMART_LOW_TMP_C2C ??
                shippingFee['default']?.OKMART_LOW_TMP_C2C ??
                0;
          default:
            return 0.0;
        }
      }

      if (virtualItems.isNotEmpty) {
        final grouped = _groupItemsBySeller(virtualItems);
        grouped.forEach((sellerId, items) {
          groups.add({"name": "虛擬商品(免運)", "items": items});
        });
      }

      if (refrigerationItems.isNotEmpty) {
        refrigBySeller.forEach((sellerId, items) {
          final method = _refrigerationMethods[sellerId];
          final store = _refrigerationStores[sellerId];

          List<CartItem> homeItems = [];
          List<CartItem> pickupItems = [];

          if (method == DeliveryMethod.home) {
            for (var item in items) {
              if (item.product.allowHomeDelivery) {
                homeItems.add(item);
              } else {
                pickupItems.add(item);
              }
            }
          } else {
            pickupItems = items;
          }

          if (homeItems.isNotEmpty) {
            final double defaultFee =
                shippingFee["default"]?.homeDeliveryRefrig ?? 0;
            final double customFee =
                shippingFee[sellerId]?.homeDeliveryRefrig ?? defaultFee;
            groups.add({
              "name": "冷藏(宅配到府)",
              "items": homeItems,
              "method": DeliveryMethod.home,
              "fee": defaultFee,
              "feeDeduction": defaultFee - customFee,
            });
          }
          if (pickupItems.isNotEmpty) {
            final double defaultFee =
                shippingFee["default"]?.OKMART_LOW_TMP_C2C ?? 0;
            final double customFee =
                shippingFee[sellerId]?.OKMART_LOW_TMP_C2C ?? defaultFee;
            groups.add({
              "name": "冷藏(店到店)",
              "items": pickupItems,
              "store": store,
              "method": DeliveryMethod.cvs,
              "cvsType": LogisticsSubType.OKMART_LOW_TMP_C2C,
              "fee": defaultFee,
              "feeDeduction": defaultFee - customFee,
            });
          }
        });
      }

      if (normalItems.isNotEmpty) {
        normalBySeller.forEach((sellerId, items) {
          final method = _normalMethods[sellerId];
          final cvsType = _normalCvsTypes[sellerId];
          final store = _normalStores[sellerId];

          List<CartItem> homeItems = [];
          List<CartItem> pickupItems = [];

          if (method == DeliveryMethod.home) {
            for (var item in items) {
              if (item.product.allowHomeDelivery) {
                homeItems.add(item);
              } else {
                pickupItems.add(item);
              }
            }
          } else {
            pickupItems = items;
          }

          if (homeItems.isNotEmpty) {
            final double defaultFee = shippingFee["default"]?.homeDelivery ?? 0;
            final double customFee =
                shippingFee[sellerId]?.homeDelivery ?? defaultFee;
            groups.add({
              "name": "一般(宅配到府)",
              "items": homeItems,
              "method": DeliveryMethod.home,
              "fee": defaultFee,
              "feeDeduction": defaultFee - customFee,
            });
          }
          if (pickupItems.isNotEmpty) {
            final double defaultFee = cvsType != null
                ? getDefaultPickupFee(sellerId, cvsType)
                : 0;
            final double customFee = cvsType != null
                ? getPickupFee(sellerId, cvsType)
                : 0;
            groups.add({
              "name": "一般(店到店)",
              "items": pickupItems,
              "store": store,
              "method": DeliveryMethod.cvs,
              "cvsType": cvsType,
              "fee": defaultFee,
              "feeDeduction": defaultFee - customFee,
            });
          }
        });
      }
      return groups;
    }

    Map<String, double> getOrderSummary() {
      final mGroups = generateGroup();
      double mSubTotal = widget.extra["subTotal"] ?? 0;
      int mDiscountAmount = ((widget.extra['discountCoin'] ?? 0) / 10).floor();
      double mShippingCost = mGroups.fold(
        0,
        (sum, item) => sum + (item['fee'] ?? 0),
      );
      double mShippingCostDeduction = mGroups.fold(
        0,
        (sum, item) => sum + (item['feeDeduction'] ?? 0),
      );
      double mTransactionFee =
          (mSubTotal - mDiscountAmount) *
          (shippingFee["default"]?.transactionFeeRate ?? 0);
      final mTotalAmount =
          mSubTotal -
          mDiscountAmount +
          mShippingCost -
          mShippingCostDeduction +
          mTransactionFee;

      return {
        "subTotal": mSubTotal,
        "discountAmount": ParseUtils.parseDouble(mDiscountAmount) ?? 0.0,
        "shippingCost": mShippingCost,
        "shippingCostDeduction": mShippingCostDeduction,
        "transactionFee": mTransactionFee,
        "totalAmount": mTotalAmount,
      };
    }

    if (_checkoutStat == CheckoutStat.validating) {
      return _buildLayout(
        child: ValidationWebview(
          accountInfo: accountInfo,
          onSuccess: () {
            setState(() {
              _checkoutStat = CheckoutStat.settingMap;
            });
          },
        ),
      );
    } else if (_checkoutStat == CheckoutStat.settingMap) {
      return _buildLayout(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 24, bottom: 36),
            child: Column(
              children: [
                _buildReceiverInfo(),
                const SizedBox(height: 12),
                // _buildOrderSummary(),
                // const SizedBox(height: 12),
                CheckoutDeliverySection(
                  shippingFee: shippingFee,
                  cartItems: cartItems,
                  refrigerationMethods: _refrigerationMethods,
                  refrigerationStores: _refrigerationStores,
                  normalMethods: _normalMethods,
                  normalCvsTypes: _normalCvsTypes,
                  normalStores: _normalStores,
                  // manualPickupItemIds: _manualPickupItemIds,
                  onRefrigerationMethodChanged: (sellerId, val) =>
                      setState(() => _refrigerationMethods[sellerId] = val),
                  onNormalMethodChanged: (sellerId, val) =>
                      setState(() => _normalMethods[sellerId] = val),
                  onNormalCvsTypeChanged: (sellerId, val) => setState(() {
                    _normalCvsTypes[sellerId] = val;
                    _normalStores[sellerId] = null;
                  }),
                  onSelectStore: (type, subType, sellerId) {
                    setState(() {
                      _selectingStoreFor = type;
                      _selectingStoreForSellerId = sellerId;
                      _logisticsSubType = subType;
                      _checkoutStat = CheckoutStat.choosingMap;
                    });
                  },
                  // onManualPickupItemToggle: (productId) {
                  //   if (_manualPickupItemIds.contains(productId))
                  //     _manualPickupItemIds.remove(productId);
                  //   else
                  //     _manualPickupItemIds.add(productId);
                  //   setState(() {});
                  // },
                ),
                Builder(
                  builder: (context) {
                    final result = getOrderSummary();

                    return _buildOrderSummary(
                      subtotal: result["subTotal"]!,
                      discountAmount: result['discountAmount']!.toInt(),
                      shippingCost: result['shippingCost']!,
                      shippingCostDeduction: result['shippingCostDeduction']!,
                      transactionFee: result['transactionFee']!,
                      totalAmount: result['totalAmount']!,
                      transactionFeeRate:
                          shippingFee["default"]?.transactionFeeRate ?? 0,
                    );
                  },
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (!isRefrigerationValid || !isNormalValid)
                          ? null
                          : () {
                              // Generate Groups
                              // bool splitOccurred = false;

                              // Check for split in Refrig
                              // refrigBySeller.forEach((sellerId, items) {
                              //   final method = _refrigerationMethods[sellerId];
                              //   if (method == DeliveryMethod.home) {
                              //     final hasNonHome = items.any(
                              //       (i) => !i.product.allowHomeDelivery,
                              //     );
                              //     if (hasNonHome) splitOccurred = true;
                              //   }
                              // });

                              // Check for split in Normal
                              // normalBySeller.forEach((sellerId, items) {
                              //   final method = _normalMethods[sellerId];
                              //   if (method == DeliveryMethod.home) {
                              //     final hasNonHome = items.any(
                              //       (i) => !i.product.allowHomeDelivery,
                              //     );
                              //     if (hasNonHome) splitOccurred = true;
                              //   }
                              // });

                              // if (splitOccurred) {
                              //   ScaffoldMessenger.of(context).showSnackBar(
                              //     const SnackBar(
                              //       content: Text("部分商品不支援宅配，已自動拆分為店到店訂單"),
                              //       duration: Duration(seconds: 5),
                              //     ),
                              //   );
                              // }

                              final result = getOrderSummary();
                              setState(() {
                                _checkoutStat = CheckoutStat.processingPayment;
                              });
                              context
                                  .push(
                                    Routes.ecPayPage,
                                    extra: {
                                      "subTotal": widget.extra["subTotal"],
                                      "totalAmount": result['totalAmount'],
                                      "discountCoin":
                                          widget.extra['discountCoin'],
                                      "shippingCost": result["shippingCost"],
                                      "shippingCostDeduction":
                                          result["shippingCostDeduction"],
                                      "transactionFee":
                                          result["transactionFee"],
                                      "cartItems": widget.extra['cartItems'],
                                      "transactionFeeRateAtSale":
                                          shippingFee["default"]
                                              ?.transactionFeeRate,
                                      "userLevelAtSale":
                                          widget.extra['userLevelAtSale'],
                                      "userMaxDiscountAtSale":
                                          widget.extra['userMaxDiscountAtSale'],
                                      "groups": generateGroup(),
                                    },
                                  )
                                  // If currentOrder's status is pending, refetch currentOrder
                                  .then((value) async {
                                    final resultOrder = ref
                                        .read(systemNotifierProvider)
                                        .currentOrder;
                                    if (resultOrder != null &&
                                        resultOrder.orderStatus == "pending") {
                                      final result = await ref
                                          .read(orderNotifierProvider.notifier)
                                          .getOrder(orderId: resultOrder.id);
                                      if (result.isSuccess) {
                                        ref
                                            .read(
                                              systemNotifierProvider.notifier,
                                            )
                                            .setCurrentOrder(result.data);
                                      }
                                    }
                                  })
                                  // If currentOrder's status is still pending, cancel it
                                  .then((value) async {
                                    final resultOrder = ref
                                        .read(systemNotifierProvider)
                                        .currentOrder;
                                    if (resultOrder != null &&
                                        resultOrder.orderStatus == "pending") {
                                      final result = await ref
                                          .read(orderNotifierProvider.notifier)
                                          .updateOrder(
                                            orderId: resultOrder.id,
                                            status: "canceled",
                                          );
                                      if (result.isSuccess) {
                                        ref
                                            .read(
                                              systemNotifierProvider.notifier,
                                            )
                                            .setCurrentOrder(result.data);
                                      }
                                    }
                                  })
                                  // If currentOrder is null -> no order created -> pop
                                  .then((value) {
                                    final resultOrder = ref
                                        .read(systemNotifierProvider)
                                        .currentOrder;
                                    if (resultOrder == null) {
                                      // ignore: use_build_context_synchronously
                                      return context.pop();
                                    }
                                    final orderStatus = resultOrder.orderStatus;
                                    if (orderStatus != "paid") {
                                      showDialog(
                                        // ignore: use_build_context_synchronously
                                        context: context,
                                        builder: (context) {
                                          return AlertDialog(
                                            backgroundColor: const Color(
                                              0xFF262A33,
                                            ),
                                            title: Text(
                                              orderStatus == "canceled"
                                                  ? "交易取消"
                                                  : orderStatus == "expired"
                                                  ? "交易逾期"
                                                  : "交易失敗",
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(
                                                  context,
                                                ).pop(true),
                                                child: const Text(
                                                  '確定',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ).then((value) {
                                        setState(() {
                                          _checkoutStat =
                                              CheckoutStat.settingMap;
                                        });
                                      });
                                    }
                                  });
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryButtonColor,
                        foregroundColor: AppColors.primaryTextColor,
                        disabledBackgroundColor: AppColors.mutedTextColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        "下一步，前往付款",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (_checkoutStat == CheckoutStat.choosingMap) {
      return _buildLayout(
        child: Stack(
          fit: StackFit.expand,
          children: [
            LogisticsMapWebview(
              logisticsSubType: _logisticsSubType.name,
              onSuccess: (response) {
                setState(() {
                  final info = LogisticsMapInfo.fromApiResponseMap(response);
                  final sellerId = _selectingStoreForSellerId;
                  if (sellerId != null) {
                    if (_selectingStoreFor == 'refrigeration') {
                      _refrigerationStores[sellerId] = info;
                    } else if (_selectingStoreFor == 'normal') {
                      _normalStores[sellerId] = info;
                    }
                  }
                  _checkoutStat = CheckoutStat.settingMap;
                });
              },
            ),
          ],
        ),
      );
    } else if (_checkoutStat == CheckoutStat.processingPayment &&
        currentOrder?.orderStatus == "paid") {
      return _buildLayout(
        child: Builder(
          builder: (context) {
            Future.delayed(Durations.medium2, () async {
              void handleOrderFailure() {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("部分商品無法建立運單，請至「我的」>「我的訂單」查看"),
                    backgroundColor: AppColors.dangerButtonColor,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }

              if (currentOrder == null) {
                handleOrderFailure();
                // ignore: use_build_context_synchronously
                context.pop();
                return;
              }

              int groupLength = generateGroup().length;
              Order retryOrder = currentOrder;
              final totalRetry = 10;
              int retry = 1;
              while (retryOrder.deliveries.length != groupLength) {
                await Future.delayed(const Duration(milliseconds: 2500));
                final result = await ref
                    .read(orderNotifierProvider.notifier)
                    .getOrder(orderId: retryOrder.id);
                if (result.isSuccess) {
                  retryOrder = result.data!;
                } else {
                  retry++;
                  if (retry > totalRetry) {
                    handleOrderFailure();
                    // ignore: use_build_context_synchronously
                    context.pop();
                    return;
                  }
                }
              }

              _sendOrderCompletedNotification(retryOrder);
              // ignore: use_build_context_synchronously
              context.pop();
            });
            return PageLoading('運單確認中，請稍後......');
          },
        ),
        allowPop: false,
      );
    } else {
      return _buildLayout(
        child: PageLoading('運單確認中，請稍後......'),
        allowPop: false,
      );
    }
  }
}
