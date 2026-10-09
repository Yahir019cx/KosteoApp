import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kosteo/data/api_client.dart';
import 'package:kosteo/data/app_store.dart';
import 'package:kosteo/screens/leftovers_screen.dart';
import 'package:kosteo/theme/tokens.dart';

class InitialStore extends KosteoStore {
  bool fail = false;
  (num, String, num)? saved;
  @override
  Future<void> saveInitialInventory(
    Ingredient i,
    num cantidad,
    String unidad,
    num costoPorUnidad,
  ) async {
    if (fail) throw ApiException('Este insumo ya tiene inventario inicial.');
    saved = (cantidad, unidad, costoPorUnidad);
    leftovers.add(LeftoverItem(i, 1500));
    notifyListeners();
  }
}

void main() {
  for (final width in [390.0, 1194.0]) {
    for (final fail in [false, true]) {
      testWidgets('Inventario inicial: $width, error=$fail', (tester) async {
        final originalError = FlutterError.onError;
        FlutterError.onError = (details) {
          FlutterError.dumpErrorToConsole(details, forceReport: true);
          originalError?.call(details);
        };
        addTearDown(() => FlutterError.onError = originalError);
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final data = InitialStore()..fail = fail;
        store = data;
        data.units = [
          {
            'unidadId': 1,
            'codigo': 'kg',
            'dimension': 'MASA',
            'factorBase': 1000,
          },
          {'unidadId': 2, 'codigo': 'g', 'dimension': 'MASA', 'factorBase': 1},
        ];
        data.ingredients.add(
          Ingredient(
            'Camarón',
            IngredientCategory.seafood,
            Icons.restaurant,
            'kg',
            'g',
          )..id = 1,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: buildKosteoTheme(),
            home: const LeftoversScreen(counting: false),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cargar inventario inicial'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Elegir insumo'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Camarón'));
        await tester.pumpAndSettle();
        expect(find.text('Costo por kg'), findsOneWidget);
        await tester.enterText(find.byType(TextField).at(0), '1,5');
        await tester.enterText(find.byType(TextField).at(1), '190');
        await tester.pumpAndSettle();
        expect(find.text('Valor inicial: \$285'), findsOneWidget);
          await tester.ensureVisible(find.text('Guardar saldo inicial'));
          await tester.tap(find.text('Guardar saldo inicial'));
        await tester.pumpAndSettle();
        if (fail) {
          expect(
            find.text('Este insumo ya tiene inventario inicial.'),
            findsOneWidget,
          );
          expect(data.saved, isNull);
        } else {
          expect(data.saved, (1.5, 'kg', 190));
          expect(find.text('Inventario inicial guardado'), findsOneWidget);
          expect(data.leftovers.single.theoretical, 1500);
        }
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 6));
        data.api.dispose();
      });
    }
  }
}
