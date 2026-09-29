import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/features/order/widgets/order_date_filter.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/filter_button.dart';
import 'package:flutter_ad_ecommerce/features/order/widgets/order_date_range_dialog.dart';
import 'package:flutter_ad_ecommerce/pages/order_page.dart';
import 'package:flutter_ad_ecommerce/utils/formatter.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Dio dio;
  late List<RequestOptions> requests;
  var fail = false;
  final now = DateTime.now();
  final selectedDate = DateTime(now.year, now.month, 15);
  final selectedDateText = Formatter.formatDateOnly(selectedDate);

  setUp(() {
    fail = false;
    requests = [];
    dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            if (fail) {
              handler.reject(
                DioException.badResponse(
                  statusCode: 400,
                  requestOptions: options,
                  response: Response(
                    requestOptions: options,
                    statusCode: 400,
                    data: {
                      'message': [
                        {'field': 'endDate', 'message': '日期範圍無效'},
                      ],
                    },
                  ),
                ),
              );
            } else {
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'success': true,
                    'data': {
                      'orders': [],
                      'total': 0,
                      'page': 1,
                      'limit': 20,
                      'totalPages': 0,
                    },
                  },
                ),
              );
            }
          },
        ),
      );
  });

  tearDown(() => dio.close());

  Future<void> openPage(WidgetTester tester) async {
    // Check the compact filter row on a narrow phone.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dioProvider.overrideWithValue(dio)],
        child: const MaterialApp(home: OrderPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> selectRange(WidgetTester tester, String option) async {
    await tester.tap(
      find.descendant(
        of: find.byType(OrderDateFilter),
        matching: find.byType(FilterButton),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text(option));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  Future<void> pickDay(WidgetTester tester, int fieldIndex, int day) async {
    await tester.tap(find.byType(TextField).at(fieldIndex));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.tap(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.text('$day'),
      ),
    );
    await tester.tap(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.text('確定'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Presets, sorting, clearing and readable errors stay in sync', (
    tester,
  ) async {
    await openPage(tester);
    expect(requests.single.queryParameters, {
      'page': 1,
      'limit': 20,
      'order': 'desc',
    });
    expect(find.text('訂單是空的'), findsOneWidget);
    expect(find.text('最近一週'), findsNothing);
    expect(find.text('最近一個月'), findsNothing);
    expect(
      tester.getCenter(find.text('由後往前')).dy,
      tester.getCenter(find.text('選擇日期區間')).dy,
    );

    final beforeWeek = DateTime.now().toUtc();
    await selectRange(tester, '最近一週');
    await tester.pumpAndSettle();
    final weekStart = DateTime.parse(
      requests.last.queryParameters['startDate'],
    );
    final weekEnd = DateTime.parse(requests.last.queryParameters['endDate']);
    expect(weekEnd.isBefore(beforeWeek), isFalse);
    expect(weekEnd.isAfter(DateTime.now().toUtc()), isFalse);
    expect(weekEnd.difference(weekStart), const Duration(days: 7));
    expect(find.text('此期間內沒有訂單'), findsOneWidget);
    final query = requests.last.queryParameters;
    await tester.tap(find.text('由後往前'));
    await tester.pumpAndSettle();
    expect(requests.last.queryParameters, {...query, 'order': 'asc'});

    fail = true;
    final beforeMonth = DateTime.now().toUtc();
    await selectRange(tester, '最近一個月');
    await tester.pumpAndSettle();
    expect(find.text('無法載入訂單：日期範圍無效'), findsOneWidget);
    expect(find.text('日期區間:最近一個月'), findsOneWidget);
    final monthStart = DateTime.parse(
      requests.last.queryParameters['startDate'],
    );
    final monthEnd = DateTime.parse(requests.last.queryParameters['endDate']);
    expect(monthEnd.isBefore(beforeMonth), isFalse);
    expect(monthEnd.isAfter(DateTime.now().toUtc()), isFalse);
    expect(monthEnd.difference(monthStart), const Duration(days: 30));

    fail = false;
    await selectRange(tester, '全部');
    await tester.pumpAndSettle();
    expect(requests.last.queryParameters, {
      'page': 1,
      'limit': 20,
      'order': 'asc',
    });
    expect(find.text('選擇日期區間'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Custom range applies inclusive dates; cancelling preserves the query',
    (tester) async {
      await openPage(tester);
      await selectRange(tester, '自訂');
      await tester.pumpAndSettle();
      expect(find.byType(OrderDateRangeDialog), findsOneWidget);
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(2));
      await pickDay(tester, 0, 15);
      await pickDay(tester, 1, 15);
      await tester.pump();
      await tester.tap(find.text('確定'));
      await tester.pumpAndSettle();
      expect(find.byType(OrderDateRangeDialog), findsNothing);
      expect(
        requests.last.queryParameters['startDate'],
        selectedDate.toUtc().toIso8601String(),
      );
      expect(
        requests.last.queryParameters['endDate'],
        DateTime(now.year, now.month, 16).toUtc().toIso8601String(),
      );
      expect(
        find.text('日期區間:$selectedDateText ~ $selectedDateText'),
        findsOneWidget,
      );

      final count = requests.length;
      await selectRange(tester, '自訂');
      await tester.pumpAndSettle();
      expect(find.text(selectedDateText), findsNWidgets(2));
      await pickDay(tester, 0, 1);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(requests.length, count);
      expect(
        find.text('日期區間:$selectedDateText ~ $selectedDateText'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final startOnly in [true, false]) {
    testWidgets(
      'Custom ${startOnly ? 'start' : 'end'}-only range omits the other API bound',
      (tester) async {
        await openPage(tester);
        await selectRange(tester, '自訂');
        await tester.pumpAndSettle();
        final confirm = find.widgetWithText(ElevatedButton, '確定');
        expect(tester.widget<ElevatedButton>(confirm).onPressed, isNull);
        await pickDay(tester, startOnly ? 0 : 1, 15);
        await tester.pump();
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(requests.last.queryParameters, {
          'page': 1,
          'limit': 20,
          'order': 'desc',
          if (startOnly) 'startDate': selectedDate.toUtc().toIso8601String(),
          if (!startOnly)
            'endDate': DateTime(
              now.year,
              now.month,
              16,
            ).toUtc().toIso8601String(),
        });
        expect(
          find.text(
            startOnly
                ? '日期區間:$selectedDateText ~ 無限制'
                : '日期區間:無限制 ~ $selectedDateText',
          ),
          findsOneWidget,
        );
        final count = requests.length;
        await selectRange(tester, '自訂');
        await tester.pumpAndSettle();
        final fields = tester
            .widgetList<TextField>(find.byType(TextField))
            .toList();
        expect(fields[startOnly ? 0 : 1].controller!.text, selectedDateText);
        expect(fields[startOnly ? 1 : 0].controller!.text, isEmpty);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(requests.length, count);
      },
    );
  }

  testWidgets('Custom dates validate before sending a request', (tester) async {
    await openPage(tester);
    await selectRange(tester, '自訂');
    await tester.pumpAndSettle();
    await pickDay(tester, 0, 16);
    await pickDay(tester, 1, 15);
    await tester.tap(find.text('確定'));
    await tester.pumpAndSettle();
    expect(find.text('結束日期不可早於開始日期'), findsOneWidget);
    expect(requests.length, 1);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(requests.length, 1);
  });

  testWidgets('Date controls remain available during an in-flight request', (
    tester,
  ) async {
    final pending = <(RequestOptions, RequestInterceptorHandler)>[];
    dio.interceptors.clear();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => pending.add((options, handler)),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dioProvider.overrideWithValue(dio)],
        child: const MaterialApp(home: OrderPage()),
      ),
    );
    await tester.pump();
    expect(find.text('載入訂單中......'), findsOneWidget);
    await selectRange(tester, '最近一週');
    await tester.pump();
    expect(find.text('日期區間:最近一週'), findsOneWidget);
    await selectRange(tester, '全部');
    await tester.pump();
    // Flush Dio's queued interceptor timers without settling the loading spinner.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(pending.length, 3);
    for (final (options, handler) in pending) {
      handler.resolve(
        Response(
          requestOptions: options,
          data: {
            'success': true,
            'data': {
              'orders': [],
              'total': 0,
              'page': 1,
              'limit': 20,
              'totalPages': 0,
            },
          },
        ),
      );
    }
    await tester.pumpAndSettle();
    expect(find.text('訂單是空的'), findsOneWidget);
    expect(find.text('選擇日期區間'), findsOneWidget);
  });
}
