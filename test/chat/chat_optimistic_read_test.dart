import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/provider/chat_sync_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chat_test_support.dart';

void main() {
  late ChatAdapter api;
  late Dio dio;
  late ChatSyncController sync;
  late Completer<ResponseBody> pending;

  setUp(() async {
    api = ChatAdapter();
    pending = Completer<ResponseBody>();
    api.handler = (r) async {
      if (r.method == 'PUT') return pending.future;
      return jsonResponse({
        ...listResponse([room('a', unread: 3)]),
        'listState': listState(1, unread: 3),
      });
    };
    dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = api;
    sync = ChatSyncController(dio, () async => false);
    sync.configureSession('u', foreground: true);
    await settle();
    api.event('stream.ready', {'schemaVersion': 1, 'cursor': 'start'});
    await settle();
  });
  tearDown(() {
    sync.dispose();
    dio.close(force: true);
  });

  void update(int version, int unread) {
    sync.applyEvent('chatroom.updated', {
      'chatRoomId': 'a',
      'room': room('a', version: version, unread: unread),
      'listState': listState(version, unread: unread),
    });
  }

  void receipt() {
    sync.applyEvent('messages.read', {
      'chatRoomId': 'a',
      'readerType': 'user',
      'messages': [
        {'id': 'm', 'version': 2, 'isRead': true},
      ],
    });
  }

  test(
    'swipe immediately clears badges, failure retains new incoming unread',
    () async {
      final result = sync.markReadFromList('a');
      expect(sync.rooms.single.totalUnread, 0);
      expect(sync.totalUnread, 0);
      update(2, 4);
      expect(sync.rooms.single.totalUnread, 1);
      expect(sync.totalUnread, 1);
      pending.complete(jsonResponse({}, status: 500));
      expect(await result, isFalse);
      expect(sync.rooms.single.totalUnread, 4);
      expect(sync.totalUnread, 4);
    },
  );

  test(
    'SSE confirms read before HTTP failure and later messages remain unread',
    () async {
      final result = sync.markReadFromList('a');
      receipt();
      update(2, 0);
      update(3, 1);
      expect(sync.rooms.single.totalUnread, 1);
      expect(sync.totalUnread, 1);
      pending.complete(jsonResponse({}, status: 500));
      expect(await result, isTrue);
      expect(sync.totalUnread, 1);
    },
  );

  test(
    'REST started before read confirmation cannot remove optimistic state',
    () async {
      final snapshot = Completer<ResponseBody>();
      api.handler = (r) async =>
          r.method == 'PUT' ? pending.future : snapshot.future;
      final load = sync.loadList();
      final result = sync.markReadFromList('a');
      snapshot.complete(
        jsonResponse({
          ...listResponse([room('a', version: 2, unread: 1)]),
          'listState': listState(2),
        }),
      );
      await load;
      expect(sync.totalUnread, 0);
      receipt();
      update(2, 1);
      pending.complete(jsonResponse({}, status: 500));
      expect(await result, isTrue);
      expect(sync.totalUnread, 1);
    },
  );

  test(
    'HTTP success reconciles counts through fresh metadata without SSE',
    () async {
      final result = sync.markReadFromList('a');
      expect(sync.totalUnread, 0);
      api.handler = (r) async => r.method == 'PUT'
          ? pending.future
          : jsonResponse({
              ...listResponse([room('a', version: 2, unread: 1)]),
              'listState': listState(2),
            });
      pending.complete(jsonResponse([]));
      expect(await result, isTrue);
      expect(sync.rooms.single.totalUnread, 1);
      expect(sync.totalUnread, 1);
    },
  );
  test('logout clears optimistic state and ignores the old response', () async {
    final result = sync.markReadFromList('a');
    expect(sync.totalUnread, 0);
    sync.configureSession(null, foreground: true);
    pending.complete(jsonResponse({}, status: 500));
    expect(await result, isFalse);
    expect(sync.rooms, isEmpty);
    expect(sync.totalUnread, 0);
  });

  test('stale removal cannot undo a pending read of a newer room', () async {
    update(3, 3);
    final result = sync.markReadFromList('a');
    sync.applyEvent('chatroom.removed', {
      'chatRoomId': 'a',
      'roomVersion': 2,
      'listState': listState(2, unread: 0),
    });
    expect(sync.rooms.single.totalUnread, 0);
    expect(sync.totalUnread, 0);
    pending.complete(jsonResponse({}, status: 500));
    expect(await result, isFalse);
    expect(sync.totalUnread, 3);
  });
  test('replayed old receipt cannot confirm a newer unread baseline', () async {
    update(3, 3);
    final result = sync.markReadFromList('a');
    receipt();
    update(2, 0);
    update(4, 4);
    expect(sync.totalUnread, 1);
    pending.complete(jsonResponse({}, status: 500));
    expect(await result, isFalse);
    expect(sync.totalUnread, 4);
  });
}
