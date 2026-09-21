import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/models/product.dart';
import 'package:flutter_ad_ecommerce/pages/ecpay_page.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/provider/system_provider.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final failure in [
    (
      body: <String, dynamic>{'message': '此商品規格已下架，無法建立訂單'},
      message: '此商品規格已下架，無法建立訂單',
    ),
    (
      body: <String, dynamic>{
        'error': [
          {'productName': 'Test product', 'reason': '商品已下架'},
        ],
      },
      message: '商品已下架',
    ),
    for (final reason in {
      'Product not found': '商品已下架或不存在',
      'Product deleted': '商品已刪除',
      'Product inactive': '商品已下架',
      'Variant not found': '所選規格已下架或不存在',
      'Variant inactive': '所選規格已下架',
      'Insufficient stock': '庫存不足',
    }.entries)
      (
        body: <String, dynamic>{
          'success': false,
          'statusCode': 400,
          'message': jsonEncode({
            'error': [
              {
                'productId': 'product',
                'productVariantId': 'variant',
                'productName': 'Test product',
                'reason': reason.key,
              },
            ],
          }),
        },
        message: reason.value,
      ),
    (body: <String, dynamic>{}, message: '無法建立訂單，請確認商品、規格及結帳資料後再試。'),
  ]) {
    testWidgets('Order HTTP 400 shows warning: ${failure.message}', (
      tester,
    ) async {
      final requests = <String>[];
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options.path);
            if (options.method == 'GET') {
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'success': true,
                    'data': options.path == 'api/cart/list'
                        ? []
                        : {'products': [], 'total': 0, 'totalPages': 1},
                  },
                ),
              );
              return;
            }
            handler.reject(
              DioException.badResponse(
                statusCode: 400,
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 400,
                  data: failure.body,
                ),
              ),
            );
          },
        ),
      );
      addTearDown(() => dio.close());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dioProvider.overrideWithValue(dio)],
          child: MaterialApp(
            home: ECPayPage(
              extra: {
                'subTotal': 100.0,
                'totalAmount': 100.0,
                'discountCoin': 0.0,
                'shippingCost': 0.0,
                'shippingCostDeduction': 0.0,
                'transactionFee': 0.0,
                'cartItems': <CartItem>[],
                'groups': <Map<String, dynamic>>[],
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('訂單建立失敗'), findsOneWidget);
      expect(find.text(failure.message), findsOneWidget);
      expect(find.text('返回'), findsOneWidget);
      expect(find.byType(InAppWebView), findsNothing);
      expect(requests, ['/api/order', 'api/cart/list', '/api/product/list']);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ECPayPage)),
      );
      expect(container.read(systemNotifierProvider).currentOrder, isNull);
      expect(tester.takeException(), isNull);
    });
  }
}
