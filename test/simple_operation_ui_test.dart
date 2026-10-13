import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kosteo/data/app_store.dart';
import 'package:kosteo/screens/new_order_screen.dart';
import 'package:kosteo/screens/orders_screen.dart';
import 'package:kosteo/screens/products_screen.dart';
import 'package:kosteo/screens/dashboard_screen.dart';
import 'package:kosteo/widgets/basics.dart';

class _Store extends KosteoStore {
  List<int>? selected;
  OrderStatus? next;
  @override
  Future<void> queueStates(List<Order> orders, OrderStatus state) async {
    selected = orders.map((o) => o.number).toList();
    next = state;
  }
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
    Future<_Store> setup(WidgetTester tester, Widget screen) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final old = store;
      addTearDown(() => store = old);
      final fake = _Store()..loaded = true;
      store = fake;
      products.clear();
      addTearDown(products.clear);
      await tester.pumpWidget(
        MaterialApp(
          home: screen is OrdersScreen ? Scaffold(body: screen) : screen,
        ),
      );
      return fake;
    }

    testWidgets('Una entrada de porciones para tres aguachiles ($width)', (
      tester,
    ) async {
      await setup(tester, const ProductsScreen());
      for (final color in ['Verde', 'Rojo', 'Negro']) {
        products.add(
          Product(
            'Aguachile $color',
            120,
            'Aguachiles',
            Icons.restaurant,
            Colors.green,
            sizes: {'Individual': 120, 'Pa Compartir': 190},
          )..id = products.length + 1,
        );
      }
      store.productChanged();
      await tester.pumpAndSettle();
      expect(find.text('Porciones de aguachiles'), findsOneWidget);
    });
    testWidgets('Marea Brava: una salsa, entrega y picker sin fecha ($width)', (
      tester,
    ) async {
      await setup(tester, const NewOrderScreen());
      final p =
          Product(
              'Marea Brava',
              120,
              'Especiales',
              Icons.restaurant,
              Colors.green,
            )
            ..id = 1
            ..presentationIds = {'Única': 1}
            ..options = [
              {
                'opcionId': 1,
                'tipo': 'COMPLEMENTO',
                'nombre': 'Tostadas',
                'precioAdicional': 0,
              },
              {
                'opcionId': 2,
                'tipo': 'COMPLEMENTO',
                'nombre': 'Tostitos',
                'precioAdicional': 0,
              },
              for (var i = 0; i < 3; i++)
                {
                  'opcionId': 3 + i,
                  'tipo': 'EXTRA',
                  'nombre': ['Salsa Verde', 'Salsa Roja', 'Salsa Negra'][i],
                  'precioAdicional': 0,
                },
            ];
      products.add(p);
      await tester.pumpWidget(
        MaterialApp(home: NewOrderScreen(key: UniqueKey())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Marea Brava'));
      await tester.pumpAndSettle();
      expect(find.text('Elige la salsa'), findsOneWidget);
      final add = find.widgetWithText(PrimaryButton, 'Agregar · \$120');
      expect(tester.widget<PrimaryButton>(add).onTap, isNull);
      await tester.tap(find.text('Seleccionar salsa'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'negra');
      await tester.pumpAndSettle();
      expect(find.text('Verde'), findsNothing);
      await tester.tap(find.text('Negra'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sin nombre').first);
      await tester.pumpAndSettle();
      expect(find.text('Recoger'), findsNothing);
      await tester.tap(find.text('Horario de entrega'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
            .mode,
        CupertinoDatePickerMode.time,
      );
      await tester.tap(find.text('Usar horario'));
      await tester.pumpAndSettle();
      expect(find.text('Entrega a las 14:00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('Seleccionar tres pedidos y enviarlos juntos ($width)', (
      tester,
    ) async {
      final fake = await setup(tester, const OrdersScreen());
      fake.ordersFilter.value = OrderStatus.ready;
      for (var i = 1; i <= 3; i++) {
        fake.orders.add(
          Order(i, 'Cliente $i', '14:00', [], OrderStatus.ready)
            ..tipoEntrega = 'ENTREGA'
            ..jornadaId = 1,
        );
      }
      fake.productChanged();
      await tester.pumpAndSettle();
      await tester.tap(
        find.bySemanticsLabel('Seleccionar para cambiar estado'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar'));
      await tester.pumpAndSettle();
      expect(fake.selected, [1, 2, 3]);
      expect(fake.next, OrderStatus.delivering);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
    testWidgets(
      'Gráfica explica costos pendientes sin inventar ganancia ($width)',
      (tester) async {
        final fake = await setup(tester, const SizedBox());
        fake.metrics[Period.shift] = const Metrics(
          1800,
          null,
          null,
          0,
          null,
          knownCost: 600,
          costPending: [
            {'nombre': 'Tostitos', 'motivo': 'Costo pendiente'},
          ],
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DashboardScreen(
                onOpenOrders: (_) {},
                onOpenShift: () {},
                onOpenMore: () {},
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 2));
        await tester.ensureVisible(find.text('Ganancia estimada'));
        await tester.tap(find.text('Ganancia estimada'));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Provisional'), findsOneWidget);
        expect(
          find.text('Costo conocido: \$600 · subtotal provisional'),
          findsOneWidget,
        );
        expect(find.text('Tostitos: Costo pendiente'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
