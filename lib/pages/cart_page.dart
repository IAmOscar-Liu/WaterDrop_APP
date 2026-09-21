import 'dart:math' show min;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/features/cart/widgets/cart_item_card.dart';
import 'package:flutter_ad_ecommerce/features/cart/widgets/quantity_dialog.dart';
import 'package:flutter_ad_ecommerce/models/account_info.dart';
import 'package:flutter_ad_ecommerce/models/api_enums.dart';
import 'package:flutter_ad_ecommerce/models/order.dart';
import 'package:flutter_ad_ecommerce/models/product.dart';
import 'package:flutter_ad_ecommerce/provider/account_provider.dart';
import 'package:flutter_ad_ecommerce/provider/cart_provider.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/provider/message_stats_provider.dart';
import 'package:flutter_ad_ecommerce/provider/order_provider.dart';
import 'package:flutter_ad_ecommerce/provider/payment_settings_provider.dart';
import 'package:flutter_ad_ecommerce/provider/product_provider.dart';
import 'package:flutter_ad_ecommerce/provider/system_provider.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:flutter_ad_ecommerce/shared/layouts/app_scaffold.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/app_panel.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/messaging_app_bar.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/page_status.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/receiver_info_panel.dart';
import 'package:flutter_ad_ecommerce/utils/api_call_manager.dart';
import 'package:flutter_ad_ecommerce/utils/coin_utils.dart';
import 'package:flutter_ad_ecommerce/utils/number_formatter_extension.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CartPage extends ConsumerStatefulWidget {
  const CartPage({super.key});

  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

class _CartPageState extends ConsumerState<CartPage> {
  static const int _discountCoinStepUnits = 10 * CoinUtils.unitsPerCoin;

  int? _discountCoinUnits;
  bool _hasInitializedDiscountCoin = false;
  bool _isProcessingTransaction = false;

  final TextEditingController _discountCoinController = TextEditingController();

  AccountInfo get accountInfo => ref.watch(accountNotifierProvider);
  int get subTotal => ref.watch(cartTotalPriceProvider).round();
  int get totalCheckedItems => ref.watch(cartTotalItemsProvider);
  double? get _discountCoin => _discountCoinUnits == null
      ? null
      : CoinUtils.fromCoinUnits(_discountCoinUnits!);
  double get discountAmount => CoinUtils.toTwd(_discountCoin ?? 0);
  int get maxDiscount => (subTotal * accountInfo.discountRate).floor();
  String? get errorDiscountText {
    if (_discountCoinController.text.isEmpty) return null;
    final units = _discountCoinUnits;
    if (units == null || units % _discountCoinStepUnits != 0) {
      return '折抵金幣必須為 10 的倍數';
    }
    if (units > CoinUtils.toCoinUnits(accountInfo.coins)) {
      return '輸入值不能超過您擁有的金幣 - ${accountInfo.coins.formatCoinValue()}';
    }
    if (units > CoinUtils.toCoinUnits(maxDiscount * 10)) {
      return '輸入值不能超過最多可折抵數量 - ${(maxDiscount * 10).formatCoinValue()}';
    }
    return null;
  }

  @override
  void dispose() {
    _discountCoinController.dispose();
    super.dispose();
  }

  int get _maximumDiscountCoinUnits {
    final account = ref.read(accountNotifierProvider);
    final subtotal = ref.read(cartTotalPriceProvider).round();
    final maxDiscount = (subtotal * account.discountRate).floor();
    final availableUnits = min(
      CoinUtils.toCoinUnits(account.coins),
      CoinUtils.toCoinUnits(maxDiscount * 10),
    );
    return availableUnits ~/ _discountCoinStepUnits * _discountCoinStepUnits;
  }

  void _useMaximumDiscountCoin() {
    final units = _maximumDiscountCoinUnits;
    setState(() {
      _discountCoinController.text = CoinUtils.fromCoinUnits(
        units,
      ).toInt().toString();
      _discountCoinUnits = units;
      _hasInitializedDiscountCoin = true;
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

  Widget _buildPayment() {
    return AppPanel(
      margin: EdgeInsets.symmetric(horizontal: 16.0),
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
                  text: accountInfo.coins.formatCoinValue(),
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
          // Text(
          //   "如需修改，請至「我的」頁面進行變更",
          //   style: TextStyle(color: AppColors.mutedTextColor),
          // ),
          SizedBox(height: 16),
          TextField(
            controller: _discountCoinController,
            style: TextStyle(color: AppColors.primaryTextColor),
            decoration: InputDecoration(
              labelText: '請輸入要折抵的金幣數量',
              helperText: _discountCoinController.text.isEmpty
                  ? '請輸入 10 的倍數，例如 120、130'
                  : null,
              helperStyle: TextStyle(color: AppColors.infoColor),
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
            inputFormatters: [
              TextInputFormatter.withFunction((oldValue, newValue) {
                return RegExp(r'^\d*$').hasMatch(newValue.text)
                    ? newValue
                    : oldValue;
              }),
            ],
            onChanged: (value) {
              setState(() {
                _hasInitializedDiscountCoin = true;
                _discountCoinUnits = CoinUtils.tryParseCoinUnits(value);
              });
            },
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed:
                  _isProcessingTransaction ||
                      _discountCoinUnits == _maximumDiscountCoinUnits
                  ? null
                  : _useMaximumDiscountCoin,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.infoColor,
                disabledForegroundColor: AppColors.secondaryTextColor,
                minimumSize: const Size(0, 28),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('使用最高可折抵金幣'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfo() {
    return AppPanel(
      margin: EdgeInsets.symmetric(horizontal: 16.0),
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
    return AppScaffold(
      appBar: MessagingAppBar(title: '我的購物車'),
      resizeToAvoidBottomInset: true,
      dismissKeyboardOnTap: true,
      body: child,
    );
  }

  Future<String?> _checkoutValidation(
    AccountInfo mAccountInfo,
    List<CartItem> mCartItems,
    int mTotalItems,
    int mSubTotal,
  ) async {
    final availability = await ref
        .read(cartProvider.notifier)
        .validateCheckoutItems(mCartItems);
    if (availability.isFailure) return availability.error;

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

    // Prefill only when the first selection is ready. Navigation and later
    // balance/cart updates must not overwrite a deliberate choice, even zero.
    if (!_hasInitializedDiscountCoin &&
        !_isProcessingTransaction &&
        cartData.isDone &&
        totalCheckedItems > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            !_hasInitializedDiscountCoin &&
            !_isProcessingTransaction &&
            ref.read(cartProvider).isDone &&
            ref.read(cartTotalItemsProvider) > 0) {
          _useMaximumDiscountCoin();
        }
      });
    }

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
                      final availableVariants =
                          currentItem.product.availableVariants;
                      final currentVariant =
                          currentItem.variant ??
                          ProductVariant(
                            id: currentItem.productVariantId,
                            productId: currentItem.productId,
                          );
                      final dialogVariants = availableVariants.isNotEmpty
                          ? availableVariants
                          : [currentVariant];
                      final selectedVariant = availableVariants.firstWhere(
                        (variant) => variant.id == currentItem.productVariantId,
                        orElse: () => currentVariant,
                      );
                      return CartItemCard(
                        key: UniqueKey(),
                        product: currentItem.product,
                        variant: currentItem.variant,
                        productVariantId: currentItem.productVariantId,
                        quantity: currentItem.quantity,
                        checked: currentItem.checked,
                        onCheckedChange: (value) {
                          if (value != null) {
                            ref
                                .read(cartProvider.notifier)
                                .toggleCartItem(
                                  currentItem.productId,
                                  value,
                                  productVariantId:
                                      currentItem.productVariantId,
                                );
                          }
                        },
                        onQuantityChange: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return QuantityDialog(
                                quantity: currentItem.quantity,
                                variants: dialogVariants,
                                selectedVariant: selectedVariant,
                                onSuccess: (value) {
                                  if (value.quantity != currentItem.quantity ||
                                      value.variant.id !=
                                          currentItem.productVariantId) {
                                    ref
                                        .read(cartProvider.notifier)
                                        .updateCartItem(
                                          currentItem,
                                          quantity: value.quantity,
                                          productVariantId: value.variant.id,
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
                              .removeItem(
                                currentItem.productId,
                                productVariantId: currentItem.productVariantId,
                              );
                        },
                      );
                    },
                  ),
                  if (totalCheckedItems > 0) ...[
                    SizedBox(height: 12),
                    ReceiverInfoPanel(accountInfo: accountInfo),
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
                                var shouldRefreshProducts = false;
                                setState(() {
                                  _isProcessingTransaction = true;
                                });
                                final checkedCartItems = cartItems
                                    .where((item) => item.checked)
                                    .toList();
                                final checkoutSubTotal = checkedCartItems.fold(
                                  0.0,
                                  (sum, item) => sum + item.lineTotal,
                                );
                                final invalidMsg = await _checkoutValidation(
                                  accountInfo,
                                  checkedCartItems,
                                  totalCheckedItems,
                                  checkoutSubTotal.round(),
                                );
                                if (!mounted) return;
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
                                          "無法結帳",
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        content: SingleChildScrollView(
                                          child: Text(
                                            invalidMsg,
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
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
                                    if (!mounted) return;
                                    setState(() {
                                      _isProcessingTransaction = false;
                                    });
                                  });
                                }
                                final refreshedItems = ref
                                    .read(cartProvider)
                                    .data!;
                                for (
                                  var i = 0;
                                  i < checkedCartItems.length;
                                  i++
                                ) {
                                  checkedCartItems[i] = refreshedItems
                                      .firstWhere(
                                        (item) =>
                                            item.id == checkedCartItems[i].id,
                                      );
                                }
                                final shippingFeeResult = await ref
                                    .read(
                                      paymentSettingsNotifierProvider.notifier,
                                    )
                                    .loadShippingFee(
                                      checkedCartItems
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
                                        "subTotal": checkoutSubTotal,
                                        "totalPrice": checkoutSubTotal,
                                        "discountCoin": _discountCoin ?? 0,
                                        "userLevelAtSale": accountInfo.level,
                                        "userMaxDiscountAtSale": maxDiscount,
                                        "cartItems": checkedCartItems,
                                      },
                                    )
                                    .then((value) {
                                      final currentOrder = ref
                                          .read(systemNotifierProvider)
                                          .currentOrder;
                                      if (currentOrder != null &&
                                          currentOrder.orderStatus ==
                                              OrderStatus.pending) {
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
                                      if (orderStatus == OrderStatus.paid ||
                                          orderStatus ==
                                              OrderStatus.paymentProcessing) {
                                        shouldRefreshProducts = true;
                                        return showDialog(
                                          // ignore: use_build_context_synchronously
                                          context: context,
                                          builder: (context) {
                                            return AlertDialog(
                                              backgroundColor: const Color(
                                                0xFF262A33,
                                              ),
                                              title: Text(
                                                orderStatus == OrderStatus.paid
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
                                        if (shouldRefreshProducts) ...[
                                          ApiCallManager.updateApiCallTimestamp(
                                            productListApiCacheKey,
                                          ),
                                          ref
                                              .read(
                                                productNotifierProvider
                                                    .notifier,
                                              )
                                              .refreshProducts(),
                                        ],
                                      ]);
                                    })
                                    .then((value) {
                                      if (!mounted) return;
                                      ref
                                          .read(systemNotifierProvider.notifier)
                                          .setCurrentOrder(null);
                                      setState(() {
                                        if (shouldRefreshProducts) {
                                          _discountCoinController.clear();
                                          _discountCoinUnits = null;
                                          _hasInitializedDiscountCoin = false;
                                        }
                                        _isProcessingTransaction = false;
                                      });
                                    });
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryButtonColor,
                          foregroundColor: AppColors.primaryTextColor,
                          disabledBackgroundColor: AppColors.borderColor,
                          disabledForegroundColor: AppColors.secondaryTextColor,
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
