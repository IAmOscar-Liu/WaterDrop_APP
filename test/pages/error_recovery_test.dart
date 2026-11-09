import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/pages/product_page.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/provider/product_provider.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/page_status.dart';
import 'package:flutter_ad_ecommerce/utils/app_failure.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../chat/chat_test_support.dart';

void main() {
  testWidgets(
    'market pagination keeps rows and offers one explicit retry without an automatic failure loop',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final interval = VisibilityDetectorController.instance.updateInterval;
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      addTearDown(
        () => VisibilityDetectorController.instance.updateInterval = interval,
      );
      final api = ChatAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = api;
      var failMore = true;
      api.handler = (r) async {
        final page = r.queryParameters['page'] as int;
        if (page == 2 && failMore) {
          return jsonResponse({'message': 'secret'}, status: 503);
        }
        return jsonResponse({
          'products': [
            {'id': '$page', 'name': '商品 $page', 'price': 10},
          ],
          'page': page,
          'totalPages': 2,
          'total': 2,
          'limit': 20,
        });
      };
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dioProvider.overrideWithValue(dio)],
          child: const MaterialApp(home: ProductPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('商品 1'), findsOneWidget);
      expect(find.text('載入失敗，點擊重試'), findsOneWidget);
      final before = api.requests.length;
      await tester.pump(const Duration(seconds: 1));
      expect(api.requests, hasLength(before));
      failMore = false;
      await tester.tap(find.text('載入失敗，點擊重試'));
      await tester.pumpAndSettle();
      expect(find.text('商品 1'), findsOneWidget);
      expect(find.text('商品 2'), findsOneWidget);
      expect(api.requests.last.queryParameters['page'], 2);
      await tester.pumpWidget(const SizedBox.shrink());
      dio.close(force: true);
    },
  );
  testWidgets(
    'connection panel keeps filters and retries the same market query',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final api = ChatAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = api;
      var offline = true;
      api.handler = (r) async {
        if (offline) {
          throw DioException(
            requestOptions: r,
            type: DioExceptionType.connectionError,
            message: 'secret network details',
          );
        }
        return jsonResponse({
          'products': [],
          'page': 1,
          'limit': 20,
          'totalPages': 1,
          'total': 0,
        });
      };
      await tester.pumpWidget(
        ProviderScope(
          overrides: [dioProvider.overrideWithValue(dio)],
          child: const MaterialApp(home: ProductPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('目前無法連線'), findsOneWidget);
      expect(find.text('全部'), findsOneWidget);
      expect(find.textContaining('secret'), findsNothing);
      offline = false;
      await tester.tap(find.text('重試'));
      await tester.pumpAndSettle();
      expect(find.text('很抱歉，找不到您想要的相關商品'), findsOneWidget);
      expect(api.requests, hasLength(2));
      await tester.pumpWidget(const SizedBox.shrink());
      dio.close(force: true);
    },
  );
  test('pagination failure preserves rows and retries page two', () async {
    final api = ChatAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = api;
    final container = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(dio)],
    );
    addTearDown(() {
      container.dispose();
      dio.close(force: true);
    });
    var fail = false;
    api.handler = (r) async => fail
        ? jsonResponse({'message': 'secret'}, status: 503)
        : jsonResponse({
            'products': [
              {'id': 'page-${r.queryParameters['page']}'},
            ],
            'page': r.queryParameters['page'],
            'total': 2,
            'totalPages': 2,
            'limit': 20,
          });
    final notifier = container.read(productNotifierProvider.notifier);
    await notifier.loadProducts(categoryId: 'A');
    fail = true;
    await notifier.fetchMoreProducts();
    expect(
      container.read(productNotifierProvider).data!.products.single.id,
      'page-1',
    );
    expect(container.read(productNotifierProvider).paginationFailed, isTrue);
    fail = false;
    await notifier.fetchMoreProducts();
    expect(api.requests.last.queryParameters['page'], 2);
    expect(
      container.read(productNotifierProvider).data!.products.map((p) => p.id),
      ['page-1', 'page-2'],
    );
  });
  test(
    'refresh error retains the current query but changing category does not show old rows',
    () async {
      final api = ChatAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = api;
      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      addTearDown(() {
        container.dispose();
        dio.close(force: true);
      });
      api.handler = (_) async => jsonResponse({
        'products': [
          {'id': 'A'},
        ],
        'page': 1,
        'totalPages': 1,
        'total': 1,
        'limit': 20,
      });
      final notifier = container.read(productNotifierProvider.notifier);
      await notifier.loadProducts(categoryId: 'A');
      api.handler = (_) async =>
          jsonResponse({'message': 'secret'}, status: 503);
      await notifier.refreshProducts();
      expect(
        container.read(productNotifierProvider).data!.products.single.id,
        'A',
      );
      expect(container.read(productNotifierProvider).failure, isNotNull);
      final pending = Completer<ResponseBody>();
      api.handler = (_) => pending.future;
      final loading = notifier.loadProducts(categoryId: 'B');
      await settle();
      expect(container.read(productNotifierProvider).data, isNull);
      pending.complete(jsonResponse({'message': 'secret'}, status: 503));
      await loading;
    },
  );
  testWidgets('retry honors the server cooldown and hides raw technical text', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageError(
            AppFailure(
              kind: FailureKind.rateLimited,
              retryAt: DateTime.now().add(const Duration(seconds: 2)),
            ),
            onRetry: () => retries++,
          ),
        ),
      ),
    );
    expect(find.text('2秒後重試'), findsOneWidget);
    await tester.tap(find.text('2秒後重試'));
    expect(retries, 0);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2100)),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.text('重試'));
    expect(retries, 1);
  });
}
