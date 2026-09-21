import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/models/product.dart';
import 'package:flutter_ad_ecommerce/provider/cart_provider.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> row(String id, {bool checked = true}) => {
  'id': id,
  'productId': id == 'valid' ? 'active-product' : 'stale-product',
  'productVariantId': id,
  'checked': checked,
  'quantity': 1,
  'product': {'id': id, 'name': id, 'status': 'active'},
};

void main() {
  for (final scenario in [
    'inactive product',
    'deleted product',
    'missing product',
    'inactive variant',
    'missing variant',
    'delete failed',
    'delete acknowledged but row remains',
    'already removed',
    'legacy removal 404',
    'refresh failed',
  ]) {
    test('Checkout cleans up stale selected rows: $scenario', () async {
      final rows = [
        row('stale'),
        row('valid'),
        row('unchecked', checked: false),
      ];
      final selected = rows.take(2).map(CartItem.fromApiResponseMap).toList();
      final requests = <RequestOptions>[];
      var deleted = false;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            void reject(int status) => handler.reject(
              DioException.badResponse(
                statusCode: status,
                requestOptions: options,
                response: Response(requestOptions: options, statusCode: status),
              ),
            );
            Object data;
            if (options.path == 'api/cart/list') {
              if (deleted && scenario == 'refresh failed') {
                reject(500);
                return;
              }
              data = List<Map<String, dynamic>>.of(rows);
            } else if (options.path == '/api/cart/item') {
              expect(options.method, 'POST');
              expect(options.data, {
                'productId': 'stale-product',
                'productVariantId': 'stale',
                'quantity': 0,
              });
              if (scenario == 'delete failed') {
                reject(400);
                return;
              }
              if (scenario != 'delete acknowledged but row remains') {
                rows.removeWhere((row) => row['id'] == 'stale');
              }
              deleted = true;
              if (scenario == 'legacy removal 404') {
                reject(404);
                return;
              }
              data = {};
            } else if (options.path == '/api/product/active-product') {
              if (scenario == 'already removed') {
                // Lifecycle cleanup wins the race before our removal request.
                rows.removeWhere((row) => row['id'] == 'stale');
              }
              data = {
                'status': 'active',
                'variants': [
                  {'id': 'valid', 'status': 'active'},
                ],
              };
            } else {
              expect(options.path, '/api/product/stale-product');
              if (scenario == 'missing product') {
                reject(404);
                return;
              }
              data = {
                'status': scenario == 'inactive product'
                    ? 'inactive'
                    : 'active',
                if (scenario == 'deleted product')
                  'deletedAt': '2026-09-17T00:00:00Z',
                'variants': [
                  if (scenario != 'missing variant')
                    {'id': 'stale', 'status': 'inactive'},
                ],
              };
            }
            handler.resolve(
              Response(
                requestOptions: options,
                data: {'success': true, 'data': data},
              ),
            );
          },
        ),
      );
      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      addTearDown(container.dispose);
      addTearDown(() => dio.close());

      final result = await container
          .read(cartProvider.notifier)
          .validateCheckoutItems(selected);

      // Checkout must stop even after successful cleanup.
      expect(result.isFailure, isTrue);
      expect(requests.map((r) => r.path), [
        'api/cart/list',
        '/api/product/stale-product',
        '/api/product/active-product',
        '/api/cart/item',
        'api/cart/list',
      ]);
      final state = container.read(cartProvider);
      if (scenario == 'refresh failed') {
        expect(state.hasError, isTrue);
        expect(result.error, contains('無法確認購物車更新結果'));
      } else if (scenario == 'delete failed' ||
          scenario == 'delete acknowledged but row remains') {
        expect(state.data!.map((item) => item.id), [
          'stale',
          'valid',
          'unchecked',
        ]);
        expect(result.error, contains('尚未移除'));
        expect(result.error, isNot(contains('已從購物車移除')));
      } else {
        expect(state.data!.map((item) => item.id), ['valid', 'unchecked']);
        expect(result.error, contains('已從購物車移除'));
      }
    });
  }

  test(
    'Cleanup continues after one removal fails and refreshes once at the end',
    () async {
      final rows = [row('first'), row('second')];
      final selected = rows.map(CartItem.fromApiResponseMap).toList();
      final requests = <RequestOptions>[];
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            Object data;
            if (options.path == 'api/cart/list') {
              data = List<Map<String, dynamic>>.of(rows);
            } else if (options.path == '/api/cart/item') {
              if (options.data['productVariantId'] == 'first') {
                handler.reject(DioException(requestOptions: options));
                return;
              }
              rows.removeWhere((row) => row['id'] == 'second');
              data = {};
            } else {
              data = {'status': 'inactive'};
            }
            handler.resolve(
              Response(
                requestOptions: options,
                data: {'success': true, 'data': data},
              ),
            );
          },
        ),
      );
      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      addTearDown(container.dispose);
      addTearDown(() => dio.close());
      final result = await container
          .read(cartProvider.notifier)
          .validateCheckoutItems(selected);
      expect(result.error, contains('尚未移除'));
      expect(container.read(cartProvider).data!.single.id, 'first');
      expect(requests.map((r) => r.path), [
        'api/cart/list',
        '/api/product/stale-product',
        '/api/cart/item',
        '/api/cart/item',
        'api/cart/list',
      ]);
    },
  );
}
