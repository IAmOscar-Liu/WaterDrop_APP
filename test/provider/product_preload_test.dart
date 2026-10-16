import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/pages/product_page.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/provider/product_provider.dart';
import 'package:flutter_ad_ecommerce/utils/api_call_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../chat/chat_test_support.dart' show ChatAdapter, jsonResponse, settle;

Map<String, dynamic> productPage({
  int page = 1,
  String prefix = 'product',
  int pages = 2,
}) => {
  'products': List.generate(
    20,
    (i) => {
      'id': '$prefix-${(page - 1) * 20 + i}',
      'name': '商品 $i',
      'price': 100,
    },
  ),
  'page': page,
  'limit': 20,
  'total': pages * 20,
  'totalPages': pages,
};

void main() {
  testWidgets(
    'preload survives without listeners and the market reuses its first 20 items',
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
      api.handler = (r) async =>
          jsonResponse(productPage(page: r.queryParameters['page'] as int));
      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      final notifier = container.read(productNotifierProvider.notifier);
      await tester.runAsync(() => notifier.loadProducts(reuseExisting: true));
      await container.pump();
      expect(
        container.read(productNotifierProvider).data!.products,
        hasLength(20),
      );
      await ApiCallManager.updateApiCallTimestamp(productListApiCacheKey);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProductPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.requests, hasLength(1));
      expect(api.requests.single.queryParameters['page'], 1);
      expect(api.requests.single.queryParameters['limit'], 20);
      expect(api.requests.single.queryParameters['status'], 'active');
      await tester.runAsync(notifier.fetchMoreProducts);
      await tester.pumpAndSettle();
      expect(api.requests.last.queryParameters['page'], 2);
      expect(
        container.read(productNotifierProvider).data!.products,
        hasLength(40),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      dio.close(force: true);
    },
  );

  test(
    'entry joins a pending preload and an older response cannot replace a search',
    () async {
      final api = ChatAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = api;
      final initial = Completer<ResponseBody>();
      api.handler = (r) async => r.queryParameters['search'] == null
          ? initial.future
          : jsonResponse(productPage(prefix: 'filtered'));
      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      addTearDown(() {
        container.dispose();
        dio.close(force: true);
      });
      final notifier = container.read(productNotifierProvider.notifier);
      final preload = notifier.loadProducts(reuseExisting: true);
      await settle();
      await notifier.loadProducts(reuseExisting: true);
      expect(api.requests, hasLength(1));
      await notifier.loadProducts(search: 'search');
      initial.complete(jsonResponse(productPage()));
      await preload;
      expect(
        container.read(productNotifierProvider).data!.products.first.id,
        startsWith('filtered'),
      );
    },
  );

  test('failed preload retries and logout discards late responses', () async {
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
    final notifier = container.read(productNotifierProvider.notifier);
    api.handler = (_) async =>
        jsonResponse({'message': 'offline'}, status: 503);
    await notifier.loadProducts(reuseExisting: true);
    expect(container.read(productNotifierProvider).hasError, isTrue);
    api.handler = (_) async => jsonResponse(productPage());
    await notifier.loadProducts(reuseExisting: true);
    expect(container.read(productNotifierProvider).isDone, isTrue);
    final late = Completer<ResponseBody>();
    api.handler = (_) => late.future;
    final refreshing = notifier.refreshProducts();
    await settle();
    container.invalidate(productNotifierProvider);
    await container.pump();
    late.complete(jsonResponse(productPage()));
    await refreshing;
    expect(container.read(productNotifierProvider).isInitial, isTrue);
  });
}
