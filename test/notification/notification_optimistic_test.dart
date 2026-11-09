import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../chat/chat_test_support.dart' show jsonResponse, settle;
import 'notification_sync_test.dart' show setup, notice, counts, page;

void main() {
  test(
    'read hides unread row immediately and failure restores membership',
    () async {
      final pending = Completer<ResponseBody>();
      final (sync, _) = await setup(
        handler: (r) async {
          if (r.path.endsWith('/stats')) return jsonResponse(counts(1));
          if (r.method == 'POST') return pending.future;
          return jsonResponse(page([notice('a')]));
        },
      );
      final q = sync.openQuery(onlyUnread: true, search: '通知');
      await sync.loadList(q);
      final result = sync.markRead('a');
      expect(sync.messages(q), isEmpty);
      expect(sync.stats!.total, 0);
      expect(sync.stats!.systemAlert, 0);
      expect(
        sync.item('a')!.isRead,
        isFalse,
      ); // Canonical data stays untouched.
      pending.complete(jsonResponse({}, status: 500));
      expect((await result).isFailure, isTrue);
      await settle();
      expect(sync.messages(q).single.id, 'a');
      expect(sync.stats!.total, 1);
    },
  );

  test(
    'SSE-confirmed read survives HTTP failure and a new unread item',
    () async {
      final pending = Completer<ResponseBody>();
      final (sync, _) = await setup(
        handler: (r) async {
          if (r.path.endsWith('/stats')) return jsonResponse(counts(1));
          if (r.method == 'POST') return pending.future;
          return jsonResponse(page([notice('a')]));
        },
      );
      final q = sync.openQuery();
      await sync.loadList(q);
      final result = sync.markRead('a');
      sync.applyEvent('notification.updated', {
        'notification': notice('a', version: 2, read: true),
        'stats': counts(2, unread: 0),
      });
      sync.applyEvent('notification.created', {
        'notification': notice('b'),
        'stats': counts(3),
      });
      expect(sync.stats!.total, 1);
      pending.complete(jsonResponse({}, status: 500));
      expect((await result).isSuccess, isTrue);
      await settle();
      expect(sync.stats!.total, 1);
      expect(sync.messages(q).firstWhere((m) => m.id == 'a').isRead, isTrue);
    },
  );

  test(
    'failed batch restores only items not confirmed deleted by SSE',
    () async {
      final pending = Completer<ResponseBody>();
      final (sync, _) = await setup(
        handler: (r) async {
          if (r.path.endsWith('/stats')) {
            return jsonResponse(counts(1, unread: 2));
          }
          if (r.method == 'DELETE') return pending.future;
          return jsonResponse({
            ...page([notice('a'), notice('b')]),
            'stats': counts(1, unread: 2),
          });
        },
      );
      final q = sync.openQuery();
      await sync.loadList(q);
      final result = sync.deleteMany(['a', 'b']);
      expect(sync.messages(q), isEmpty);
      expect(sync.stats!.total, 0);
      sync.applyEvent('notification.deleted', {
        'notificationId': 'a',
        'version': 2,
        'stats': counts(2),
      });
      expect(sync.stats!.total, 0);
      pending.complete(jsonResponse({}, status: 500));
      expect((await result).isFailure, isTrue);
      await settle();
      expect(sync.messages(q).map((m) => m.id), ['b']);
      expect(sync.stats!.total, 1);
    },
  );

  test('REST counts racing with two writes do not double subtract', () async {
    final reads = <String, Completer<ResponseBody>>{};
    var stats = counts(1, unread: 2);
    final (sync, _) = await setup(
      handler: (r) async {
        if (r.path.endsWith('/stats')) return jsonResponse(stats);
        if (r.method == 'POST') {
          final id = (r.data['notificationIds'] as List).single as String;
          return (reads[id] = Completer<ResponseBody>()).future;
        }
        return jsonResponse({
          ...page([notice('a'), notice('b')]),
          'stats': counts(1, unread: 2),
        });
      },
    );
    final q = sync.openQuery();
    await sync.loadList(q);
    final a = sync.markRead('a');
    final b = sync.markRead('b');
    await settle();
    stats = counts(2); // Server committed A, but SSE has not delivered it.
    await sync.loadStats();
    expect(sync.stats!.total, 0);
    reads['a']!.complete(
      jsonResponse({
        'notifications': [notice('a', version: 2, read: true)],
        'stats': counts(2),
      }),
    );
    await a;
    await settle();
    expect(sync.stats!.total, 0);
    reads['b']!.complete(jsonResponse({}, status: 500));
    expect((await b).isFailure, isTrue);
    await settle();
    expect(sync.stats!.total, 1);
    expect(sync.messages(q).firstWhere((m) => m.id == 'a').isRead, isTrue);
    expect(sync.messages(q).firstWhere((m) => m.id == 'b').isRead, isFalse);
  });

  test(
    'read and delete overlap debits an unread notification only once',
    () async {
      final read = Completer<ResponseBody>();
      final deletion = Completer<ResponseBody>();
      final (sync, _) = await setup(
        handler: (r) async {
          if (r.path.endsWith('/stats')) return jsonResponse(counts(1));
          if (r.method == 'POST') return read.future;
          if (r.method == 'DELETE') return deletion.future;
          return jsonResponse(page([notice('a')]));
        },
      );
      final q = sync.openQuery();
      await sync.loadList(q);
      final a = sync.markRead('a');
      final b = sync.delete('a');
      expect(sync.stats!.total, 0);
      sync.applyEvent('notification.updated', {
        'notification': notice('a', version: 2, read: true),
        'stats': counts(2, unread: 0),
      });
      read.complete(jsonResponse({}, status: 500));
      deletion.complete(jsonResponse({}, status: 500));
      expect((await a).isSuccess, isTrue);
      expect((await b).isFailure, isTrue);
      await settle();
      expect(sync.stats!.total, 0);
      expect(sync.messages(q).single.isRead, isTrue);
    },
  );
  test(
    'logout discards pending deletion and cannot restore the old user',
    () async {
      final pending = Completer<ResponseBody>();
      final (sync, _) = await setup(
        handler: (r) async {
          if (r.path.endsWith('/stats')) return jsonResponse(counts(1));
          if (r.method == 'DELETE') return pending.future;
          return jsonResponse(page([notice('a')]));
        },
      );
      final q = sync.openQuery();
      await sync.loadList(q);
      final result = sync.delete('a');
      await settle();
      sync.configureSession(null, foreground: true);
      pending.complete(jsonResponse({}, status: 500));
      expect((await result).isFailure, isTrue);
      await settle();
      expect(sync.stats, isNull);
      expect(sync.messages(q), isEmpty);
    },
  );
}
