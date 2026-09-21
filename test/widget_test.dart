import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/shared/layouts/app_scaffold.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/simple_app_bar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Page surface dismisses keyboard only when opted in', (
    tester,
  ) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);

    for (final dismissKeyboard in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: AppScaffold(
            dismissKeyboardOnTap: dismissKeyboard,
            body: Column(
              children: [
                TextField(focusNode: focusNode),
                const Expanded(child: SizedBox.expand()),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);
      await tester.tapAt(const Offset(200, 300));
      await tester.pump();
      expect(focusNode.hasFocus, !dismissKeyboard);
    }
  });

  testWidgets('Page navigation respects the surrounding PopScope', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    var allowPop = false;
    late StateSetter updatePage;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const AppScaffold(body: Text('Home')),
      ),
    );
    navigator.currentState!.push<void>(
      MaterialPageRoute(
        builder: (context) => StatefulBuilder(
          builder: (context, setState) {
            updatePage = setState;
            return PopScope(
              canPop: allowPop,
              child: const AppScaffold(
                appBar: SimpleAppBar(title: 'Checkout'),
                useSafeArea: true,
                body: Text('Payment in progress'),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Payment in progress'), findsOneWidget);

    updatePage(() => allowPop = true);
    await tester.pump();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });
}
