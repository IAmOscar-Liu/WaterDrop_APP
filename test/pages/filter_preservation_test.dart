import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/app_constants.dart';
import 'package:flutter_ad_ecommerce/models/product.dart';
import 'package:flutter_ad_ecommerce/pages/message_page.dart';
import 'package:flutter_ad_ecommerce/pages/product_page.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/provider/notification_sync_provider.dart';
import 'package:flutter_ad_ecommerce/provider/product_category_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../chat/chat_test_support.dart';
import '../notification/notification_sync_test.dart' show counts, page;

class _Categories extends ProductCategory {
  @override
  List<Category> build() =>
      List.generate(10, (i) => Category(id: '$i', name: '分類$i'));
}

void main() {
  for (final market in [true, false]) {
    for (final failure in [false, true]) {
      testWidgets(
        'horizontal filters stay mounted during category loading (market=$market, failure=$failure)',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          await tester.binding.setSurfaceSize(const Size(360, 740));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final api = ChatAdapter(eventPath: '/api/notification/events');
          final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
            ..httpClientAdapter = api;
          final sync = NotificationSyncController(dio, () async => false);
          final pending = Completer<ResponseBody>();
          var lists = 0;
          final empty = market
              ? {
                  'products': [],
                  'page': 1,
                  'limit': 20,
                  'total': 0,
                  'totalPages': 1,
                }
              : page([]);
          api.handler = (r) async {
            if (r.path.endsWith('/stats')) return jsonResponse(counts(1));
            lists++;
            return lists == 1 ? jsonResponse(empty) : pending.future;
          };
          if (!market && AppConstants.notificationSseEnabled) {
            sync.configureSession('u', foreground: true);
          }
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                dioProvider.overrideWithValue(dio),
                productCategoryProvider.overrideWith(_Categories.new),
                notificationSyncProvider.overrideWith((ref) => sync),
              ],
              child: MaterialApp(
                home: market ? const ProductPage() : const MessagePage(),
              ),
            ),
          );
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            dio.close(force: true);
          });
          if (!market && AppConstants.notificationSseEnabled) {
            for (var i = 0; i < 10 && api.connections.isEmpty; i++) {
              await tester.pump(const Duration(milliseconds: 1));
            }
            api.event('stream.ready', {'schemaVersion': 1, 'cursor': 'head'});
          }
          await tester.pumpAndSettle();
          final horizontal = find
              .byWidgetPredicate(
                (widget) =>
                    widget is Scrollable &&
                    widget.axisDirection == AxisDirection.right,
              )
              .first;
          final scroll = tester.state<ScrollableState>(horizontal);
          scroll.position.jumpTo(scroll.position.maxScrollExtent);
          await tester.pump();
          final offset = scroll.position.pixels;
          expect(offset, greaterThan(0));
          final category = market ? '分類9' : '其他';
          await tester.tap(find.text(category));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(lists, 2);
          expect(
            find.text(market ? '載入商品中......' : '載入訊息中......'),
            findsOneWidget,
          );
          expect(
            identical(tester.state<ScrollableState>(horizontal), scroll),
            isTrue,
          );
          expect(scroll.position.pixels, closeTo(offset, 0.1));
          expect(find.text('僅顯示未讀'), market ? findsNothing : findsOneWidget);
          pending.complete(
            failure
                ? jsonResponse({'message': 'failed'}, status: 503)
                : jsonResponse(empty),
          );
          await tester.pumpAndSettle();
          expect(
            identical(tester.state<ScrollableState>(horizontal), scroll),
            isTrue,
          );
          expect(scroll.position.pixels, closeTo(offset, 0.1));
          expect(find.text(category), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
