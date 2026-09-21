import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/models/product.dart';
import 'package:flutter_ad_ecommerce/provider/cart_provider.dart';
import 'package:flutter_ad_ecommerce/provider/collection_provider.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/provider/product_provider.dart';
import 'package:flutter_ad_ecommerce/utils/product_availability.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> cartRow({int quantity = 1}) => {
  'id': 'cart-item',
  'productId': 'product',
  'productVariantId': 'variant',
  'quantity': quantity,
  'checked': true,
  'product': {'id': 'product', 'name': '商品', 'status': 'active'},
};

ProviderContainer setup(
  void Function(RequestOptions, RequestInterceptorHandler) onRequest,
) {
  final dio = Dio()
    ..interceptors.add(InterceptorsWrapper(onRequest: onRequest));
  final container = ProviderContainer(
    overrides: [dioProvider.overrideWithValue(dio)],
  );
  addTearDown(container.dispose);
  addTearDown(() => dio.close());
  return container;
}

void main() {
  for (final scenario in [
    'already removed',
    'refresh failed',
    'unrelated 404',
  ]) {
    test(
      'Collection removal handles $scenario without retaining stale membership',
      () async {
        var removalRequested = false;
        final requests = <RequestOptions>[];
        final container = setup((options, handler) {
          requests.add(options);
          if (options.method == 'DELETE') {
            removalRequested = true;
            handler.reject(
              DioException.badResponse(
                statusCode: 404,
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 404,
                  data: {
                    'message': scenario == 'unrelated 404'
                        ? 'Route not found'
                        : 'Collection not found',
                  },
                ),
              ),
            );
          } else if (removalRequested && scenario == 'refresh failed') {
            handler.reject(DioException(requestOptions: options));
          } else {
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'success': true,
                  'data': {
                    'collections': [
                      if (!removalRequested)
                        {
                          'id': 'saved',
                          'productId': 'product',
                          'product': {'id': 'product', 'status': 'active'},
                        },
                    ],
                    'total': removalRequested ? 0 : 1,
                    'totalPages': 1,
                  },
                },
              ),
            );
          }
        });
        final subscription = container.listen(
          collectionNotifierProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        final notifier = container.read(collectionNotifierProvider.notifier);
        await notifier.loadCollections(search: 'query');
        final result = await notifier.removeCollection('product');
        final state = container.read(collectionNotifierProvider);
        if (scenario == 'unrelated 404') {
          expect(result.isFailure, isTrue);
          expect(state.data!.collections.single.productId, 'product');
          expect(requests.map((r) => r.method), ['GET', 'DELETE']);
        } else {
          expect(result.isSuccess, isTrue);
          expect(requests.map((r) => r.method), ['GET', 'DELETE', 'GET']);
          expect(requests.last.queryParameters['search'], 'query');
          if (scenario == 'refresh failed') {
            expect(state.hasError, isTrue);
          } else {
            expect(state.data!.collections, isEmpty);
            expect(state.data!.total, 0);
          }
        }
      },
    );
  }

  test(
    'Product list filters active products on initial load and pagination',
    () async {
      final queries = <Map<String, dynamic>>[];
      final container = setup((options, handler) {
        queries.add(options.queryParameters);
        handler.resolve(
          Response(
            requestOptions: options,
            data: {
              'success': true,
              'data': {'products': [], 'totalPages': 2},
            },
          ),
        );
      });
      final sub = container.listen(productNotifierProvider, (_, _) {});
      addTearDown(sub.close);
      final notifier = container.read(productNotifierProvider.notifier);
      await notifier.loadProducts(search: 'query');
      await notifier.fetchMoreProducts();
      expect(queries.map((q) => q['status']), ['active', 'active']);
      expect(queries.map((q) => q['page']), [1, 2]);
      expect(queries.map((q) => q['search']), ['query', 'query']);
    },
  );

  for (final changed in [false, true]) {
    test(
      'Checkout stops and replaces cached cart after ${changed ? 'quantity change' : 'server removal'}',
      () async {
        var refresh = false;
        final requests = <String>[];
        final container = setup((options, handler) {
          requests.add(options.path);
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'success': true,
                'data': !refresh
                    ? [cartRow()]
                    : changed
                    ? [cartRow(quantity: 2)]
                    : [],
              },
            ),
          );
        });
        final notifier = container.read(cartProvider.notifier);
        await notifier.loadCartItems();
        final selected = container.read(cartProvider).data!;
        refresh = true;
        final result = await notifier.validateCheckoutItems(selected);
        expect(result.isFailure, isTrue);
        final latest = container.read(cartProvider).data!;
        expect(
          changed ? latest.single.quantity : latest.length,
          changed ? 2 : 0,
        );
        expect(requests, ['api/cart/list', 'api/cart/list']);
      },
    );
  }

  test('Cart refresh failure blocks checkout', () async {
    final container = setup((options, handler) {
      handler.reject(DioException(requestOptions: options));
    });
    final result = await container
        .read(cartProvider.notifier)
        .validateCheckoutItems([CartItem.fromApiResponseMap(cartRow())]);
    expect(result.error, '無法確認購物車狀態，請稍後再試');
  });

  test('Active but soft-deleted product blocks checkout', () async {
    final container = setup((options, handler) {
      handler.resolve(
        Response(
          requestOptions: options,
          data: {
            'success': true,
            'data': options.path == 'api/cart/list'
                ? [cartRow()]
                : {
                    'status': 'active',
                    'deletedAt': '2026-09-17T00:00:00Z',
                    'variants': [
                      {'id': 'variant', 'status': 'active'},
                    ],
                  },
          },
        ),
      );
    });
    final result = await container
        .read(cartProvider.notifier)
        .validateCheckoutItems([CartItem.fromApiResponseMap(cartRow())]);
    expect(result.error, contains('已下架'));
  });

  for (final operation in ['add', 'quantity', 'variant']) {
    for (final status in [400, 404]) {
      test(
        '$operation availability $status refreshes and replaces the cart before returning',
        () async {
          var rejected = false;
          final requests = <String>[];
          final container = setup((options, handler) {
            requests.add(options.path);
            if (options.method == 'GET') {
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'success': true,
                    'data': rejected ? [] : [cartRow()],
                  },
                ),
              );
            } else {
              rejected = true;
              handler.reject(
                DioException.badResponse(
                  statusCode: status,
                  requestOptions: options,
                  response: Response(
                    requestOptions: options,
                    statusCode: status,
                    data: {
                      'message': status == 400
                          ? 'Product variant is inactive'
                          : operation == 'variant'
                          ? 'Cart item not found'
                          : 'Product not found',
                    },
                  ),
                ),
              );
            }
          });
          final cart = container.read(cartProvider.notifier);
          await cart.loadCartItems();
          final item = container.read(cartProvider).data!.single;
          final result = switch (operation) {
            'add' => await cart.addCartItem(
              'product',
              productVariantId: 'variant',
            ),
            'quantity' => await cart.updateItemQuantity(
              'product',
              productVariantId: 'variant',
              quantity: 2,
            ),
            _ => await cart.updateItemVariant(item, productVariantId: 'other'),
          };
          expect(result.error, productUnavailableMessage);
          expect(container.read(cartProvider).data, isEmpty);
          expect(requests.last, 'api/cart/list');
          expect(requests.length, 3);
        },
      );
    }
  }

  test(
    'Unavailable collection addition refreshes the visible list without deleting saved records',
    () async {
      final methods = <String>[];
      final container = setup((options, handler) {
        methods.add(options.method);
        if (options.method == 'POST') {
          handler.reject(
            DioException.badResponse(
              statusCode: 400,
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: 400,
                data: {'message': 'Product is unavailable'},
              ),
            ),
          );
        } else {
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'success': true,
                'data': {'collections': [], 'total': 0, 'totalPages': 1},
              },
            ),
          );
        }
      });
      final sub = container.listen(collectionNotifierProvider, (_, _) {});
      addTearDown(sub.close);
      final result = await container
          .read(collectionNotifierProvider.notifier)
          .addCollection('product');
      expect(result.error, productUnavailableMessage);
      expect(
        container.read(collectionNotifierProvider).data!.collections,
        isEmpty,
      );
      expect(methods, ['POST', 'GET']);
    },
  );
}
