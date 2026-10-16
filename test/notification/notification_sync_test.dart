import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/models/api_enums.dart';
import 'package:flutter_ad_ecommerce/provider/notification_sync_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import '../chat/chat_test_support.dart' show ChatAdapter, jsonResponse, settle;

Map<String, dynamic> notice(
  String id, {
  int version = 1,
  bool read = false,
  String type = 'system_alert',
}) => {
  'id': id,
  'userId': 'u',
  'version': version,
  'type': type,
  'title': '通知 $id',
  'body': '測試內容',
  'isRead': read,
  'createdAt': '2026-10-12T01:00:00.000Z',
  'updatedAt': '2026-10-12T01:00:00.000Z',
  'metadata': null,
};
Map<String, dynamic> counts(int version, {int unread = 1}) => {
  'version': version,
  'total': unread,
  'system_alert': unread,
  'order_status': 0,
  'promotion': 0,
  'coins_earned': 0,
  'chat_message': 0,
  'other': 0,
};
Map<String, dynamic> page(
  List<Map<String, dynamic>> items, {
  int current = 1,
  int pages = 1,
  int version = 1,
}) => {
  'notifications': items,
  'page': current,
  'limit': 20,
  'total': items.length,
  'totalPages': pages,
  'listSnapshot': 'snapshot',
  'listSnapshotExpiresAt': '2099-10-12T01:00:00Z',
  'stats': counts(version),
};

Future<(NotificationSyncController, ChatAdapter)> setup({
  Future<ResponseBody> Function(RequestOptions)? handler,
}) async {
  final api = ChatAdapter(eventPath: '/api/notification/events');
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..httpClientAdapter = api;
  final sync = NotificationSyncController(dio, () async => false);
  api.handler =
      handler ??
      (r) async =>
          jsonResponse(r.path.endsWith('/stats') ? counts(1) : page([]));
  addTearDown(() {
    sync.dispose();
    dio.close(force: true);
  });
  sync.configureSession('u', foreground: true);
  await settle();
  api.event('stream.ready', {'schemaVersion': 1, 'cursor': 'head'});
  await settle();
  return (sync, api);
}

void main() {
  test(
    'no-op read reconciles an owned deletion without restoring stale content',
    () async {
      final (sync, api) = await setup(
        handler: (r) async {
          if (r.path.endsWith('/stats')) return jsonResponse(counts(1));
          if (r.path.endsWith('/list')) {
            return jsonResponse(page([notice('a')]));
          }
          if (r.method == 'POST') {
            return jsonResponse({
              'notifications': [],
              'stats': counts(2, unread: 0),
            });
          }
          return jsonResponse({}, status: 404);
        },
      );
      final q = sync.openQuery();
      await sync.loadList(q);
      expect((await sync.markRead('a')).isSuccess, isTrue);
      expect(sync.unavailable('a'), isTrue);
      await sync.loadList(q); // An older snapshot must not undo the 404.
      expect(sync.messages(q), isEmpty);
      expect(api.requests.where((r) => r.path.endsWith('/a')), hasLength(1));
    },
  );

  test(
    'background resume reuses only notification cursor; reset invalidates stale requests',
    () async {
      final (sync, api) = await setup();
      final q = sync.openQuery();
      sync.setQueryVisible(q, true);
      await sync.loadList(q);
      api.event('notification.created', {
        'schemaVersion': 1,
        'notification': notice('a'),
        'stats': counts(2),
      }, id: 'n2');
      await settle();
      sync.configureSession('u', foreground: false);
      await settle();
      expect(api.connections.first.isClosed, isTrue);
      sync.configureSession('u', foreground: true);
      await settle();
      expect(api.requests.last.path, '/api/notification/events');
      expect(api.requests.last.headers['Last-Event-ID'], 'n2');
      api.event('stream.ready', {'schemaVersion': 1, 'cursor': 'n2'});
      await settle();
      expect(sync.messages(q).single.id, 'a');
      final delayed = Completer<ResponseBody>();
      api.handler = (_) => delayed.future;
      final loading = sync.loadList(q);
      await settle();
      // Exercise the real reset callback, without waiting through reconnect backoff.
      sync.stream.onReset();
      delayed.complete(jsonResponse(page([notice('old')])));
      await loading;
      expect(q.loaded, isFalse);
      expect(sync.messages(q), isEmpty);
      expect(sync.stats, isNull);
    },
  );

  test(
    'an event during a search refresh leaves the query dirty until a subsequent snapshot',
    () async {
      final (sync, api) = await setup();
      final q = sync.openQuery(search: '通知');
      await sync.loadList(q);
      final delayed = Completer<ResponseBody>();
      api.handler = (_) => delayed.future;
      final refreshing = sync.loadList(q);
      await settle();
      api.event('notification.created', {
        'schemaVersion': 1,
        'notification': notice('a'),
        'stats': counts(2),
      }, id: 'changed');
      await settle();
      delayed.complete(jsonResponse(page([])));
      await refreshing;
      expect(q.dirty, isTrue);
      api.handler = (_) async => jsonResponse(page([notice('a')], version: 2));
      await sync.loadList(q);
      expect(q.dirty, isFalse);
      expect(sync.messages(q).single.id, 'a');
    },
  );

  test(
    'offscreen feed updates authoritative stats without caching all notifications',
    () async {
      final statsResponse = Completer<ResponseBody>();
      final (sync, api) = await setup(handler: (_) => statsResponse.future);
      api.event('notification.created', {
        'schemaVersion': 1,
        'notification': notice('a'),
        'stats': counts(3, unread: 2),
      }, id: 'n1');
      await settle();
      expect(sync.stats!.total, 2);
      expect(sync.item('a'), isNull);
      statsResponse.complete(jsonResponse(counts(1)));
      await settle();
      expect(sync.stats!.version, 3);
      expect(sync.stream.cursor, 'n1');
      expect(api.requests.where((r) => r.path.endsWith('/list')), isEmpty);
    },
  );

  test(
    'batch events sharing stats version update every item and unread-only membership',
    () async {
      final (sync, api) = await setup(
        handler: (r) async => jsonResponse(
          r.path.endsWith('/stats')
              ? counts(1, unread: 2)
              : page([notice('a'), notice('b')]),
        ),
      );
      final q = sync.openQuery(onlyUnread: true);
      await sync.loadList(q);
      for (final id in ['a', 'b']) {
        api.event('notification.updated', {
          'schemaVersion': 1,
          'notification': notice(id, version: 2, read: true),
          'stats': counts(2, unread: 0),
        }, id: 'read-$id');
      }
      await settle();
      expect(sync.messages(q), isEmpty);
      expect(sync.item('a')!.isRead, isTrue);
      expect(sync.item('b')!.isRead, isTrue);
      expect(sync.stats!.total, 0);
      expect(api.requests.where((r) => r.method == 'POST'), isEmpty);
    },
  );

  test(
    'snapshot races preserve inserts, newer reads and deletion tombstones',
    () async {
      final delayed = Completer<ResponseBody>();
      final (sync, api) = await setup(
        handler: (r) async => r.path.endsWith('/stats')
            ? jsonResponse(counts(1))
            : delayed.future,
      );
      final q = sync.openQuery();
      final loading = sync.loadList(q);
      await settle();
      api.event('notification.deleted', {
        'schemaVersion': 1,
        'notificationId': 'a',
        'version': 2,
        'stats': counts(2, unread: 0),
      }, id: 'delete');
      api.event('notification.created', {
        'schemaVersion': 1,
        'notification': notice('new'),
        'stats': counts(3),
      }, id: 'new');
      api.event('notification.updated', {
        'schemaVersion': 1,
        'notification': notice('b', version: 2, read: true),
        'stats': counts(4),
      }, id: 'read');
      await settle();
      delayed.complete(jsonResponse(page([notice('a'), notice('b')])));
      await loading;
      expect(sync.messages(q).map((m) => m.id), containsAll(['new', 'b']));
      expect(sync.messages(q).any((m) => m.id == 'a'), isFalse);
      expect(sync.item('b')!.isRead, isTrue);
      expect(sync.stats!.version, 4);
    },
  );

  test(
    'filtered snapshots use scalar types and preserve search text; page failures retry same page',
    () async {
      var failed = false;
      final (sync, api) = await setup(
        handler: (r) async {
          if (r.path.endsWith('/stats')) return jsonResponse(counts(1));
          final n = r.queryParameters['page'] as int;
          if (n == 2 && !failed) {
            failed = true;
            return jsonResponse({}, status: 503);
          }
          return jsonResponse(page([], current: n, pages: 3));
        },
      );
      final q = sync.openQuery(
        type: NotificationType.systemAlert,
        search: '  %測試_ ',
        onlyUnread: true,
      );
      await sync.loadList(q);
      expect(q.hasMore, isTrue);
      await sync.loadList(q, more: true);
      expect(q.page, 1);
      await sync.loadList(q, more: true);
      expect(q.page, 2);
      await sync.loadList(q, more: true);
      expect(q.hasMore, isFalse);
      final requests = api.requests
          .where((r) => r.path.endsWith('/list'))
          .toList();
      expect(requests.map((r) => r.queryParameters['page']), [1, 2, 2, 3]);
      expect(
        requests.every(
          (r) =>
              r.queryParameters['limit'] == 20 &&
              r.queryParameters['types'] == 'system_alert' &&
              r.queryParameters['search'] == '  %測試_ ',
        ),
        isTrue,
      );
      expect(requests[1].queryParameters['listSnapshot'], 'snapshot');
      expect(requests[1].queryParameters.containsKey('snapshot'), isFalse);
    },
  );

  test(
    'replaced snapshot restarts only the query with a fresh token',
    () async {
      final (sync, api) = await setup(
        handler: (r) async {
          if (r.path.endsWith('/stats')) return jsonResponse(counts(1));
          if (r.queryParameters.containsKey('listSnapshot')) {
            return jsonResponse({
              'code': 'NOTIFICATION_LIST_SNAPSHOT_EXPIRED',
            }, status: 410);
          }
          return jsonResponse(page([notice('a')], pages: 2));
        },
      );
      final q = sync.openQuery();
      await sync.loadList(q);
      await sync.loadList(q, more: true);
      expect(q.page, 1);
      expect(q.error, isNull);
      expect(api.connections, hasLength(1));
      expect(sync.stream.cursor, 'head');
      expect(api.requests.last.queryParameters['snapshot'], isTrue);
    },
  );

  test(
    'failed mutation responses cannot undo event-confirmed read/delete',
    () async {
      Completer<ResponseBody>? mutation;
      final (sync, api) = await setup(
        handler: (r) async {
          if (r.method != 'GET') return mutation!.future;
          return jsonResponse(
            r.path.endsWith('/stats') ? counts(1) : page([notice('a')]),
          );
        },
      );
      final q = sync.openQuery();
      await sync.loadList(q);
      mutation = Completer<ResponseBody>();
      final reading = sync.markRead('a');
      await settle();
      api.event('notification.updated', {
        'schemaVersion': 1,
        'notification': notice('a', version: 2, read: true),
        'stats': counts(2, unread: 0),
      }, id: 'read');
      await settle();
      mutation.complete(jsonResponse({}, status: 503));
      expect((await reading).isSuccess, isTrue);
      mutation = Completer<ResponseBody>();
      final deleting = sync.delete('a');
      await settle();
      api.event('notification.deleted', {
        'schemaVersion': 1,
        'notificationId': 'a',
        'version': 3,
        'stats': counts(3, unread: 0),
      }, id: 'delete');
      await settle();
      mutation.complete(jsonResponse({}, status: 503));
      expect((await deleting).isSuccess, isTrue);
      expect(sync.messages(q), isEmpty);
      expect(api.requests.where((r) => r.path.endsWith('/list')), hasLength(1));
    },
  );

  test(
    'search events invalidate without guessing SQL matching; covered views do not refetch',
    () async {
      final (sync, api) = await setup();
      final q = sync.openQuery(search: '%_');
      await sync.loadList(q);
      api.event('notification.created', {
        'schemaVersion': 1,
        'notification': notice('a'),
        'stats': counts(2),
      }, id: 'created');
      await settle();
      expect(q.dirty, isTrue);
      expect(sync.messages(q), isEmpty);
      expect(api.requests.where((r) => r.path.endsWith('/list')), hasLength(1));
      api.handler = (r) async => jsonResponse(page([notice('a')], version: 2));
      await sync.loadList(q);
      expect(sync.messages(q).single.id, 'a');
      expect(q.dirty, isFalse);
    },
  );

  test(
    'visible details read without a loaded list and receive deletes',
    () async {
      final (sync, api) = await setup(
        handler: (r) async {
          if (r.path.endsWith('/stats')) return jsonResponse(counts(1));
          if (r.method == 'POST') {
            return jsonResponse({
              'notifications': [notice('a', version: 2, read: true)],
              'stats': counts(2, unread: 0),
            });
          }
          return jsonResponse(notice('a'));
        },
      );
      final detail = sync.openDetail('a');
      sync.setDetailVisible(detail, true);
      await settle();
      expect(sync.item('a')!.isRead, isTrue);
      expect(api.requests.where((r) => r.method == 'POST'), hasLength(1));
      api.event('notification.deleted', {
        'schemaVersion': 1,
        'notificationId': 'a',
        'version': 3,
        'stats': counts(3, unread: 0),
      }, id: 'delete');
      await settle();
      expect(sync.unavailable('a'), isTrue);
      expect(sync.item('a'), isNull);
    },
  );

  test(
    'logout rejects stale HTTP and clears independent notification cursor',
    () async {
      final delayed = Completer<ResponseBody>();
      final (sync, api) = await setup(
        handler: (r) async => r.path.endsWith('/stats')
            ? jsonResponse(counts(1))
            : delayed.future,
      );
      final q = sync.openQuery();
      final loading = sync.loadList(q);
      await settle();
      sync.configureSession(null, foreground: false);
      delayed.complete(jsonResponse(page([notice('a')])));
      await loading;
      expect(sync.messages(q), isEmpty);
      expect(sync.stats, isNull);
      expect(sync.stream.cursor, isNull);
      expect(api.connections.single.isClosed, isTrue);
    },
  );
}
