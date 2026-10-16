import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/models/chatroom.dart';
import 'package:flutter_ad_ecommerce/provider/chat_sync_provider.dart';
import 'package:flutter_ad_ecommerce/service/chatroom_sse_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'chat_test_support.dart';

void main() {
  test(
    'SSE handles byte fragmentation, UTF8, CRLF, multiline data, heartbeat and truncated EOF',
    () async {
      final source =
          '\uFEFF: heartbeat\r\n\r\nretry: 3000\r\nevent: message.created\r\nid: opaque\r\ndata: {"text":\r\ndata: "你好😀"}\r\n\r\nevent: stream.ready\ndata: {"cursor":"c"}\n\nid: incomplete\ndata: no delimiter';
      final frames = await decodeChatSse(
        Stream.fromIterable(utf8.encode(source).map((b) => [b])),
      ).toList();
      expect(frames, hasLength(2));
      expect(frames[0].event, 'message.created');
      expect(frames[0].id, 'opaque');
      expect(frames[0].retry, 3000);
      expect(jsonDecode(frames[0].data)['text'], '你好😀');
      expect(frames[1].id, isNull);
    },
  );

  test(
    'history reducer does not revert receipts or duplicate canonical messages',
    () {
      final h = ChatHistory()..loading = true;
      h.read('m', 3);
      h.merge(ChatMessage.fromApiResponseMap(message('m')));
      h.merge(ChatMessage.fromApiResponseMap(message('m', version: 2)));
      expect(h.messages.length, 1);
      expect(h.messages['m']!.version, 3);
      expect(h.messages['m']!.isRead, isTrue);
    },
  );

  late ChatAdapter api;
  late Dio dio;
  late ChatSyncController sync;
  setUp(() async {
    api = ChatAdapter();
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

  test(
    'one user stream routes all rooms, honors listVisible and uses authoritative counts',
    () async {
      sync.openRoom('a');
      await settle();
      sync.applyEvent('message.created', {
        'chatRoomId': 'b',
        'message': message('b1', room: 'b'),
      });
      expect(sync.histories['a']!.messages, isEmpty);
      expect(sync.histories.containsKey('b'), isFalse);
      sync.applyEvent('chatroom.updated', {
        'chatRoomId': 'b',
        'room': room('b', visible: false),
        'listState': listState(2, unread: 0),
      });
      expect(sync.rooms, isEmpty);
      final update = {
        'chatRoomId': 'b',
        'room': room('b', version: 2),
        'listState': listState(3, unread: 5),
      };
      sync.applyEvent('chatroom.updated', update);
      sync.applyEvent('chatroom.updated', update);
      expect(sync.rooms.single.id, 'b');
      expect(sync.totalUnread, 5);
      expect(api.connections, hasLength(1));
      expect(api.requests.where((r) => r.path.endsWith('/history/b')), isEmpty);
    },
  );

  test(
    'new message/read receipt during snapshot merge survives older REST response',
    () async {
      final pending = Completer<ResponseBody>();
      api.handler = (r) async => r.path.contains('/history/')
          ? pending.future
          : jsonResponse(listResponse([]));
      sync.openRoom('a');
      await settle();
      api.event('message.created', {
        'schemaVersion': 1,
        'chatRoomId': 'a',
        'message': message('live'),
      }, id: 'c1');
      api.event('messages.read', {
        'schemaVersion': 1,
        'chatRoomId': 'a',
        'messages': [
          {'id': 'older', 'version': 2, 'isRead': true},
        ],
      }, id: 'c2');
      await settle();
      pending.complete(
        jsonResponse(historyResponse([message('older')], next: 'next')),
      );
      await settle();
      expect(
        sync.histories['a']!.messages.keys,
        containsAll(['live', 'older']),
      );
      expect(sync.histories['a']!.messages['older']!.isRead, isTrue);
      expect(sync.stream.cursor, 'c2');
    },
  );

  test(
    'older history uses 20 and exclusive cursor, serializes requests and retains retry cursor',
    () async {
      var calls = 0;
      final older = Completer<ResponseBody>();
      api.handler = (r) async {
        if (r.path.contains('/history/')) {
          calls++;
          if (calls == 1) {
            return jsonResponse(
              historyResponse([message('new')], next: 'older-token'),
            );
          }
          return older.future;
        }
        return jsonResponse(listResponse([]));
      };
      sync.openRoom('a');
      await settle();
      final first = sync.loadHistory('a', older: true);
      final second = sync.loadHistory('a', older: true);
      await settle();
      expect(calls, 2);
      final request = api.requests.last;
      expect(request.queryParameters, {'limit': 20, 'before': 'older-token'});
      older.complete(
        jsonResponse(historyResponse([message('new'), message('old')])),
      );
      await Future.wait([first, second]);
      expect(sync.histories['a']!.messages.length, 2);
      expect(sync.histories['a']!.hasMore, isFalse);
      expect(sync.stream.cursor, 'start');
    },
  );

  test(
    'room removal blocks late history/list responses and newer grant restores room',
    () async {
      final pending = Completer<ResponseBody>();
      api.handler = (r) async => r.path.contains('/history/')
          ? pending.future
          : jsonResponse(listResponse([room('a')]));
      sync.openRoom('a');
      await settle();
      sync.applyEvent('chatroom.removed', {
        'chatRoomId': 'a',
        'roomVersion': 3,
        'listState': listState(3, unread: 0),
      });
      pending.complete(jsonResponse(historyResponse([message('secret')])));
      await settle();
      await sync.loadList();
      expect(sync.histories['a']!.removed, isTrue);
      expect(sync.histories['a']!.messages, isEmpty);
      expect(sync.rooms, isEmpty);
      api.handler = (r) async => jsonResponse(historyResponse([]));
      sync.applyEvent('chatroom.updated', {
        'chatRoomId': 'a',
        'room': room('a', version: 4),
        'listState': listState(4),
      });
      await settle();
      expect(sync.histories['a']!.removed, isFalse);
      expect(sync.rooms.single.id, 'a');
    },
  );

  test(
    'send uses sync canonical envelope and SSE-before-POST receipt wins',
    () async {
      sync.openRoom('a');
      await settle();
      final post = Completer<ResponseBody>();
      api.handler = (r) async =>
          r.method == 'POST' ? post.future : jsonResponse(historyResponse([]));
      final sending = sync.send('a', 'hello', []);
      await settle();
      final request = api.requests.last;
      expect(request.path, '/api/chatroom/sync/message/a');
      final key = request.data['clientMessageId'] as String;
      final created = message('own', clientId: key);
      sync.applyEvent('message.created', {
        'chatRoomId': 'a',
        'message': created,
      });
      sync.applyEvent('messages.read', {
        'chatRoomId': 'a',
        'messages': [
          {'id': 'own', 'version': 2, 'isRead': true},
        ],
      });
      post.complete(jsonResponse(created));
      await sending;
      expect(sync.histories['a']!.messages.length, 1);
      expect(sync.histories['a']!.messages['own']!.isRead, isTrue);
      expect(sync.drafts['a'], isEmpty);
      expect(
        api.requests.where((r) => r.path.contains('/history/')),
        hasLength(1),
      );
    },
  );

  test('failed send retries with the same UUID and attachment input', () async {
    sync.openRoom('a');
    await settle();
    var sends = 0;
    final bodies = <Map>[];
    api.handler = (r) async {
      bodies.add(Map.from(r.data as Map));
      sends++;
      if (sends == 1) return jsonResponse({'message': 'offline'}, status: 503);
      return jsonResponse(
        message('confirmed', clientId: r.data['clientMessageId']),
      );
    };
    await sync.send('a', 'hello', []);
    final draft = sync.drafts['a']!.single;
    expect(draft.error, isNotNull);
    await sync.retrySend('a', draft);
    expect(bodies[0], bodies[1]);
    expect(sync.drafts['a'], isEmpty);
  });

  test(
    'background/resume reconnects once with checkpoint; logout drops caches and cursor',
    () async {
      api.event('chatroom.updated', {
        'schemaVersion': 1,
        'chatRoomId': 'a',
        'room': room('a'),
        'listState': listState(2),
      }, id: 'checkpoint');
      await settle();
      sync.configureSession('u', foreground: false);
      sync.configureSession('u', foreground: true);
      sync.configureSession('u', foreground: true);
      await settle();
      expect(api.connections, hasLength(2));
      expect(api.requests.last.headers['Last-Event-ID'], 'checkpoint');
      api.event('stream.ready', {'schemaVersion': 1, 'cursor': 'checkpoint'});
      await settle();
      expect(sync.connected, isTrue);
      expect(sync.rooms, isNotEmpty);
      sync.configureSession(null, foreground: false);
      expect(sync.rooms, isEmpty);
      expect(sync.stream.cursor, isNull);
    },
  );

  test(
    'read receipt before send confirmation is retained without a created frame',
    () async {
      sync.openRoom('a');
      await settle();
      final post = Completer<ResponseBody>();
      api.handler = (r) async => post.future;
      final sending = sync.send('a', 'hello', []);
      await settle();
      final key = api.requests.last.data['clientMessageId'] as String;
      sync.applyEvent('messages.read', {
        'chatRoomId': 'a',
        'messages': [
          {'id': 'own', 'version': 2, 'isRead': true},
        ],
      });
      post.complete(jsonResponse(message('own', clientId: key)));
      await sending;
      expect(sync.histories['a']!.messages['own']!.isRead, isTrue);
    },
  );

  test(
    'full reset discards checkpoint and snapshots but preserves failed drafts',
    () async {
      sync.openRoom('a');
      await settle();
      api.handler = (r) async =>
          jsonResponse({'message': 'offline'}, status: 503);
      await sync.send('a', 'keep my draft', []);
      api.event('stream.reset', {'reason': 'resync_required'});
      await settle();
      expect(sync.stream.cursor, isNull);
      expect(sync.histories, isEmpty);
      expect(sync.drafts['a']!.single.content, 'keep my draft');
      api.handler = null;
      sync.configureSession('u', foreground: false);
      sync.configureSession('u', foreground: true);
      await settle();
      expect(api.requests.last.headers.containsKey('Last-Event-ID'), isFalse);
      api.event('stream.ready', {'schemaVersion': 1, 'cursor': 'fresh'});
      await settle();
      expect(sync.histories['a']!.loaded, isTrue);
    },
  );

  test(
    'snapshot token is reused across pages and older page cannot restore a tombstone',
    () async {
      api.handler = (r) async {
        if (r.queryParameters['page'] == 2) {
          return jsonResponse(listResponse([room('a')], page: 2, pages: 2));
        }
        return jsonResponse(listResponse([room('a')], pages: 2));
      };
      await sync.loadList();
      sync.applyEvent('chatroom.removed', {
        'chatRoomId': 'a',
        'roomVersion': 5,
        'listState': listState(5, unread: 0),
      });
      await sync.loadList(more: true);
      expect(api.requests.last.queryParameters, {
        'page': 2,
        'limit': 20,
        'listSnapshot': 'snapshot',
      });
      expect(sync.rooms, isEmpty);
      expect(sync.hasMoreRooms, isFalse);
      expect(sync.totalUnread, 0);
    },
  );

  test(
    'expired list snapshot refreshes only list, with existing stream checkpoint',
    () async {
      var calls = 0;
      api.handler = (r) async {
        calls++;
        if (calls == 1) {
          return jsonResponse({
            'code': 'CHATROOM_LIST_SNAPSHOT_EXPIRED',
          }, status: 410);
        }
        expect(r.queryParameters['snapshot'], isTrue);
        return jsonResponse(listResponse([room('a')]));
      };
      await sync.loadList();
      expect(calls, 2);
      expect(sync.rooms.single.id, 'a');
      expect(sync.stream.cursor, 'start');
      expect(api.connections, hasLength(1));
    },
  );

  test(
    'failed older-page request keeps messages and retries the same cursor',
    () async {
      var calls = 0;
      api.handler = (r) async {
        calls++;
        if (calls == 1) {
          return jsonResponse(historyResponse([message('new')], next: 'next'));
        }
        if (calls == 2) {
          return jsonResponse({'message': 'temporary'}, status: 503);
        }
        expect(r.queryParameters['before'], 'next');
        return jsonResponse(historyResponse([message('old')]));
      };
      sync.openRoom('a');
      await settle();
      await sync.loadHistory('a', older: true);
      expect(sync.histories['a']!.olderError, isNotNull);
      expect(sync.histories['a']!.messages.keys, ['new']);
      await sync.loadHistory('a', older: true);
      expect(sync.histories['a']!.messages.keys, containsAll(['old', 'new']));
    },
  );
}
