import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/models/account_info.dart';
import 'package:flutter_ad_ecommerce/pages/home_page.dart';
import 'package:flutter_ad_ecommerce/provider/account_provider.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/provider/treasure_box_provider.dart';
import 'package:flutter_ad_ecommerce/utils/result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestAccount extends AccountNotifier {
  @override
  AccountInfo build() =>
      AccountInfo.zero().copyWith(termsAcceptedAt: DateTime(2026, 9, 17));

  @override
  Future<Result> refreshAccountInfo() async => Result.success();
}

class _BoxApi {
  _BoxApi({this.reward = 5, this.opened = false});

  final double reward;
  bool opened;
  bool empty = false;
  bool additionalBox = false;
  int openRequests = 0;

  Dio createDio() {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final opening = options.path == '/api/treasureBox/open/box';
          if (opening) {
            expectSync(options.method, 'POST');
            opened = true;
            openRequests++;
          } else {
            expectSync(options.path, '/api/treasureBox/list');
          }
          final row = {
            'id': 'box',
            'userId': 'user',
            'isOpened': opened,
            'isActive': true,
            'coinsAwarded': reward,
            'accountingStatus': opened
                ? 'acquired'
                : reward == 0
                ? 'zero_reward'
                : 'claimable',
            // The refresh may omit this field and derive claimability from accountingStatus.
            if (opening) 'isClaimable': true,
          };
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'success': true,
                'data': opening
                    ? row
                    : [
                        if (!empty) row,
                        if (!empty && additionalBox)
                          {
                            'id': 'another-box',
                            'userId': 'user',
                            'isOpened': false,
                            'isActive': true,
                            'accountingStatus': 'claimable',
                          },
                      ],
              },
            ),
          );
        },
      ),
    );
    return dio;
  }
}

Future<ProviderContainer> _showHome(WidgetTester tester, Dio dio) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(dio),
        accountNotifierProvider.overrideWith(_TestAccount.new),
      ],
      child: const MaterialApp(home: HomePage()),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(HomePage)));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('A new day with no earned boxes shows the no-boxes message', (
    tester,
  ) async {
    final api = _BoxApi()..empty = true;
    final dio = api.createDio();
    addTearDown(() => dio.close());
    final container = await _showHome(tester, dio);

    void expectNoEarnedBoxes() {
      expect(find.text('您尚未獲得寶箱，快去看廣告獲得寶箱吧！'), findsOneWidget);
      expect(find.text('您已開啟所有寶箱！'), findsNothing);
      expect(container.read(claimableTreasureBoxCountProvider), 0);
      expect(container.read(emptyTreasureBoxCountProvider), 10);
      expect(api.openRequests, 0);
    }

    expectNoEarnedBoxes();
    final refresh = container
        .read(treasureBoxNotifierProvider.notifier)
        .loadTreasureBoxes();
    await tester.pumpAndSettle();
    await refresh;
    expectNoEarnedBoxes();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final reward in [5.0, 0.0]) {
    testWidgets(
      'Last opened box keeps all-opened message after refresh and re-entry (reward $reward)',
      (tester) async {
        final api = _BoxApi(reward: reward);
        final dio = api.createDio();
        addTearDown(() => dio.close());
        var container = await _showHome(tester, dio);
        expect(find.text('您有 1 個寶箱可以開啟!'), findsOneWidget);

        await tester.tap(find.text('1'));
        await tester.pumpAndSettle();
        expect(api.openRequests, 1);
        expect(find.text('您已開啟所有寶箱！'), findsOneWidget);

        final refresh = container
            .read(treasureBoxNotifierProvider.notifier)
            .loadTreasureBoxes();
        await tester.pumpAndSettle();
        await refresh;
        expect(
          container.read(treasureBoxNotifierProvider).isDone,
          isTrue,
          reason: container.read(treasureBoxNotifierProvider).toString(),
        );
        final openedBox = container
            .read(treasureBoxNotifierProvider)
            .data!
            .first;
        expect(openedBox.isOpened, isTrue);
        expect(openedBox.isClaimable, isFalse);
        expect(container.read(emptyTreasureBoxCountProvider), 9);
        expect(find.text('您已開啟所有寶箱！'), findsOneWidget);
        expect(find.textContaining('您尚未獲得寶箱'), findsNothing);
        await tester.tap(find.text('1'));
        await tester.pumpAndSettle();
        expect(api.openRequests, 1);

        // A fresh provider scope must derive the same message from the API alone.
        await tester.pumpWidget(const SizedBox.shrink());
        container = await _showHome(tester, dio);
        expect(find.text('您已開啟所有寶箱！'), findsOneWidget);

        // An empty daily response must still show the normal no-boxes message.
        api.empty = true;
        final dailyRefresh = container
            .read(treasureBoxNotifierProvider.notifier)
            .loadTreasureBoxes(keepPreviousData: false);
        await tester.pumpAndSettle();
        await dailyRefresh;
        expect(find.textContaining('您尚未獲得寶箱'), findsOneWidget);
        expect(find.text('您已開啟所有寶箱！'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'An opened box and an unopened box still show the remaining count',
    (tester) async {
      final api = _BoxApi(opened: true)..additionalBox = true;
      final dio = api.createDio();
      addTearDown(() => dio.close());
      final container = await _showHome(tester, dio);
      expect(find.text('您有 1 個寶箱可以開啟!'), findsOneWidget);
      expect(container.read(emptyTreasureBoxCountProvider), 8);
      expect(find.text('您已開啟所有寶箱！'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
