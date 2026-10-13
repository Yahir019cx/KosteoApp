import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kosteo/data/app_store.dart';
import 'package:kosteo/screens/purchases_screen.dart';
import 'package:kosteo/screens/edit_purchase_sheet.dart';
import 'package:kosteo/theme/tokens.dart';
import 'package:kosteo/widgets/basics.dart';

class PartialStore extends KosteoStore {
  (num, num, String)? saved;
  @override
  Future<void> queuePurchaseYield(
    Purchase p,
    num processed,
    num useful,
    String unit,
  ) async {
    saved = (processed, useful, unit);
  }
}

void main() {
  for (final width in [390.0, 1194.0]) {
    testWidgets('Compra anterior visible y rendimiento parcial: $width', (
      tester,
    ) async {
      final previous = store;
      addTearDown(() => store = previous);
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fake = PartialStore()..loaded = true;
      store = fake;
      fake.units = [
        {
          'unidadId': 1,
          'codigo': 'kg',
          'dimension': 'MASA',
          'factorBase': 1000,
        },
        {'unidadId': 2, 'codigo': 'g', 'dimension': 'MASA', 'factorBase': 1},
      ];
      final ing = Ingredient(
        'Pepino',
        IngredientCategory.produce,
        Icons.eco,
        'kg',
        'g',
        hasYield: true,
      )..id = 1;
      fake.ingredients.add(ing);
      final purchase = Purchase(ing, 10, 300, '14:00', yieldValue: 4000)
        ..id = 10
        ..remainingToProcess = 5
        ..processed = 5
        ..manualProcessing = true
        ..date = DateTime.now().subtract(const Duration(days: 8));
      fake.purchases.add(purchase);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildKosteoTheme(),
          home: const Scaffold(body: PurchasesScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Registro y pendientes anteriores'), findsOneWidget);
      await tester.ensureVisible(find.text('Pepino'));
      await tester.tap(find.text('Pepino'));
      await tester.pumpAndSettle();
      expect(find.text('Procesar Pepino'), findsOneWidget);
      expect(find.text('Editar datos de compra'), findsNothing);
      expect(find.byType(TextField), findsNWidgets(2));
      await tester.enterText(find.byType(TextField).first, '6');
      await tester.enterText(find.byType(TextField).last, '4');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PrimaryButton>(
              find.widgetWithText(PrimaryButton, 'Registrar rendimiento'),
            )
            .onTap,
        isNull,
      );
      await tester.enterText(find.byType(TextField).first, '3.7');
      await tester.pumpAndSettle();
      expect(find.text('Quedarán 1.3 kg por procesar.'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '3');
      await tester.enterText(find.byType(TextField).last, '2,4');
      await tester.tap(find.text('kg').last);
      await tester.pumpAndSettle();
      expect(find.text('Quedarán 2 kg por procesar.'), findsOneWidget);
      await tester.ensureVisible(find.text('Registrar rendimiento'));
      await tester.tap(find.text('Registrar rendimiento'));
      await tester.pumpAndSettle();
      expect(fake.saved, (3, 2.4, 'kg'));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 6));
      fake.api.dispose();
    });
  }
  testWidgets('Compra completamente procesada conserva resumen sin editor', (
    tester,
  ) async {
    final ing = Ingredient(
      'Pepino',
      IngredientCategory.produce,
      Icons.eco,
      'kg',
      'g',
    );
    final purchase = Purchase(ing, 10, 300, '14:00', yieldValue: 8000)
      ..remainingToProcess = 0
      ..manualProcessing = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showEditPurchaseSheet(context, purchase),
              child: const Text('Compra'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Compra'));
    await tester.pumpAndSettle();
    expect(find.text('Compra procesada completamente'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
