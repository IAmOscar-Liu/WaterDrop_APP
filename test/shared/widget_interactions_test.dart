import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/models/account_info.dart';
import 'package:flutter_ad_ecommerce/shared/layouts/app_scaffold.dart';
import 'package:flutter_ad_ecommerce/shared/layouts/draggable_details_sheet.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/filter_button.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/receiver_info_panel.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/search_filter_button.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Search filter forwards the current query after updates', (
    tester,
  ) async {
    String? selectedQuery;
    for (final query in ['', '茶葉']) {
      await tester.pumpWidget(
        MaterialApp(
          home: AppScaffold(
            body: SearchFilterButton(
              query: query,
              onSelect: (value) => selectedQuery = value,
            ),
          ),
        ),
      );
      await tester.tap(find.text(query.isEmpty ? '關鍵字搜尋' : '搜尋：$query'));
      expect(selectedQuery, query);
    }
  });

  testWidgets('Filter can toggle selection without losing its callback', (
    tester,
  ) async {
    var selected = false;
    await tester.pumpWidget(
      MaterialApp(
        home: AppScaffold(
          body: StatefulBuilder(
            builder: (context, setState) => FilterButton(
              isSelected: selected,
              onPressed: () => setState(() => selected = !selected),
              icon: selected ? const Icon(Icons.check) : null,
              child: const Text('Unread'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Unread'));
    await tester.pump();
    expect(selected, isTrue);
    expect(find.byIcon(Icons.check), findsOneWidget);
    await tester.tap(find.text('Unread'));
    await tester.pump();
    expect(selected, isFalse);
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets(
    'Receiver details update from missing to populated account data',
    (tester) async {
      final emptyAccount = AccountInfo.zero();
      Future<void> showAccount(AccountInfo account) => tester.pumpWidget(
        MaterialApp(
          home: AppScaffold(
            body: SingleChildScrollView(
              child: ReceiverInfoPanel(accountInfo: account),
            ),
          ),
        ),
      );
      await showAccount(emptyAccount);
      expect(find.textContaining('尚未填寫'), findsNWidgets(5));
      await showAccount(
        emptyAccount.copyWith(
          name: '測試收件人',
          address: '台北市測試路1號',
          phone: '0912345678',
          bankCode: '004',
          bankName: '測試銀行',
          bankAccount: '123456789',
        ),
      );
      expect(find.textContaining('尚未填寫'), findsNothing);
      for (final value in [
        '姓名：測試收件人',
        '地址：台北市測試路1號',
        '手機號碼：0912345678',
        '銀行：004 測試銀行',
        '銀行帳號：123456789',
      ]) {
        expect(find.text(value), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Detail sheet expands, scrolls, and returns a result to its page',
    (tester) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => AppScaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    result = await showDraggableDetailsSheet<String>(
                      context: context,
                      headerBuilder: (sheetContext) => TextButton(
                        onPressed: () =>
                            Navigator.of(sheetContext).pop('created'),
                        child: const Text('Create'),
                      ),
                      bodyBuilder: (context, controller) => ListView.builder(
                        controller: controller,
                        itemExtent: 48,
                        itemCount: 40,
                        itemBuilder: (context, index) => Text('Record $index'),
                      ),
                    );
                  },
                  child: const Text('Open details'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open details'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
      final initialTop = tester.getTopLeft(find.byType(ListView)).dy;

      await tester.drag(find.byType(ListView), const Offset(0, -220));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byType(ListView)).dy, lessThan(initialTop));
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      // The gesture that reaches the maximum extent resizes the sheet;
      // a subsequent gesture scrolls its content.
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.text('Record 0').hitTestable(), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(result, 'created');
      expect(find.text('Open details'), findsOneWidget);
      expect(find.byType(DraggableScrollableSheet), findsNothing);

      // A dismissed and reopened sheet starts at its initial extent again.
      await tester.tap(find.text('Open details'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.text('Open details'), findsOneWidget);
    },
  );
}
