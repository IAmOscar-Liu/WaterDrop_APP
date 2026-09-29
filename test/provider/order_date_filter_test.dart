import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/provider/order_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class PendingRequest {
  PendingRequest(this.options, this.handler);
  final RequestOptions options;
  final RequestInterceptorHandler handler;

  void succeed(String id, {int totalPages = 3}) {
    handler.resolve(
      Response(
        requestOptions: options,
        data: {
          'success': true,
          'data': {
            'orders': [
              {'id': id},
            ],
            'total': 21,
            'page': options.queryParameters['page'],
            'limit': 20,
            'totalPages': totalPages,
          },
        },
      ),
    );
  }

  void fail() {
    handler.reject(
      DioException.badResponse(
        statusCode: 400,
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: 400,
          data: {
            'message': [
              {'field': 'startDate', 'message': 'Invalid start date.'},
              {'field': 'endDate', 'message': 'Invalid end date.'},
            ],
          },
        ),
      ),
    );
  }
}

void main() {
  late Dio dio;
  late ProviderContainer container;
  late OrderNotifier notifier;
  late StreamController<PendingRequest> requests;
  late StreamIterator<PendingRequest> iterator;

  Future<PendingRequest> nextRequest() async {
    expect(
      await iterator.moveNext().timeout(const Duration(seconds: 5)),
      isTrue,
    );
    return iterator.current;
  }

  setUp(() {
    requests = StreamController<PendingRequest>();
    iterator = StreamIterator(requests.stream);
    dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) =>
              requests.add(PendingRequest(options, handler)),
        ),
      );
    container = ProviderContainer(
      overrides: [dioProvider.overrideWithValue(dio)],
    );
    notifier = container.read(orderNotifierProvider.notifier);
  });

  tearDown(() async {
    container.dispose();
    dio.close();
    await iterator.cancel();
    await requests.close();
  });

  test(
    'UTC bounds and sort persist through pagination; clearing resets query',
    () async {
      final start = DateTime.parse('2026-09-01T00:00:00+08:00');
      final end = DateTime.parse('2026-09-30T00:00:00+08:00');
      var loading = notifier.loadOrders(
        order: 'asc',
        startDate: start,
        endDate: end,
      );
      final first = await nextRequest();
      expect(first.options.path, '/api/order/list');
      expect(first.options.queryParameters, {
        'page': 1,
        'limit': 20,
        'order': 'asc',
        'startDate': '2026-08-31T16:00:00.000Z',
        'endDate': '2026-09-29T16:00:00.000Z',
      });
      first.succeed('first');
      await loading;
      final fetching = notifier.fetchMoreOrders();
      final second = await nextRequest();
      expect(second.options.queryParameters, {
        ...first.options.queryParameters,
        'page': 2,
      });
      second.succeed('second');
      await fetching;
      expect(
        container.read(orderNotifierProvider).data!.orders.map((o) => o.id),
        ['first', 'second'],
      );

      loading = notifier.loadOrders();
      final cleared = await nextRequest();
      expect(cleared.options.queryParameters, {
        'page': 1,
        'limit': 20,
        'order': 'desc',
      });
      cleared.succeed('all');
      await loading;
      expect(
        container.read(orderNotifierProvider).data!.orders.single.id,
        'all',
      );
    },
  );

  for (final startOnly in [true, false]) {
    test('Supports ${startOnly ? 'start' : 'end'}-only bounds', () async {
      final bound = DateTime.utc(2026, 9, 1);
      final loading = notifier.loadOrders(
        startDate: startOnly ? bound : null,
        endDate: startOnly ? null : bound,
      );
      final request = await nextRequest();
      expect(
        request.options.queryParameters.containsKey(
          startOnly ? 'endDate' : 'startDate',
        ),
        isFalse,
      );
      expect(
        request.options.queryParameters[startOnly ? 'startDate' : 'endDate'],
        bound.toIso8601String(),
      );
      request.succeed('order');
      await loading;
    });
  }

  for (final staleFailure in [false, true]) {
    for (final pagination in [false, true]) {
      test(
        'Ignores stale ${pagination ? 'pagination' : 'initial'} ${staleFailure ? 'error' : 'success'}',
        () async {
          Future<dynamic> stale = notifier.loadOrders();
          var staleRequest = await nextRequest();
          if (pagination) {
            staleRequest.succeed('old');
            await stale;
            stale = notifier.fetchMoreOrders();
            staleRequest = await nextRequest();
          }
          final current = notifier.loadOrders(startDate: DateTime.utc(2026, 9));
          final currentRequest = await nextRequest();
          currentRequest.succeed('current');
          await current;
          staleFailure ? staleRequest.fail() : staleRequest.succeed('stale');
          await stale;
          final state = container.read(orderNotifierProvider);
          expect(state.isDone, isTrue);
          expect(state.data!.orders.single.id, 'current');
          expect(state.data!.page, 1);
        },
      );
    }
  }

  test('Failed pagination retains results and retries the same page', () async {
    final loading = notifier.loadOrders();
    (await nextRequest()).succeed('first');
    await loading;
    final failed = notifier.fetchMoreOrders();
    (await nextRequest()).fail();
    expect(await failed, 'Invalid start date.\nInvalid end date.');
    expect(container.read(orderNotifierProvider).data!.page, 1);
    final retrying = notifier.fetchMoreOrders();
    final retried = await nextRequest();
    expect(retried.options.queryParameters['page'], 2);
    retried.succeed('second', totalPages: 2);
    await retrying;
    expect(
      container.read(orderNotifierProvider).data!.orders.map((o) => o.id),
      ['first', 'second'],
    );
    expect(await notifier.fetchMoreOrders(), isNull);
  });

  test('Initial validation errors expose readable messages', () async {
    final loading = notifier.loadOrders();
    (await nextRequest()).fail();
    await loading;
    expect(
      container.read(orderNotifierProvider).error,
      'Invalid start date.\nInvalid end date.',
    );
  });
}
