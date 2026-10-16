import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/pages/sync_chatroom_page.dart';
import 'package:flutter_ad_ecommerce/provider/chat_sync_provider.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/router/chat_route_observer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'chat_test_support.dart'
    show
        ChatAdapter,
        jsonResponse,
        listResponse,
        historyResponse,
        room,
        message;

void main() {
  testWidgets(
    'renders live messages, scrolls for older history, and retains failed send',
    (tester) async {
      final api = ChatAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = api;
      final sync = ChatSyncController(dio, () async => false);
      var olderCalls = 0;
      api.handler = (r) async {
        if (r.path.endsWith('/list')) return jsonResponse(listResponse([]));
        if (r.path.contains('/history/')) {
          if (r.queryParameters['before'] != null) {
            olderCalls++;
            return jsonResponse(historyResponse([message('old')]));
          }
          return jsonResponse(
            historyResponse(
              List.generate(20, (i) => message('m${20 - i}')),
              next: 'older',
            ),
          );
        }
        if (r.method == 'POST') {
          return jsonResponse({'message': 'failed send'}, status: 503);
        }
        if (r.path.endsWith('/read')) return jsonResponse({'messages': []});
        return jsonResponse(room('a'));
      };
      sync.configureSession('u', foreground: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatSyncProvider.overrideWith((ref) => sync),
            dioProvider.overrideWithValue(dio),
          ],
          child: const MaterialApp(
            home: SyncChatroomPage(extra: {'chatRoomId': 'a'}),
          ),
        ),
      );
      for (var i = 0; i < 10 && api.connections.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 1));
      }
      api.event('stream.ready', {'schemaVersion': 1, 'cursor': 'head'});
      await tester.pumpAndSettle();
      expect(find.textContaining('你好'), findsWidgets);
      await tester.drag(find.byType(ListView), const Offset(0, 2400));
      await tester.pumpAndSettle();
      // The explicit older-page affordance remains accessible even on short lists.
      for (var i = 0; i < 6 && olderCalls == 0; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, 1500));
        await tester.pumpAndSettle();
      }
      expect(olderCalls, 1);
      api.event('message.created', {
        'schemaVersion': 1,
        'chatRoomId': 'a',
        'message': message('live'),
      }, id: 'next');
      await tester.pumpAndSettle();
      expect(sync.histories['a']!.messages.containsKey('live'), isTrue);
      await tester.enterText(find.byType(TextField), 'keep this draft');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();
      expect(sync.drafts['a']!.single.content, 'keep this draft');
      expect(sync.drafts['a']!.single.error, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      dio.close(force: true);
    },
  );

  testWidgets(
    'stacked rooms keep one stream and restore read visibility on pop',
    (tester) async {
      final api = ChatAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = api;
      final sync = ChatSyncController(dio, () async => false);
      api.handler = (r) async {
        if (r.path.endsWith('/list')) return jsonResponse(listResponse([]));
        if (r.path.contains('/history/')) {
          return jsonResponse(historyResponse([]));
        }
        if (r.path.endsWith('/read')) return jsonResponse({'messages': []});
        return jsonResponse(room(r.path.split('/').last));
      };
      sync.configureSession('u', foreground: true);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatSyncProvider.overrideWith((ref) => sync),
            dioProvider.overrideWithValue(dio),
          ],
          child: MaterialApp(
            navigatorKey: navigator,
            navigatorObservers: [chatRouteObserver],
            home: const SyncChatroomPage(extra: {'chatRoomId': 'a'}),
          ),
        ),
      );
      for (var i = 0; i < 10 && api.connections.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 1));
      }
      api.event('stream.ready', {'schemaVersion': 1, 'cursor': 'head'});
      await tester.pumpAndSettle();
      expect(sync.visibleRoom, 'a');
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const SyncChatroomPage(extra: {'chatRoomId': 'b'}),
        ),
      );
      await tester.pumpAndSettle();
      expect(sync.visibleRoom, 'b');
      expect(api.connections, hasLength(1));
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(sync.visibleRoom, 'a');
      expect(api.connections, hasLength(1));
      // Notification taps can also stack two routes for the same room.
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const SyncChatroomPage(extra: {'chatRoomId': 'a'}),
        ),
      );
      await tester.pumpAndSettle();
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(sync.visibleRoom, 'a');
      expect(sync.histories['a']!.loaded, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      dio.close(force: true);
    },
  );
}
