import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/app_constants.dart';
import 'package:flutter_ad_ecommerce/layout/root_layout.dart';
import 'package:flutter_ad_ecommerce/pages/message_page.dart';
import 'package:flutter_ad_ecommerce/pages/single_message_details.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/provider/notification_sync_provider.dart';
import 'package:flutter_ad_ecommerce/router/chat_route_observer.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:flutter_ad_ecommerce/service/notification_tap_service.dart';
import 'package:flutter_ad_ecommerce/utils/events.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import '../chat/chat_test_support.dart' show ChatAdapter, jsonResponse;
import 'notification_sync_test.dart' show notice, counts, page;

void main() {
  for (final scenario in ['cold', 'warm', 'missing-id', 'deleted']) {
    testWidgets('notification tap: $scenario', (tester) async {
      pendingNotificationTap.value = null;
      final auth = ValueNotifier((loggedIn: false, loading: true));
      final api = ChatAdapter(eventPath: '/api/notification/events');
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = api;
      final sync = NotificationSyncController(dio, () async => false);
      api.handler = (r) async {
        if (r.path.endsWith('/stats')) return jsonResponse(counts(1));
        if (r.path.endsWith('/list')) return jsonResponse(page([]));
        if (r.method == 'POST') {
          return jsonResponse({
            'notifications': [notice('a', version: 2, read: true)],
            'stats': counts(2, unread: 0),
          });
        }
        return scenario == 'deleted'
            ? jsonResponse({'message': 'Not found'}, status: 404)
            : jsonResponse(notice('a'));
      };
      final tap = NotificationTappedEvent(
        data: {
          'command': 'message',
          if (scenario != 'missing-id') 'notificationId': 'a',
        },
        title: 'Push title must not become cached content',
      );
      if (scenario == 'cold') queueNotificationTap(tap);
      final router = GoRouter(
        routes: [
          ShellRoute(
            observers: [chatRouteObserver],
            builder: (context, state, child) => ValueListenableBuilder(
              valueListenable: auth,
              builder: (context, value, _) => RootLayout(
                isLoggedIn: value.loggedIn,
                isLoading: value.loading,
                error: null,
                navigationShell: child,
              ),
            ),
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const Scaffold(body: Text('Home')),
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
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationSyncProvider.overrideWith((ref) => sync),
            dioProvider.overrideWithValue(dio),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      expect(api.requests, isEmpty);
      if (scenario == 'cold') {
        expect(pendingNotificationTap.value, same(tap));
        auth.value = (loggedIn: true, loading: true);
        await tester.pump();
        await tester.pump();
        expect(api.requests, isEmpty);
        expect(pendingNotificationTap.value, same(tap));
      }
      sync.configureSession('u', foreground: true);
      for (var i = 0; i < 10 && api.connections.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 1));
      }
      api.event('stream.ready', {'schemaVersion': 1, 'cursor': 'head'});
      auth.value = (loggedIn: true, loading: false);
      if (scenario != 'cold') {
        await tester.pumpAndSettle();
        queueNotificationTap(tap);
      }
      await tester.pumpAndSettle();
      expect(pendingNotificationTap.value, isNull);
      if (scenario == 'missing-id' || scenario == 'deleted') {
        expect(find.byType(MessagePage), findsOneWidget);
        expect(find.byType(SingleMessageDetails), findsNothing);
        expect(api.requests.where((r) => r.method == 'POST'), isEmpty);
        if (scenario == 'deleted') {
          expect(find.text('此訊息已刪除或無法存取'), findsOneWidget);
        }
      } else {
        expect(find.byType(SingleMessageDetails), findsOneWidget);
        expect(find.text('通知 a'), findsOneWidget);
        expect(
          find.text('Push title must not become cached content'),
          findsNothing,
        );
        expect(
          api.requests.where((r) => r.path == '/api/notification/sync/a'),
          hasLength(1),
        );
        expect(api.requests.where((r) => r.method == 'POST'), hasLength(1));
        expect(sync.stats!.total, 0);
        router.pop();
        await tester.pumpAndSettle();
        expect(find.text('Home'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      router.dispose();
      auth.dispose();
      pendingNotificationTap.value = null;
      dio.close(force: true);
    }, skip: !AppConstants.notificationSseEnabled);
  }
}
