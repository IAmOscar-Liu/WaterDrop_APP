import 'dart:async';
import 'dart:developer';
import 'dart:math' show min;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/features/cart/widgets/cart_item_card.dart';
import 'package:flutter_ad_ecommerce/features/cart/widgets/quantity_dialog.dart';
import 'package:flutter_ad_ecommerce/models/account_info.dart';
import 'package:flutter_ad_ecommerce/models/order.dart';
import 'package:flutter_ad_ecommerce/models/product.dart';
import 'package:flutter_ad_ecommerce/provider/account_provider.dart';
import 'package:flutter_ad_ecommerce/provider/cart_provider.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/provider/message_stats_provider.dart';
import 'package:flutter_ad_ecommerce/provider/order_provider.dart';
import 'package:flutter_ad_ecommerce/provider/payment_settings_provider.dart';
import 'package:flutter_ad_ecommerce/provider/system_provider.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:flutter_ad_ecommerce/utils/number_formatter_extension.dart';
import 'package:flutter_ad_ecommerce/utils/parse_utils.dart';
import 'package:flutter_ad_ecommerce/utils/events.dart';
import 'package:flutter_ad_ecommerce/widgets/keyboard_dismiss_on_tap.dart';
import 'package:flutter_ad_ecommerce/widgets/messaging_app_bar.dart';
import 'package:flutter_ad_ecommerce/widgets/page_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CartPage extends ConsumerStatefulWidget {
  const CartPage({super.key});

  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

class _CartPageState extends ConsumerState<CartPage> {
  late StreamSubscription _routeChangeSubscription;
  // PaymentOption? _selectedOption =
  //     PaymentOption.creditDebitCard; // Default selected option
  int? _discountCoin;
  bool _isProcessingTransaction = false;

  final TextEditingController _discountCoinController = TextEditingController();

  AccountInfo get accountInfo => ref.watch(accountNotifierProvider);
  int get subTotal => ref.watch(cartTotalPriceProvider).round();
  int get totalCheckedItems => ref.watch(cartTotalItemsProvider);
  int get discountAmount => ((_discountCoin ?? 0) / 10).floor();
  int get maxDiscount => (subTotal * accountInfo.discountRate).floor();
  String? get errorDiscountText =>
      (_discountCoin != null && _discountCoin! > accountInfo.coins)
      ? "輸入值不能超過您擁有的金幣 - ${accountInfo.coins}"
      : (_discountCoin != null && _discountCoin! > maxDiscount * 10)
      ? '輸入值不能超過最多可折抵數量 - ${maxDiscount * 10}'
      : (_discountCoin != null &&
            (_discountCoin! / 10) != (_discountCoin! / 10).floor())
      ? "輸入值需為10的倍數"
      : null;

  @override
  void initState() {
    super.initState();
    _updateDiscountCoin();
    _routeChangeSubscription = eventBus.on<RouterChangeEvent>().listen((event) {
      if (event.to == Routes.cartPage && event.to != event.from) {
        // log('[Cart] re-enter cart page');
        _updateDiscountCoin();
      }
    });
  }

  @override
  void dispose() {
    _discountCoinController.dispose();
    _routeChangeSubscription.cancel();
    super.dispose();
  }

  void _updateDiscountCoin() {
    Future.delayed(Duration.zero, () {
      log('cart page - _updateDiscountCoin');
      final int initialDiscountCoin =
          (min(accountInfo.coins, maxDiscount * 10) / 10).floor() * 10;
      _discountCoinController.text = initialDiscountCoin.toString();
      setState(() {
        _discountCoin = initialDiscountCoin;
      });
    });
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: AppColors.mutedTextColor,
          ),
          SizedBox(height: 24),
          Text(
            '購物車是空的',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryTextColor,
            ),
          ),
          SizedBox(height: 12),
          Text(
            '快去逛逛，把喜歡的商品加入購物車吧！',
            style: TextStyle(fontSize: 16, color: AppColors.secondaryTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiverInfo() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.0),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.containerBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "收件人資訊",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppColors.primaryTextColor,
            ),
          ),
          Divider(color: AppColors.dividerColor),
          Text(
            "姓名：${accountInfo.name.isEmpty ? "尚未至「我的」頁面填寫" : accountInfo.name}",
            style: TextStyle(color: AppColors.secondaryTextColor),
          ),
          Text(
            "地址：${(accountInfo.address == null || accountInfo.address!.isEmpty) ? "尚未至「我的」頁面填寫" : accountInfo.address}",
            style: TextStyle(color: AppColors.secondaryTextColor),
          ),
          Text(
            "手機號碼：${(accountInfo.phone == null || accountInfo.phone!.isEmpty) ? "尚未至「我的」頁面填寫" : accountInfo.phone}",
            style: TextStyle(color: AppColors.secondaryTextColor),
          ),
          Text(
            "如需修改，請至「我的」頁面進行變更",
            style: TextStyle(color: AppColors.mutedTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildPayment() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.0),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.containerBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "金幣支付",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppColors.primaryTextColor,
            ),
          ),
          Divider(color: AppColors.dividerColor),
          RichText(
            text: TextSpan(
              style: TextStyle(color: AppColors.secondaryTextColor),
              children: [
                TextSpan(text: "您目前擁有金幣: "),
                TextSpan(
                  text: accountInfo.coins.formatWithCommas(decimals: 2),
                  style: TextStyle(color: AppColors.goldColor),
                ),
              ],
            ),
          ),
          RichText(
            text: TextSpan(
              style: TextStyle(color: AppColors.secondaryTextColor),
              children: [
                TextSpan(text: "您的等級 "),
                TextSpan(
                  text: accountInfo.level,
                  style: TextStyle(color: AppColors.greenColor),
                ),
                TextSpan(text: " 可用金幣折抵 "),
                TextSpan(
                  text: (accountInfo.discountRate * 100).floor().toString(),
                  style: TextStyle(color: AppColors.successColor),
                ),
                TextSpan(text: " %"),
              ],
            ),
          ),
          Text(
            "(10金幣=1新台幣)",
            style: TextStyle(color: AppColors.mutedTextColor),
          ),
          Text(
            "使用金幣數量折抵(您的等級權益最多可折抵${maxDiscount.formatWithCommas()}元)",
            style: TextStyle(color: AppColors.mutedTextColor, fontSize: 14),
          ),
          Text(
            "如需修改，請至「我的」頁面進行變更",
            style: TextStyle(color: AppColors.mutedTextColor),
          ),
          SizedBox(height: 16),
          TextField(
            controller: _discountCoinController,
            style: TextStyle(color: AppColors.primaryTextColor),
            decoration: InputDecoration(
              labelText: '請輸入要折抵的金幣數量',
              labelStyle: TextStyle(color: AppColors.secondaryTextColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.selectedBorderColor),
              ),
              filled: true,
              fillColor: AppColors.cardBgColor,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              errorText: errorDiscountText,
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) {
              setState(() {
                _discountCoin = int.tryParse(value);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfo() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.0),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.containerBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "訂單摘要",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppColors.primaryTextColor,
            ),
          ),
          Divider(color: AppColors.dividerColor),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "商品總金額",
                style: TextStyle(color: AppColors.secondaryTextColor),
              ),
              Text(
                subTotal.toDollarsString(prefix: "NT"),
                style: TextStyle(color: AppColors.primaryTextColor),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "金幣折抵",
                style: TextStyle(color: AppColors.secondaryTextColor),
              ),
              Text(
                "- ${discountAmount.toDollarsString(prefix: "NT")}",
                style: TextStyle(color: AppColors.successColor),
              ),
            ],
          ),
          Divider(color: AppColors.dividerColor),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                !kReleaseMode ? "總計(不含運費、手續費)" : "總計(不含運費)",
                style: TextStyle(color: AppColors.secondaryTextColor),
              ),
              Text(
                (subTotal - discountAmount).toDollarsString(prefix: "NT"),
                style: TextStyle(
                  color: AppColors.goldColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLayout({required Widget child}) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBgColor,
      appBar: MessagingAppBar(title: '我的購物車'),
      resizeToAvoidBottomInset: true,
      body: KeyboardDismissOnTap(child: child),
    );
  }

  Future<String?> _checkoutValidation(
    AccountInfo mAccountInfo,
    List<CartItem> mCartItems,
    int mTotalItems,
    int mSubTotal,
  ) async {
    if (mAccountInfo.name.isEmpty) {
      return "收件人姓名未填寫";
    }
    if (mAccountInfo.phone == null || mAccountInfo.phone!.isEmpty) {
      return "收件人手機號碼未填寫";
    }
    if (mAccountInfo.email.isEmpty) {
      return "收件人地址未填寫";
    }
    if (mTotalItems > 4) {
      return "單筆訂單商品種類不能超過4種";
    }
    if (mSubTotal > 20000) {
      return "商品總金額不能超過20000元";
    }

    final senderNames = mCartItems
        .map((item) => item.product.seller?.realName)
        .toList();
    final senderCellPhones = mCartItems
        .map((item) => item.product.seller?.phone)
        .toList();

    final response = await ref
        .read(dioProvider)
        .post(
          "/api/ecpay/express/validate",
          data: {
            "SenderNames": senderNames,
            "SenderCellPhones": senderCellPhones,
            "ReceiverName": mAccountInfo.name,
            "ReceiverCellPhone": mAccountInfo.phone,
            "ReceiverEmail": mAccountInfo.email,
            "GoodsNames": mCartItems.map((item) => item.product.name).toList(),
            "GoodsAmount": mSubTotal,
          },
        );
    if (response.data['success'] == true) return null;
    return response.data['message'];
  }

  @override
  Widget build(BuildContext context) {
    final cartData = ref.watch(cartProvider);

    if (cartData.isInitial || cartData.isLoading) {
      return _buildLayout(child: PageLoading('載入購物清單中......'));
    }

    final List<CartItem> cartItems = cartData.data ?? [];

    return _buildLayout(
      child: cartItems.isEmpty
          ? _buildEmptyCart()
          : SingleChildScrollView(
              padding: EdgeInsets.only(top: 12, bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListView.builder(
                    itemCount: cartItems.length,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final currentItem = cartItems[index];
                      return CartItemCard(
                        key: UniqueKey(),
                        product: currentItem.product,
                        quantity: currentItem.quantity,
                        checked: currentItem.checked,
                        onCheckedChange: (value) {
                          if (value != null) {
                            ref
                                .read(cartProvider.notifier)
                                .toggleCartItem(currentItem.productId, value);
                          }
                        },
                        onQuantityChange: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return QuantityDialog(
                                quantity: currentItem.quantity,
                                onSuccess: (value) {
                                  if (value != currentItem.quantity) {
                                    ref
                                        .read(cartProvider.notifier)
                                        .updateItemQuantity(
                                          currentItem.productId,
                                          quantity: value,
                                        );
                                  }
                                },
                              );
                            },
                          );
                        },
                        onDelete: () {
                          ref
                              .read(cartProvider.notifier)
                              .removeItem(currentItem.productId);
                        },
                      );
                    },
                  ),
                  if (totalCheckedItems > 0) ...[
                    SizedBox(height: 12),
                    _buildReceiverInfo(),
                    SizedBox(height: 12),
                    _buildPayment(),
                    SizedBox(height: 12),
                    _buildOrderInfo(),
                    SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ElevatedButton(
                        onPressed:
                            (!cartData.isDone ||
                                _isProcessingTransaction ||
                                errorDiscountText != null)
                            ? null
                            : () async {
                                setState(() {
                                  _isProcessingTransaction = true;
                                });
                                final invalidMsg = await _checkoutValidation(
                                  accountInfo,
                                  cartItems.where((c) => c.checked).toList(),
                                  totalCheckedItems,
                                  subTotal,
                                );
                                if (invalidMsg != null) {
                                  return showDialog(
                                    // ignore: use_build_context_synchronously
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        backgroundColor: const Color(
                                          0xFF262A33,
                                        ),
                                        title: Text(
                                          "資料有誤",
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        content: Text(
                                          invalidMsg,
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
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
                                      _isProcessingTransaction = false;
                                    });
                                  });
                                }
                                final shippingFeeResult = await ref
                                    .read(
                                      paymentSettingsNotifierProvider.notifier,
                                    )
                                    .loadShippingFee(
                                      cartItems
                                          .map((item) => item.product.sellerId)
                                          .toSet()
                                          .toList(),
                                    );
                                if (!shippingFeeResult.isSuccess) {
                                  return showDialog(
                                    // ignore: use_build_context_synchronously
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        backgroundColor: const Color(
                                          0xFF262A33,
                                        ),
                                        title: Text(
                                          "資料有誤",
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        content: Text(
                                          "無法取得賣家運費",
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
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
                                      _isProcessingTransaction = false;
                                    });
                                  });
                                }
                                // ignore: use_build_context_synchronously
                                context
                                    .push(
                                      Routes.paymentSettingsPage,
                                      extra: {
                                        "shippingFee": shippingFeeResult.data,
                                        "subTotal": ParseUtils.parseDouble(
                                          subTotal,
                                        ),
                                        "discountCoin": _discountCoin ?? 0,
                                        "userLevelAtSale": accountInfo.level,
                                        "userMaxDiscountAtSale": maxDiscount,
                                        "cartItems": cartItems
                                            .where((item) => item.checked)
                                            .toList(),
                                      },
                                    )
                                    .then((value) {
                                      final currentOrder = ref
                                          .read(systemNotifierProvider)
                                          .currentOrder;
                                      if (currentOrder != null &&
                                          currentOrder.orderStatus ==
                                              'pending') {
                                        return ref
                                            .read(
                                              orderNotifierProvider.notifier,
                                            )
                                            .getOrder(orderId: currentOrder.id)
                                            .then((result) {
                                              if (result.isSuccess) {
                                                return result.data;
                                              }
                                              return currentOrder;
                                            });
                                      }
                                      return currentOrder;
                                    })
                                    .then((value) {
                                      final orderStatus = value is Order
                                          ? value.orderStatus
                                          : null;
                                      if (orderStatus == "paid" ||
                                          orderStatus == "payment-processing") {
                                        return showDialog(
                                          // ignore: use_build_context_synchronously
                                          context: context,
                                          builder: (context) {
                                            return AlertDialog(
                                              backgroundColor: const Color(
                                                0xFF262A33,
                                              ),
                                              title: Text(
                                                orderStatus == "paid"
                                                    ? "交易成功"
                                                    : "訂單已送出，請於指定期限內完成付款(如已付款，請於訂單紀錄確認付款狀態)",
                                                style: TextStyle(
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
                                        );
                                      }
                                    })
                                    .then((value) {
                                      return Future.wait([
                                        ref
                                            .read(cartProvider.notifier)
                                            .loadCartItems(),
                                        ref
                                            .read(
                                              accountNotifierProvider.notifier,
                                            )
                                            .refreshAccountInfo(),
                                        ref
                                            .read(
                                              messageStatsNotifierProvider
                                                  .notifier,
                                            )
                                            .loadMessageStats(),
                                      ]);
                                    })
                                    .then((value) {
                                      _updateDiscountCoin();
                                      ref
                                          .read(systemNotifierProvider.notifier)
                                          .setCurrentOrder(null);
                                      setState(() {
                                        _isProcessingTransaction = false;
                                      });
                                    });
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryButtonColor,
                          foregroundColor: AppColors.primaryTextColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          side: BorderSide.none,
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          "確認結帳",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
