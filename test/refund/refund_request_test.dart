import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/models/api_enums.dart';
import 'package:flutter_ad_ecommerce/models/order.dart';
import 'package:flutter_ad_ecommerce/provider/refund_request_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../chat/chat_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ChatAdapter adapter;
  late Dio dio;
  late RefundRequestService service;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    adapter = ChatAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;
    service = RefundRequestService(dio, 'buyer');
  });
  tearDown(() => dio.close(force: true));

  test(
    'posts only allowed fields, no seller required, returns current status',
    () async {
      adapter.handler = (request) async {
        final body = request.data as Map;
        expect(body.keys.toSet(), {
          'orderItemId',
          'quantity',
          'clientRequestId',
        });
        expect(
          body['clientRequestId'],
          matches(
            RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
            ),
          ),
        );
        expect(request.extra['authOwner'], 'buyer');
        return jsonResponse({
          'id': 'refund',
          'status': 'rejected',
          'rejectionReason': '原因',
        });
      };
      final result = await service.submit(
        itemId: 'item',
        quantity: 1,
        reason: ' ',
      );
      expect(result.item!.status, RefundStatus.rejected);
      expect(result.item!.rejectionReason, '原因');
      expect(await service.pending('item'), isNull);
    },
  );

  test(
    'lost response survives restart and retries exact original payload',
    () async {
      adapter.handler = (request) async => throw DioException(
        requestOptions: request,
        type: DioExceptionType.receiveTimeout,
      );
      expect(
        (await service.submit(
          itemId: 'item',
          quantity: 2,
          reason: ' damaged ',
          note: 'note',
        )).uncertain,
        isTrue,
      );
      final original = Map.of(adapter.requests.single.data as Map);
      final restarted = RefundRequestService(dio, 'buyer');
      expect(await restarted.pending('item'), original);
      expect(
        await RefundRequestService(dio, 'other-buyer').pending('item'),
        isNull,
      );
      adapter.handler = (request) async {
        expect(request.data, original);
        return jsonResponse({'id': 'already-created', 'status': 'completed'});
      };
      final result = await restarted.submit(
        itemId: 'item',
        quantity: 99,
        reason: 'changed',
      );
      expect(result.item!.status, RefundStatus.completed);
      expect(await restarted.pending('item'), isNull);
    },
  );

  test('concurrent submits share a single POST', () async {
    final response = Completer<ResponseBody>();
    adapter.handler = (_) => response.future;
    final first = service.submit(itemId: 'item', quantity: 1);
    final second = service.submit(itemId: 'item', quantity: 2);
    await settle();
    expect(adapter.requests.length, 1);
    response.complete(jsonResponse({'id': 'refund'}));
    expect((await first).isSuccess, isTrue);
    expect((await second).isSuccess, isTrue);
  });

  test(
    'business failure releases draft; deliberate new attempt gets new UUID',
    () async {
      adapter.handler = (_) async =>
          jsonResponse({'code': 'REFUND_WINDOW_EXPIRED'}, status: 409);
      final result = await service.submit(itemId: 'item', quantity: 1);
      expect(result.uncertain, isFalse);
      expect(result.error, contains('新申請期限'));
      expect(await service.pending('item'), isNull);
      final oldId = (adapter.requests.single.data as Map)['clientRequestId'];
      adapter.handler = (_) async => jsonResponse({'id': 'new'});
      await service.submit(itemId: 'item', quantity: 1);
      expect(
        (adapter.requests.last.data as Map)['clientRequestId'],
        isNot(oldId),
      );
    },
  );

  test('conflict and server errors retain original draft', () async {
    for (final status in [409, 503]) {
      adapter.handler = (_) async =>
          jsonResponse({'code': 'REFUND_REQUEST_CONFLICT'}, status: status);
      final result = await service.submit(itemId: 'item', quantity: 1);
      expect(result.uncertain, isTrue);
      expect(await service.pending('item'), isNotNull);
    }
  });

  test(
    'unknown payment time is a business failure with support guidance',
    () async {
      adapter.handler = (_) async =>
          jsonResponse({'code': 'PAYMENT_TIME_UNKNOWN'}, status: 409);
      final result = await service.submit(itemId: 'item', quantity: 1);
      expect(result.error, '無法確認付款時間，請聯絡客服協助');
      expect(result.uncertain, isFalse);
      expect(await service.pending('item'), isNull);
    },
  );

  test('unknown receipt gives support guidance', () async {
    adapter.handler = (_) async =>
        jsonResponse({'code': 'RECEIPT_TIME_UNKNOWN'}, status: 409);
    expect(
      (await service.submit(itemId: 'item', quantity: 1)).error,
      contains('聯絡客服'),
    );
  });

  test(
    'eligibility timestamps, available quantities and rejection survive parsing/copy',
    () {
      final item = OrderItem.fromApiResponseMap({
        'canRefund': false,
        'remainingRefundQuantity': 0,
        'unreservedRefundQuantity': 2,
        'refundWindowStatus': 'expired',
        'refundBlockReason': 'REFUND_WINDOW_EXPIRED',
        'refundDeadlineAt': '2026-11-01T02:00:00Z',
        'refundServerTime': '2026-11-02T02:00:00Z',
        'refundItems': [
          {
            'status': 'rejected',
            'rejectionReason': '請補充說明',
            'originalRequest': {'quantity': 2},
            'logs': [
              {'status': 'rejected'},
            ],
          },
        ],
      });
      expect(item.copyWith().unreservedRefundQuantity, 2);
      expect(item.copyWith().canRefund, isFalse);
      expect(
        item.copyWith().refundDeadlineAt!.toUtc(),
        DateTime.utc(2026, 11, 1, 2),
      );
      expect(item.refundItems.single.originalRequest!['quantity'], 2);
      expect(item.refundItems.single.logs.single.status, RefundStatus.rejected);
      expect(
        item.copyWith(remainingRefundQuantity: 1).remainingRefundQuantity,
        1,
      );
      expect(OrderItem.fromApiResponseMap({}).refundDeadlineAt, isNull);
      expect(
        OrderItem.fromApiResponseMap({}).refundReceiptChecksBypassed,
        isFalse,
      );
      for (final status in ['open', 'not_started', 'unknown', 'expired']) {
        final bypassed = OrderItem.fromApiResponseMap({
          'canRefund': status == 'open',
          'remainingRefundQuantity': status == 'open' ? 1 : 0,
          'refundWindowSource': 'payment_for_testing',
          'refundReceiptChecksBypassed': true,
          'refundWindowStatus': status,
        }).copyWith();
        expect(bypassed.canRefund, status == 'open');
        expect(bypassed.refundWindowSource, 'payment_for_testing');
        expect(bypassed.refundReceiptChecksBypassed, isTrue);
      }
    },
  );
}
