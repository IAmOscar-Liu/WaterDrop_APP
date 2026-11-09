import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/app_constants.dart';
import 'package:flutter_ad_ecommerce/pages/message_page.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/provider/notification_sync_provider.dart';
import 'package:flutter_ad_ecommerce/router/chat_route_observer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../chat/chat_test_support.dart';
import 'notification_sync_test.dart' show notice, counts, page, setup;

Future<(ChatAdapter, NotificationSyncController)> openMessages(
  WidgetTester tester, {
  Future<ResponseBody> Function(RequestOptions)? mutation,
}) async {
  final interval = VisibilityDetectorController.instance.updateInterval;
  VisibilityDetectorController.instance.updateInterval = Duration.zero;
  addTearDown(
    () => VisibilityDetectorController.instance.updateInterval = interval,
  );
  final api = ChatAdapter(eventPath: '/api/notification/events');
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..httpClientAdapter = api;
  final sync = NotificationSyncController(dio, () async => false);
  api.handler = (r) async {
    if (r.method != 'GET') return mutation!(r);
    return jsonResponse(
      r.path.endsWith('/stats')
          ? counts(1, unread: 2)
          : page([notice('a'), notice('b')]),
    );
  };
  final router = GoRouter(
    observers: [chatRouteObserver],
    routes: [GoRoute(path: '/', builder: (_, _) => const MessagePage())],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    dio.close(force: true);
  });
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
  return (api, sync);
}

void main() {
  testWidgets(
    'left swipe reveals choices and read action does not delete',
    (tester) async {
      final (api, sync) = await openMessages(
        tester,
        mutation: (r) async => jsonResponse({
          'notifications': [notice('a', version: 2, read: true)],
          'stats': counts(2),
        }),
      );
      await tester.drag(find.text('通知 a'), const Offset(-220, 0));
      await tester.pumpAndSettle();
      expect(find.text('標為已讀'), findsOneWidget);
      expect(find.text('刪除'), findsOneWidget);
      expect(api.requests.where((r) => r.method != 'GET'), isEmpty);
      await tester.tap(find.text('標為已讀'));
      await tester.pumpAndSettle();
      expect(sync.item('a')!.isRead, isTrue);
      expect(api.requests.where((r) => r.method == 'DELETE'), isEmpty);
      expect(api.requests.singleWhere((r) => r.method == 'POST').data, {
        'notificationIds': ['a'],
      });
      await tester.drag(find.text('通知 a'), const Offset(-220, 0));
      await tester.pumpAndSettle();
      expect(find.text('標為已讀'), findsNothing);
      expect(find.text('已讀'), findsNothing);
      expect(find.text('刪除'), findsOneWidget);
      expect(find.byTooltip('刪除'), findsOneWidget);
      expect(find.byIcon(Icons.mark_email_read_outlined), findsNothing);
      await tester.drag(find.text('通知 b'), const Offset(-220, 0));
      await tester.pumpAndSettle();
      expect(find.text('已讀'), findsNothing);
      expect(find.text('標為已讀'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    skip: !AppConstants.notificationSseEnabled,
  );

  testWidgets(
    'pending read keeps filter colors stable while blocking taps',
    (tester) async {
      final pending = Completer<ResponseBody>();
      final (_, sync) = await openMessages(
        tester,
        mutation: (_) => pending.future,
      );
      final selectedFinder = find.widgetWithText(ElevatedButton, '全部');
      final unselectedFinder = find.widgetWithText(OutlinedButton, '系統通知');
      final unreadFinder = find.widgetWithText(OutlinedButton, '僅顯示未讀');
      final selectedBefore = tester
          .widget<ElevatedButton>(selectedFinder)
          .style!;
      final unselectedBefore = tester
          .widget<OutlinedButton>(unselectedFinder)
          .style!;
      final unreadBefore = tester.widget<OutlinedButton>(unreadFinder).style!;
      await tester.drag(find.text('通知 a'), const Offset(-220, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('標為已讀'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      final selected = tester.widget<ElevatedButton>(selectedFinder);
      final unselected = tester.widget<OutlinedButton>(unselectedFinder);
      final unread = tester.widget<OutlinedButton>(unreadFinder);
      expect(selected.onPressed, isNull);
      expect(unselected.onPressed, isNull);
      expect(unread.onPressed, isNull);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == '編輯訊息',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
      expect(
        selected.style!.backgroundColor!.resolve({WidgetState.disabled}),
        selectedBefore.backgroundColor!.resolve({}),
      );
      expect(
        selected.style!.foregroundColor!.resolve({WidgetState.disabled}),
        selectedBefore.foregroundColor!.resolve({}),
      );
      expect(
        selected.style!.elevation!.resolve({WidgetState.disabled}),
        selectedBefore.elevation!.resolve({}),
      );
      expect(
        unselected.style!.foregroundColor!.resolve({WidgetState.disabled}),
        unselectedBefore.foregroundColor!.resolve({}),
      );
      expect(
        unread.style!.foregroundColor!.resolve({WidgetState.disabled}),
        unreadBefore.foregroundColor!.resolve({}),
      );
      expect(sync.stats!.total, 0);
      pending.complete(
        jsonResponse({
          'notifications': [notice('a', version: 2, read: true)],
          'stats': counts(2, unread: 0),
        }),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<ElevatedButton>(selectedFinder).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
    skip: !AppConstants.notificationSseEnabled,
  );

  testWidgets(
    'batch delete confirms once and sends all selected IDs in one request',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final pending = Completer<ResponseBody>();
      final (api, _) = await openMessages(
        tester,
        mutation: (_) => pending.future,
      );
      await tester.tap(find.byTooltip('編輯訊息'));
      await tester.pumpAndSettle();
      expect(find.text('選取訊息'), findsOneWidget);
      expect(find.text('完成'), findsNothing);
      expect(
        tester.getTopLeft(find.text('全選')).dy,
        greaterThan(tester.getBottomLeft(find.text('僅顯示未讀')).dy),
      );
      expect(
        tester.getTopLeft(find.text('已選取0則')).dx,
        greaterThan(tester.getTopLeft(find.text('全選')).dx),
      );
      await tester.tap(find.text('全選'));
      await tester.pumpAndSettle();
      expect(find.text('已選取2則'), findsOneWidget);
      expect(find.text('全不選'), findsOneWidget);
      await tester.tap(find.text('全不選'));
      await tester.pumpAndSettle();
      expect(find.text('已選取0則'), findsOneWidget);
      await tester.tap(find.text('全選'));
      await tester.pumpAndSettle();
      expect(find.text('已選取2則'), findsOneWidget);
      await tester.tap(find.byTooltip('刪除所選訊息'));
      await tester.pumpAndSettle();
      expect(find.text('確定要刪除這 2 則訊息嗎？'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(api.requests.where((r) => r.method == 'DELETE'), isEmpty);
      expect(find.text('已選取2則'), findsOneWidget);
      await tester.tap(find.byTooltip('刪除所選訊息'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('刪除'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(api.requests.where((r) => r.method == 'DELETE'), hasLength(1));
      expect(
        (api.requests.singleWhere((r) => r.method == 'DELETE').data
            as Map)['notificationIds'],
        unorderedEquals(['a', 'b']),
      );
      expect(find.byTooltip('刪除所選訊息'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == '刪除所選訊息',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('通知 a'), findsNothing);
      expect(find.text('通知 b'), findsNothing);
      expect(find.text('已刪除 2 則訊息'), findsNothing);
      pending.complete(
        jsonResponse({
          'deleted': [
            {'id': 'a', 'version': 2},
            {'id': 'b', 'version': 2},
          ],
          'stats': counts(2, unread: 0),
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('目前沒有訊息'), findsOneWidget);
      expect(find.text('已刪除 2 則訊息'), findsOneWidget);
      expect(find.text('訊息中心'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    skip: !AppConstants.notificationSseEnabled,
  );

  testWidgets(
    'failed optimistic batch restores rows and selection',
    (tester) async {
      final pending = Completer<ResponseBody>();
      await openMessages(tester, mutation: (_) => pending.future);
      await tester.tap(find.byTooltip('編輯訊息'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('全選'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('刪除所選訊息'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('刪除'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('通知 a'), findsNothing);
      expect(find.text('通知 b'), findsNothing);
      expect(find.text('已選取2則'), findsOneWidget);
      pending.complete(jsonResponse({}, status: 500));
      await tester.pumpAndSettle();
      expect(find.text('通知 a'), findsOneWidget);
      expect(find.text('通知 b'), findsOneWidget);
      expect(find.text('已選取2則'), findsOneWidget);
      expect(find.text('選取訊息'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    skip: !AppConstants.notificationSseEnabled,
  );

  testWidgets(
    'failed swipe deletion preserves the row and can be retried',
    (tester) async {
      final (api, _) = await openMessages(
        tester,
        mutation: (_) async => jsonResponse({'message': '請稍後再試'}, status: 503),
      );
      await tester.drag(find.text('通知 a'), const Offset(-220, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('刪除'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(api.requests.where((r) => r.method == 'DELETE'), hasLength(1));
      expect(find.text('通知 a'), findsOneWidget);
      expect(find.text('通知 b'), findsOneWidget);
      expect(find.text('服務暫時無法使用，請稍後再試。'), findsOneWidget);
      await tester.drag(find.text('通知 a'), const Offset(-220, 0));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, '刪除'))
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
    skip: !AppConstants.notificationSseEnabled,
  );

  testWidgets(
    'long press selects without reading and remote deletion prunes selection',
    (tester) async {
      final (api, _) = await openMessages(tester);
      await tester.longPress(find.text('通知 a'));
      await tester.pumpAndSettle();
      expect(find.text('已選取1則'), findsOneWidget);
      await tester.tap(find.text('通知 b'));
      await tester.pumpAndSettle();
      expect(find.text('已選取2則'), findsOneWidget);
      expect(api.requests.where((r) => r.method != 'GET'), isEmpty);
      api.event('notification.deleted', {
        'schemaVersion': 1,
        'notificationId': 'a',
        'version': 2,
        'stats': counts(2),
      }, id: 'deleted-a');
      await tester.pumpAndSettle();
      expect(find.text('已選取1則'), findsOneWidget);
      await tester.tap(find.byTooltip('取消選取'));
      await tester.pumpAndSettle();
      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('訊息中心'), findsOneWidget);
    },
    skip: !AppConstants.notificationSseEnabled,
  );

  test('batch conflict leaves every unrelated message available', () async {
    final (sync, api) = await setup();
    api.handler = (r) async => r.method == 'DELETE'
        ? jsonResponse({'message': 'Notifications not found'}, status: 404)
        : jsonResponse(page([notice('a'), notice('b')]));
    final query = sync.openQuery();
    await sync.loadList(query);
    final result = await sync.deleteMany(['a', 'b', 'a']);
    expect(result.isFailure, isTrue);
    expect(sync.item('a'), isNotNull);
    expect(sync.item('b'), isNotNull);
    expect(sync.deleting('a'), isFalse);
    expect(api.requests.singleWhere((r) => r.method == 'DELETE').data, {
      'notificationIds': ['a', 'b'],
    });
    sync.closeQuery(query);
  });

  test(
    'batch response validates all tombstones before removing any row',
    () async {
      final (sync, api) = await setup();
      api.handler = (r) async => r.method == 'DELETE'
          ? jsonResponse({
              'deleted': [
                {'id': 'a', 'version': 2},
              ],
              'stats': counts(2),
            })
          : jsonResponse(page([notice('a'), notice('b')]));
      final query = sync.openQuery();
      await sync.loadList(query);
      expect((await sync.deleteMany(['a', 'b'])).isFailure, isTrue);
      expect(sync.listValue(query).data!.messages, hasLength(2));
      sync.closeQuery(query);
    },
  );
}
