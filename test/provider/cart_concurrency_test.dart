import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/models/product.dart';
import 'package:flutter_ad_ecommerce/provider/cart_provider.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/utils/custom_async_value.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> row(String id, {int quantity = 1, bool checked = true}) =>
    {
      'id': id,
      'productId': id,
      'productVariantId': '$id-variant',
      'quantity': quantity,
      'checked': checked,
      'product': {'id': id, 'name': id, 'price': 100, 'status': 'active'},
    };

class PendingRequest {
  PendingRequest(this.options, this.handler);
  final RequestOptions options;
  final RequestInterceptorHandler handler;

  void reply(Object data) => handler.resolve(
    Response(requestOptions: options, data: {'success': true, 'data': data}),
  );

  void fail() => handler.reject(
    DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
    ),
  );
}

class Harness {
  final dio = Dio();
  final requests = StreamController<PendingRequest>();
  late final iterator = StreamIterator(requests.stream);
  late final container = ProviderContainer(
    overrides: [dioProvider.overrideWithValue(dio)],
  );
  late final cart = container.read(cartProvider.notifier);
  final seen = <String>[];

  Harness() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          seen.add('${options.method} ${options.path}');
          requests.add(PendingRequest(options, handler));
        },
      ),
    );
    addTearDown(() async {
      container.dispose();
      dio.close();
      await iterator.cancel();
      await requests.close();
    });
  }

  Future<PendingRequest> next(String method, String path) async {
    expect(await iterator.moveNext(), isTrue);
    final request = iterator.current;
    expect(request.options.method, method);
    expect(request.options.path, path);
    return request;
  }

  Future<void> seed(List<Map<String, dynamic>> rows) async {
    final pending = cart.loadCartItems();
    (await next('GET', 'api/cart/list')).reply(rows);
    await pending;
  }

  CustomAsyncValue<List<CartItem>> get state => container.read(cartProvider);
}

void main() {
  test(
    'rapid removals stay optimistic, serialize, and deduplicate repeated taps',
    () async {
      final h = Harness();
      await h.seed([row('a'), row('b'), row('c')]);
      final statuses = <CustomAsyncValueStatus>[];
      h.container.listen(cartProvider, (_, next) => statuses.add(next.status));
      final first = h.cart.removeItem('a', productVariantId: 'a-variant');
      final second = h.cart.removeItem('b', productVariantId: 'b-variant');
      final duplicate = h.cart.removeItem('a', productVariantId: 'a-variant');
      expect(h.state.data!.map((e) => e.id), ['c']);
      expect(h.state.isProcessing, isTrue);
      final write = await h.next('POST', '/api/cart/item');
      expect(write.options.data['productId'], 'a');
      expect(h.seen.where((r) => r.startsWith('POST')).length, 1);
      write.reply({});
      (await h.next('GET', 'api/cart/list')).reply([row('b'), row('c')]);
      expect((await first).isSuccess, isTrue);
      expect(h.state.data!.map((e) => e.id), ['c']);
      expect(h.state.isProcessing, isTrue);
      final nextWrite = await h.next('POST', '/api/cart/item');
      expect(nextWrite.options.data['productId'], 'b');
      nextWrite.reply({});
      (await h.next('GET', 'api/cart/list')).reply([row('c')]);
      expect((await second).isSuccess, isTrue);
      expect(h.state.isProcessing, isTrue);
      (await h.next('GET', 'api/cart/list')).reply([row('c')]);
      expect((await duplicate).isSuccess, isTrue);
      expect(h.state.isDone, isTrue);
      expect(h.seen.where((r) => r.startsWith('POST')).length, 2);
      expect(statuses.where((s) => s == CustomAsyncValueStatus.done).length, 1);
    },
  );

  test(
    'failed removal restores only that item and later removals still run',
    () async {
      final h = Harness();
      await h.seed([row('a'), row('b')]);
      final first = h.cart.removeItem('a', productVariantId: 'a-variant');
      final second = h.cart.removeItem('b', productVariantId: 'b-variant');
      (await h.next('POST', '/api/cart/item')).fail();
      (await h.next('GET', 'api/cart/list')).reply([row('a'), row('b')]);
      expect((await first).isFailure, isTrue);
      expect(h.state.data!.map((e) => e.id), ['a']);
      expect(h.state.isProcessing, isTrue);
      (await h.next('POST', '/api/cart/item')).reply({});
      (await h.next('GET', 'api/cart/list')).reply([row('a')]);
      expect((await second).isSuccess, isTrue);
      expect(h.state.isDone, isTrue);
      expect(h.state.data!.map((e) => e.id), ['a']);
    },
  );

  test('older refresh cannot overwrite queued quantity edits', () async {
    final h = Harness();
    await h.seed([row('a')]);
    final item = h.state.data!.single;
    final refresh = h.cart.loadCartItems(keepPreviousData: true);
    final oldRead = await h.next('GET', 'api/cart/list');
    final edit1 = h.cart.updateCartItem(
      item,
      quantity: 2,
      productVariantId: 'a-variant',
    );
    final edit2 = h.cart.updateCartItem(
      item,
      quantity: 4,
      productVariantId: 'a-variant',
    );
    expect(h.state.data!.single.quantity, 4);
    expect((await h.cart.validateCheckoutItems([item])).isFailure, isTrue);
    oldRead.reply([row('a')]);
    await refresh;
    expect(h.state.data!.single.quantity, 4);
    final write1 = await h.next('POST', '/api/cart/item');
    expect(write1.options.data['quantity'], 2);
    write1.reply({});
    (await h.next('GET', 'api/cart/list')).reply([row('a', quantity: 2)]);
    await edit1;
    expect(h.state.data!.single.quantity, 4);
    expect(h.state.isProcessing, isTrue);
    final write2 = await h.next('POST', '/api/cart/item');
    expect(write2.options.data['quantity'], 4);
    write2.reply({});
    final lastRead = await h.next('GET', 'api/cart/list');
    expect(h.state.isDone, isFalse);
    lastRead.reply([row('a', quantity: 4)]);
    await edit2;
    expect(h.state.isDone, isTrue);
    expect(h.state.data!.single.quantity, 4);
  });

  test(
    'queued adds compute quantity from the preceding confirmed result',
    () async {
      final h = Harness();
      await h.seed([row('a')]);
      final first = h.cart.addCartItem('a', productVariantId: 'a-variant');
      final second = h.cart.addCartItem('a', productVariantId: 'a-variant');
      for (final quantity in [2, 3]) {
        final write = await h.next('POST', '/api/cart/item');
        expect(write.options.data['quantity'], quantity);
        write.reply({});
        (await h.next(
          'GET',
          'api/cart/list',
        )).reply([row('a', quantity: quantity)]);
      }
      await Future.wait([first, second]);
      expect(h.state.data!.single.quantity, 3);
      expect(h.state.isDone, isTrue);
    },
  );

  test(
    'mixed edits, checkbox changes and removal preserve the latest intent',
    () async {
      final h = Harness();
      await h.seed([row('a'), row('b')]);
      final edit = h.cart.updateCartItem(
        h.state.data!.first,
        quantity: 3,
        productVariantId: 'a-variant',
      );
      final toggle = h.cart.toggleCartItem(
        'b',
        false,
        productVariantId: 'b-variant',
      );
      final remove = h.cart.removeItem('a', productVariantId: 'a-variant');
      expect(h.state.data!.single.id, 'b');
      expect(h.state.data!.single.checked, isFalse);
      (await h.next('POST', '/api/cart/item')).reply({});
      (await h.next(
        'GET',
        'api/cart/list',
      )).reply([row('a', quantity: 3), row('b')]);
      await edit;
      expect(h.state.data!.single.id, 'b');
      expect(h.state.data!.single.checked, isFalse);
      final checkbox = await h.next('PUT', '/api/cart/item/toggle');
      expect(checkbox.options.data['checked'], isFalse);
      checkbox.reply({});
      (await h.next(
        'GET',
        'api/cart/list',
      )).reply([row('a', quantity: 3), row('b', checked: false)]);
      await toggle;
      expect(h.state.isProcessing, isTrue);
      (await h.next('POST', '/api/cart/item')).reply({});
      (await h.next('GET', 'api/cart/list')).reply([row('b', checked: false)]);
      await remove;
      expect(h.state.isDone, isTrue);
      expect(h.state.data!.single.id, 'b');
      expect(h.state.data!.single.checked, isFalse);
    },
  );

  test(
    'rapid checkbox toggles keep the last selection and totals during refresh',
    () async {
      final h = Harness();
      await h.seed([row('a'), row('b')]);
      // Keep derived providers subscribed so their optimistic values are tested.
      h.container.listen(cartTotalPriceProvider, (_, _) {});
      h.container.listen(cartTotalItemsProvider, (_, _) {});
      final first = h.cart.toggleCartItem(
        'a',
        false,
        productVariantId: 'a-variant',
      );
      expect(h.container.read(cartTotalPriceProvider), 100);
      final second = h.cart.toggleCartItem(
        'a',
        true,
        productVariantId: 'a-variant',
      );
      expect(h.container.read(cartTotalPriceProvider), 200);
      final third = h.cart.toggleCartItem(
        'a',
        false,
        productVariantId: 'a-variant',
      );
      expect(h.container.read(cartTotalPriceProvider), 100);
      for (final checked in [false, true, false]) {
        final request = await h.next('PUT', '/api/cart/item/toggle');
        expect(request.options.data['checked'], checked);
        request.reply({});
        (await h.next(
          'GET',
          'api/cart/list',
        )).reply([row('a', checked: checked), row('b')]);
        // A stale intermediate response must not restore a superseded selection.
        if (checked) {
          await second;
          expect(h.state.data!.first.checked, isFalse);
          expect(h.state.isDone, isFalse);
          expect(h.container.read(cartTotalPriceProvider), 100);
        }
      }
      await Future.wait([first, second, third]);
      expect(h.state.isDone, isTrue);
      expect(h.container.read(cartTotalItemsProvider), 1);
      expect(h.container.read(cartTotalPriceProvider), 100);
    },
  );

  test(
    'failed checkbox request restores server selection while preserving other pending selections',
    () async {
      final h = Harness();
      await h.seed([row('a'), row('b')]);
      final first = h.cart.toggleCartItem(
        'a',
        false,
        productVariantId: 'a-variant',
      );
      final second = h.cart.toggleCartItem(
        'b',
        false,
        productVariantId: 'b-variant',
      );
      expect(h.state.data!.every((item) => !item.checked), isTrue);
      (await h.next('PUT', '/api/cart/item/toggle')).fail();
      (await h.next('GET', 'api/cart/list')).reply([row('a'), row('b')]);
      expect((await first).isFailure, isTrue);
      expect(h.state.data!.first.checked, isTrue);
      expect(h.state.data!.last.checked, isFalse);
      expect(h.state.isDone, isFalse);
      (await h.next('PUT', '/api/cart/item/toggle')).reply({});
      (await h.next(
        'GET',
        'api/cart/list',
      )).reply([row('a'), row('b', checked: false)]);
      expect((await second).isSuccess, isTrue);
      expect(h.state.isDone, isTrue);
      expect(h.state.data!.map((item) => item.checked), [true, false]);
    },
  );

  test(
    'failed reconciliation blocks checkout until a successful reload',
    () async {
      final h = Harness();
      await h.seed([row('a')]);
      final remove = h.cart.removeItem('a', productVariantId: 'a-variant');
      (await h.next('POST', '/api/cart/item')).fail();
      (await h.next('GET', 'api/cart/list')).fail();
      expect((await remove).isFailure, isTrue);
      expect(h.state.isDone, isFalse);
      final reload = h.cart.loadCartItems();
      (await h.next('GET', 'api/cart/list')).reply([row('a')]);
      await reload;
      expect(h.state.isDone, isTrue);
    },
  );
}
