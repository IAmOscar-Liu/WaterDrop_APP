import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/app_constants.dart';
import 'package:flutter_ad_ecommerce/pages/chatroom_list_page.dart';
import 'package:flutter_ad_ecommerce/provider/chat_sync_provider.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'chat_test_support.dart';

void main() {
  testWidgets(
    'support-room events update the visible list every ten seconds',
    (tester) async {
      final interval = VisibilityDetectorController.instance.updateInterval;
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      addTearDown(() {
        VisibilityDetectorController.instance.updateInterval = interval;
      });
      final api = ChatAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = api;
      final sync = ChatSyncController(dio, () async => false);
      api.handler = (_) async => jsonResponse(listResponse([]));
      sync.configureSession('u', foreground: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatSyncProvider.overrideWith((ref) => sync),
            dioProvider.overrideWithValue(dio),
          ],
          child: const MaterialApp(home: ChatroomListPage()),
        ),
      );
      for (var i = 0; i < 10 && api.connections.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 1));
      }
      api.event('stream.ready', {'schemaVersion': 1, 'cursor': 'head'});
      await tester.pumpAndSettle();
      expect(find.text('目前沒有聊天室'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsNothing);

      for (var i = 1; i <= 3; i++) {
        await tester.pump(const Duration(seconds: 10));
        final incoming = message('support-$i')..['senderType'] = 'admin';
        api.event('message.created', {
          'schemaVersion': 1,
          'chatRoomId': 'a',
          'message': incoming,
        }, id: 'message-$i');
        api.event('chatroom.updated', {
          'schemaVersion': 1,
          'chatRoomId': 'a',
          'room': {
            ...room('a', version: i + 1, unread: i),
            'lastMessage': incoming,
          },
          'listState': listState(i + 1, unread: i),
        }, id: 'room-$i');
        await tester.pumpAndSettle();
        expect(find.text('水滴客服'), findsOneWidget);
        expect(find.text('客服: 你好 support-$i'), findsOneWidget);
        expect(find.text('$i'), findsOneWidget);
        if (i > 1) {
          expect(find.text('客服: 你好 support-${i - 1}'), findsNothing);
        }
      }
      // Updates use the same stream, without polling or opening the room.
      expect(api.connections, hasLength(1));
      expect(api.requests.where((r) => r.path.endsWith('/list')), hasLength(1));
      expect(api.requests.any((r) => r.path.contains('/history/')), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      dio.close(force: true);
    },
    skip: !AppConstants.chatSseEnabled,
  );
  testWidgets(
    'refresh, reordering and reconnect keep the visible room in place',
    (tester) async {
      final interval = VisibilityDetectorController.instance.updateInterval;
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      addTearDown(
        () => VisibilityDetectorController.instance.updateInterval = interval,
      );
      final api = ChatAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = api;
      final sync = ChatSyncController(dio, () async => false);
      final rooms = List.generate(
        20,
        (i) => {
          ...room('r$i'),
          'lastActivityAt': DateTime.utc(
            2026,
            10,
            11,
            0,
            20 - i,
          ).toIso8601String(),
          'lastMessage': message('preview-$i', room: 'r$i'),
        },
      );
      api.handler = (_) async => jsonResponse(listResponse(rooms));
      sync.configureSession('u', foreground: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatSyncProvider.overrideWith((ref) => sync),
            dioProvider.overrideWithValue(dio),
          ],
          child: const MaterialApp(home: ChatroomListPage()),
        ),
      );
      for (var i = 0; i < 10 && api.connections.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 1));
      }
      api.event('stream.ready', {'schemaVersion': 1, 'cursor': 'head'});
      await tester.pumpAndSettle();
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      scrollable.position.jumpTo(400);
      await tester.pumpAndSettle();
      final anchor = find.text('客服: 你好 preview-5');
      final y = tester.getTopLeft(anchor).dy;
      final refresh = Completer<ResponseBody>();
      api.handler = (_) => refresh.future;
      // REST refresh still runs on page entry/return for associated metadata.
      final loading = sync.loadList();
      await tester.pump();
      expect(tester.getTopLeft(anchor).dy, closeTo(y, 1));
      refresh.complete(jsonResponse(listResponse(rooms)));
      await tester.pumpAndSettle();
      await loading;
      expect(tester.getTopLeft(anchor).dy, closeTo(y, 1));
      api.event('chatroom.updated', {
        'schemaVersion': 1,
        'chatRoomId': 'r19',
        'room': {
          ...rooms.last,
          'version': 2,
          'lastActivityAt': '2026-10-11T02:00:00Z',
        },
        'listState': listState(2),
      }, id: 'moved');
      await tester.pump();
      await tester.pump();
      expect(tester.getTopLeft(anchor).dy, closeTo(y, 1));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(anchor).dy, closeTo(y, 1));
      api.event('chatroom.removed', {
        'schemaVersion': 1,
        'chatRoomId': 'r19',
        'roomVersion': 3,
        'listState': listState(3),
      }, id: 'removed');
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(anchor).dy, closeTo(y, 1));
      // Repeated live moves with different card heights must not accumulate
      // drift, and checking each frame catches post-frame jumpTo corrections.
      for (var cycle = 0; cycle < 3; cycle++) {
        await tester.pump(const Duration(seconds: 30));
        final index = 18 - cycle;
        api.event('chatroom.updated', {
          'schemaVersion': 1,
          'chatRoomId': 'r$index',
          'room': {
            ...rooms[index],
            'version': 2,
            'lastActivityAt': DateTime.utc(
              2026,
              10,
              11,
              3 + cycle,
            ).toIso8601String(),
            'product': {'name': '商品', 'variantName': '規格 $cycle'},
          },
          'listState': listState(4 + cycle),
        }, id: 'reorder-$cycle');
        for (var frame = 0; frame < 3; frame++) {
          await tester.pump();
          expect(tester.getTopLeft(anchor).dy, closeTo(y, 1));
        }
      }
      sync.configureSession('u', foreground: false);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(anchor).dy, closeTo(y, 1));
      // Readers already at the top should see the newest room without being
      // carried down the list with the previously first row.
      await tester.drag(find.byType(ListView), const Offset(0, 1800));
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, 0, reason: 'scroll back to the top');
      sync.applyEvent('chatroom.updated', {
        'chatRoomId': 'r18',
        'room': {
          ...rooms[18],
          'version': 3,
          'lastActivityAt': '2026-10-11T06:00:00Z',
        },
        'listState': listState(7),
      });
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, 0);
      expect(find.text('客服: 你好 preview-18'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      dio.close(force: true);
    },
    skip: !AppConstants.chatSseEnabled,
  );

  for (final scenario in [
    (name: 'top', count: 20, offset: 0.0),
    (name: 'scrolled', count: 20, offset: 400.0),
    (name: 'short list', count: 1, offset: 0.0),
  ]) {
    testWidgets(
      'repeated reconnects do not move the ${scenario.name} list, even for one frame',
      (tester) async {
        final interval = VisibilityDetectorController.instance.updateInterval;
        VisibilityDetectorController.instance.updateInterval = Duration.zero;
        addTearDown(
          () => VisibilityDetectorController.instance.updateInterval = interval,
        );
        final api = ChatAdapter();
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
          ..httpClientAdapter = api;
        final sync = ChatSyncController(dio, () async => false);
        final rooms = List.generate(
          scenario.count,
          (i) => {
            ...room('r$i'),
            'lastActivityAt': DateTime.utc(
              2026,
              10,
              11,
              0,
              30 - i,
            ).toIso8601String(),
            'lastMessage': message('preview-$i', room: 'r$i'),
          },
        );
        api.handler = (_) async => jsonResponse(listResponse(rooms));
        sync.configureSession('u', foreground: true);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              chatSyncProvider.overrideWith((ref) => sync),
              dioProvider.overrideWithValue(dio),
            ],
            child: const MaterialApp(home: ChatroomListPage()),
          ),
        );
        for (var i = 0; i < 10 && api.connections.isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 1));
        }
        api.event('stream.ready', {'schemaVersion': 1, 'cursor': 'head'});
        await tester.pumpAndSettle();
        final scrollable = tester.state<ScrollableState>(
          find.byType(Scrollable),
        );
        scrollable.position.jumpTo(scenario.offset);
        await tester.pumpAndSettle();
        final anchor = find.text(
          '客服: 你好 preview-${scenario.offset == 0 ? 0 : 5}',
        );
        final originalY = tester.getTopLeft(anchor).dy;
        final viewport = tester.getRect(find.byType(ListView));
        for (var cycle = 0; cycle < 3; cycle++) {
          await tester.pump(const Duration(seconds: 30));
          unawaited(api.connections.last.close());
          await tester.pump();
          await tester.pump();
          expect(find.text('聊天室正在重新連線……'), findsOneWidget);
          expect(tester.getRect(find.byType(ListView)), viewport);
          expect(tester.getTopLeft(anchor).dy, closeTo(originalY, 0.1));
          expect(scrollable.position.pixels, closeTo(scenario.offset, 0.1));
          await tester.pump(const Duration(seconds: 9));
          for (var i = 0; i < 10 && api.connections.length < cycle + 2; i++) {
            await tester.pump(const Duration(milliseconds: 1));
          }
          expect(api.connections.length, cycle + 2);
          api.event('stream.ready', {'schemaVersion': 1, 'cursor': 'head'});
          await tester.pump();
          await tester.pump();
          expect(tester.getRect(find.byType(ListView)), viewport);
          expect(tester.getTopLeft(anchor).dy, closeTo(originalY, 0.1));
          expect(scrollable.position.pixels, closeTo(scenario.offset, 0.1));
        }
        expect(
          api.requests.where((r) => r.path.endsWith('/list')),
          hasLength(1),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        dio.close(force: true);
      },
      skip: !AppConstants.chatSseEnabled,
    );
  }
}
