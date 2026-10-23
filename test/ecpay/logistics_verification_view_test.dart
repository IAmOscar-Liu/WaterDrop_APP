import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/features/ecpay/widget/logistics_verification_view.dart';
import 'package:flutter_ad_ecommerce/models/account_info.dart';
import 'package:flutter_ad_ecommerce/models/payment_settings.dart';
import 'package:flutter_ad_ecommerce/models/product.dart';
import 'package:flutter_ad_ecommerce/pages/payment_settings_page.dart';
import 'package:flutter_ad_ecommerce/provider/account_provider.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/router/chat_route_observer.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logistics_verification_result_test.dart' show validatedBody;

class TestAccount extends AccountNotifier {
  @override
  AccountInfo build() => AccountInfo.zero().copyWith(
    id: 'buyer',
    oauthId: 'oauth',
    name: '王小明',
    phone: '0912345678',
    email: 'buyer@example.com',
  );
  void change(AccountInfo account) => state = account;
}

class PendingRequest {
  PendingRequest(this.options, this.handler);
  final RequestOptions options;
  final RequestInterceptorHandler handler;
  void reply(Object? body, {int status = 200, Headers? headers}) {
    handler.resolve(
      Response(
        requestOptions: options,
        statusCode: status,
        data: body,
        headers: headers,
      ),
    );
  }

  void fail(DioExceptionType type) =>
      handler.reject(DioException(requestOptions: options, type: type));
}

class Harness {
  final requests = <PendingRequest>[];
  final dio = Dio();
  final navigator = GlobalKey<NavigatorState>();
  final type = ValueNotifier('C2C');
  late ProviderContainer container;
  int successes = 0;
  int edits = 0;
  int backs = 0;

  Harness() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(PendingRequest(options, handler));
        },
      ),
    );
    addTearDown(() => dio.close(force: true));
    addTearDown(type.dispose);
  }

  Future<void> show(WidgetTester tester, {bool realPage = false}) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(dio),
          accountNotifierProvider.overrideWith(TestAccount.new),
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [chatRouteObserver],
          home: realPage
              ? PaymentSettingsPage(
                  extra: {
                    'shippingFee': <String, PaymentSettings>{},
                    'discountCoin': 0,
                    'cartItems': <CartItem>[],
                    'subTotal': 0.0,
                  },
                )
              : Scaffold(
                  body: ValueListenableBuilder(
                    valueListenable: type,
                    builder: (context, value, _) => LogisticsVerificationView(
                      logisticsType: value,
                      onSuccess: () => successes++,
                      onBack: () => backs++,
                      onEdit: () => edits++,
                    ),
                  ),
                ),
        ),
      ),
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(LogisticsVerificationView)),
    );
    await waitForRequests(tester, 1);
  }

  Future<void> waitForRequests(WidgetTester tester, int count) async {
    for (var i = 0; i < 10 && requests.length < count; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  TestAccount get account =>
      container.read(accountNotifierProvider.notifier) as TestAccount;
  AccountInfo get receiver => container.read(accountNotifierProvider);
}

void main() {
  testWidgets(
    'Starts one authenticated-client POST outside build, explicit success advances',
    (tester) async {
      final h = Harness();
      await h.show(tester);
      expect(h.requests.length, 1);
      final request = h.requests.single;
      expect(request.options.method, 'POST');
      expect(request.options.path, '/api/ecpay/express/test/validate');
      expect(request.options.queryParameters, isEmpty);
      expect(request.options.receiveTimeout, const Duration(seconds: 30));
      expect(request.options.cancelToken, isNotNull);
      expect(request.options.data, {
        'type': 'C2C',
        'ReceiverName': '王小明',
        'ReceiverCellPhone': '0912345678',
        'ReceiverEmail': 'buyer@example.com',
      });
      expect(find.byType(InAppWebView), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      h.account.change(h.receiver.copyWith(coins: 100));
      await tester.pump();
      expect(h.requests.length, 1);
      request.reply(validatedBody());
      await tester.pump();
      expect(h.successes, 1);
    },
  );

  testWidgets('Failure allows one manual retry and blocks repeated taps', (
    tester,
  ) async {
    final h = Harness();
    await h.show(tester);
    h.requests.single.reply({
      'success': true,
      'data': {'success': false, 'code': 'PROVIDER_REJECTED'},
    });
    await tester.pumpAndSettle();
    expect(h.successes, 0);
    expect(find.textContaining('綠界未接受'), findsOneWidget);
    expect(find.text('修改寄貨資料'), findsOneWidget);
    final retry = tester
        .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, '重試'))
        .onPressed!;
    retry();
    retry();
    await h.waitForRequests(tester, 2);
    expect(h.requests.length, 2);
    h.requests.last.reply(validatedBody());
    await tester.pump();
    expect(h.successes, 1);
  });

  testWidgets(
    '429 keeps retry disabled for Retry-After and never retries automatically',
    (tester) async {
      final h = Harness();
      await h.show(tester);
      h.requests.single.reply(
        {'success': false, 'code': 'LOGISTICS_VERIFICATION_LIMIT'},
        status: 429,
        headers: Headers.fromMap({
          'retry-after': ['60'],
        }),
      );
      await tester.pump();
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      await tester.pump(const Duration(seconds: 59));
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(h.requests.length, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
      );
      expect(h.requests.length, 1);
    },
  );

  for (final edit in [
    'name',
    'phone',
    'email',
    'type',
    'account',
    'logout and back',
  ]) {
    testWidgets('$edit cancels pending verification and rejects late success', (
      tester,
    ) async {
      final h = Harness();
      await h.show(tester);
      final original = h.receiver;
      switch (edit) {
        case 'name':
          h.account.change(original.copyWith(name: '王小華'));
        case 'phone':
          h.account.change(original.copyWith(phone: '0987654321'));
        case 'email':
          h.account.change(original.copyWith(email: 'new@example.com'));
        case 'type':
          h.type.value = 'B2C';
        case 'account':
          h.account.change(original.copyWith(id: 'other'));
        case 'logout and back':
          h.account.change(AccountInfo.zero());
          h.account.change(original);
      }
      await tester.pump();
      expect(h.requests.first.options.cancelToken!.isCancelled, isTrue);
      h.requests.first.reply(validatedBody());
      await tester.pumpAndSettle();
      expect(h.successes, 0);
      final retry = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      if (edit == 'account' || edit == 'logout and back') {
        expect(retry.onPressed, isNull);
      } else {
        retry.onPressed!();
        await h.waitForRequests(tester, 2);
        expect(h.requests.length, 2);
        expect(h.requests.last.options.data['ReceiverName'], h.receiver.name);
        expect(h.requests.last.options.data['type'], h.type.value);
        h.requests.last.reply(validatedBody());
        await tester.pump();
        expect(h.successes, 1);
      }
    });
  }

  testWidgets('Navigating away cancels; returning requires manual retry', (
    tester,
  ) async {
    final h = Harness();
    await h.show(tester);
    h.navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Other page')),
      ),
    );
    await tester.pumpAndSettle();
    expect(h.requests.single.options.cancelToken!.isCancelled, isTrue);
    h.requests.single.reply(validatedBody());
    await tester.pump();
    h.navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(h.successes, 0);
    expect(h.requests.length, 1);
    expect(find.text('重試'), findsOneWidget);
  });

  testWidgets('Back and disposal cancel without late navigation', (
    tester,
  ) async {
    final h = Harness();
    await h.show(tester);
    await tester.tap(find.text('返回購物車'));
    expect(h.backs, 1);
    expect(h.requests.single.options.cancelToken!.isCancelled, isTrue);
    await tester.pumpWidget(const SizedBox());
    h.requests.single.reply(validatedBody());
    await tester.pump();
    expect(h.successes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Disposal alone cancels the request and ignores late results', (
    tester,
  ) async {
    final h = Harness();
    await h.show(tester);
    await tester.pumpWidget(const SizedBox());
    expect(h.requests.single.options.cancelToken!.isCancelled, isTrue);
    h.requests.single.reply(validatedBody());
    await tester.pump();
    expect(h.successes, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('An older response cannot finish a newer receiver attempt', (
    tester,
  ) async {
    final h = Harness();
    await h.show(tester);
    h.account.change(h.receiver.copyWith(name: '王小華'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重試'));
    await h.waitForRequests(tester, 2);
    h.requests.first.reply(validatedBody());
    await tester.pump();
    expect(h.successes, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    h.requests.last.reply(validatedBody());
    await tester.pump();
    expect(h.successes, 1);
  });

  testWidgets('Timeout stays blocked and edit is available', (tester) async {
    final h = Harness();
    await h.show(tester);
    h.requests.single.fail(DioExceptionType.receiveTimeout);
    await tester.pumpAndSettle();
    expect(find.textContaining('尚無法確認結果'), findsOneWidget);
    await tester.tap(find.text('修改寄貨資料'));
    expect(h.edits, 1);
    expect(h.successes, 0);
    expect(h.requests.length, 1);
  });

  testWidgets(
    'Actual checkout settings stays blocked then advances only on VALIDATED',
    (tester) async {
      final h = Harness();
      await h.show(tester, realPage: true);
      final request = h.requests.singleWhere(
        (r) => r.options.path == '/api/ecpay/express/test/validate',
      );
      expect(find.text('下一步，前往付款'), findsNothing);
      expect(find.byType(InAppWebView), findsNothing);
      request.reply({
        'success': true,
        'data': {'success': false, 'code': 'PROVIDER_REJECTED'},
      });
      await tester.pumpAndSettle();
      expect(find.text('下一步，前往付款'), findsNothing);
      expect(find.byType(LogisticsVerificationView), findsOneWidget);
      await tester.tap(find.text('重試'));
      await h.waitForRequests(tester, 2);
      h.requests.last.reply(validatedBody());
      await tester.pumpAndSettle();
      expect(find.byType(LogisticsVerificationView), findsNothing);
      expect(find.text('下一步，前往付款'), findsOneWidget);
    },
  );
}
