import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/utils/app_failure.dart';
import 'package:flutter_test/flutter_test.dart';

DioException rejected(
  dynamic body, {
  int status = 500,
  Map<String, List<String>>? headers,
}) => DioException(
  requestOptions: RequestOptions(path: '/private?token=secret'),
  type: DioExceptionType.badResponse,
  response: Response(
    requestOptions: RequestOptions(path: '/private'),
    data: body,
    statusCode: status,
    headers: Headers.fromMap(headers ?? {}),
  ),
);

void main() {
  test(
    'unknown server text, HTML, legacy arrays and arbitrary exceptions never reach copy',
    () {
      for (final source in [
        rejected({'message': 'SELECT password FROM users; token=secret'}),
        rejected('<html>internal proxy /etc/password</html>', status: 502),
        rejected({
          'message': [
            {'field': 'secret', 'message': 'private value'},
          ],
        }, status: 400),
        StateError('secret stack trace'),
      ]) {
        final failure = AppFailure.from(source);
        expect(failure.message, isNot(contains('secret')));
        expect(failure.message, isNot(contains('SELECT')));
        expect(failure.message, isNot(contains('private')));
      }
    },
  );
  test(
    'business code has priority over HTTP status and never implies login for a business 403',
    () {
      final failure = AppFailure.from(
        rejected({
          'code': 'PAYMENT_KEY_MISMATCH',
          'message': 'secret',
        }, status: 403),
      );
      expect(failure.message, contains('結帳已失效'));
      expect(failure.message, isNot(contains('重新登入')));
      expect(failure.kind, FailureKind.forbidden);
    },
  );
  test('connection, timeout and intentional cancellation are distinct', () {
    for (final pair in [
      (DioExceptionType.connectionError, FailureKind.connection),
      (DioExceptionType.receiveTimeout, FailureKind.timeout),
      (DioExceptionType.cancel, FailureKind.canceled),
    ]) {
      expect(
        AppFailure.from(
          DioException(requestOptions: RequestOptions(), type: pair.$1),
        ).kind,
        pair.$2,
      );
    }
  });
  test(
    'approved field codes use local messages, and unknown field messages are ignored',
    () {
      final failure = AppFailure.from(
        rejected({
          'fieldErrors': [
            {
              'field': 'receiver.phone',
              'code': 'INVALID_FORMAT',
              'message': 'secret raw value',
            },
            {'field': 'data.secret', 'code': 'NEW_UNKNOWN', 'message': 'SQL'},
          ],
        }, status: 400),
      );
      expect(failure.fieldErrors.keys, ['receiver.phone']);
      expect(failure.message, '資料格式不正確，請重新確認。');
    },
  );
  test('request reference and legal cooldown formats are retained', () {
    final now = DateTime.utc(2026, 11, 4, 12);
    const reference = '67f4318c-a57e-4e18-bb4e-b5fcc7c048ef';
    final failure = AppFailure.from(
      rejected(
        {'code': 'RATE_LIMITED'},
        status: 429,
        headers: {
          'retry-after': ['30'],
          'x-request-id': [reference],
        },
      ),
      now: now,
    );
    expect(failure.retryAt, now.add(const Duration(seconds: 30)));
    expect(failure.requestId, reference);
    expect(
      AppFailure.parseRetryAfter('Wed, 04 Nov 2026 12:01:00 GMT', now),
      now.add(const Duration(minutes: 1)),
    );
    expect(AppFailure.parseRetryAfter('invalid', now), isNull);
    expect(AppFailure.parseRetryAfter('-2', now), isNull);
    expect(
      AppFailure.from(rejected({'requestId': 'private-token'})).requestId,
      isNull,
    );
  });
  test(
    'mixed-version HTTP 200 failure retains envelope status and unknown code falls back',
    () {
      final failure = AppFailure.from(
        rejected({
          'success': false,
          'statusCode': 503,
          'code': 'NEW_CODE',
          'message': 'secret',
        }, status: 200),
      );
      expect(failure.kind, FailureKind.unavailable);
      expect(failure.statusCode, 503);
      expect(failure.message, '服務暫時無法使用，請稍後再試。');
    },
  );
}
