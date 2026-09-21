import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/models/product.dart';
import 'package:flutter_ad_ecommerce/provider/cart_provider.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final inactiveSecondVariant in [false, true]) {
    test(
      'Fresh status of each selected variant is checked with one product fetch ($inactiveSecondVariant)',
      () async {
        final requests = <String>[];
        final dio = Dio();
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options.path);
              if (options.path == 'api/cart/list') {
                handler.resolve(
                  Response(
                    requestOptions: options,
                    data: {
                      'success': true,
                      'data': ['first', 'second']
                          .map(
                            (id) => {
                              'id': id,
                              'productId': 'product',
                              'productVariantId': id,
                              'checked': true,
                              'product': {'id': 'product', 'status': 'active'},
                            },
                          )
                          .toList(),
                    },
                  ),
                );
                return;
              }
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'success': true,
                    'data': {
                      'id': 'product',
                      'status': 'active',
                      'variants': [
                        {
                          'id': 'first',
                          'status': 'active',
                          'availableStock': 0,
                        },
                        {
                          'id': 'second',
                          'status': inactiveSecondVariant
                              ? 'inactive'
                              : 'active',
                        },
                      ],
                    },
                  },
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
        final items = ['first', 'second']
            .map(
              (id) => CartItem.fromApiResponseMap({
                'id': id,
                'productId': 'product',
                'productVariantId': id,
                'checked': true,
                'product': {
                  'id': 'product',
                  'name': 'Test product',
                  'status': 'active',
                },
              }),
            )
            .toList();
        final result = await container
            .read(cartProvider.notifier)
            .validateCheckoutItems(items);
        expect(result.isFailure, inactiveSecondVariant);
        expect(requests, [
          'api/cart/list',
          '/api/product/product',
          if (inactiveSecondVariant) ...['/api/cart/item', 'api/cart/list'],
        ]);
      },
    );
  }
}
