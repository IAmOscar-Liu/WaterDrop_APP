import 'package:dio/dio.dart';
import 'package:flutter_ad_ecommerce/features/ecpay/logistics_verification_result.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> validatedBody() => {
  'success': true,
  'data': {
    'verificationId': 'correlation-id',
    'success': true,
    'code': 'VALIDATED',
    'providerCode': '300',
  },
};

Response<dynamic> response(
  Object? body, {
  int status = 200,
  Headers? headers,
}) => Response(
  requestOptions: RequestOptions(path: '/api/ecpay/express/test/validate'),
  statusCode: status,
  data: body,
  headers: headers,
);

void main() {
  test(
    'An exception never unlocks checkout even if it contains a success body',
    () {
      final reply = response(validatedBody());
      expect(
        LogisticsVerificationResult.fromError(
          DioException(requestOptions: reply.requestOptions, response: reply),
        ).validated,
        isFalse,
      );
    },
  );

  test(
    'Only explicit HTTP 200 and both successful flags and VALIDATED pass',
    () {
      expect(
        LogisticsVerificationResult.fromResponse(
          response(validatedBody()),
        ).validated,
        isTrue,
      );
      for (final status in [201, 400, 401, 403, 404, 429, 500, 502, 503, 504]) {
        expect(
          LogisticsVerificationResult.fromResponse(
            response(validatedBody(), status: status),
          ).validated,
          isFalse,
        );
      }
      for (final body in [
        null,
        '<html>success</html>',
        {},
        {'success': true},
        {...validatedBody(), 'success': false},
        {...validatedBody(), 'success': 'true'},
        {
          'success': true,
          'data': {'code': 'VALIDATED'},
        },
        {
          'success': true,
          'data': {'success': true},
        },
        {
          'success': true,
          'data': {'success': 'true', 'code': 'VALIDATED'},
        },
        {
          'success': true,
          'data': {'success': false, 'code': 'VALIDATED'},
        },
        {
          'success': true,
          'data': {'success': true, 'code': 'PENDING'},
        },
        {
          'success': true,
          'data': {'success': true, 'providerCode': '300'},
        },
        {'RtnCode': '300', 'RtnMsg': 'success'},
      ]) {
        expect(
          LogisticsVerificationResult.fromResponse(response(body)).validated,
          isFalse,
        );
      }
    },
  );

  test('400 legacy field strings use safe local feedback', () {
    final result = LogisticsVerificationResult.fromResponse(
      response({
        'success': false,
        'message': [
          {'field': 'ReceiverName', 'message': '姓名長度不符'},
          {'field': 'ReceiverCellPhone', 'message': '手機格式不符'},
          {'field': 'ReceiverEmail', 'message': '電子郵件格式不符'},
        ],
      }, status: 400),
    );
    expect(result.message, '收件資料不完整或格式不正確，請確認後再試。');
    expect(result.validated, isFalse);
  });

  test('Provider rejection never exposes raw data or blames the recipient', () {
    final result = LogisticsVerificationResult.fromResponse(
      response({
        'success': true,
        'data': {
          'success': false,
          'code': 'PROVIDER_REJECTED',
          'message': 'sensitive raw text',
        },
      }),
    );
    expect(result.validated, isFalse);
    expect(result.message, contains('綠界未接受'));
    expect(result.message, isNot(contains('sensitive')));
  });

  for (final seconds in ['60', '90', 'bad', '-1']) {
    test('429 honors Retry-After $seconds or defaults to 60 seconds', () {
      final result = LogisticsVerificationResult.fromResponse(
        response(
          {},
          status: 429,
          headers: Headers.fromMap({
            'retry-after': [seconds],
          }),
        ),
      );
      expect(result.retryAfterSeconds, seconds == '90' ? 90 : 60);
    });
  }

  for (final type in [
    DioExceptionType.receiveTimeout,
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.connectionError,
    DioExceptionType.cancel,
  ]) {
    test('Transport failure $type blocks without leaking request details', () {
      final result = LogisticsVerificationResult.fromError(
        DioException(
          requestOptions: RequestOptions(path: 'sensitive-path'),
          type: type,
        ),
      );
      expect(result.validated, isFalse);
      expect(result.message, isNot(contains('sensitive-path')));
    });
  }
}
