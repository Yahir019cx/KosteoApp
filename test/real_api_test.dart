import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:kosteo/data/api_client.dart';
import 'package:kosteo/data/app_store.dart';
import 'package:kosteo/screens/shell.dart';
import 'package:kosteo/screens/product_edit_screen.dart';
import 'package:kosteo/screens/product_cost_sheet.dart';
import 'package:kosteo/screens/new_order_screen.dart';
import 'package:kosteo/screens/gas_sheet.dart';
import 'package:kosteo/theme/tokens.dart';

class RealHttp extends HttpOverrides {}

void main() {
  const enabled = bool.fromEnvironment('REAL_API_TEST');
  setUpAll(() async {
    final font = FontLoader(kFont);
    for (final n in ['500', '700']) {
      font.addFont(
        File('assets/fonts/PlusJakartaSans-$n.ttf')
            .readAsBytes()
            .then((bytes) => ByteData.view(bytes.buffer)),
      );
    }
    await font.load();
  });
  test(
    'Flutter → NestJS → SQL: operación real reversible',
    () async {
      final client = ApiClient(
        client: IOClient(RealHttp().createHttpClient(null)),
        baseUrl: const String.fromEnvironment('TEST_API_URL'),
      );
      store = KosteoStore(client: client);
      try {
        await store.load();
        expect(store.error, isNull);
        expect(store.ingredients.length, greaterThanOrEqualTo(27));
        final now = DateTime.now();
        await store.openShift(now, now.add(const Duration(days: 1)));
        final newIngredient = Ingredient(
          '__FLUTTER_${operationKey()}',
          IngredientCategory.produce,
          Icons.restaurant,
          'kg',
          'g',
          hasYield: true,
        );
        await store.addIngredient(newIngredient);
        expect(newIngredient.id, greaterThan(0));
        await store.saveInitialInventory(newIngredient, 1.5, 'kg', 190);
        expect(
          store.leftovers
              .firstWhere((l) => l.ingredient.id == newIngredient.id)
              .theoretical,
          1500,
        );
        expect(store.metrics[Period.shift]!.investment, 0);
        Ingredient ing(String n) =>
            store.ingredients.firstWhere((i) => i.name == n);
        await store.addPurchase(
          ing('Pepino'),
          3,
          90,
          yieldValue: 2.5,
          yieldUnit: 'kg',
        );
        final pep = store.purchases.firstWhere(
          (p) => p.ingredient.name == 'Pepino',
        );
        expect(pep.yieldValue, 2500);
        await store.updatePurchase(pep, qty: 3, total: 90, yieldValue: 2500);
        expect(
          store.purchases.firstWhere((p) => p.id == pep.id).jornadaId,
          store.jornadaId,
        );
        await store.addPurchase(ing('Limón'), 2, 120, yieldValue: 1050);
        await store.addPurchase(ing('Camarón'), 1, 220, yieldValue: 1000);
        await store.addPurchase(ing('Envase individual'), 25, 199);
        await store.addPurchase(ing('Tostitos'), 10, 120);
        await store.addPurchase(ing('Tostadas'), 1, 40, yieldValue: 40);
        var p = products.firstWhere((p) => p.name == 'Aguachile Verde').copy();
        p.price = 120.25;
        p.sizes = {'Individual': 120.25, 'Pa Compartir': 190.50};
        p.options = p.options
            .map(
              (o) => {
                ...o,
                'precioAdicional': o['tipo'] == 'EXTRA' ? 15.50 : 0,
              },
            )
            .toList();
        await store.saveProduct(p);
        p = products.firstWhere((p) => p.name == 'Aguachile Verde');
        expect(p.price, 120.25);
        expect(p.sizes?['Individual'], 120.25);
        expect(p.sizes?['Pa Compartir'], 190.50);
        final pres = p.presentationIds['Individual']!,
            side = p.options.firstWhere(
              (o) => o['nombre'] == 'Tostitos',
            )['opcionId'];
        final components = [
          {'insumoId': ing('Camarón').id, 'cantidad': 130},
          {'insumoId': ing('Pepino').id, 'cantidad': 125},
          {'insumoId': ing('Envase individual').id, 'cantidad': 1},
          {'insumoId': ing('Tostitos').id, 'opcionId': side, 'cantidad': 1},
          {'insumoId': ing('Limón').id, 'cantidad': null},
        ];
        await client.request(
          'PUT',
          '/platillos/${p.id}/componentes',
          body: {
            'presentacionId': pres,
            'componentes': components,
            'costoFijoCondimentos': 1.5,
            'confirmada': false,
          },
        );
        final preview = await client.get('/platillos/${p.id}/costo', {
          'presentacionId': pres,
          'opciones': '[$side]',
        });
        expect(preview['costoTotal'], isNull);
        expect(preview['subtotalCostoConocido'], 54.56);
        final anticipados = <int>[];
        for (var i = 0; i < 2; i++) {
          final futuro = await store.addOrder([
            OrderLine(
              p,
              1,
              size: 'Individual',
              sides: i == 0 ? ['Tostitos', 'Tostadas'] : ['Tostitos'],
            ),
          ], sinJornada: true);
          expect(futuro.jornadaId, isNull);
          expect(futuro.status, OrderStatus.pending);
          expect(
            futuro.lines.single.sides.toSet(),
            i == 0 ? {'Tostitos', 'Tostadas'} : {'Tostitos'},
          );
          anticipados.add(futuro.number);
        }
        await store.asignarPedidos(anticipados, store.jornadaAbiertaId!);
        for (final id in anticipados) {
          final asignado = store.orders.firstWhere((o) => o.number == id);
          expect(asignado.jornadaId, store.jornadaAbiertaId);
          expect(asignado.lines.single.unitPrice, 120.25);
          await store.changeStatus(asignado, OrderStatus.cancelled);
        }
        var order = await store.addOrder(
          [OrderLine(p, 2, size: 'Individual', side: 'Tostitos')],
          customer: 'Prueba reversible',
          phone: '5550000000',
          type: 'ENTREGA',
          reference: 'Portón azul',
          notes: 'Sin cebolla',
        );
        expect(order.total, 240.50);
        expect(order.costoBolsaAplicado, 0.10);
        expect(order.lines.single.cost, isNull);
        expect(order.reference, 'Portón azul');
        for (final state in [
          OrderStatus.preparing,
          OrderStatus.ready,
          OrderStatus.delivering,
          OrderStatus.delivered,
        ]) {
          await store.changeStatus(order, state);
          order = store.orders.firstWhere((o) => o.number == order.number);
        }
        expect(order.lines.single.fixedCondimentsApplied, 1.5);
        expect(
          order.lines.single.fixedCondimentsApplied! * order.lines.single.qty,
          3,
        );
        expect(store.metrics[Period.today]!.sales, 240.50);
        expect(store.metrics[Period.today]!.profit, isNull);
        final cancel = await store.addOrder([
          OrderLine(p, 1, size: 'Individual', side: 'Tostadas'),
        ]);
        await store.changeStatus(cancel, OrderStatus.cancelled);
        await store.addGas(230.25, comment: 'Reparto de prueba');
        expect(store.gasTotal, 230.25);
        final shrimp = store.leftovers.firstWhere(
          (l) => l.ingredient.name == 'Camarón',
        );
        store.setCount(shrimp, shrimp.theoretical! - 30);
        await store.saveCounts();
        expect(
          store.leftovers
              .firstWhere((l) => l.ingredient.name == 'Camarón')
              .diff,
          -30,
        );
        final photo = Uint8List.fromList(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGPQmbjgPwAEpwJdvOLonwAAAABJRU5ErkJggg==',
          ),
        );
        p = products.firstWhere((p) => p.name == 'Aguachile Verde').copy();
        p.image = photo;
        await store.saveProduct(p);
        expect(products.firstWhere((item) => item.id == p.id).image, isNotNull);
        await store.closeShift();
        expect(store.shiftClosed, isTrue);
        expect(store.metrics[Period.shift]!.profit, isNull);
        await client.request(
          'PATCH',
          '/platillos/${p.id}',
          body: {'nombre': 'Nombre posterior'},
        );
        await store.menu();
        await store.refresh();
        final historic = store.orders.firstWhere(
          (o) => o.number == order.number,
        );
        expect(historic.lines.single.name, contains('Aguachile Verde'));
        expect(historic.total, 240.50);
        expect(historic.costoBolsaAplicado, 0.10);
        components.last['cantidad'] = 100;
        await client.request(
          'PUT',
          '/platillos/${p.id}/componentes',
          body: {
            'presentacionId': pres,
            'componentes': components,
            'costoFijoCondimentos': 1.5,
            'confirmada': true,
          },
        );
        await store.refresh();
        expect(
          store.orders
              .firstWhere((o) => o.number == order.number)
              .lines
              .single
              .cost,
          65.99,
        );
      } finally {
        client.dispose();
      }
    },
    skip: enabled
        ? false
        : 'Ejecutar desde KosteoWS: node test/run_flutter_e2e.cjs',
    timeout: const Timeout(Duration(seconds: 45)),
  );

  for (final size in const [Size(390, 844), Size(1194, 834)]) {
    testWidgets('UI con datos reales · ${size.width}', (tester) async {
      final originalError = FlutterError.onError;
      FlutterError.onError = (details) {
        FlutterError.dumpErrorToConsole(details, forceReport: true);
        originalError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalError);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(theme: buildKosteoTheme(), home: const HomeShell()),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.bySemanticsLabel('Acciones rápidas'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final p = products.firstWhere((p) => p.name == 'Nombre posterior');
      await tester.pumpWidget(
        MaterialApp(
          theme: buildKosteoTheme(),
          home: ProductEditScreen(product: p),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      // Reload the real service with a new HTTP connection for bottom sheets.
      store = KosteoStore(
        client: ApiClient(
          client: IOClient(RealHttp().createHttpClient(null)),
          baseUrl: const String.fromEnvironment('TEST_API_URL'),
        ),
      );
      await tester.runAsync(store.load);
      expect(store.error, isNull);
      await tester.runAsync(
        () => showProductCost(
          tester.element(find.byType(ProductEditScreen)),
          p,
        ).timeout(const Duration(milliseconds: 500), onTimeout: () {}),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.text('Confirmar cantidades'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(theme: buildKosteoTheme(), home: const NewOrderScreen()),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.runAsync(
        () =>
            showGasSheet(tester.element(find.byType(NewOrderScreen)))
                .timeout(const Duration(milliseconds: 500), onTimeout: () {}),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.text('Gasolina de reparto'), findsOneWidget);
      expect(find.text('Moto'), findsNothing);
      expect(tester.takeException(), isNull);
      store.api.dispose();
    }, skip: !enabled);
  }
}
