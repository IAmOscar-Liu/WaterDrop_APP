import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/utils/app_failure.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../chat/chat_test_support.dart';

void main() {
  test(
    'shared client rejects legacy HTTP-200 failures but preserves successful negative checkout evaluations',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final api = ChatAdapter();
      final dio = container.read(dioProvider)..httpClientAdapter = api;
      api.handler = (_) async => ResponseBody.fromString(
        '{"success":false,"statusCode":503,"code":"SERVICE_UNAVAILABLE","message":"secret"}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
      final options = Options(extra: {'requiresAuth': false});
      try {
        await dio.get('/test', options: options);
        fail('Expected failure envelope rejection');
      } on DioException catch (error) {
        expect(AppFailure.from(error).statusCode, 503);
        expect(AppFailure.from(error).message, isNot(contains('secret')));
      }
      api.handler = (_) async =>
          jsonResponse({'canCheckout': false, 'issues': []});
      final result = await dio.get('/test', options: options);
      expect(result.data['data']['canCheckout'], isFalse);
      expect(api.requests, hasLength(2));
    },
  );
}
