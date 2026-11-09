import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/provider/message_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../chat/chat_test_support.dart';
import '../notification/notification_sync_test.dart' show notice, counts, page;

void main() {
  for (final success in [false, true]) {
    test(
      'legacy batch delete restores rows only when deletion fails (success=$success)',
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
        var attempted = false;
        api.handler = (r) async {
          if (r.method == 'DELETE') {
            attempted = true;
            return success
                ? jsonResponse({'deletedCount': 2})
                : jsonResponse({'message': 'failed'}, status: 503);
          }
          if (r.path.endsWith('/stats')) {
            return jsonResponse(counts(2, unread: success ? 0 : 2));
          }
          // A refresh error after a committed deletion must not restore removed rows.
          if (attempted) {
            return jsonResponse({'message': 'refresh failed'}, status: 503);
          }
          return jsonResponse(page([notice('a'), notice('b')]));
        };
        final notifier = container.read(messageNotifierProvider.notifier);
        await notifier.loadMessages();
        final result = await notifier.deleteMessages(['a', 'b', 'a']);
        expect(result.isSuccess, success);
        expect(
          container
              .read(messageNotifierProvider)
              .data!
              .messages
              .map((m) => m.id),
          success ? isEmpty : ['a', 'b'],
        );
        expect(api.requests.singleWhere((r) => r.method == 'DELETE').data, {
          'notificationIds': ['a', 'b'],
        });
        await settle();
      },
    );
  }
}
