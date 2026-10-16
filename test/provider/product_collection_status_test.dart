import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/models/product.dart';
import 'package:flutter_ad_ecommerce/provider/collection_provider.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/provider/product_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../chat/chat_test_support.dart' show ChatAdapter, jsonResponse, settle;

Map<String, dynamic> _page({int page = 1, bool saved = false}) => {
  'products': [
    {'id': 'product-$page', 'name': 'Product', 'isCollected': saved},
  ],
  'page': page,
  'limit': 20,
  'totalPages': 2,
};

void main() {
  test('collection status preserves false and missing values distinctly', () {
    final product = Product.fromApiResponseMap({
      'id': 'product',
      'isCollected': true,
    });
    expect(product.isCollected, isTrue);
    expect(product.copyWith(name: 'Renamed').isCollected, isTrue);
    final removed = product.copyWith(isCollected: false);
    expect(removed.isCollected, isFalse);
    expect(Product.fromApiResponseMap(removed.toMap()).isCollected, isFalse);
    expect(Product.fromApiResponseMap({'id': 'embedded'}).isCollected, isNull);
  });

  test(
    'only successful collection mutations change cached product status',
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
      var fail = false;
      api.handler = (r) async {
        if (r.path == '/api/product/list') return jsonResponse(_page());
        expect(r.path, '/api/collection');
        expect(r.data, {'productId': 'product-1'});
        return fail
            ? jsonResponse({'message': 'offline'}, status: 503)
            : jsonResponse({});
      };
      await container.read(productNotifierProvider.notifier).loadProducts();
      final subscription = container.listen(
        collectionNotifierProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final collections = container.read(collectionNotifierProvider.notifier);
      bool? saved() => container
          .read(productNotifierProvider)
          .data!
          .products
          .single
          .isCollected;
      expect(saved(), isFalse);
      expect((await collections.addCollection('product-1')).isSuccess, isTrue);
      expect(saved(), isTrue);
      fail = true;
      expect(
        (await collections.removeCollection('product-1')).isFailure,
        isTrue,
      );
      expect(saved(), isTrue);
      fail = false;
      expect(
        (await collections.removeCollection('product-1')).isSuccess,
        isTrue,
      );
      expect(saved(), isFalse);
      expect(api.requests.where((r) => r.method == 'GET'), hasLength(1));
    },
  );

  for (final page in [1, 2]) {
    test(
      'mutation wins over an older response for product page $page',
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
        final pending = Completer<ResponseBody>();
        api.handler = (r) async => r.queryParameters['page'] == page
            ? pending.future
            : jsonResponse(_page());
        final notifier = container.read(productNotifierProvider.notifier);
        if (page == 2) await notifier.loadProducts();
        final request = page == 1
            ? notifier.loadProducts()
            : notifier.fetchMoreProducts();
        await settle();
        notifier.setProductCollected('product-$page', true);
        expect(
          page == 1
              ? container.read(productNotifierProvider).isLoading
              : container.read(productNotifierProvider).isFetching,
          isTrue,
        );
        pending.complete(jsonResponse(_page(page: page)));
        await request;
        expect(
          container
              .read(productNotifierProvider)
              .data!
              .products
              .last
              .isCollected,
          isTrue,
        );

        // A subsequent REST refresh remains authoritative (e.g. another device).
        api.handler = (_) async =>
            jsonResponse(_page(page: page, saved: false));
        await notifier.refreshProducts();
        expect(
          container
              .read(productNotifierProvider)
              .data!
              .products
              .single
              .isCollected,
          isFalse,
        );
      },
    );
  }
}
