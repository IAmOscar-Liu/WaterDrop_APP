import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/models/account_info.dart';
import 'package:flutter_ad_ecommerce/pages/account_delivery_page.dart';
import 'package:flutter_ad_ecommerce/pages/bank_search_page.dart';
import 'package:flutter_ad_ecommerce/provider/account_provider.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import '../chat/chat_test_support.dart' show ChatAdapter, jsonResponse;

class _Account extends AccountNotifier {
  @override
  AccountInfo build() => AccountInfo.fromApiResponseMap({
    'id': 'u',
    'bankCode': '004',
    'bankName': '臺灣銀行',
    'bankAccount': '12345678',
  });
}

void main() {
  testWidgets(
    'delivery bank selection searches code/name and preserves selection on cancel',
    (tester) async {
      final api = ChatAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = api;
      api.handler = (_) async => jsonResponse([
        {'code': '004', 'name': '臺灣銀行'},
        {'code': '808', 'name': '玉山銀行'},
        {'code': '812', 'name': '台新銀行'},
      ]);
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const AccountDeliveryPage()),
          GoRoute(
            path: Routes.bankSearch,
            builder: (_, s) => BankSearchPage(selectedCode: s.extra as String?),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dioProvider.overrideWithValue(dio),
            accountNotifierProvider.overrideWith(_Account.new),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      final selector = find.widgetWithText(TextFormField, '銀行代碼 / 銀行名稱');
      await tester.ensureVisible(selector);
      await tester.tap(selector);
      await tester.pumpAndSettle();
      expect(find.byType(BankSearchPage), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      await tester.enterText(find.byType(TextField), '008');
      await tester.pumpAndSettle();
      expect(find.text('沒有符合的銀行'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '808');
      await tester.pumpAndSettle();
      expect(find.text('808 玉山銀行'), findsOneWidget);
      expect(find.text('004 臺灣銀行'), findsNothing);
      await tester.enterText(find.byType(TextField), '玉山');
      await tester.pumpAndSettle();
      await tester.tap(find.text('808 玉山銀行'));
      await tester.pumpAndSettle();
      expect(find.text('808 玉山銀行'), findsOneWidget);
      expect(find.text('12345678'), findsOneWidget);
      await tester.ensureVisible(selector);
      await tester.tap(selector);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '台新');
      await tester.pumpAndSettle();
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('808 玉山銀行'), findsOneWidget);
      expect(
        api.requests.where((r) => r.path == '/api/system/bank-list'),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      dio.close(force: true);
    },
  );

  testWidgets('bank search retries a failed directory load', (tester) async {
    final api = ChatAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = api;
    var failed = true;
    api.handler = (_) async => failed
        ? jsonResponse({'message': 'offline'}, status: 503)
        : jsonResponse([
            {'code': '004', 'name': '臺灣銀行'},
          ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dioProvider.overrideWithValue(dio)],
        child: const MaterialApp(home: BankSearchPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('銀行資料載入失敗，點擊重試'), findsOneWidget);
    failed = false;
    await tester.tap(find.text('銀行資料載入失敗，點擊重試'));
    await tester.pumpAndSettle();
    expect(find.text('004 臺灣銀行'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    dio.close(force: true);
  });
}
