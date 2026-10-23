import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/features/cart/widgets/quantity_dialog.dart';
import 'package:flutter_ad_ecommerce/models/product.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/selection_option_tile.dart';
import 'package:flutter_test/flutter_test.dart';

const soldOut = ProductVariant(
  id: 'sold-out',
  productId: 'product',
  name: 'TEST',
);
const available = ProductVariant(
  id: 'available',
  productId: 'product',
  name: 'WAE',
  availableStock: 2,
);

Future<void> openDialog(
  WidgetTester tester, {
  required List<ProductVariant> variants,
  required ProductVariant selected,
  ValueChanged<CartItemEditResult>? onSuccess,
  Future<String?> Function(CartItemEditResult)? onSubmit,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => QuantityDialog(
                quantity: 1,
                variants: variants,
                selectedVariant: selected,
                onSubmit:
                    onSubmit ??
                    (value) async {
                      onSuccess?.call(value);
                      return null;
                    },
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sold-out variant remains visible and cannot be selected', (
    tester,
  ) async {
    CartItemEditResult? result;
    await openDialog(
      tester,
      variants: [soldOut, available],
      selected: available,
      onSuccess: (value) => result = value,
    );

    expect(find.text('已售完'), findsOneWidget);
    expect(find.text('庫存 0'), findsNothing);
    final title = tester.widget<Text>(find.text('TEST'));
    expect(title.style!.decoration, TextDecoration.lineThrough);
    expect(title.style!.decorationColor, title.style!.color);
    final option = tester.widget<SelectionOptionTile>(
      find.widgetWithText(SelectionOptionTile, 'TEST'),
    );
    expect(option.onTap, isNull);
    await tester.tap(find.text('TEST'));
    await tester.tap(find.text('確定'));
    await tester.pumpAndSettle();
    expect(result!.variant.id, available.id);
    expect(result!.quantity, 1);
  });

  testWidgets(
    'sold-out cart selection requires choosing an available variant',
    (tester) async {
      CartItemEditResult? result;
      await openDialog(
        tester,
        variants: [soldOut, available],
        selected: soldOut,
        onSuccess: (value) => result = value,
      );
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text('WAE'));
      await tester.pump();
      await tester.tap(find.text('確定'));
      await tester.pumpAndSettle();
      expect(result!.variant.id, available.id);
    },
  );

  testWidgets('single named variant is visible', (tester) async {
    await openDialog(tester, variants: [available], selected: available);
    expect(find.text('選擇規格'), findsOneWidget);
    expect(find.text('WAE'), findsOneWidget);
  });

  testWidgets('single unnamed default hides choices but can be submitted', (
    tester,
  ) async {
    const defaultVariant = ProductVariant(
      id: 'default',
      productId: 'product',
      availableStock: 2,
    );
    CartItemEditResult? result;
    await openDialog(
      tester,
      variants: [defaultVariant],
      selected: defaultVariant,
      onSuccess: (value) => result = value,
    );
    expect(find.text('選擇規格'), findsNothing);
    await tester.tap(find.text('確定'));
    await tester.pumpAndSettle();
    expect(result!.variant.id, defaultVariant.id);
  });

  testWidgets('all sold out disables confirmation', (tester) async {
    await openDialog(tester, variants: [soldOut], selected: soldOut);
    expect(find.text('TEST'), findsOneWidget);
    expect(find.text('已售完'), findsWidgets);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
  });

  testWidgets('no current variants hides choices and blocks stale selection', (
    tester,
  ) async {
    await openDialog(tester, variants: [], selected: available);
    expect(find.text('選擇規格'), findsNothing);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
  });

  for (final name in ['WAE', null]) {
    testWidgets('quantity limit applies to variant name $name', (tester) async {
      final variant = ProductVariant(
        id: 'variant',
        productId: 'product',
        name: name,
        availableStock: 2,
      );
      await openDialog(tester, variants: [variant], selected: variant);
      expect(find.text('庫存 2'), findsWidgets);
      await tester.enterText(find.byType(TextFormField), '3');
      await tester.pump();
      expect(find.text('數量不可超過庫存'), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(find.byType(QuantityDialog), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '2');
      await tester.pump();
      expect(find.text('數量不可超過庫存'), findsNothing);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
      );
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(find.text('數量不可超過庫存'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      expect(find.text('數量不可超過庫存'), findsNothing);
    });
  }

  testWidgets('changing variant revalidates quantity without clamping', (
    tester,
  ) async {
    const larger = ProductVariant(
      id: 'larger',
      productId: 'product',
      name: 'Larger',
      availableStock: 5,
    );
    await openDialog(tester, variants: [larger, available], selected: larger);
    await tester.enterText(find.byType(TextFormField), '3');
    await tester.tap(find.text('WAE'));
    await tester.pump();
    expect(find.text('數量不可超過庫存'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      '3',
    );
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
  });

  for (final outcome in ['success', 'stock failure', 'exception']) {
    testWidgets('closes before API finishes and handles $outcome', (
      tester,
    ) async {
      final pending = Completer<String?>();
      var calls = 0;
      await openDialog(
        tester,
        variants: [available],
        selected: available,
        onSubmit: (_) {
          calls++;
          return pending.future;
        },
      );
      await tester.tap(find.text('確定'));
      await tester.pumpAndSettle();
      expect(find.byType(QuantityDialog), findsNothing);
      expect(pending.isCompleted, isFalse);
      expect(calls, 1);
      if (outcome == 'exception') {
        pending.completeError(Exception('network failure'));
      } else {
        pending.complete(outcome == 'success' ? null : '庫存不足');
      }
      await tester.pumpAndSettle();
      expect(find.byType(QuantityDialog), findsNothing);
      if (outcome == 'success') {
        expect(find.byType(SnackBar), findsNothing);
      } else {
        expect(find.byType(SnackBar), findsOneWidget);
        expect(
          find.text(
            outcome == 'exception' ? '修改商品失敗：修改失敗，請稍後再試' : '修改商品失敗：庫存不足',
          ),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}
