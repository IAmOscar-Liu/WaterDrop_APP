// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:collection';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/app_constants.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/features/ecpay/widget/checkout_delivery_section.dart';
import 'package:flutter_ad_ecommerce/models/account_info.dart';
import 'package:flutter_ad_ecommerce/utils/uri_utils.dart';
import 'package:flutter_ad_ecommerce/widgets/page_status.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ValidationWebview extends ConsumerStatefulWidget {
  final AccountInfo accountInfo;
  final Function() onSuccess;
  const ValidationWebview({
    super.key,
    required this.accountInfo,
    required this.onSuccess,
  });

  @override
  ConsumerState<ValidationWebview> createState() => _ValidationWebviewState();
}

class _ValidationWebviewState extends ConsumerState<ValidationWebview> {
  Timer? _timer;
  bool _isTimeout = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(Duration(seconds: kReleaseMode ? 30 : 0), () {
      setState(() {
        _isTimeout = true;
      });
    });
  }

  @override
  dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
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
                baseUrl:
                    "${AppConstants.apiBaseUrl}api/ecpay/express/test/create",
                queryParams: {
                  "type": AppConstants.logisticsSubType,
                  'ReceiverName': widget.accountInfo.name,
                  'ReceiverCellPhone': widget.accountInfo.phone,
                  'ReceiverEmail': widget.accountInfo.email,
                },
              );
              log(urlWithAddedParams.toString());
              await controller.loadUrl(
                urlRequest: URLRequest(url: WebUri.uri(urlWithAddedParams)),
              );

              controller.addJavaScriptHandler(
                handlerName: 'express-test-reply',
                callback: (args) {
                  // final response = args.firstOrNull;
                  // log("Response - $response");
                  _timer?.cancel();
                  widget.onSuccess();
                },
              );
            },
          ),
        ),
        if (!_isTimeout)
          Container(
            color: AppColors.scaffoldBgColor,
            child: PageLoading('處理中，請稍後......'),
          ),
      ],
    );
  }
}

class LogisticsMapWebview extends StatelessWidget {
  final LogisticsSubType logisticsSubType;
  final Function(dynamic) onSuccess;
  const LogisticsMapWebview({
    super.key,
    required this.logisticsSubType,
    required this.onSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: InAppWebView(
        onPermissionRequest: (controller, request) async {
          return PermissionResponse(
            resources: request.resources,
            action: PermissionResponseAction.GRANT,
          );
        },
        onWebViewCreated: (controller) async {
          final urlWithAddedParams = UriUtils.addQueryParamsToUrl(
            baseUrl: "${AppConstants.apiBaseUrl}api/ecpay/logistics/map",
            queryParams: {
              'logisticsSubType':
                  logisticsSubType == LogisticsSubType.OKMART_LOW_TMP_C2C
                  ? "OKMARTC2C"
                  : logisticsSubType.name,
            },
          );
          log(urlWithAddedParams.toString());
          await controller.loadUrl(
            urlRequest: URLRequest(url: WebUri.uri(urlWithAddedParams)),
          );

          controller.addJavaScriptHandler(
            handlerName: 'logistics-map-callback',
            callback: (args) {
              final response = args.firstOrNull;
              // log("Response - $response");
              onSuccess(response);
            },
          );
        },
      ),
    );
  }
}

// class CreateGroupExpressWebview extends ConsumerStatefulWidget {
//   final Order order;
//   final List<Map<String, dynamic>> groups;
//   final Function(dynamic) onSuccess;
//   final Function(dynamic) onFailure;

//   const CreateGroupExpressWebview({
//     super.key,
//     required this.order,
//     required this.groups,
//     required this.onSuccess,
//     required this.onFailure,
//   });

//   @override
//   ConsumerState<CreateGroupExpressWebview> createState() =>
//       _CreateGroupExpressWebviewState();
// }

// class _CreateGroupExpressWebviewState
//     extends ConsumerState<CreateGroupExpressWebview> {
//   final Map<int, bool> _expressStatus = {};
//   Timer? _timer;

//   @override
//   void initState() {
//     super.initState();
//     if (widget.groups.isEmpty) {
//       WidgetsBinding.instance.addPostFrameCallback(
//         (_) => widget.onSuccess(null),
//       );
//     } else {
//       _timer = Timer(const Duration(seconds: 70), () {
//         bool allSuccess = true;
//         for (int i = 0; i < widget.groups.length; i++) {
//           if (_expressStatus[i] != true) {
//             allSuccess = false;
//             break;
//           }
//         }
//         if (allSuccess) {
//           widget.onSuccess(null);
//         } else {
//           widget.onFailure("Timeout or partial failure");
//         }
//       });
//     }
//   }

//   @override
//   void dispose() {
//     _timer?.cancel();
//     super.dispose();
//   }

//   void _updateStatus(int index, bool isSuccess) {
//     if (_expressStatus[index] == true) {
//       return;
//     }
//     _expressStatus[index] = isSuccess;

//     bool allSuccess = true;
//     for (int i = 0; i < widget.groups.length; i++) {
//       if (_expressStatus[i] != true) {
//         allSuccess = false;
//         break;
//       }
//     }

//     if (allSuccess) {
//       _timer?.cancel();
//       widget.onSuccess(null);
//     }
//   }

//   // Widget _buildRefrigPickupWebview(Map<String, dynamic> group, int index) {
//   //   List<CartItem> refrigPickupItems = group["items"];
//   //   LogisticsMapInfo store = group["store"];
//   //   double goodsAmount = refrigPickupItems.fold(
//   //     0,
//   //     (sum, item) => sum + item.product.price * item.quantity,
//   //   );

//   //   return CreateExpressWebview(
//   //     orderId: widget.order.id,
//   //     productIds: refrigPickupItems.map((e) => e.productId).toList(),
//   //     LogisticsSubType: LogisticsSubType.OKMARTC2C.name,
//   //     GoodsName: refrigPickupItems[0].product.name,
//   //     GoodsAmount: goodsAmount,
//   //     ReceiverStoreID: store.CVSStoreID,
//   //     ReceiverStoreAddress: store.CVSAddress,
//   //     ReceiverStoreName: store.CVSStoreName,
//   //     ReceiverStoreTelephone: store.CVSTelephone,
//   //     SenderName: refrigPickupItems[0].product.seller?.realName,
//   //     SenderCellPhone: refrigPickupItems[0].product.seller?.phone,
//   //     shippingCost: group["fee"],
//   //     onSuccess: (res) => _updateStatus(index, true),
//   //     onFailure: (err) => _updateStatus(index, false),
//   //   );
//   // }

//   Widget _buildNormalPickupWebview(Map<String, dynamic> group, int index) {
//     List<CartItem> normalPickupItems = group["items"];
//     LogisticsMapInfo store = group["store"];
//     LogisticsSubType cvsType = group["cvsType"];
//     double goodsAmount = normalPickupItems.fold(
//       0,
//       (sum, item) => sum + item.product.price * item.quantity,
//     );

//     return CreateExpressWebview(
//       orderId: widget.order.id,
//       productIds: normalPickupItems.map((e) => e.productId).toList(),
//       LogisticsSubType: cvsType.name,
//       GoodsName: normalPickupItems[0].product.name,
//       GoodsAmount: goodsAmount,
//       ReceiverStoreID: store.CVSStoreID,
//       ReceiverStoreAddress: store.CVSAddress,
//       ReceiverStoreName: store.CVSStoreName,
//       ReceiverStoreTelephone: store.CVSTelephone,
//       SenderName: normalPickupItems[0].product.seller?.realName,
//       SenderCellPhone: normalPickupItems[0].product.seller?.phone,
//       shippingCost: group["fee"],
//       shippingCostDeduction: group["feeDeduction"],
//       onSuccess: (res) => _updateStatus(index, true),
//       onFailure: (err) => _updateStatus(index, false),
//     );
//   }

//   Widget _buildDeliveryWebview(Map<String, dynamic> group, int index) {
//     List<CartItem> items = group["items"];
//     LogisticsSubType? cvsType = group["cvsType"];

//     return DeliveryView(
//       orderId: widget.order.id,
//       LogisticsType: group["name"] == "虛擬商品(免運)"
//           ? "virtual"
//           : group["name"] == "冷藏(店到店)"
//           ? "CVS"
//           : "home_delivery",
//       LogisticsSubType: cvsType?.name,
//       cartItems: items,
//       cvsStoreInfo: group["store"],
//       fee: group["fee"],
//       feeDeduction: group["feeDeduction"],
//       onSuccess: (res) => _updateStatus(index, true),
//       onFailure: (err) => _updateStatus(index, false),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       fit: StackFit.expand,
//       children: [
//         ...widget.groups.asMap().entries.map((entry) {
//           final index = entry.key;
//           final group = entry.value;
//           final groupName = group["name"];
//           // if (groupName == "冷藏(店到店)") {
//           //   return _buildRefrigPickupWebview(group, index);
//           // }
//           if (groupName == "一般(店到店)") {
//             return _buildNormalPickupWebview(group, index);
//           }
//           return _buildDeliveryWebview(group, index);
//         }),
//         Container(
//           color: AppColors.scaffoldBgColor,
//           child: PageLoading('運單建立中，請稍後......'),
//         ),
//       ],
//     );
//   }
// }

// class CreateExpressWebview extends ConsumerStatefulWidget {
//   // final String MerchantTradeNo;
//   final String orderId;
//   final List<String> productIds;
//   final String LogisticsSubType;
//   final String GoodsName;
//   final double GoodsAmount;
//   final String ReceiverStoreID;
//   final String? ReceiverStoreName;
//   final String? ReceiverStoreAddress;
//   final String? ReceiverStoreTelephone;
//   final String? SenderName;
//   final String? SenderCellPhone;
//   final double? shippingCost;
//   final double? shippingCostDeduction;

//   final Function(dynamic) onSuccess;
//   final Function(dynamic) onFailure;

//   const CreateExpressWebview({
//     super.key,
//     // required this.MerchantTradeNo,
//     required this.orderId,
//     required this.productIds,
//     required this.LogisticsSubType,
//     required this.GoodsName,
//     required this.GoodsAmount,
//     required this.ReceiverStoreID,
//     this.ReceiverStoreName,
//     this.ReceiverStoreAddress,
//     this.ReceiverStoreTelephone,
//     this.SenderName,
//     this.SenderCellPhone,
//     required this.onSuccess,
//     required this.onFailure,
//     required this.shippingCost,
//     required this.shippingCostDeduction,
//   });

//   @override
//   ConsumerState<CreateExpressWebview> createState() =>
//       _CreateExpressWebviewState();
// }

// class _CreateExpressWebviewState extends ConsumerState<CreateExpressWebview> {
//   Timer? _timer;
//   bool _isTimeout = false;

//   @override
//   void initState() {
//     super.initState();
//     _timer = Timer(Duration(seconds: 60), () {
//       setState(() {
//         _isTimeout = true;
//       });
//       widget.onFailure(null);
//     });
//   }

//   @override
//   dispose() {
//     _timer?.cancel();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final AccountInfo accountInfo = ref.watch(accountNotifierProvider);

//     return Stack(
//       fit: StackFit.expand,
//       children: [
//         SizedBox.expand(
//           child: InAppWebView(
//             onPermissionRequest: (controller, request) async {
//               return PermissionResponse(
//                 resources: request.resources,
//                 action: PermissionResponseAction.GRANT,
//               );
//             },
//             onWebViewCreated: (controller) async {
//               final urlWithAddedParams = UriUtils.addQueryParamsToUrl(
//                 baseUrl: "${AppConstants.apiBaseUrl}api/ecpay/express/create",
//                 queryParams: {
//                   "token": ref.watch(systemNotifierProvider).accessToken,
//                   "type": AppConstants.logisticsSubType,
//                   "orderId": widget.orderId,
//                   "productIds": widget.productIds,
//                   'LogisticsSubType': widget.LogisticsSubType,
//                   "GoodsName": widget.GoodsName,
//                   "GoodsAmount": widget.GoodsAmount,
//                   "ReceiverName": accountInfo.name,
//                   "ReceiverCellPhone": accountInfo.phone,
//                   "ReceiverEmail": accountInfo.email,
//                   "ReceiverStoreID": widget.ReceiverStoreID,
//                   "ReceiverStoreName": widget.ReceiverStoreName,
//                   "ReceiverStoreAddress": widget.ReceiverStoreAddress,
//                   "ReceiverStoreTelephone": widget.ReceiverStoreTelephone,
//                   "SenderName": widget.SenderName,
//                   "SenderCellPhone": widget.SenderCellPhone,
//                   "shippingCost": widget.shippingCost,
//                   "shippingCostDeduction": widget.shippingCostDeduction,
//                 },
//               );
//               log(urlWithAddedParams.toString());
//               await controller.loadUrl(
//                 urlRequest: URLRequest(url: WebUri.uri(urlWithAddedParams)),
//               );

//               controller.addJavaScriptHandler(
//                 handlerName: 'express-reply',
//                 callback: (args) {
//                   final response = args.firstOrNull;
//                   // log("Response - $response");
//                   _timer?.cancel();
//                   widget.onSuccess(response);
//                 },
//               );
//             },
//           ),
//         ),
//         if (!_isTimeout)
//           Container(
//             color: AppColors.scaffoldBgColor,
//             child: PageLoading('運單建立中，請稍後......'),
//           ),
//       ],
//     );
//   }
// }

// class DeliveryView extends ConsumerStatefulWidget {
//   const DeliveryView({
//     super.key,
//     required this.orderId,
//     required this.LogisticsType,
//     this.LogisticsSubType,
//     this.cvsStoreInfo,
//     required this.fee,
//     required this.feeDeduction,
//     required this.cartItems,
//     required this.onSuccess,
//     required this.onFailure,
//   });
//   final String orderId;
//   final String LogisticsType;
//   final String? LogisticsSubType;
//   final LogisticsMapInfo? cvsStoreInfo;
//   final double? fee;
//   final double? feeDeduction;
//   final List<CartItem> cartItems;
//   final Function(dynamic) onSuccess;
//   final Function(dynamic) onFailure;

//   @override
//   ConsumerState<DeliveryView> createState() => _DeliveryViewState();
// }

// class _DeliveryViewState extends ConsumerState<DeliveryView> {
//   // orderId: string;
//   // GoodsAmount: number;
//   // LogisticsType: string;
//   // LogisticsSubType: string | null | undefined;
//   // id: string | undefined;
//   // createdAt: Date | undefined;
//   // updatedAt: Date | undefined;
//   // merchantTradeNo: string | null | undefined;
//   // metadata: unknown;
//   // merchantTradeNo: string | null | undefined;
//   // AllPayLogisticsID: string | null | undefined;
//   // CVSPaymentNo: string | null | undefined;
//   // CVSValidationNo: string | null | undefined;
//   // LogisticsSubType: string | null | undefined;
//   // RtnCode: string | null | undefined;
//   // RtnMsg: string | null | undefined;
//   // ReceiverStoreId: string | null | undefined;
//   // homeDeliveryData: unknown;
//   // productIds: string[]

//   @override
//   void initState() {
//     super.initState();

//     Future.delayed(Duration.zero, () {
//       final accountInfo = ref.read(accountNotifierProvider);

//       double goodsAmount = widget.cartItems.fold(
//         0.0,
//         (sum, item) => sum + item.product.price * item.quantity,
//       );

//       Map<String, String>? getCvsStoreInfo(LogisticsMapInfo? storeInfo) {
//         if (storeInfo == null) return null;
//         final Map<String, String> store = {
//           "storeID": storeInfo.CVSStoreID,
//           "storeName": storeInfo.CVSStoreName,
//           "storeAddress": storeInfo.CVSAddress,
//         };
//         if (storeInfo.CVSTelephone != null) {
//           store["storeTelephone"] = storeInfo.CVSTelephone!;
//         }
//         return store;
//       }

//       ref
//           .read(dioProvider)
//           .post(
//             "/api/delivery/create",
//             data: {
//               "orderId": widget.orderId,
//               "LogisticsType": widget.LogisticsType,
//               "LogisticsSubType": widget.LogisticsSubType,
//               "GoodsAmount": goodsAmount,
//               "productIds": widget.cartItems.map((e) => e.productId).toList(),
//               "RtnCode": "300",
//               "RtnMsg": "訂單處理中(賣家已收到訂單資料)",
//               "fee": widget.fee,
//               "feeDeduction": widget.feeDeduction,
//               "cvsStoreInfo": getCvsStoreInfo(widget.cvsStoreInfo),
//               "homeDeliveryData": {
//                 "name": accountInfo.name,
//                 "phone": accountInfo.phone,
//                 "address": accountInfo.address,
//                 "email": accountInfo.email,
//               },
//               "metadata": {
//                 "LogisticsType": widget.LogisticsType,
//                 "LogisticsSubType": widget.LogisticsSubType,
//                 "GoodsAmount": goodsAmount,
//                 "RtnCode": "300",
//                 "RtnMsg": "訂單處理中(賣家已收到訂單資料)",
//               },
//             },
//           )
//           .then((response) {
//             if (response.data["success"] != true) {
//               return widget.onFailure(response.data["message"]);
//             }
//             widget.onSuccess(null);
//           })
//           .catchError((err) {
//             widget.onFailure(err);
//           });
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       fit: StackFit.expand,
//       children: [
//         Container(
//           color: AppColors.scaffoldBgColor,
//           child: PageLoading('運單建立中，請稍後......'),
//         ),
//       ],
//     );
//   }
// }
