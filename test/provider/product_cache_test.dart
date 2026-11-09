import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/provider/product_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../chat/chat_test_support.dart';

void main() {
  late ChatAdapter api;
  late Dio dio;
  late ProviderContainer container;
  late ProductNotifier notifier;
  late DateTime now;

  ResponseBody page(String id, {int page = 1, int pages = 3}) => jsonResponse({
    'products': [
      {'id': id, 'isCollected': false},
    ],
    'page': page,
    'limit': 20,
    'total': pages,
    'totalPages': pages,
  });
  List<String> ids() => container
      .read(productNotifierProvider)
      .data!
      .products
      .map((p) => p.id)
      .toList();
  Future<void> load(String category) =>
      notifier.loadProducts(categoryId: category, reuseExisting: true);

  setUp(() {
    now = DateTime.utc(2026, 11, 4);
    api = ChatAdapter();
    dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = api;
    container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(dio),
        productCacheClockProvider.overrideWithValue(() => now),
      ],
    );
    notifier = container.read(productNotifierProvider.notifier);
    api.handler = (r) async => page(
      '${r.queryParameters['categoryId']}-${r.queryParameters['page']}',
      page: r.queryParameters['page'] as int,
    );
  });
  tearDown(() {
    container.dispose();
    dio.close(force: true);
  });

  test(
    'switching back reuses that category and resumes after its loaded pages',
    () async {
      await load('A');
      await notifier.fetchMoreProducts();
      await load('B');
      await load('A');
      expect(api.requests, hasLength(3));
      expect(ids(), ['A-1', 'A-2']);
      await notifier.fetchMoreProducts();
      expect(api.requests.last.queryParameters['page'], 3);
      expect(ids(), ['A-1', 'A-2', 'A-3']);
    },
  );

  test(
    'each category expires independently at ten minutes; hits and pages do not renew it',
    () async {
      await load('A');
      now = now.add(const Duration(minutes: 5));
      await load('B');
      now = now.add(const Duration(minutes: 4));
      await load('A');
      expect(api.requests, hasLength(2));
      await notifier.fetchMoreProducts();
      expect(api.requests, hasLength(3));
      now = now.add(const Duration(minutes: 1));
      await load('A');
      expect(api.requests, hasLength(4));
      expect(ids(), ['A-1']);
      await load('B');
      expect(api.requests, hasLength(4));
      expect(ids(), ['B-1']);
    },
  );

  test(
    'search and both price bounds are part of the category cache key',
    () async {
      final queries = [
        (search: null, min: null, max: null),
        (search: '帽子', min: null, max: null),
        (search: '帽子', min: 10, max: null),
        (search: '帽子', min: 10, max: 50),
      ];
      for (var round = 0; round < 2; round++) {
        for (final q in queries) {
          await notifier.loadProducts(
            categoryId: 'A',
            search: q.search,
            minPrice: q.min,
            maxPrice: q.max,
            reuseExisting: true,
          );
        }
      }
      expect(api.requests, hasLength(4));
    },
  );

  test(
    'explicit refresh invalidates other categories as well as the active query',
    () async {
      await load('A');
      await load('B');
      await notifier.refreshProducts();
      expect(api.requests, hasLength(3));
      await load('A');
      expect(api.requests, hasLength(4));
    },
  );

  test(
    'collection changes propagate to cached categories without another request',
    () async {
      await load('A');
      await load('B');
      notifier.setProductCollected('A-1', true);
      await load('A');
      expect(
        container
            .read(productNotifierProvider)
            .data!
            .products
            .single
            .isCollected,
        isTrue,
      );
      expect(api.requests, hasLength(2));
    },
  );

  test(
    'failures are retried and empty successful results are cached',
    () async {
      api.handler = (_) async =>
          jsonResponse({'message': 'offline'}, status: 503);
      await load('A');
      expect(container.read(productNotifierProvider).hasError, isTrue);
      api.handler = (_) async => jsonResponse({
        'products': [],
        'page': 1,
        'totalPages': 1,
        'total': 0,
        'limit': 20,
      });
      await load('A');
      await load('B');
      await load('A');
      expect(api.requests, hasLength(3));
      expect(ids(), isEmpty);
    },
  );

  test(
    'switching to a cached category invalidates an older in-flight response',
    () async {
      await load('A');
      final pending = Completer<ResponseBody>();
      api.handler = (_) => pending.future;
      final older = load('B');
      await settle();
      await load('A');
      pending.complete(page('B-late'));
      await older;
      expect(ids(), ['A-1']);
      expect(api.requests, hasLength(2));
    },
  );

  test(
    'reset clears caches and late responses cannot repopulate them',
    () async {
      await load('A');
      final pending = Completer<ResponseBody>();
      api.handler = (_) => pending.future;
      final older = load('B');
      await settle();
      notifier.reset();
      pending.complete(page('B-late'));
      await older;
      expect(container.read(productNotifierProvider).isInitial, isTrue);
      api.handler = (_) async => page('fresh');
      await load('A');
      await load('B');
      expect(api.requests, hasLength(4));
      expect(ids(), ['fresh']);
    },
  );
}
