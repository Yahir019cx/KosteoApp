import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kosteo/data/app_store.dart';
import 'package:kosteo/screens/day_close_screen.dart';
import 'package:kosteo/screens/ingredients_screen.dart';
import 'package:kosteo/screens/leftovers_screen.dart';
import 'package:kosteo/screens/product_edit_screen.dart';
import 'package:kosteo/screens/new_ingredient_screen.dart';
import 'package:kosteo/screens/new_order_screen.dart';
import 'package:kosteo/screens/new_purchase_screen.dart';
import 'package:kosteo/screens/shell.dart';
import 'package:kosteo/theme/tokens.dart';

/// Renderiza cada pantalla en teléfono y tablet y falla si hay errores
/// de layout (overflow, constraints) o excepciones.
/// `flutter test --update-goldens` además guarda capturas en test/goldens/.
void main() {
  setUpAll(() async {
    Future<void> load(String family, List<String> files) async {
      final loader = FontLoader(family);
      for (final f in files) {
        loader.addFont(
          File(f).readAsBytes().then((b) => ByteData.view(b.buffer)),
        );
      }
      await loader.load();
    }

    await load(kFont, [
      'assets/fonts/PlusJakartaSans-500.ttf',
      'assets/fonts/PlusJakartaSans-700.ttf',
    ]);
    final lucide = _lucideDir();
    if (lucide != null) {
      for (final w in ['300', '600']) {
        await load('packages/lucide_icons_flutter/Lucide$w', [
          '$lucide/assets/build_font/LucideVariable-w$w.ttf',
        ]);
      }
    }
  });

  setUp(() {
    store = KosteoStore()..loaded = true;
    store.units = [
      {'unidadId': 1, 'codigo': 'g', 'dimension': 'MASA', 'factorBase': 1},
      {'unidadId': 2, 'codigo': 'kg', 'dimension': 'MASA', 'factorBase': 1000},
    ];
    products.clear();
    final p =
        Product(
            'Aguachile Verde',
            120.25,
            'Aguachiles',
            Icons.restaurant,
            Colors.green,
            sizes: {'Individual': 120.25, 'Pa Compartir': 190.50},
          )
          ..id = 1
          ..presentationIds = {'Individual': 1, 'Pa Compartir': 2}
          ..options = [
            {
              'opcionId': 1,
              'tipo': 'COMPLEMENTO',
              'nombre': 'Tostitos',
              'precioAdicional': 0,
            },
            {
              'opcionId': 2,
              'tipo': 'COMPLEMENTO',
              'nombre': 'Tostadas',
              'precioAdicional': 0,
            },
            {
              'opcionId': 3,
              'tipo': 'EXTRA',
              'nombre': 'Piña',
              'precioAdicional': 15.50,
            },
          ];
    products.add(p);
    final shrimp = Ingredient(
      'Camarón',
      IngredientCategory.seafood,
      Icons.restaurant,
      'kg',
      'g',
      hasYield: true,
    )..id = 1;
    store.ingredients.add(shrimp);
    store.purchases.add(
      Purchase(shrimp, 1, 220.25, '08:00', yieldValue: 1000)
        ..id = 1
        ..jornadaId = 1,
    );
    store.jornada = {
      'jornadaId': 1,
      'estado': 'ABIERTA',
      'fechaInicio': '2026-10-10',
      'fechaFin': '2026-10-11',
    };
    store.leftovers.add(LeftoverItem(shrimp, 650));
    for (final p in Period.values) {
      store.metrics[p] = const Metrics(
        120.25,
        null,
        null,
        0,
        null,
        inventory: 143,
      );
    }
  });
  const sizes = {'phone': Size(390, 844), 'tablet': Size(1194, 834)};
  final screens = <String, Widget Function()>{
    'shell': () => const HomeShell(),
    'new_order': () => const NewOrderScreen(),
    'new_purchase': () => const NewPurchaseScreen(),
    'ingredients': () => const IngredientsScreen(),
    'new_ingredient': () => const NewIngredientScreen(),
    'leftovers': () => const LeftoversScreen(),
    'day_close': () => const DayCloseScreen(),
    'product_edit': () => ProductEditScreen(product: products.first),
  };

  for (final size in sizes.entries) {
    for (final s in screens.entries) {
      testWidgets('${s.key} @ ${size.key}', (tester) async {
        await _pumpApp(tester, size.value, s.value());
        await _shot('${s.key}_${size.key}');
      });
    }

    testWidgets('shell tabs + sheets @ ${size.key}', (tester) async {
      await _pumpApp(tester, size.value, const HomeShell());
      await tester.tap(find.text('Pedidos').last);
      await _settle(tester);
      await _shot('orders_${size.key}');
      await tester.tap(find.text('Compras').last);
      await _settle(tester);
      await _shot('purchases_${size.key}');
      await tester.tap(find.text('Camarón').first);
      await _settle(tester);
      await _shot('edit_purchase_${size.key}');
      await tester.tapAt(const Offset(20, 20));
      await _settle(tester);
      await tester.tap(find.bySemanticsLabel('Acciones rápidas'));
      await _settle(tester);
      await _shot('quick_actions_${size.key}');
      await tester.tapAt(const Offset(20, 20));
      await _settle(tester);
      await tester.tap(find.text('Productos').last);
      await _settle(tester);
      await _shot('products_tab_${size.key}');
      await tester.tap(find.text('Inicio').last);
      await _settle(tester);
      await tester.tap(find.bySemanticsLabel('Más opciones'));
      await _settle(tester);
      await _shot('more_${size.key}');
    });

    testWidgets('new order options sheet @ ${size.key}', (tester) async {
      await _pumpApp(tester, size.value, const NewOrderScreen());
      await tester.tap(find.text('Pa Compartir').first);
      await _settle(tester);
      await tester.tap(find.text('Aguachile Verde'));
      await _settle(tester);
      await _shot('product_options_${size.key}');
      await tester.tap(find.textContaining('Agregar ·'));
      await _settle(tester);
      await _shot('new_order_cart_${size.key}');
    });

    testWidgets('new purchase steps @ ${size.key}', (tester) async {
      await _pumpApp(tester, size.value, const NewPurchaseScreen());
      await tester.tap(find.text('Mariscos'));
      await _settle(tester);
      await _shot('purchase_step2_${size.key}');
      await tester.tap(find.text('Camarón'));
      await _settle(tester);
      await _shot('purchase_step3_${size.key}');
    });
  }
}

late WidgetTester _current;

Future<void> _pumpApp(WidgetTester tester, Size size, Widget home) async {
  _current = tester;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildKosteoTheme(),
      scrollBehavior: const KosteoScrollBehavior(),
      home: home,
    ),
  );
  await _settle(tester);
}

// No usamos pumpAndSettle: el punto de "jornada activa" late indefinidamente.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _shot(String name) async {
  if (!autoUpdateGoldenFiles) return;
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
  _current.takeException();
}

String? _lucideDir() {
  final home = Platform.environment['LOCALAPPDATA'] ?? '';
  final dir = Directory('$home/Pub/Cache/hosted/pub.dev');
  if (!dir.existsSync()) return null;
  final match = dir.listSync().whereType<Directory>().where(
    (d) => d.path.contains('lucide_icons_flutter-'),
  );
  return match.isEmpty ? null : match.last.path;
}
