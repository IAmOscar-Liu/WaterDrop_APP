import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/models/account_info.dart';
import 'package:flutter_ad_ecommerce/features/cart/widgets/cart_item_card.dart';
import 'package:flutter_ad_ecommerce/models/api_enums.dart';
import 'package:flutter_ad_ecommerce/models/order.dart';
import 'package:flutter_ad_ecommerce/models/product.dart';
import 'package:flutter_ad_ecommerce/pages/cart_page.dart';
import 'package:flutter_ad_ecommerce/provider/account_provider.dart';
import 'package:flutter_ad_ecommerce/provider/cart_provider.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/provider/message_stats_provider.dart';
import 'package:flutter_ad_ecommerce/provider/product_provider.dart';
import 'package:flutter_ad_ecommerce/provider/system_provider.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:flutter_ad_ecommerce/utils/custom_async_value.dart';
import 'package:flutter_ad_ecommerce/utils/events.dart';
import 'package:flutter_ad_ecommerce/utils/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestAccount extends AccountNotifier {
  _TestAccount(this.coins);

  final double coins;

  @override
  AccountInfo build() => AccountInfo.zero().copyWith(
    coins: coins,
    name: 'Test recipient',
    phone: '0912345678',
    email: 'test@example.com',
  );

  void setCoins(double coins) => state = state.copyWith(coins: coins);

  @override
  Future<Result> refreshAccountInfo() async => Result.success();
}

class _TestCart extends Cart {
  _TestCart({this.initiallyLoading = false});

  final bool initiallyLoading;
  bool clearOnReload = false;

  @override
  CustomAsyncValue<List<CartItem>> build() => initiallyLoading
      ? CustomAsyncValue.loading()
      : CustomAsyncValue.done(_items());

  void setItems({double price = 1000}) =>
      state = CustomAsyncValue.done(_items(price: price));

  void addUncheckedItem() {
    state = CustomAsyncValue.done([
      ...state.data!,
      state.data!.first.copyWith(
        id: 'unchecked',
        productId: 'unchecked',
        checked: false,
      ),
    ]);
  }

  @override
  Future<void> loadCartItems({bool? keepPreviousData = false}) async {
    if (clearOnReload) {
      state = CustomAsyncValue.done([]);
    } else if (state.data != null) {
      state = CustomAsyncValue.done(state.data!);
    }
  }

  List<CartItem> _items({double price = 1000}) => [
    CartItem.fromApiResponseMap({
      'id': 'item',
      'productId': 'product',
      'productVariantId': 'variant',
      'checked': true,
      'quantity': 1,
      'product': {
        'id': 'product',
        'name': 'Test product',
        'price': price,
        'stock': 10,
        'status': 'active',
      },
    }),
  ];
}

class _ApiCart extends Cart {
  @override
  CustomAsyncValue<List<CartItem>> build() =>
      CustomAsyncValue.done(_TestCart()._items());
}

class _TestMessageStats extends MessageStatsNotifier {
  @override
  Future<void> loadMessageStats() async {}
}

class _TestProducts extends ProductNotifier {
  @override
  Future<void> refreshProducts() async {}
}

Future<ProviderContainer> _showCart(
  WidgetTester tester,
  double coins, {
  bool initiallyLoading = false,
  bool useCartApi = false,
  GoRouter? router,
  void Function(RequestOptions, RequestInterceptorHandler)? onRequest,
}) async {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest:
          onRequest ??
          (options, handler) => handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'success': true,
                'data': options.path == '/api/product/product'
                    ? {
                        'id': 'product',
                        'status': 'active',
                        'variants': [
                          {'id': 'variant', 'status': 'active'},
                        ],
                      }
                    : <String, dynamic>{},
              },
            ),
          ),
    ),
  );
  addTearDown(() => dio.close());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountNotifierProvider.overrideWith(() => _TestAccount(coins)),
        cartProvider.overrideWith(
          () => useCartApi
              ? _ApiCart()
              : _TestCart(initiallyLoading: initiallyLoading),
        ),
        dioProvider.overrideWithValue(dio),
        messageStatsNotifierProvider.overrideWith(_TestMessageStats.new),
        productNotifierProvider.overrideWith(_TestProducts.new),
      ],
      child: router == null
          ? const MaterialApp(home: CartPage())
          : MaterialApp.router(routerConfig: router),
    ),
  );
  if (initiallyLoading) {
    await tester.pump();
  } else {
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextField));
    await tester.pumpAndSettle();
  }
  return ProviderScope.containerOf(tester.element(find.byType(CartPage)));
}

Future<void> _useMaximum(WidgetTester tester) async {
  final button = find.text('使用最高可折抵金幣');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  for (final entry in <double, String>{
    125.75: '120',
    9.99: '0',
    1250: '1250',
    2500.75: '2000',
  }.entries) {
    testWidgets('Suggested discount for ${entry.key} coins is ${entry.value}', (
      tester,
    ) async {
      await _showCart(tester, entry.key);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, entry.value);
      expect(field.decoration!.errorText, isNull);
    });
  }

  testWidgets('Discount must be a multiple of ten and stay within limits', (
    tester,
  ) async {
    await _showCart(tester, 125.75);
    final field = find.byType(TextField);

    Future<String?> enter(String value) async {
      await tester.enterText(field, value);
      await tester.pump();
      return tester.widget<TextField>(field).decoration!.errorText;
    }

    final checkout = find.widgetWithText(ElevatedButton, '確認結帳');
    expect(await enter('125'), '折抵金幣必須為 10 的倍數');
    expect(tester.widget<ElevatedButton>(checkout).onPressed, isNull);
    expect(await enter('120'), isNull);
    expect(tester.widget<ElevatedButton>(checkout).onPressed, isNotNull);
    expect(await enter('130'), contains('不能超過您擁有的金幣'));
    expect(await enter('0'), isNull);
    expect(await enter(''), isNull);

    // Reject a decimal paste as a whole, without converting it to other digits.
    await enter('120');
    await enter('12.5');
    expect(tester.widget<TextField>(field).controller!.text, '120');
  });

  testWidgets('A multiple of ten still respects the order discount cap', (
    tester,
  ) async {
    await _showCart(tester, 5000);
    await tester.enterText(find.byType(TextField), '2010');
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration!.errorText,
      contains('不能超過最多可折抵數量'),
    );
  });

  for (final condition in [
    'inactive product',
    'inactive variant',
    'missing variant',
    'network failure',
  ]) {
    testWidgets('Checkout stops in cart for $condition', (tester) async {
      final requests = <String>[];
      await _showCart(
        tester,
        125.75,
        onRequest: (options, handler) {
          requests.add(options.path);
          if (condition == 'network failure') {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
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
                  'status': condition == 'inactive product'
                      ? 'inactive'
                      : 'active',
                  'variants': [
                    if (condition != 'missing variant')
                      {
                        'id': 'variant',
                        'status': condition == 'inactive variant'
                            ? 'inactive'
                            : 'active',
                      },
                  ],
                },
              },
            ),
          );
        },
      );
      final checkout = find.widgetWithText(ElevatedButton, '確認結帳');
      await tester.ensureVisible(checkout);
      await tester.pumpAndSettle();
      await tester.tap(checkout);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('無法結帳'), findsOneWidget);
      expect(
        find.textContaining(
          condition == 'network failure' ? '無法確認商品狀態' : '已下架',
        ),
        findsOneWidget,
      );
      expect(requests, [
        '/api/product/product',
        if (condition != 'network failure') '/api/cart/item',
      ]);
      expect(find.byType(CartPage), findsOneWidget);
      await tester.tap(find.text('確定'));
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(checkout).onPressed, isNotNull);
    });
  }

  testWidgets(
    'Unavailable item disappears from the cart after deletion and refresh',
    (tester) async {
      var removed = false;
      final requests = <String>[];
      final container = await _showCart(
        tester,
        125.75,
        useCartApi: true,
        onRequest: (options, handler) {
          requests.add(options.path);
          Object data;
          if (options.path == 'api/cart/list') {
            data = removed
                ? []
                : [
                    {
                      'id': 'item',
                      'productId': 'product',
                      'productVariantId': 'variant',
                      'checked': true,
                      'quantity': 1,
                      'product': {
                        'id': 'product',
                        'name': 'Test product',
                        'price': 1000,
                        'status': 'active',
                      },
                    },
                  ];
          } else if (options.path == '/api/cart/item') {
            expect(options.data, {
              'productId': 'product',
              'productVariantId': 'variant',
              'quantity': 0,
            });
            removed = true;
            data = {};
          } else {
            expect(options.path, '/api/product/product');
            data = {'id': 'product', 'status': 'inactive'};
          }
          handler.resolve(
            Response(
              requestOptions: options,
              data: {'success': true, 'data': data},
            ),
          );
        },
      );
      expect(find.byType(CartItemCard), findsOneWidget);
      final checkout = find.widgetWithText(ElevatedButton, '確認結帳');
      await tester.ensureVisible(checkout);
      await tester.tap(checkout);
      await tester.pumpAndSettle();
      expect(find.text('無法結帳'), findsOneWidget);
      expect(find.textContaining('已從購物車移除'), findsOneWidget);
      expect(find.byType(CartItemCard), findsNothing);
      expect(container.read(cartProvider).data, isEmpty);
      expect(requests, [
        'api/cart/list',
        '/api/product/product',
        '/api/cart/item',
        'api/cart/list',
      ]);
      await tester.tap(find.text('確定'));
      await tester.pumpAndSettle();
      expect(find.byType(CartPage), findsOneWidget);
      expect(find.byType(CartItemCard), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('First suggestion waits for the cart to load', (tester) async {
    final container = await _showCart(tester, 125.75, initiallyLoading: true);
    expect(find.byType(TextField), findsNothing);
    (container.read(cartProvider.notifier) as _TestCart).setItems();
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '120',
    );
  });

  testWidgets(
    'Returning to cart preserves entered, zero, and empty discounts',
    (tester) async {
      await _showCart(tester, 125.75);
      final field = find.byType(TextField);
      for (final value in ['50', '0', '', '125']) {
        await tester.enterText(field, value);
        await tester.pump();
        eventBus.fire(
          RouterChangeEvent(from: Routes.cartPage, to: Routes.productPage),
        );
        eventBus.fire(
          RouterChangeEvent(from: Routes.productPage, to: Routes.cartPage),
        );
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(field).controller!.text, value);
      }
    },
  );

  testWidgets('Balance changes preserve input until maximum is requested', (
    tester,
  ) async {
    final container = await _showCart(tester, 125.75);
    final field = find.byType(TextField);
    await tester.enterText(field, '100');
    (container.read(accountNotifierProvider.notifier) as _TestAccount).setCoins(
      85.75,
    );
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller!.text, '100');
    expect(
      tester.widget<TextField>(field).decoration!.errorText,
      contains('不能超過您擁有的金幣'),
    );
    await _useMaximum(tester);
    expect(tester.widget<TextField>(field).controller!.text, '80');
    expect(tester.widget<TextField>(field).decoration!.errorText, isNull);
    (container.read(accountNotifierProvider.notifier) as _TestAccount).setCoins(
      500,
    );
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller!.text, '80');
  });

  testWidgets('Cart changes preserve input and maximum uses the new cap', (
    tester,
  ) async {
    final container = await _showCart(tester, 5000);
    final field = find.byType(TextField);
    await tester.enterText(field, '1000');
    (container.read(cartProvider.notifier) as _TestCart).setItems(price: 200);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field).controller!.text, '1000');
    expect(
      tester.widget<TextField>(field).decoration!.errorText,
      contains('不能超過最多可折抵數量'),
    );
    await _useMaximum(tester);
    expect(tester.widget<TextField>(field).controller!.text, '400');
    expect(tester.widget<TextField>(field).decoration!.errorText, isNull);
  });

  for (final status in [
    null,
    OrderStatus.paid,
    OrderStatus.paymentProcessing,
  ]) {
    testWidgets('Checkout return handles discount for status $status', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      late ProviderContainer container;
      final router = GoRouter(
        initialLocation: Routes.cartPage,
        routes: [
          GoRoute(
            path: Routes.cartPage,
            builder: (context, state) => const CartPage(),
          ),
          GoRoute(
            path: Routes.paymentSettingsPage,
            builder: (context, state) => Scaffold(
              body: TextButton(
                onPressed: () {
                  if (status != null) {
                    container
                        .read(systemNotifierProvider.notifier)
                        .setCurrentOrder(
                          Order.fromApiResponseMap({
                            'id': 'completed-order',
                            'orderStatus': status.wireValue,
                          }),
                        );
                    (container.read(cartProvider.notifier) as _TestCart)
                            .clearOnReload =
                        true;
                    (container.read(accountNotifierProvider.notifier)
                            as _TestAccount)
                        .setCoins(35.75);
                  }
                  context.pop();
                },
                child: const Text('Return from payment'),
              ),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      container = await _showCart(tester, 125.75, router: router);
      // Unchecked items must not be validated or block this checkout.
      (container.read(cartProvider.notifier) as _TestCart).addUncheckedItem();
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '50');
      tester.testTextInput.hide();
      final checkout = find.widgetWithText(ElevatedButton, '確認結帳');
      await tester.ensureVisible(checkout);
      await tester.pumpAndSettle();
      await tester.tap(checkout);
      await tester.pumpAndSettle();
      expect(find.text('Return from payment'), findsOneWidget);
      await tester.tap(find.text('Return from payment'));
      await tester.pumpAndSettle();
      if (status != null) {
        await tester.tap(find.text('確定'));
        await tester.pumpAndSettle();
        expect(find.text('購物車是空的'), findsOneWidget);
        (container.read(cartProvider.notifier) as _TestCart).setItems();
        await tester.pumpAndSettle();
      }
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        status == null ? '50' : '30',
      );
      expect(tester.takeException(), isNull);
    });
  }
}
