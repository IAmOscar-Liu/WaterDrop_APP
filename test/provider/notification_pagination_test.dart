import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/provider/message_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final operation in ['read', 'delete']) {
    for (final count in [41, 65]) {
      test(
        '$operation refreshes loaded pages in batches of 20 with total $count',
        () async {
          final ids = List.generate(count, (index) => 'message-$index');
          final queries = <Map<String, dynamic>>[];
          final dio = Dio()
            ..interceptors.add(
              InterceptorsWrapper(
                onRequest: (options, handler) {
                  dynamic payload = <String, dynamic>{};
                  if (options.path == '/api/notification/list') {
                    queries.add(Map.of(options.queryParameters));
                    final page = options.queryParameters['page'] as int;
                    final limit = options.queryParameters['limit'] as int;
                    final start = min((page - 1) * limit, ids.length);
                    payload = {
                      'notifications': ids
                          .sublist(start, min(start + limit, ids.length))
                          .map((id) => {'id': id})
                          .toList(),
                      'total': ids.length,
                      'page': page,
                      'limit': limit,
                      'totalPages': (ids.length / limit).ceil(),
                    };
                  } else if (options.path == '/api/notification' ||
                      options.path == '/api/notification/mark-as-read') {
                    // Both actions remove the first row from an unread-only query.
                    ids.removeAt(0);
                  }
                  handler.resolve(
                    Response(
                      requestOptions: options,
                      data: {'success': true, 'data': payload},
                    ),
                  );
                },
              ),
            );
          final container = ProviderContainer(
            overrides: [dioProvider.overrideWithValue(dio)],
          );
          addTearDown(container.dispose);
          addTearDown(() => dio.close());
          final notifier = container.read(messageNotifierProvider.notifier);
          await notifier.loadMessages(search: 'test', onlyUnread: true);
          await notifier.fetchMoreMessages();
          if (count == 41) await notifier.fetchMoreMessages();
          queries.clear();

          final result = operation == 'read'
              ? await notifier.markAsRead('message-0')
              : await notifier.deleteMessage('message-0');
          expect(result.isSuccess, isTrue);
          expect(queries.map((q) => q['page']), [1, 2]);
          expect(
            queries.every(
              (q) =>
                  q['limit'] == 20 &&
                  q['search'] == 'test' &&
                  q['onlyUnread'] == true,
            ),
            isTrue,
          );
          final refreshed = container.read(messageNotifierProvider).data!;
          expect(refreshed.messages.length, 40);
          expect(refreshed.total, count - 1);
          expect(refreshed.totalPages, count == 41 ? 2 : 4);
          expect(refreshed.page, 2);
          await notifier.fetchMoreMessages();
          expect(
            queries.map((q) => q['page']),
            count == 41 ? [1, 2] : [1, 2, 3],
          );
          expect(queries.every((q) => q['limit'] == 20), isTrue);
        },
      );
    }
  }
}
