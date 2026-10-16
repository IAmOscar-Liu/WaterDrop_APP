import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/provider/account_provider.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/provider/system_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../chat/chat_test_support.dart' show ChatAdapter, jsonResponse, settle;

void main() {
  test(
    'REST auth retry uses persisted token and preserves idempotency body',
    () async {
      late ProviderContainer container;
      var refreshes = 0;
      container = ProviderContainer(
        overrides: [
          chatTokenRefreshProvider.overrideWithValue(() async {
            refreshes++;
            container
                .read(systemNotifierProvider.notifier)
                .setAccessToken('new-token');
            return true;
          }),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(systemNotifierProvider.notifier)
          .setAccessToken('old-token');
      final dio = container.read(dioProvider);
      final api = ChatAdapter();
      dio.httpClientAdapter = api;
      api.handler = (r) async =>
          r.headers['Authorization'] == 'Bearer old-token'
          ? jsonResponse({'message': 'expired'}, status: 401)
          : jsonResponse({'id': 'message'});
      final response = await dio
          .post(
            '/api/chatroom/sync/message/a',
            data: {'clientMessageId': 'stable-key', 'content': 'hello'},
          )
          .timeout(const Duration(seconds: 2));
      expect(response.data['success'], isTrue);
      expect(refreshes, 1);
      expect(api.requests, hasLength(2));
      expect(api.requests.last.headers['Authorization'], 'Bearer new-token');
      expect(api.requests.last.data['clientMessageId'], 'stable-key');
    },
  );

  test(
    '401 from an old account is never retried using the next account',
    () async {
      var refreshes = 0;
      final container = ProviderContainer(
        overrides: [
          chatTokenRefreshProvider.overrideWithValue(() async {
            refreshes++;
            return true;
          }),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(systemNotifierProvider.notifier)
          .setAccessToken('old-token');
      final dio = container.read(dioProvider);
      final api = ChatAdapter();
      dio.httpClientAdapter = api;
      final response = Completer<ResponseBody>();
      api.handler = (_) => response.future;
      final request = dio.post(
        '/api/chatroom/sync/message/a',
        data: {'content': 'private'},
      );
      final expectation = expectLater(request, throwsA(isA<DioException>()));
      await settle();
      container.read(accountNotifierProvider.notifier).reset();
      container
          .read(systemNotifierProvider.notifier)
          .setAccessToken('other-user-token');
      response.complete(jsonResponse({'message': 'expired'}, status: 401));
      await expectation;
      expect(refreshes, 0);
      expect(api.requests, hasLength(1));
    },
  );
}
