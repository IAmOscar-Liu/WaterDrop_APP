import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/app_constants.dart';
import 'package:flutter_ad_ecommerce/pages/message_page.dart';
import 'package:flutter_ad_ecommerce/pages/single_message_details.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/provider/notification_sync_provider.dart';
import 'package:flutter_ad_ecommerce/router/chat_route_observer.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/badge_count.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/messaging_app_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../chat/chat_test_support.dart' show ChatAdapter, jsonResponse;
import 'notification_sync_test.dart' show notice, counts, page;

void main() {
  testWidgets(
    'badges, list, read details, remote deletion and route visibility share one stream',
    (tester) async {
      final interval = VisibilityDetectorController.instance.updateInterval;
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      addTearDown(
        () => VisibilityDetectorController.instance.updateInterval = interval,
      );
      final api = ChatAdapter(eventPath: '/api/notification/events');
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = api;
      final sync = NotificationSyncController(dio, () async => false);
      var created = false;
      api.handler = (r) async {
        if (r.path.endsWith('/stats')) {
          return jsonResponse(counts(1, unread: 0));
        }
        if (r.path.endsWith('/list')) {
          return jsonResponse(
            page(created ? [notice('a')] : [], version: created ? 2 : 1),
          );
        }
        if (r.method == 'POST') {
          return jsonResponse({
            'notifications': [notice('a', version: 2, read: true)],
            'stats': counts(3, unread: 0),
          });
        }
        return jsonResponse(notice('a'));
      };
      final router = GoRouter(
        observers: [chatRouteObserver],
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                const Scaffold(appBar: MessagingAppBar(title: 'Home')),
          ),
          GoRoute(
            path: Routes.messagePage,
            builder: (_, _) => const MessagePage(),
          ),
          GoRoute(
            path: Routes.singleMessageDetails,
            builder: (_, state) => SingleMessageDetails(extra: state.extra),
          ),
        ],
      );
      sync.configureSession('u', foreground: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationSyncProvider.overrideWith((ref) => sync),
            dioProvider.overrideWithValue(dio),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      for (var i = 0; i < 10 && api.connections.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 1));
      }
      api.event('stream.ready', {'schemaVersion': 1, 'cursor': 'head'});
      await tester.pumpAndSettle();
      expect(find.byType(BadgeCount), findsNothing);
      created = true;
      api.event('notification.created', {
        'schemaVersion': 1,
        'notification': notice('a'),
        'stats': counts(2),
      }, id: 'new');
      await tester.pumpAndSettle();
      expect(tester.widget<BadgeCount>(find.byType(BadgeCount)).count, 1);
      expect(api.requests.where((r) => r.path.endsWith('/list')), isEmpty);
      await tester.tap(find.byIcon(Icons.notifications));
      await tester.pumpAndSettle();
      expect(find.text('通知 a'), findsOneWidget);
      expect(sync.messageCenterVisible, isTrue);
      expect(api.requests.where((r) => r.method == 'POST'), isEmpty);
      await tester.tap(find.text('通知 a'));
      await tester.pumpAndSettle();
      expect(sync.messageCenterVisible, isFalse);
      expect(find.text('測試內容'), findsOneWidget);
      expect(api.requests.where((r) => r.method == 'POST'), hasLength(1));
      expect(sync.stats!.total, 0);
      api.event('notification.deleted', {
        'schemaVersion': 1,
        'notificationId': 'a',
        'version': 3,
        'stats': counts(4, unread: 0),
      }, id: 'gone');
      await tester.pumpAndSettle();
      expect(find.text('此訊息已刪除或無法存取'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(sync.messageCenterVisible, isTrue);
      expect(find.text('目前沒有訊息'), findsOneWidget);
      expect(api.connections, hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      router.dispose();
      dio.close(force: true);
    },
    skip: !AppConstants.notificationSseEnabled,
  );
  testWidgets(
    'live inserts, deletes and reconnect preserve the visible notification',
    (tester) async {
      final interval = VisibilityDetectorController.instance.updateInterval;
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      addTearDown(
        () => VisibilityDetectorController.instance.updateInterval = interval,
      );
      final api = ChatAdapter(eventPath: '/api/notification/events');
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = api;
      final sync = NotificationSyncController(dio, () async => false);
      final items = List.generate(
        20,
        (i) => {
          ...notice('row-$i', read: true),
          'createdAt': DateTime.utc(
            2026,
            10,
            12,
          ).subtract(Duration(minutes: i)).toIso8601String(),
        },
      );
      api.handler = (r) async => jsonResponse(
        r.path.endsWith('/stats') ? counts(1, unread: 0) : page(items),
      );
      sync.configureSession('u', foreground: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationSyncProvider.overrideWith((ref) => sync),
            dioProvider.overrideWithValue(dio),
          ],
          child: const MaterialApp(home: MessagePage()),
        ),
      );
      for (var i = 0; i < 10 && api.connections.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 1));
      }
      api.event('stream.ready', {'schemaVersion': 1, 'cursor': 'head'});
      await tester.pumpAndSettle();
      final scroll = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      scroll.position.jumpTo(400);
      await tester.pumpAndSettle();
      final anchor = find.text('通知 row-5');
      final y = tester.getTopLeft(anchor).dy;
      api.event('notification.created', {
        'schemaVersion': 1,
        'notification': {...notice('new'), 'createdAt': '2026-10-12T01:00:00Z'},
        'stats': counts(2),
      }, id: 'new');
      for (var i = 0; i < 3; i++) {
        await tester.pump();
        expect(tester.getTopLeft(anchor).dy, closeTo(y, 1));
      }
      api.event('notification.deleted', {
        'schemaVersion': 1,
        'notificationId': 'new',
        'version': 2,
        'stats': counts(3, unread: 0),
      }, id: 'deleted');
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(anchor).dy, closeTo(y, 1));
      sync.configureSession('u', foreground: false);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(anchor).dy, closeTo(y, 1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      dio.close(force: true);
    },
    skip: !AppConstants.notificationSseEnabled,
  );
  testWidgets(
    'automatic pagination shows loading without a load-more button and crosses empty pages',
    (tester) async {
      final interval = VisibilityDetectorController.instance.updateInterval;
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      addTearDown(
        () => VisibilityDetectorController.instance.updateInterval = interval,
      );
      final api = ChatAdapter(eventPath: '/api/notification/events');
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = api;
      final sync = NotificationSyncController(dio, () async => false);
      final second = Completer<ResponseBody>();
      final third = Completer<ResponseBody>();
      final pages = <int>[];
      api.handler = (r) async {
        if (r.path.endsWith('/stats')) return jsonResponse(counts(1));
        final current = r.queryParameters['page'] as int;
        pages.add(current);
        if (current == 2) return second.future;
        if (current == 3) return third.future;
        return jsonResponse(page([notice('a')], pages: 3));
      };
      sync.configureSession('u', foreground: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationSyncProvider.overrideWith((ref) => sync),
            dioProvider.overrideWithValue(dio),
          ],
          child: const MaterialApp(home: MessagePage()),
        ),
      );
      for (var i = 0; i < 10 && api.connections.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 1));
      }
      api.event('stream.ready', {'schemaVersion': 1, 'cursor': 'head'});
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('載入更多'), findsNothing);
      }
      expect(pages, [1, 2]);
      expect(find.text('載入中……'), findsOneWidget);
      second.complete(jsonResponse(page([], current: 2, pages: 3)));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('載入更多'), findsNothing);
      }
      expect(pages, [1, 2, 3]);
      third.complete(jsonResponse({'message': 'offline'}, status: 503));
      await tester.pumpAndSettle();
      expect(find.text('載入失敗，點擊重試'), findsOneWidget);
      api.handler = (_) async =>
          jsonResponse(page([notice('b')], current: 3, pages: 3));
      await tester.tap(find.text('載入失敗，點擊重試'));
      await tester.pumpAndSettle();
      expect(find.text('通知 b'), findsOneWidget);
      expect(find.text('載入更多'), findsNothing);
      expect(find.text('載入中……'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      dio.close(force: true);
    },
    skip: !AppConstants.notificationSseEnabled,
  );
}
