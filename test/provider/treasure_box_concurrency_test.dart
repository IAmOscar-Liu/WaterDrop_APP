import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/models/account_info.dart';
import 'package:flutter_ad_ecommerce/provider/account_provider.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/provider/treasure_box_provider.dart';
import 'package:flutter_ad_ecommerce/utils/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> box(String id, {bool opened = false}) => {
  'id': id,
  'userId': 'user',
  'isActive': true,
  'isOpened': opened,
  'accountingStatus': opened ? 'acquired' : 'claimable',
  'coinsAwarded': opened ? 5 : 0,
};

class TestAccount extends AccountNotifier {
  int refreshes = 0;
  Completer<Result>? pending;
  @override
  AccountInfo build() => AccountInfo.zero();
  @override
  Future<Result> refreshAccountInfo() async {
    refreshes++;
    return pending == null ? Result.success() : await pending!.future;
  }
}

class Request {
  Request(this.options, this.handler);
  final RequestOptions options;
  final RequestInterceptorHandler handler;
  void reply(Object data) => handler.resolve(
    Response(
      requestOptions: options,
      statusCode: 200,
      data: {'success': true, 'data': data},
    ),
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
  final requests = StreamController<Request>();
  late final iterator = StreamIterator(requests.stream);
  final account = TestAccount();
  final seen = <String>[];
  late final container = ProviderContainer(
    overrides: [
      dioProvider.overrideWithValue(dio),
      accountNotifierProvider.overrideWith(() => account),
    ],
  );
  late final boxes = container.read(treasureBoxNotifierProvider.notifier);

  Harness() {
    container.listen(treasureBoxNotifierProvider, (_, _) {});
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          seen.add(options.path);
          requests.add(Request(options, handler));
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

  Future<Request> next(String path) async {
    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current.options.path, path);
    return iterator.current;
  }

  Future<void> seed() async {
    final loading = boxes.loadTreasureBoxes();
    (await next('/api/treasureBox/list')).reply([box('a'), box('b')]);
    await loading;
  }

  List<bool> get opened => container
      .read(treasureBoxNotifierProvider)
      .data!
      .take(2)
      .map((b) => b.isOpened)
      .toList();
}

void main() {
  test(
    'distinct opens are optimistic, duplicates suppressed, balances serialized',
    () async {
      final h = Harness();
      await h.seed();
      h.account.pending = Completer<Result>();
      final a = h.boxes.openBox('a');
      final b = h.boxes.openBox('b');
      expect((await h.boxes.openBox('a')).isFailure, isTrue);
      expect(h.opened, [true, true]);
      (await h.next('/api/treasureBox/open/a')).reply(box('a', opened: true));
      // Wait until the account refresh has started, without releasing it.
      while (h.account.refreshes == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(h.seen.where((p) => p.contains('/open/')).length, 1);
      expect(h.opened, [true, true]);
      h.account.pending!.complete(Result.success());
      h.account.pending = null;
      expect((await a).data, 5);
      (await h.next('/api/treasureBox/open/b')).reply(box('b', opened: true));
      expect((await b).data, 5);
      expect(h.account.refreshes, 2);
      expect(h.container.read(treasureBoxNotifierProvider).isDone, isTrue);
      expect(h.container.read(totalOpenedBoxAmountProvider), 10);
      expect(h.opened, [true, true]);
    },
  );

  test(
    'failure restores its box without undoing other pending opens',
    () async {
      final h = Harness();
      await h.seed();
      final a = h.boxes.openBox('a');
      final b = h.boxes.openBox('b');
      (await h.next('/api/treasureBox/open/a')).fail();
      (await h.next('/api/treasureBox/list')).reply([box('a'), box('b')]);
      expect((await a).isFailure, isTrue);
      expect(h.opened, [false, true]);
      (await h.next('/api/treasureBox/open/b')).reply(box('b', opened: true));
      expect((await b).isSuccess, isTrue);
      expect(h.opened, [false, true]);
      expect(h.container.read(treasureBoxNotifierProvider).isDone, isTrue);
    },
  );

  test('refresh in flight cannot overwrite queued opens', () async {
    final h = Harness();
    await h.seed();
    final refresh = h.boxes.loadTreasureBoxes();
    final read = await h.next('/api/treasureBox/list');
    final a = h.boxes.openBox('a');
    final b = h.boxes.openBox('b');
    expect(h.opened, [true, true]);
    read.reply([box('a'), box('b')]);
    await refresh;
    expect(h.opened, [true, true]);
    (await h.next('/api/treasureBox/open/a')).reply(box('a', opened: true));
    await a;
    expect(h.opened, [true, true]);
    (await h.next('/api/treasureBox/open/b')).reply(box('b', opened: true));
    await b;
    expect(h.opened, [true, true]);
  });

  test('queued box removed by a refresh is not opened', () async {
    final h = Harness();
    await h.seed();
    final refresh = h.boxes.loadTreasureBoxes();
    final read = await h.next('/api/treasureBox/list');
    final a = h.boxes.openBox('a');
    read.reply([box('b')]);
    await refresh;
    expect((await a).isFailure, isTrue);
    expect(h.seen.where((p) => p.contains('/open/')), isEmpty);
    expect(h.container.read(treasureBoxNotifierProvider).isDone, isTrue);
  });
}
