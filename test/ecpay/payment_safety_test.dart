import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/features/ecpay/payment_preparation.dart';
import 'package:flutter_ad_ecommerce/models/api_enums.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/provider/order_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../chat/chat_test_support.dart';

void main() {
  late ChatAdapter adapter;
  late Dio dio;
  late ProviderContainer container;
  final uri = Uri.parse('https://example.test/api/ecpay/new?orderId=order');

  setUp(() {
    adapter = ChatAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;
    container = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(dio)],
    );
  });
  tearDown(() {
    container.dispose();
    dio.close(force: true);
  });

  test('loads a prepared HTML form with exactly one request', () async {
    const html = '<html><form action="https://payment.test"></form></html>';
    adapter.handler = (_) async => ResponseBody.fromString(html, 200);
    final result = await preparePaymentForm(dio, uri);
    expect(result.data, html);
    expect(adapter.requests, hasLength(1));
  });

  for (final entry in {
    'INSUFFICIENT_SPENDABLE_COINS': '購物金不足',
    'PAYMENT_ALREADY_STARTED': '避免重複付款',
    'INVALID_SHIPPING_INFO': '配送資訊',
    'COIN_LEDGER_REQUIRED': '折抵暫時無法使用',
  }.entries) {
    test(
      'payment preparation translates ${entry.key} without retrying',
      () async {
        adapter.handler = (_) async =>
            jsonResponse({'code': entry.key}, status: 409);
        final result = await preparePaymentForm(dio, uri);
        expect(result.isFailure, isTrue);
        expect(result.error, contains(entry.value));
        expect(adapter.requests, hasLength(1));
      },
    );
  }

  test('connection failure preserves an uncertain payment message', () async {
    adapter.handler = (request) async => throw DioException(
      requestOptions: request,
      type: DioExceptionType.receiveTimeout,
    );
    final result = await preparePaymentForm(dio, uri);
    expect(result.error, contains('原訂單'));
    expect(result.error, contains('避免重複付款'));
    expect(adapter.requests, hasLength(1));
  });

  test('cancel sends only the allowed status field', () async {
    adapter.handler = (_) async =>
        jsonResponse({'id': 'order', 'orderStatus': 'canceled'});
    final result = await container
        .read(orderNotifierProvider.notifier)
        .updateOrder(orderId: 'order', status: OrderStatus.canceled);
    expect(result.data?.orderStatus, OrderStatus.canceled);
    expect(adapter.requests.single.data, {'status': 'canceled'});
  });

  test('cancel conflict re-reads the original processing order', () async {
    adapter.handler = (request) async => request.method == 'PUT'
        ? jsonResponse({'code': 'PAYMENT_CONFIRMATION_PENDING'}, status: 409)
        : jsonResponse({'id': 'order', 'orderStatus': 'payment-processing'});
    final result = await container
        .read(orderNotifierProvider.notifier)
        .updateOrder(orderId: 'order', status: OrderStatus.canceled);
    expect(result.data?.orderStatus, OrderStatus.paymentProcessing);
    expect(adapter.requests.map((request) => request.method), ['PUT', 'GET']);
    expect(adapter.requests.last.path, '/api/order/order');
  });

  test('client cannot submit financial status or expiry', () async {
    for (final status in [
      OrderStatus.paid,
      OrderStatus.failed,
      OrderStatus.expired,
      OrderStatus.paymentProcessing,
    ]) {
      final result = await container
          .read(orderNotifierProvider.notifier)
          .updateOrder(orderId: 'order', status: status);
      expect(result.isFailure, isTrue);
    }
    expect(adapter.requests, isEmpty);
  });
}
