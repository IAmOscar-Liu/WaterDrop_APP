import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/models/product.dart';
import 'package:flutter_ad_ecommerce/pages/single_product_details.dart';
import 'package:flutter_ad_ecommerce/provider/collection_provider.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/selection_option_tile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _CollectionApi {
  _CollectionApi({this.saved = false, this.status = 'active'});

  bool saved;
  final String? status;
  String? deletedAt;
  bool hideSavedProduct = false;
  bool rejectCartAddition = false;
  bool failLookup = false;
  bool failMutation = false;
  bool collectionMissing = false;
  bool secondPage = false;
  List<Map<String, dynamic>> variants = [];
  final requests = <RequestOptions>[];
  Object? navigationResult;

  Map<String, dynamic> get product => {
    'id': 'product',
    'name': 'Test product',
    'price': 100,
    'variants': variants,
    'deletedAt': deletedAt,
    if (status != null) 'status': status,
  };

  Dio createDio() {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          Object response;
          if (options.path == '/api/product/product') {
            response = {'success': true, 'data': product};
          } else if (options.path == '/api/collection/list') {
            final page = options.queryParameters['page'];
            response = {
              'success': !failLookup,
              'data': {
                'collections': [
                  if (secondPage && page == 1)
                    {'productId': 'different-product'},
                  if (saved && !hideSavedProduct && (!secondPage || page == 2))
                    {'productId': 'product'},
                ],
                'totalPages': secondPage ? 2 : 1,
              },
            };
          } else if (options.path == 'api/cart/list') {
            response = {'success': true, 'data': []};
          } else if (options.path == '/api/cart/item' && rejectCartAddition) {
            handler.reject(
              DioException.badResponse(
                statusCode: 400,
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 400,
                  data: {'message': 'Product variant is inactive'},
                ),
              ),
            );
            return;
          } else if (options.path == '/api/collection') {
            if (options.method == 'DELETE' && collectionMissing) {
              saved = false;
              handler.reject(
                DioException.badResponse(
                  statusCode: 404,
                  requestOptions: options,
                  response: Response(
                    requestOptions: options,
                    statusCode: 404,
                    data: {
                      'success': false,
                      'statusCode': 404,
                      'message': 'Collection not found',
                    },
                  ),
                ),
              );
              return;
            }
            if (!failMutation) saved = options.method == 'POST';
            response = {'success': !failMutation};
          } else {
            throw StateError('Unexpected request: ${options.path}');
          }
          handler.resolve(
            Response(requestOptions: options, statusCode: 200, data: response),
          );
        },
      ),
    );
    return dio;
  }
}

Future<void> _openProduct(
  WidgetTester tester,
  _CollectionApi api, {
  String source = 'cart',
  bool hideCollection = false,
}) async {
  final dio = api.createDio();
  addTearDown(() => dio.close());
  final extra = <String, dynamic>{
    if (source == 'order')
      'productId': 'product'
    else
      'product': Product.fromApiResponseMap(api.product),
    if (source == 'collection')
      'removeFromCollection': true
    else
      'hideAddCartItemButton': true,
    if (hideCollection) 'hideAddCollectionButton': true,
  };
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: TextButton(
            onPressed: () async {
              api.navigationResult = await context.push(
                '/details',
                extra: extra,
              );
            },
            child: const Text('Open product'),
          ),
        ),
      ),
      GoRoute(
        path: '/details',
        builder: (context, state) => SingleProductDetails(extra: state.extra),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dioProvider.overrideWithValue(dio)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.tap(find.text('Open product'));
  await tester.pumpAndSettle();
}

Future<void> _tapAction(WidgetTester tester, String label) async {
  final action = find.widgetWithText(ElevatedButton, label);
  await tester.ensureVisible(action);
  await tester.pumpAndSettle();
  await tester.tap(action);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Soft-deleted active product is read-only and cannot be purchased',
    (tester) async {
      final api = _CollectionApi(saved: true)
        ..deletedAt = '2026-09-17T00:00:00Z'
        ..variants = [
          {
            'id': 'variant',
            'name': 'Small',
            'status': 'active',
            'availableStock': 10,
          },
        ];
      await _openProduct(tester, api, source: 'collection');
      expect(find.text('加入購物車'), findsNothing);
      expect(find.text('選擇規格'), findsNothing);
      expect(find.text('商品規格'), findsOneWidget);
      final product = Product.fromApiResponseMap(api.product);
      expect(product.copyWith(name: 'Renamed').isPurchasable, isFalse);
      expect(product.toMap()['deletedAt'], isNotNull);
    },
  );

  testWidgets(
    'Hidden inactive collection stays saved without an automatic DELETE',
    (tester) async {
      final api = _CollectionApi(saved: true, status: 'inactive')
        ..hideSavedProduct = true;
      await _openProduct(tester, api);
      expect(find.text('加入收藏'), findsNothing);
      expect(api.saved, isTrue);
      expect(api.requests.where((r) => r.method == 'DELETE'), isEmpty);
    },
  );

  testWidgets(
    'Unavailable cart addition refreshes product and requires choosing a remaining variant',
    (tester) async {
      final api = _CollectionApi(saved: true)
        ..rejectCartAddition = true
        ..variants = [
          {
            'id': 'old',
            'name': 'Small',
            'status': 'active',
            'availableStock': 10,
          },
        ];
      await _openProduct(tester, api, source: 'collection');
      api.variants = [
        {'id': 'new', 'name': 'Large', 'status': 'active', 'availableStock': 5},
      ];
      await _tapAction(tester, '加入購物車');
      expect(find.text('選擇規格'), findsOneWidget);
      final option = tester.widget<SelectionOptionTile>(
        find.byType(SelectionOptionTile),
      );
      expect(option.isSelected, isFalse);
      expect(
        api.requests.where((r) => r.path == '/api/product/product').length,
        1,
      );
      expect(api.requests.where((r) => r.path == 'api/cart/list').length, 1);
      expect(
        api.requests
            .where((r) => r.path == '/api/cart/item')
            .single
            .data['productVariantId'],
        'old',
      );
    },
  );

  for (final source in ['cart', 'order', 'collection']) {
    for (final status in ['active', 'inactive', null]) {
      testWidgets('Saved $status product can be removed from $source', (
        tester,
      ) async {
        final api = _CollectionApi(saved: true, status: status);
        await _openProduct(tester, api, source: source);
        expect(find.text('移除收藏'), findsOneWidget);
        expect(find.text('加入收藏'), findsNothing);
        if (status != 'active') {
          expect(find.text('加入購物車'), findsNothing);
        }
        expect(
          api.requests.where((r) => r.path == '/api/product/product').length,
          source == 'order' ? 1 : 0,
        );
        if (source == 'collection') {
          expect(api.requests, isEmpty);
        }
        await _tapAction(tester, '移除收藏');
        expect(api.saved, isFalse);
        if (source == 'collection') {
          expect(find.text('Open product'), findsOneWidget);
          expect(api.navigationResult, {'reload': true});
        } else {
          expect(find.byType(SingleProductDetails), findsOneWidget);
          expect(
            find.text('加入收藏'),
            status == 'active' ? findsOneWidget : findsNothing,
          );
        }
      });
    }
  }

  testWidgets('Add switches to remove; a failed mutation keeps the action', (
    tester,
  ) async {
    final api = _CollectionApi()..failMutation = true;
    await _openProduct(tester, api);
    await _tapAction(tester, '加入收藏');
    expect(api.saved, isFalse);
    expect(find.text('加入收藏'), findsOneWidget);
    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor,
      Colors.red,
    );
    api.failMutation = false;
    await _tapAction(tester, '加入收藏');
    expect(api.saved, isTrue);
    expect(find.text('移除收藏'), findsOneWidget);
    await _tapAction(tester, '移除收藏');
    expect(api.saved, isFalse);
    expect(find.text('加入收藏'), findsOneWidget);
  });

  for (final source in ['cart', 'collection']) {
    testWidgets(
      'Already removed collection clears the saved action from $source',
      (tester) async {
        final api = _CollectionApi(saved: true, status: 'inactive')
          ..collectionMissing = true;
        await _openProduct(tester, api, source: source);
        await _tapAction(tester, '移除收藏');
        expect(api.saved, isFalse);
        expect(api.requests.where((r) => r.method == 'DELETE').single.data, {
          'productId': 'product',
        });
        expect(api.requests.last.path, '/api/collection/list');
        if (source == 'collection') {
          expect(find.text('Open product'), findsOneWidget);
          expect(api.navigationResult, {'reload': true});
        } else {
          expect(find.byType(SingleProductDetails), findsOneWidget);
          expect(find.text('移除收藏'), findsNothing);
          expect(find.text('加入收藏'), findsNothing);
        }
      },
    );
  }

  testWidgets('Failed removal from collections stays open and can retry', (
    tester,
  ) async {
    final api = _CollectionApi(saved: true, status: 'inactive')
      ..failMutation = true;
    await _openProduct(tester, api, source: 'collection');
    await _tapAction(tester, '移除收藏');
    expect(api.saved, isTrue);
    expect(find.text('移除收藏'), findsOneWidget);
    expect(api.navigationResult, isNull);
    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).backgroundColor,
      Colors.red,
    );
    api.failMutation = false;
    await _tapAction(tester, '移除收藏');
    expect(api.navigationResult, {'reload': true});
  });

  testWidgets(
    'Membership lookup checks later pages without changing the list',
    (tester) async {
      final api = _CollectionApi(saved: true)..secondPage = true;
      await _openProduct(tester, api);
      expect(find.text('移除收藏'), findsOneWidget);
      final requests = api.requests.where(
        (r) => r.path == '/api/collection/list',
      );
      expect(requests.map((r) => r.queryParameters['page']), [1, 2]);
      expect(
        requests.every((r) => !r.queryParameters.containsKey('search')),
        isTrue,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SingleProductDetails)),
      );
      expect(container.read(collectionNotifierProvider).isInitial, isTrue);
    },
  );

  testWidgets('Failed membership lookup offers retry rather than guessing', (
    tester,
  ) async {
    final api = _CollectionApi(saved: true)..failLookup = true;
    await _openProduct(tester, api);
    expect(find.text('加入收藏'), findsNothing);
    expect(find.text('移除收藏'), findsNothing);
    api.failLookup = false;
    await _tapAction(tester, '重試讀取收藏狀態');
    expect(find.text('移除收藏'), findsOneWidget);
  });

  testWidgets('Inactive unsaved product cannot be added to collections', (
    tester,
  ) async {
    await _openProduct(tester, _CollectionApi(status: 'inactive'));
    expect(find.text('加入收藏'), findsNothing);
    expect(find.text('移除收藏'), findsNothing);
    expect(find.text('加入購物車'), findsNothing);
  });

  testWidgets('Explicit hide flag still suppresses the collection action', (
    tester,
  ) async {
    final api = _CollectionApi(saved: true);
    await _openProduct(tester, api, hideCollection: true);
    expect(find.text('加入收藏'), findsNothing);
    expect(find.text('移除收藏'), findsNothing);
    expect(api.requests, isEmpty);
  });

  testWidgets('Inactive product variants are displayed without selection', (
    tester,
  ) async {
    final api = _CollectionApi(saved: true, status: 'inactive')
      ..variants = [
        {'id': 'a', 'name': 'Small', 'status': 'active', 'availableStock': 10},
        {'id': 'b', 'name': 'Large', 'status': 'inactive', 'availableStock': 0},
      ];
    await _openProduct(tester, api, source: 'collection');
    expect(find.text('選擇規格'), findsNothing);
    expect(find.byType(SelectionOptionTile), findsNothing);
    expect(find.text('商品規格'), findsOneWidget);
    expect(find.text('Small'), findsOneWidget);
    expect(find.text('Large'), findsOneWidget);
    expect(find.text('加入購物車'), findsNothing);
  });
}
