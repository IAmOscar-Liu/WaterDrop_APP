import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/models/account_info.dart';
import 'package:flutter_ad_ecommerce/models/order.dart';
import 'package:flutter_ad_ecommerce/models/product.dart';
import 'package:flutter_ad_ecommerce/models/payment_settings.dart';
import 'package:flutter_ad_ecommerce/pages/payment_settings_page.dart';
import 'package:flutter_ad_ecommerce/provider/account_provider.dart';
import 'package:flutter_ad_ecommerce/provider/order_provider.dart';
import 'package:flutter_ad_ecommerce/provider/system_provider.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:flutter_ad_ecommerce/utils/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestAccount extends AccountNotifier {
  @override
  AccountInfo build() => AccountInfo.zero().copyWith(
    id: 'buyer',
    name: '王小明',
    phone: '0912345678',
    email: 'buyer@example.com',
  );
  void rebuild() => state = state.copyWith(coins: state.coins + 1);
}

Order paid({bool delivery = true}) => Order.fromApiResponseMap({
  'id': 'order',
  'orderStatus': 'paid',
  'deliveries': [
    if (delivery) {'id': 'delivery', 'status': 'pending'},
  ],
});

class TestOrders extends OrderNotifier {
  TestOrders(this.remainIncomplete);
  final bool remainIncomplete;
  int reads = 0;
  int refreshes = 0;
  @override
  Future<Result<Order>> getOrder({required String orderId}) async {
    reads++;
    return Result.success(paid(delivery: !remainIncomplete));
  }

  @override
  Future<void> refreshChatroomsAfterCheckout() async {
    refreshes++;
  }
}

void main() {
  for (final incomplete in [false, true]) {
    testWidgets(
      'Paid checkout returns once and completion dialog remains (incomplete=$incomplete)',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final dio = Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 200,
                    data: {
                      'success': true,
                      'data': {'success': true, 'code': 'VALIDATED'},
                    },
                  ),
                );
              },
            ),
          );
        final orders = TestOrders(incomplete);
        late ProviderContainer container;
        var returns = 0;
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    await context.push(
                      Routes.paymentSettingsPage,
                      extra: {
                        'shippingFee': <String, PaymentSettings>{},
                        'discountCoin': 0.0,
                        'subTotal': 100.0,
                        'cartItems': [
                          CartItem.fromApiResponseMap({
                            'id': 'cart',
                            'productId': 'product',
                            'productVariantId': 'variant',
                            'quantity': 1,
                            'product': {
                              'id': 'product',
                              'name': '虛擬商品',
                              'type': 'virtual',
                              'sellerId': 'seller',
                            },
                          }),
                        ],
                      },
                    );
                    returns++;
                    if (!context.mounted) return;
                    await showDialog<void>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('交易完成'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('完成'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('結帳'),
                ),
              ),
            ),
            GoRoute(
              path: Routes.paymentSettingsPage,
              builder: (_, state) => PaymentSettingsPage(extra: state.extra),
            ),
            GoRoute(
              path: Routes.ecPayPage,
              builder: (context, _) => Scaffold(
                body: Column(
                  children: [
                    TextButton(
                      onPressed: () {
                        container
                            .read(systemNotifierProvider.notifier)
                            .setCurrentOrder(paid(delivery: !incomplete));
                        (container.read(accountNotifierProvider.notifier)
                                as TestAccount)
                            .rebuild();
                      },
                      child: const Text('付款成功回呼'),
                    ),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('返回設定'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dioProvider.overrideWithValue(dio),
              accountNotifierProvider.overrideWith(TestAccount.new),
              orderNotifierProvider.overrideWith(() => orders),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        container = ProviderScope.containerOf(tester.element(find.text('結帳')));
        await tester.tap(find.text('結帳'));
        await tester.pumpAndSettle();
        final next = find.text('下一步，前往付款');
        await tester.ensureVisible(next);
        await tester.tap(next);
        await tester.pumpAndSettle();
        await tester.tap(find.text('確定'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('付款成功回呼'));
        // Rebuild the settings route underneath the payment route several times.
        await tester.pump(const Duration(seconds: 1));
        (container.read(accountNotifierProvider.notifier) as TestAccount)
            .rebuild();
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('返回設定'), findsOneWidget);
        expect(returns, 0);
        expect(orders.reads, 0);
        await tester.tap(find.text('返回設定'));
        if (incomplete) {
          await tester.pump(const Duration(milliseconds: 400));
          for (var i = 0; i < 10; i++) {
            (container.read(accountNotifierProvider.notifier) as TestAccount)
                .rebuild();
            await tester.pump(const Duration(milliseconds: 2600));
          }
        }
        await tester.pumpAndSettle();
        expect(returns, 1);
        expect(orders.reads, incomplete ? 10 : 0);
        expect(orders.refreshes, 1);
        expect(find.text('交易完成'), findsOneWidget);
        (container.read(accountNotifierProvider.notifier) as TestAccount)
            .rebuild();
        await tester.pump(const Duration(seconds: 5));
        expect(find.text('交易完成'), findsOneWidget);
        expect(returns, 1);
        await tester.tap(find.text('完成'));
        await tester.pumpAndSettle();
        expect(find.text('結帳'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        router.dispose();
        dio.close(force: true);
      },
    );
  }
}
