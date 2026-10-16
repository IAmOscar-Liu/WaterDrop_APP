import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/app_constants.dart';
import 'package:flutter_ad_ecommerce/pages/chatroom_list_page.dart';
import 'package:flutter_ad_ecommerce/pages/message_page.dart';
import 'package:flutter_ad_ecommerce/pages/order_page.dart';
import 'package:flutter_ad_ecommerce/provider/chat_sync_provider.dart';
import 'package:flutter_ad_ecommerce/provider/notification_sync_provider.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../chat/chat_test_support.dart' show ChatAdapter, jsonResponse;

void main() {
  for (final scenario in [
    (page: const OrderPage(), path: '/api/order/list', field: 'orders'),
    (
      page: const ChatroomListPage(),
      path: '/api/chatroom/list',
      field: 'rooms',
    ),
    (
      page: const MessagePage(),
      path: '/api/notification/list',
      field: 'notifications',
    ),
  ]) {
    testWidgets(
      '${scenario.page.runtimeType} loads the next page when its last row becomes visible',
      (tester) async {
        final previousInterval =
            VisibilityDetectorController.instance.updateInterval;
        VisibilityDetectorController.instance.updateInterval = Duration.zero;
        addTearDown(
          () => VisibilityDetectorController.instance.updateInterval =
              previousInterval,
        );
        final chatEnabled =
            scenario.field == 'rooms' && AppConstants.chatSseEnabled;
        final notificationEnabled =
            scenario.field == 'notifications' &&
            AppConstants.notificationSseEnabled;
        final syncEnabled = chatEnabled || notificationEnabled;
        final path = syncEnabled
            ? scenario.path.replaceFirst('/list', '/sync/list')
            : scenario.path;
        final stats = {
          'version': 1,
          'total': 0,
          'system_alert': 0,
          'order_status': 0,
          'promotion': 0,
          'coins_earned': 0,
          'chat_message': 0,
          'other': 0,
        };
        final requestedPages = <int>[];
        final api = ChatAdapter(
          eventPath: notificationEnabled
              ? '/api/notification/events'
              : '/api/chatroom/events',
        );
        final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
          ..httpClientAdapter = api;
        api.handler = (options) async {
          if (options.path != path) return jsonResponse(stats);
          final page = int.parse(options.queryParameters['page'].toString());
          requestedPages.add(page);
          return jsonResponse({
            scenario.field: List.generate(20, (index) {
              final row = (page - 1) * 20 + index;
              return {
                'id': 'row-$row',
                'userId': 'u',
                'version': 1,
                'listVisible': true,
                'accountId': 'seller',
                'product': {'name': 'Room $row', 'images': <String>[]},
                'title': 'Notification $row',
                'body': 'Message body',
                'isRead': true,
                'createdAt': DateTime.utc(
                  2026,
                  9,
                  29,
                ).subtract(Duration(seconds: row)).toIso8601String(),
                'updatedAt': '2026-09-29T00:00:00Z',
              };
            }),
            'total': 40,
            'page': page,
            'limit': 20,
            'totalPages': 2,
            'listSnapshot': 'snapshot',
            'listSnapshotExpiresAt': '2099-09-29T00:00:00Z',
            'listState': {'version': 1, 'totalRooms': 40, 'totalUnread': 0},
            'stats': stats,
          });
        };
        final chat = chatEnabled
            ? ChatSyncController(dio, () async => false)
            : null;
        final notifications = notificationEnabled
            ? NotificationSyncController(dio, () async => false)
            : null;
        chat?.configureSession('u', foreground: true);
        notifications?.configureSession('u', foreground: true);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dioProvider.overrideWithValue(dio),
              if (chat != null) chatSyncProvider.overrideWith((ref) => chat),
              if (notifications != null)
                notificationSyncProvider.overrideWith((ref) => notifications),
            ],
            child: MaterialApp(home: scenario.page),
          ),
        );
        if (syncEnabled) {
          for (var i = 0; i < 10 && api.connections.isEmpty; i++) {
            await tester.pump(const Duration(milliseconds: 1));
          }
          api.event('stream.ready', {'schemaVersion': 1, 'cursor': 'head'});
          for (var i = 0; i < 10 && requestedPages.isEmpty; i++) {
            await tester.pump(const Duration(milliseconds: 10));
          }
        }
        await tester.pumpAndSettle();
        expect(
          api.requests
              .where((r) => r.path == path)
              .every((r) => r.queryParameters['limit'] == 20),
          isTrue,
        );
        expect(requestedPages, [1]);
        final scrollable = find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        );
        Finder rowFinder(int row) => scenario.field == 'orders'
            ? find.byWidgetPredicate(
                (widget) =>
                    widget is Padding && widget.key == ValueKey('row-$row'),
              )
            : find.text(
                scenario.field == 'rooms' ? 'Room $row' : 'Notification $row',
              );
        await tester.scrollUntilVisible(
          rowFinder(19),
          300,
          scrollable: scrollable,
        );
        await tester.pumpAndSettle();
        expect(requestedPages, [1, 2]);
        await tester.scrollUntilVisible(
          rowFinder(39),
          300,
          scrollable: scrollable,
        );
        await tester.pumpAndSettle();
        expect(requestedPages, [1, 2]);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        dio.close(force: true);
      },
    );
  }
}
