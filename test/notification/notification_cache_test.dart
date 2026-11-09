import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/models/api_enums.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/provider/message_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../chat/chat_test_support.dart';
import 'notification_sync_test.dart' show setup, counts, page, notice;

void main() {
  test(
    'categories, unread and search retain separate cached queries and pages',
    () async {
      final (sync, api) = await setup();
      api.handler = (r) async => jsonResponse(
        page(
          [notice('a'), notice('b', type: 'order_status')],
          current: r.queryParameters['page'] as int,
          pages: 2,
        ),
      );
      final all = sync.openQuery();
      await sync.loadList(all, reuseExisting: true);
      await sync.loadList(all, more: true);
      sync.closeQuery(all);
      final order = sync.openQuery(type: NotificationType.orderStatus);
      await sync.loadList(order, reuseExisting: true);
      sync.closeQuery(order);
      final unread = sync.openQuery(onlyUnread: true);
      await sync.loadList(unread, reuseExisting: true);
      sync.closeQuery(unread);
      final searched = sync.openQuery(search: 'test');
      await sync.loadList(searched, reuseExisting: true);
      sync.closeQuery(searched);
      final before = api.requests.length;
      for (final q in [
        sync.openQuery(),
        sync.openQuery(type: NotificationType.orderStatus),
        sync.openQuery(onlyUnread: true),
        sync.openQuery(search: 'test'),
      ]) {
        await sync.loadList(q, reuseExisting: true);
        expect(q.loaded, isTrue);
        if (q.type == null && q.search.isEmpty && !q.onlyUnread) {
          expect(q.page, 2);
        }
        sync.closeQuery(q);
      }
      expect(api.requests, hasLength(before));
    },
  );

  test(
    'each query expires after ten minutes without extending on reuse or pagination',
    () async {
      var now = DateTime.utc(2026, 11, 4);
      final (sync, api) = await setup(now: () => now);
      api.handler = (r) async => jsonResponse(
        page([], current: r.queryParameters['page'] as int, pages: 2),
      );
      var all = sync.openQuery();
      await sync.loadList(all);
      sync.closeQuery(all);
      now = now.add(const Duration(minutes: 5));
      var order = sync.openQuery(type: NotificationType.orderStatus);
      await sync.loadList(order);
      sync.closeQuery(order);
      now = now.add(const Duration(minutes: 4));
      all = sync.openQuery();
      final before = api.requests.length;
      await sync.loadList(all, reuseExisting: true);
      expect(api.requests, hasLength(before));
      await sync.loadList(all, more: true);
      sync.closeQuery(all);
      now = now.add(const Duration(minutes: 1));
      all = sync.openQuery();
      expect(all.loaded, isFalse);
      await sync.loadList(all, reuseExisting: true);
      expect(api.requests, hasLength(before + 2));
      order = sync.openQuery(type: NotificationType.orderStatus);
      await sync.loadList(order, reuseExisting: true);
      expect(api.requests, hasLength(before + 2));
      sync.closeQuery(all);
      sync.closeQuery(order);
    },
  );

  test(
    'cached categories receive reads, deletions and new notifications',
    () async {
      final (sync, api) = await setup();
      api.handler = (r) async {
        if (r.method == 'POST') {
          return jsonResponse({
            'notifications': [notice('a', read: true, version: 2)],
            'stats': counts(2),
          });
        }
        if (r.method == 'DELETE') {
          return jsonResponse({
            'deleted': [
              {'id': 'b', 'version': 2},
            ],
            'stats': counts(3),
          });
        }
        return jsonResponse(page([notice('a'), notice('b')]));
      };
      final all = sync.openQuery();
      await sync.loadList(all);
      sync.closeQuery(all);
      final unread = sync.openQuery(onlyUnread: true);
      await sync.loadList(unread);
      sync.closeQuery(unread);
      expect((await sync.markRead('a')).isSuccess, isTrue);
      expect((await sync.deleteMany(['b'])).isSuccess, isTrue);
      api.event('notification.created', {
        'schemaVersion': 1,
        'notification': notice('c'),
        'stats': counts(4),
      }, id: 'created-c');
      await settle();
      final before = api.requests.length;
      final restored = sync.openQuery();
      await sync.loadList(restored, reuseExisting: true);
      expect(
        sync.messages(restored).map((m) => m.id),
        unorderedEquals(['a', 'c']),
      );
      expect(sync.item('a')!.isRead, isTrue);
      final restoredUnread = sync.openQuery(onlyUnread: true);
      await sync.loadList(restoredUnread, reuseExisting: true);
      expect(sync.messages(restoredUnread).map((m) => m.id), ['c']);
      expect(api.requests, hasLength(before));
      sync.closeQuery(restored);
      sync.closeQuery(restoredUnread);
    },
  );

  test(
    'search cache becomes dirty after an event and logout removes all caches',
    () async {
      final (sync, api) = await setup();
      api.handler = (_) async => jsonResponse(page([notice('a')]));
      final q = sync.openQuery(search: 'test');
      await sync.loadList(q);
      sync.closeQuery(q);
      api.event('notification.updated', {
        'schemaVersion': 1,
        'notification': notice('a', read: true, version: 2),
        'stats': counts(2),
      }, id: 'updated-a');
      await settle();
      final before = api.requests.length;
      final restored = sync.openQuery(search: 'test');
      await sync.loadList(restored, reuseExisting: true);
      expect(api.requests, hasLength(before + 1));
      sync.closeQuery(restored);
      sync.configureSession(null, foreground: false);
      final afterLogout = sync.openQuery(search: 'test');
      expect(afterLogout.loaded, isFalse);
      expect(sync.item('a'), isNull);
      sync.closeQuery(afterLogout);
    },
  );

  test(
    'legacy cache reuses categories and invalidates all after a read',
    () async {
      final api = ChatAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = api;
      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      addTearDown(() {
        container.dispose();
        dio.close(force: true);
      });
      api.handler = (r) async => jsonResponse(
        r.path.endsWith('/stats')
            ? counts(1)
            : r.method == 'POST'
            ? {}
            : page([notice('a')]),
      );
      final notifier = container.read(messageNotifierProvider.notifier);
      await notifier.loadMessages(reuseExisting: true);
      await notifier.loadMessages(
        type: NotificationType.orderStatus,
        reuseExisting: true,
      );
      await notifier.loadMessages(reuseExisting: true);
      expect(api.requests.where((r) => r.path.endsWith('/list')), hasLength(2));
      expect((await notifier.markAsRead('a')).isSuccess, isTrue);
      final before = api.requests.where((r) => r.path.endsWith('/list')).length;
      await notifier.loadMessages(
        type: NotificationType.orderStatus,
        reuseExisting: true,
      );
      expect(
        api.requests.where((r) => r.path.endsWith('/list')),
        hasLength(before + 1),
      );
      await settle();
    },
  );
}
