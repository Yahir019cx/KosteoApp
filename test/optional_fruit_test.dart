import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kosteo/data/app_store.dart';
import 'package:kosteo/screens/product_edit_screen.dart';
import 'package:kosteo/widgets/chips.dart';

class _Store extends KosteoStore {
  Product? saved;
  @override
  Future<void> saveProduct(Product p) async => saved = p.copy();
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('PlusJakartaSans');
    for (final weight in ['500', '700']) {
      loader.addFont(
        File('assets/fonts/PlusJakartaSans-$weight.ttf')
            .readAsBytes()
            .then((b) => ByteData.view(b.buffer)),
      );
    }
    await loader.load();
  });
  for (final width in [390.0, 1194.0]) {
    testWidgets('Cambiar Piña por Mango sin cambiar otros extras ($width)', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final previous = store;
      final fake = _Store();
      store = fake;
      addTearDown(() => store = previous);
      final product =
          Product(
              'Aguachile',
              120,
              'Aguachiles',
              Icons.restaurant,
              Colors.green,
            )
            ..id = 1
            ..options = [
              {
                'opcionId': 1,
                'tipo': 'COMPLEMENTO',
                'nombre': 'Tostitos',
                'precioAdicional': 0,
              },
              {
                'opcionId': 2,
                'tipo': 'EXTRA',
                'nombre': 'Piña',
                'precioAdicional': 0,
              },
              {
                'opcionId': 3,
                'tipo': 'EXTRA',
                'nombre': 'Extra camarón',
                'precioAdicional': 25.50,
              },
            ];
      await tester.pumpWidget(
        MaterialApp(home: ProductEditScreen(product: product)),
      );
      final pineapple = find.widgetWithText(CategoryChip, 'Piña');
      final mango = find.widgetWithText(CategoryChip, 'Mango');
      await tester.scrollUntilVisible(
        mango,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.widget<CategoryChip>(pineapple).selected, isTrue);
      expect(tester.widget<CategoryChip>(mango).selected, isFalse);
      await tester.tap(pineapple);
      await tester.tap(mango);
      await tester.pumpAndSettle();
      expect(product.extras, [
        'Piña',
        'Extra camarón',
      ]); // Borrador hasta guardar.
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(fake.saved!.extras, ['Extra camarón', 'Mango']);
      expect(fake.saved!.sides, ['Tostitos']);
      expect(fake.saved!.optionPrice('Extra camarón'), 25.50);
      expect(fake.saved!.optionPrice('Mango'), 0);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });
  }
}
