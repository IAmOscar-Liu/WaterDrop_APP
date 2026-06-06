import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/app_constants.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/features/ecpay/widget/checkout_delivery_section.dart';
import 'package:flutter_ad_ecommerce/models/account_info.dart';
import 'package:flutter_ad_ecommerce/models/logistics_info.dart';
import 'package:flutter_ad_ecommerce/models/order.dart';
import 'package:flutter_ad_ecommerce/models/product.dart';
import 'package:flutter_ad_ecommerce/provider/account_provider.dart';
import 'package:flutter_ad_ecommerce/provider/order_provider.dart';
import 'package:flutter_ad_ecommerce/provider/system_provider.dart';
import 'package:flutter_ad_ecommerce/utils/uri_utils.dart';
import 'package:flutter_ad_ecommerce/widgets/page_status.dart';
import 'package:flutter_ad_ecommerce/widgets/simple_app_bar.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

class ECPayPage extends ConsumerStatefulWidget {
  final dynamic extra;
  const ECPayPage({super.key, required this.extra});

  @override
  ConsumerState<ECPayPage> createState() => _ECPayPageState();
}

// final List<CartItem> cartItems;

class _ECPayPageState extends ConsumerState<ECPayPage>
    with WidgetsBindingObserver {
  String? _errorMsg;
  bool _isHandlingClientReturn = false;
  Timer? _checkoutTimer;
  String? _idempotencyKey; // To prevent duplicate order creation on app resume

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.extra is! Map ||
        widget.extra['subTotal'] == null ||
        widget.extra['totalAmount'] == null ||
        widget.extra['discountCoin'] == null ||
        widget.extra['shippingCost'] == null ||
        widget.extra['shippingCostDeduction'] == null ||
        widget.extra['transactionFee'] == null ||
        widget.extra['cartItems'] == null ||
        widget.extra['groups'] == null) {
      // If data is missing, pop immediately
      WidgetsBinding.instance.addPostFrameCallback((_) => context.pop());
      return;
    }

    _idempotencyKey = const Uuid().v4();

    _createOrder(
      subTotal: widget.extra['subTotal'],
      totalAmount: widget.extra['totalAmount'],
      discountCoin: widget.extra['discountCoin'],
      shippingCost: widget.extra['shippingCost'],
      shippingCostDeduction: widget.extra['shippingCostDeduction'],
      transactionFee: widget.extra['transactionFee'],
      cartItems: widget.extra['cartItems'],
      transactionFeeRateAtSale: widget.extra['transactionFeeRateAtSale'],
      userLevelAtSale: widget.extra['userLevelAtSale'],
      userMaxDiscountAtSale: widget.extra['userMaxDiscountAtSale'],
      groups: widget.extra['groups'],
      orderPayment: widget.extra['orderPayment'],
    );
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _checkoutTimer?.cancel();
  }

  Future<void> _createOrder({
    required double subTotal,
    required double totalAmount,
    required int discountCoin,
    required double shippingCost,
    required double shippingCostDeduction,
    required double transactionFee,
    required List<CartItem> cartItems,
    double? transactionFeeRateAtSale,
    String? userLevelAtSale,
    int? userMaxDiscountAtSale,
    required List<Map<String, dynamic>> groups,
    String? orderPayment,
  }) async {
    Future.delayed(Duration.zero, () async {
      final AccountInfo accountInfo = ref.watch(accountNotifierProvider);
      final List cvsPickupGroup = [];
      final List nonCvsPickupGroup = [];

      for (var group in groups) {
        if (group['name'] == "一般(店到店)") {
          List<CartItem> normalPickupItems = group["items"];
          LogisticsMapInfo store = group["store"];
          LogisticsSubType cvsType = group["cvsType"];
          double goodsAmount = normalPickupItems.fold(
            0,
            (sum, item) => sum + item.product.price * item.quantity,
          );
          cvsPickupGroup.add({
            "type": AppConstants.logisticsSubType,
            "productIds": normalPickupItems.map((e) => e.productId).toList(),
            "LogisticsSubType": cvsType.name,
            "GoodsName": normalPickupItems[0].product.name,
            "GoodsAmount": goodsAmount,
            "ReceiverName": accountInfo.name,
            "ReceiverCellPhone": accountInfo.phone,
            "ReceiverEmail": accountInfo.email,
            "ReceiverStoreID": store.CVSStoreID,
            "ReceiverStoreAddress": store.CVSAddress,
            "ReceiverStoreName": store.CVSStoreName,
            "ReceiverStoreTelephone": store.CVSTelephone,
            "SenderName": normalPickupItems[0].product.seller?.realName,
            "SenderCellPhone": normalPickupItems[0].product.seller?.phone,
            "shippingCost": group["fee"],
            "shippingCostDeduction": group["feeDeduction"],
          });
        } else {
          List<CartItem> items = group["items"];
          LogisticsSubType? cvsType = group["cvsType"];
          double goodsAmount = items.fold(
            0.0,
            (sum, item) => sum + item.product.price * item.quantity,
          );

          Map<String, String>? getCvsStoreInfo(LogisticsMapInfo? storeInfo) {
            if (storeInfo == null) return null;
            final Map<String, String> store = {
              "storeID": storeInfo.CVSStoreID,
              "storeName": storeInfo.CVSStoreName,
              "storeAddress": storeInfo.CVSAddress,
            };
            if (storeInfo.CVSTelephone != null) {
              store["storeTelephone"] = storeInfo.CVSTelephone!;
            }
            return store;
          }

          final logisticsTypeValue = group["name"] == "虛擬商品(免運)"
              ? "virtual"
              : group["name"] == "冷藏(店到店)"
              ? "CVS"
              : "home_delivery";

          nonCvsPickupGroup.add({
            "LogisticsType": logisticsTypeValue,
            "LogisticsSubType": cvsType?.name,
            "GoodsAmount": goodsAmount,
            "productIds": items.map((e) => e.productId).toList(),
            "RtnCode": "300",
            "RtnMsg": "訂單處理中(賣家已收到訂單資料)",
            "fee": group["fee"],
            "feeDeduction": group["feeDeduction"],
            "cvsStoreInfo": getCvsStoreInfo(group["store"]),
            "homeDeliveryData": {
              "name": accountInfo.name,
              "phone": accountInfo.phone,
              "address": accountInfo.address,
              "email": accountInfo.email,
            },
            "metadata": {
              "LogisticsType": logisticsTypeValue,
              "LogisticsSubType": cvsType?.name,
              "GoodsAmount": goodsAmount,
              "RtnCode": "300",
              "RtnMsg": "訂單處理中(賣家已收到訂單資料)",
            },
          });
        }
      }

      final result = await ref
          .read(orderNotifierProvider.notifier)
          .createOrder(
            idempotencyKey: _idempotencyKey!,
            subTotal: subTotal,
            totalAmount: totalAmount,
            discountCoin: discountCoin,
            shippingCost: shippingCost,
            shippingCostDeduction: shippingCostDeduction,
            transactionFee: transactionFee,
            transactionFeeRateAtSale: transactionFeeRateAtSale,
            userLevelAtSale: userLevelAtSale,
            userMaxDiscountAtSale: userMaxDiscountAtSale,
            cartItems: cartItems,
            shippingInfo: {
              "cvsPickupGroup": cvsPickupGroup,
              "nonCvsPickupGroup": nonCvsPickupGroup,
            },
            orderPayment: orderPayment,
          );
      if (result.isFailure) {
        setState(() {
          _errorMsg = result.error;
        });
        return;
      }
      ref.read(systemNotifierProvider.notifier).setCurrentOrder(result.data);
      _startCheckoutTimer(const Duration(minutes: 30));
    });
  }

  Future<void> _expireOrderIfPending(String orderId) async {
    var resultOrder = await ref
        .read(orderNotifierProvider.notifier)
        .getOrder(orderId: orderId);
    if (resultOrder.isFailure) {
      ref.read(systemNotifierProvider.notifier).setCurrentOrder(null);
      return;
    }
    if (resultOrder.data == null ||
        resultOrder.data!.orderStatus != "pending") {
      ref
          .read(systemNotifierProvider.notifier)
          .setCurrentOrder(resultOrder.data);
      return;
    }
    // expire order since it's still pending
    resultOrder = await ref
        .read(orderNotifierProvider.notifier)
        .updateOrder(orderId: orderId, status: "expired");
    if (resultOrder.isSuccess) {
      ref
          .read(systemNotifierProvider.notifier)
          .setCurrentOrder(resultOrder.data);
    } else {
      ref.read(systemNotifierProvider.notifier).setCurrentOrder(null);
    }
  }

  void _startCheckoutTimer(Duration duration) {
    _checkoutTimer = Timer(duration, () async {
      final currentOrder = ref.read(systemNotifierProvider).currentOrder;
      if (currentOrder != null) {
        await _expireOrderIfPending(currentOrder.id);
        // ignore: use_build_context_synchronously
        context.pop();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      final currentOrder = ref.read(systemNotifierProvider).currentOrder;
      if (currentOrder != null &&
          DateTime.now().difference(currentOrder.createdAt).inMinutes >= 30) {
        await _expireOrderIfPending(currentOrder.id);
        // ignore: use_build_context_synchronously
        context.pop();
      }
    }
  }

  void _handleClientReturn(Order order) async {
    WidgetsBinding.instance.removeObserver(this);
    setState(() {
      _isHandlingClientReturn = true;
      _checkoutTimer?.cancel();
    });
    await Future.delayed(const Duration(milliseconds: 750));
    final totalRetry = 3;
    int retry = 1;
    Order? orderResult;
    while (retry <= totalRetry) {
      final result = await ref
          .read(orderNotifierProvider.notifier)
          .getOrder(orderId: order.id);
      if (result.isSuccess &&
          (result.data!.orderStatus == "paid" ||
              result.data!.orderStatus == "payment-processing")) {
        orderResult = result.data;
        break;
      }
      retry++;
      if (retry <= totalRetry) {
        await Future.delayed(Durations.medium1);
      }
    }

    ref.read(systemNotifierProvider.notifier).setCurrentOrder(orderResult);

    // ignore: use_build_context_synchronously
    context.pop();
  }

  Widget _buildLayout({required Widget child, bool allowPop = true}) {
    return PopScope(
      canPop: allowPop,
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBgColor,
        appBar: SimpleAppBar(
          title: '商品結帳',
          // Hide the back button if popping is not allowed
          automaticallyImplyLeading: allowPop,
          leading: allowPop ? null : const SizedBox.shrink(),
        ),
        resizeToAvoidBottomInset: true,
        body: child,
      ),
    );
  }

  Widget _buildErrorLayout(String errMsg) {
    try {
      final decoded = jsonDecode(errMsg);
      if (decoded is Map && decoded['error'] is List) {
        final List<dynamic> errors = decoded['error'];
        return _buildLayout(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.dangerButtonColor,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "訂單建立失敗",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "以下商品無法購買",
                    style: TextStyle(color: AppColors.secondaryTextColor),
                  ),
                  const SizedBox(height: 16),
                  ...errors.map((e) {
                    final name = e['productName'] ?? '未知商品';
                    final reason = e['reason'];
                    String reasonText = reason ?? '未知原因';
                    if (reason == 'Not found') {
                      reasonText = '商品已下架';
                    } else if (reason == 'Insufficient stock') {
                      reasonText = '庫存不足';
                      if (e['quantity'] != null && e['remaining'] != null) {
                        reasonText +=
                            ' (需求: ${e['quantity']}, 剩餘: ${e['remaining']})';
                      }
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.containerBgColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    color: AppColors.primaryTextColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  reasonText,
                                  style: const TextStyle(
                                    color: AppColors.dangerButtonColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryButtonColor,
                      foregroundColor: AppColors.primaryTextColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text("返回"),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (_) {}

    return _buildLayout(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("發生錯誤: $errMsg", style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryButtonColor,
                foregroundColor: AppColors.primaryTextColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text("返回"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentOrder = ref.watch(systemNotifierProvider).currentOrder;

    if (_errorMsg != null) {
      return _buildErrorLayout(_errorMsg!);
    }

    if (currentOrder == null) {
      return _buildLayout(child: PageLoading('載入結帳畫面中......'));
    }

    return _buildLayout(
      child: Stack(
        fit: StackFit.expand,
        children: [
          SizedBox.expand(
            child: InAppWebView(
              onPermissionRequest: (controller, request) async {
                return PermissionResponse(
                  resources: request.resources,
                  action: PermissionResponseAction.GRANT,
                );
              },
              onWebViewCreated: (controller) async {
                final urlWithAddedParams = UriUtils.addQueryParamsToUrl(
                  baseUrl: "${AppConstants.apiBaseUrl}api/ecpay/new",
                  queryParams: {
                    "token": ref.watch(systemNotifierProvider).accessToken,
                    'orderId': currentOrder.id,
                    'idempotencyKey': _idempotencyKey,
                    'totalAmount': currentOrder.totalAmount,
                    'tradeDesc': '請在此結帳您的商品',
                    'itemName':
                        "${currentOrder.items.length}項商品", // This will overwrite the existing 'user' param
                    'ChoosePayment': currentOrder.orderPayment,
                  },
                );
                log(urlWithAddedParams.toString());
                await controller.loadUrl(
                  urlRequest: URLRequest(
                    url: WebUri.uri(urlWithAddedParams),
                    // WebUri("${AppConstants.apiBaseUrl}api/ecpay/test"),
                  ),
                );

                controller.addJavaScriptHandler(
                  handlerName: 'clientReturn',
                  callback: (args) {
                    _handleClientReturn(currentOrder);
                  },
                );
              },
            ),
          ),
          if (_isHandlingClientReturn)
            Container(
              color: AppColors.scaffoldBgColor,
              child: PageLoading('交易處理中......'),
            ),
        ],
      ),
    );
  }
}
