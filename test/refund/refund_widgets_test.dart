import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/features/order/widgets/order_item_list.dart';
import 'package:flutter_ad_ecommerce/features/order/widgets/refund_widgets.dart';
import 'package:flutter_ad_ecommerce/models/order.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/provider/refund_request_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../chat/chat_test_support.dart';

void main() {
  late Dio dio;
  late ChatAdapter adapter;
  late RefundRequestService service;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    adapter = ChatAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;
    service = RefundRequestService(dio, 'buyer');
  });
  tearDown(() => dio.close(force: true));

  OrderItem item({bool allowed = true}) => OrderItem.fromApiResponseMap({
    'id': 'item',
    'orderId': 'order',
    'productNameAtSale': '商品',
    'canRefund': allowed,
    'remainingRefundQuantity': allowed ? 2 : 0,
    'unreservedRefundQuantity': 2,
    'refundDeadlineAt': '2026-11-01T02:03:04Z',
    'refundBlockReason': allowed ? null : 'REFUND_WINDOW_EXPIRED',
    'refundItems': [
      {
        'id': 'refund',
        'status': 'rejected',
        'rejectionReason': '請補充照片',
        'quantity': 1,
      },
    ],
  });

  Widget app(Widget child) => ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(dio),
      refundRequestProvider.overrideWithValue(service),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );

  testWidgets(
    'rejection deadline appears below rejection time without opening history',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final decisionDeadline = DateTime.utc(2026, 10, 28, 2, 3, 4);
      final orderItem = item().copyWith(
        refundItems: [
          RefundItem.fromApiResponseMap({
            'status': 'rejected',
            'rejectionDeadlineAfter': decisionDeadline.toIso8601String(),
            'rejectedAt': '2026-10-27T02:03:04Z',
          }),
        ],
      );
      final currentDeadlineText = DateFormat(
        'yyyy-MM-dd HH:mm:ss',
      ).format(orderItem.refundDeadlineAt!.toLocal());
      final decisionDeadlineText = DateFormat(
        'yyyy-MM-dd HH:mm:ss',
      ).format(decisionDeadline.toLocal());
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showRefundItemsBottomSheet(
                context,
                item: orderItem,
                onCreateRefund: (_) async => false,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('查看記錄'), findsNothing);
      expect(find.text('重新申請截止時間:'), findsOneWidget);
      expect(find.text(decisionDeadlineText), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('重新申請截止時間:')).dy,
        greaterThan(tester.getTopLeft(find.text('拒絕時間:')).dy),
      );
      expect(
        find.textContaining('新申請截止時間：$currentDeadlineText'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'chat link closes refund details and passes the exact order item',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final selected = item().copyWith(
        productVariantId: 'variant-2',
        refundItems: [
          RefundItem.fromApiResponseMap({'status': 'pending'}),
        ],
      );
      OrderItem? openedItem;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showRefundItemsBottomSheet(
                context,
                item: selected,
                onCreateRefund: (_) async => false,
                onOpenChat: (value) {
                  openedItem = value;
                },
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('聊天室'));
      await tester.tap(find.text('聊天室'));
      await tester.pumpAndSettle();
      expect(openedItem, same(selected));
      expect(openedItem!.orderId, 'order');
      expect(openedItem!.productVariantId, 'variant-2');
      expect(find.text('退貨詳情'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'optional reason and absent seller do not block; quantity capped',
    (tester) async {
      adapter.handler = (_) async =>
          jsonResponse({'id': 'refund', 'status': 'pending'});
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showCreateRefundDialog(
                context,
                item: item().copyWith(
                  refundReceiptChecksBypassed: true,
                  refundWindowStatus: 'open',
                  refundWindowSource: 'payment_for_testing',
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '送出'))
            .onPressed,
        isNotNull,
      );
      expect(find.textContaining('新申請截止時間：'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '3');
      await tester.pump();
      expect(
        tester
            .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '送出'))
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byType(TextField).first, '2');
      await tester.pump();
      await tester.tap(find.text('送出'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect((adapter.requests.single.data as Map)['quantity'], 2);
    },
  );

  testWidgets(
    'expired development window hides new requests but preserves history',
    (tester) async {
      final expired = item(allowed: false).copyWith(
        refundReceiptChecksBypassed: true,
        refundWindowSource: 'payment_for_testing',
        refundWindowStatus: 'expired',
      );
      await tester.pumpWidget(
        app(
          OrderItemList(
            items: [expired.copyWith(refundItems: [])],
            onContactSupport: (_) {},
            onCreateRefund: (_) {},
            onShowRefundDetails: (_) {},
            onViewProductDetails: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('申請退貨'), findsNothing);
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showRefundItemsBottomSheet(
                context,
                item: expired,
                onCreateRefund: (_) async => false,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('新增'), findsNothing);
      expect(find.textContaining('新申請截止時間：'), findsOneWidget);
      expect(find.text('已拒絕'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'expired items keep refund history and rejection reason visible',
    (tester) async {
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showRefundItemsBottomSheet(
                context,
                item: item(allowed: false),
                onCreateRefund: (_) async => false,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('新增'), findsNothing);
      expect(find.text('已拒絕'), findsOneWidget);
      expect(find.text('請補充照片'), findsOneWidget);
      expect(find.textContaining('新申請截止時間：'), findsOneWidget);
      expect(find.textContaining('已受理申請不受影響'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pending timeout exposes recovery even when no longer eligible', (
    tester,
  ) async {
    adapter.handler = (request) async => throw DioException(
      requestOptions: request,
      type: DioExceptionType.receiveTimeout,
    );
    await tester.runAsync(
      () => service.submit(itemId: 'item', quantity: 2, reason: '原原因'),
    );
    await tester.pumpWidget(
      app(
        OrderItemList(
          items: [item(allowed: false)],
          onContactSupport: (_) {},
          onCreateRefund: (_) {},
          onShowRefundDetails: (_) {},
          onViewProductDetails: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('確認申請'), findsOneWidget);
    expect(find.text('退貨詳情'), findsOneWidget);
    expect(find.text('申請退貨'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'restored retry locks original fields and bypasses expired eligibility',
    (tester) async {
      adapter.handler = (request) async => throw DioException(
        requestOptions: request,
        type: DioExceptionType.receiveTimeout,
      );
      await tester.runAsync(
        () => service.submit(itemId: 'item', quantity: 2, reason: '原原因'),
      );
      adapter.handler = (_) async =>
          jsonResponse({'id': 'refund', 'status': 'completed'});
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showCreateRefundDialog(context, item: item(allowed: false)),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(field.enabled, isFalse);
      }
      expect(find.text('原原因'), findsOneWidget);
      await tester.tap(find.text('重試原申請'));
      await tester.pumpAndSettle();
      expect(adapter.requests[1].data, adapter.requests[0].data);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
}
