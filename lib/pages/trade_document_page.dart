import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/app_constants.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/models/order.dart';
import 'package:flutter_ad_ecommerce/provider/system_provider.dart';
import 'package:flutter_ad_ecommerce/utils/uri_utils.dart';
import 'package:flutter_ad_ecommerce/widgets/simple_app_bar.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TradeDocumentPage extends ConsumerWidget {
  const TradeDocumentPage({super.key, required this.delivery});

  final Delivery delivery;

  Widget _buildLayout({required Widget child}) {
    return Scaffold(
      backgroundColor: AppColors.primaryColor,
      appBar: SimpleAppBar(title: '檢視托運單'),
      body: child,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _buildLayout(
      child: SizedBox.expand(
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
                  "${AppConstants.apiBaseUrl}api/ecpay/helper/printTradeDocument",
              queryParams: {
                "token": ref.watch(systemNotifierProvider).accessToken,
                "LogisticsSubType": delivery.logisticsSubType,
                "AllPayLogisticsID": delivery.allPayLogisticsID,
                "CVSPaymentNo": delivery.cvsPaymentNo,
                "CVSValidationNo": delivery.cvsValidationNo,
              },
            );
            log(urlWithAddedParams.toString());
            await controller.loadUrl(
              urlRequest: URLRequest(url: WebUri.uri(urlWithAddedParams)),
            );
          },
        ),
      ),
    );
  }
}
