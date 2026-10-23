import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/models/account_info.dart';
import 'package:flutter_ad_ecommerce/models/product.dart';
import 'package:flutter_ad_ecommerce/provider/account_provider.dart';
import 'package:flutter_ad_ecommerce/provider/cart_provider.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/checkout_fixture.dart';
import 'cart_concurrency_test.dart' show Harness;

Map<String, dynamic> row({
  String id = 'cart',
  double price = 99.125,
  bool checked = true,
}) => {
  'id': id,
  'productId': 'product',
  'productVariantId': '$id-variant',
  'quantity': 3,
  'checked': checked,
  'product': {'id': 'product', 'name': '商品', 'price': 1000, 'status': 'active'},
  'variant': {'id': '$id-variant', 'name': '藍色', 'price': price},
};

class TestAccount extends AccountNotifier {
  @override
  AccountInfo build() => AccountInfo.zero().copyWith(id: 'original');
  void switchTo(String id) => state = state.copyWith(id: id);
}

void main() {
  for (final price in [0.0, 99.125]) {
    test(
      'One batch validates multiple variants with exact price $price and keeps unchecked rows',
      () async {
        final rows = [
          row(price: price),
          row(id: 'second'),
          row(id: 'unchecked', checked: false),
        ];
        final h = Harness();
        await h.seed(rows);
        final selected = h.state.data!.where((row) => row.checked).toList();
        expect(selected.first.unitPrice, price);
        final validation = h.cart.validateCheckoutItems(selected);
        expect(h.state.isProcessing, isTrue);
        final request = await h.next('POST', '/api/cart/validate-checkout');
        expect(request.options.data, {
          'items': [
            {
              'cartItemId': 'cart',
              'productVariantId': 'cart-variant',
              'quantity': 3,
              'expectedUnitPrice': price,
            },
            {
              'cartItemId': 'second',
              'productVariantId': 'second-variant',
              'quantity': 3,
              'expectedUnitPrice': 99.125,
            },
          ],
        });
        final fresh = [
          for (final r in rows)
            {
              ...r,
              'product': <String, dynamic>{
                ...r['product'] as Map,
                'name': '更新商品',
              },
            },
        ];
        request.reply(
          checkoutFixture(rows.take(2).toList(), cartItems: fresh, stock: 3),
        );
        final result = await validation;
        expect(result.isSuccess, isTrue);
        expect(result.data!.first.product.name, '更新商品');
        expect(h.state.data!.length, 3);
        expect(h.state.isDone, isTrue);
        expect(h.seen, [
          'GET api/cart/list',
          'POST /api/cart/validate-checkout',
        ]);
      },
    );
  }

  for (final code in [
    'CART_ITEM_UNAVAILABLE',
    'CART_ITEM_CHANGED',
    'CART_SELECTION_CHANGED',
    'PRICE_CHANGED',
    'PRICE_UNAVAILABLE',
    'INSUFFICIENT_STOCK',
    'STOCK_UNAVAILABLE',
  ]) {
    test(
      '$code blocks, replaces full cart, and never mutates quantities',
      () async {
        final h = Harness();
        final original = row();
        await h.seed([original]);
        final resultFuture = h.cart.validateCheckoutItems(h.state.data!);
        final request = await h.next('POST', '/api/cart/validate-checkout');
        final changed = {
          ...original,
          'product': <String, dynamic>{
            ...original['product'] as Map,
            'name': '最新商品',
          },
        };
        final data = checkoutFixture(
          [original],
          cartItems: code == 'CART_ITEM_UNAVAILABLE' ? [] : [changed],
          itemIssues: {
            'cart': [code],
          },
          stock: 2,
        );
        if (code == 'STOCK_UNAVAILABLE') {
          (data['items'] as List).first['availableStock'] = null;
        }
        if (code == 'PRICE_UNAVAILABLE') {
          (data['items'] as List).first['currentUnitPrice'] = null;
        }
        request.reply(data);
        final result = await resultFuture;
        expect(result.isFailure, isTrue);
        if (code == 'CART_ITEM_UNAVAILABLE') {
          expect(h.state.data, isEmpty);
        } else {
          expect(h.state.data!.single.product.name, '最新商品');
          expect(h.state.data!.single.quantity, 3);
        }
        if (code == 'INSUFFICIENT_STOCK') {
          expect(result.error, contains('需求：3，剩餘：2'));
        }
        expect(h.seen.length, 2);
      },
    );
  }

  test(
    'Overall selection failure blocks even when every submitted row passes',
    () async {
      final h = Harness();
      await h.seed([row()]);
      final result = h.cart.validateCheckoutItems(h.state.data!);
      (await h.next('POST', '/api/cart/validate-checkout')).reply(
        checkoutFixture(
          [row()],
          cartItems: [
            row(),
            row(id: 'other'),
          ],
          overallIssues: ['CART_SELECTION_CHANGED'],
        ),
      );
      expect((await result).error, contains('勾選商品已變更'));
      expect(h.state.data!.length, 2);
    },
  );

  for (final malformed in [
    'missing cart',
    'missing result',
    'string approval',
    'null stock',
    'changed price',
    'wrong id',
    'unchecked',
    'missing date',
  ]) {
    test(
      'Malformed approval ($malformed) fails closed and retains previous cart',
      () async {
        final h = Harness();
        await h.seed([row()]);
        final original = h.state.data!;
        final result = h.cart.validateCheckoutItems(original);
        final data = checkoutFixture([row()]);
        switch (malformed) {
          case 'missing cart':
            data.remove('cartItems');
          case 'missing result':
            data['items'] = [];
          case 'string approval':
            data['canCheckout'] = 'true';
          case 'null stock':
            data['items'][0]['availableStock'] = null;
          case 'changed price':
            data['items'][0]['currentUnitPrice'] = 10;
          case 'wrong id':
            data['items'][0]['cartItemId'] = 'foreign';
          case 'unchecked':
            data['cartItems'][0]['checked'] = false;
          case 'missing date':
            data.remove('checkedAt');
        }
        (await h.next('POST', '/api/cart/validate-checkout')).reply(data);
        expect((await result).isFailure, isTrue);
        expect(h.state.data, same(original));
        expect(h.state.isDone, isTrue);
      },
    );
  }

  for (final status in [400, 401, 403, 404, 500]) {
    test('HTTP $status blocks without fallback product requests', () async {
      final h = Harness();
      await h.seed([row()]);
      final result = h.cart.validateCheckoutItems(h.state.data!);
      final request = await h.next('POST', '/api/cart/validate-checkout');
      request.handler.reject(
        DioException.badResponse(
          statusCode: status,
          requestOptions: request.options,
          response: Response(
            requestOptions: request.options,
            statusCode: status,
          ),
        ),
      );
      expect((await result).isFailure, isTrue);
      expect(h.state.data!.length, 1);
      expect(h.state.isDone, isTrue);
      expect(h.seen.length, 2);
    });
  }

  test(
    'A queued refresh invalidates the in-flight validation snapshot',
    () async {
      final h = Harness();
      await h.seed([row()]);
      final original = h.state.data!;
      final result = h.cart.validateCheckoutItems(original);
      final request = await h.next('POST', '/api/cart/validate-checkout');
      final refresh = h.cart.loadCartItems();
      request.reply(checkoutFixture([row()], cartItems: [row(id: 'stale')]));
      expect((await result).error, contains('內容已變更'));
      expect(h.state.data, same(original));
      (await h.next('GET', 'api/cart/list')).reply([row(id: 'fresh')]);
      await refresh;
      expect(h.state.data!.single.id, 'fresh');
    },
  );

  test('Account switching away and back discards a pending response', () async {
    final started = Completer<void>();
    late RequestInterceptorHandler pending;
    late RequestOptions options;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            pending = h;
            options = o;
            started.complete();
          },
        ),
      );
    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(dio),
        accountNotifierProvider.overrideWith(TestAccount.new),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(() => dio.close());
    final future = container.read(cartProvider.notifier).validateCheckoutItems([
      CartItem.fromApiResponseMap(row()),
    ]);
    await started.future;
    final account =
        container.read(accountNotifierProvider.notifier) as TestAccount;
    account.switchTo('another');
    account.switchTo('original');
    pending.resolve(
      Response(
        requestOptions: options,
        data: {
          'success': true,
          'data': checkoutFixture([row()]),
        },
      ),
    );
    expect((await future).error, contains('帳號或購物車'));
    expect(container.read(cartProvider).data, isEmpty);
  });

  test('Disposal while validating does not publish or start cleanup', () async {
    final h = Harness();
    await h.seed([row()]);
    final result = h.cart.validateCheckoutItems(h.state.data!);
    final request = await h.next('POST', '/api/cart/validate-checkout');
    h.container.dispose();
    request.reply(
      checkoutFixture(
        [row()],
        itemIssues: {
          'cart': ['PRODUCT_UNAVAILABLE'],
        },
      ),
    );
    expect((await result).isFailure, isTrue);
    expect(h.seen.length, 2);
  });
}
