import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/features/message/widgets/notification_sync_host.dart';
import 'package:flutter_ad_ecommerce/models/account_info.dart';
import 'package:flutter_ad_ecommerce/provider/account_provider.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/provider/notification_sync_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../chat/chat_test_support.dart' show ChatAdapter, jsonResponse;
import 'notification_sync_test.dart' show counts;

class _Account extends AccountNotifier {
  @override
  AccountInfo build() =>
      AccountInfo.fromApiResponseMap({'id': 'u', 'oauthId': 'signed-in'});
}

void main() {
  testWidgets(
    'session host connects without Message Center, stops in background and clears on logout',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final api = ChatAdapter(eventPath: '/api/notification/events');
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = api;
      final sync = NotificationSyncController(dio, () async => false);
      api.handler = (_) async => jsonResponse(counts(1, unread: 0));
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationSyncProvider.overrideWith((ref) => sync),
            dioProvider.overrideWithValue(dio),
            accountNotifierProvider.overrideWith(_Account.new),
          ],
          child: MaterialApp(
            navigatorKey: navigator,
            builder: (_, child) =>
                NotificationSyncHost(loggedIn: true, child: child!),
            home: const Scaffold(body: Text('Home')),
          ),
        ),
      );
      for (var i = 0; i < 10 && api.connections.isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 1));
      }
      expect(api.connections, hasLength(1));
      api.event('stream.ready', {
        'schemaVersion': 1,
        'cursor': 'notification-head',
      });
      await tester.pumpAndSettle();
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Other page')),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.connections, hasLength(1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(api.connections.first.isClosed, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      for (var i = 0; i < 10 && api.connections.length < 2; i++) {
        await tester.pump(const Duration(milliseconds: 1));
      }
      expect(api.connections, hasLength(2));
      expect(api.requests.last.headers['Last-Event-ID'], 'notification-head');
      api.event('stream.ready', {
        'schemaVersion': 1,
        'cursor': 'notification-head',
      });
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NotificationSyncHost)),
      );
      container.read(accountNotifierProvider.notifier).reset();
      await tester.pump();
      await tester.pump();
      expect(api.connections.last.isClosed, isTrue);
      expect(sync.stats, isNull);
      expect(sync.stream.cursor, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      dio.close(force: true);
    },
  );
}
