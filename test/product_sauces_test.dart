import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kosteo/data/app_store.dart';
import 'package:kosteo/screens/product_edit_screen.dart';
import 'package:kosteo/screens/product_sauces_sheet.dart';

class _Store extends KosteoStore {
  Product? saved;
  final sauces = <Map<String, dynamic>>[
    {'salsaId': 1, 'nombre': 'Verde', 'activa': true},
  ];
  @override
  Future<List<Map<String, dynamic>>> getSauces() async => List.of(sauces);
  @override
  Future<Map<String, dynamic>> createSauce(String name) async {
    final sauce = <String, dynamic>{
      'salsaId': sauces.length + 1,
      'nombre': name,
      'activa': true,
    };
    sauces.add(sauce);
    return sauce;
  }

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
    testWidgets('Salsas desde Productos: borrador y guardado ($width)', (
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
              'Marea Brava',
              190,
              'Especiales',
              Icons.restaurant,
              Colors.green,
            )
            ..id = 4
            ..options = [
              {
                'opcionId': 1,
                'tipo': 'COMPLEMENTO',
                'nombre': 'Tostadas',
                'precioAdicional': 0,
              },
              {
                'opcionId': 2,
                'tipo': 'EXTRA',
                'nombre': 'Salsa Verde',
                'precioAdicional': 0,
              },
            ];
      await tester.pumpWidget(
        MaterialApp(home: ProductEditScreen(product: product)),
      );
      final edit = find.text('Elegir salsas disponibles');
      await tester.scrollUntilVisible(
        edit,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(edit);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Salsa Morita');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar salsa'));
      await tester.pumpAndSettle();
      expect(find.text('Morita'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'morita');
      await tester.pumpAndSettle();
      expect(find.text('Agregar salsa'), findsNothing);
      expect(product.extras, ['Salsa Verde']);
      expect(fake.sauces.last['nombre'], 'Morita');
      expect(fake.saved, isNull);
      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();
      expect(product.extras, ['Salsa Verde']);
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(
        fake.saved!.extras,
        unorderedEquals(['Salsa Verde', 'Salsa Morita']),
      );
      expect(fake.saved!.options.first['opcionId'], 1);
      expect(fake.saved!.optionPrice('Salsa Morita'), 0);
      expect(
        fake.saved!.options.firstWhere(
          (o) => o['nombre'] == 'Salsa Morita',
        )['salsaId'],
        2,
      );
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });
  }
  testWidgets('Catálogo independiente sin crear producto', (tester) async {
    final previous = store;
    final fake = _Store();
    store = fake;
    addTearDown(() => store = previous);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showSauceCatalog(context),
            child: const Text('Salsas'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Salsas'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Morita');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar salsa'));
    await tester.pumpAndSettle();
    expect(fake.sauces.last['nombre'], 'Morita');
    expect(fake.saved, isNull);
    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
