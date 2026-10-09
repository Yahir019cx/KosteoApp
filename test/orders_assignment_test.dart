import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kosteo/data/api_client.dart';
import 'package:kosteo/data/app_store.dart';
import 'package:kosteo/screens/orders_screen.dart';
import 'package:kosteo/theme/tokens.dart';

class AssignmentStore extends KosteoStore {
  bool fail = false;
  List<int> assigned = [];
  final List<int> batchSizes = [];
  bool failSecondBatch = false;
  @override
  Future<void> asignarPedidos(List<int> ids, int jornada) async {
    if (fail) throw ApiException('La jornada ya está cerrada.');
    batchSizes.add(ids.length);
    if (failSecondBatch && batchSizes.length == 2) {
      throw ApiException('La jornada ya está cerrada.');
    }
    assigned.addAll(ids);
    for (final o in orders.where((o) => ids.contains(o.number))) {
      o.jornadaId = jornada;
    }
    notifyListeners();
  }
}

void main() {
  for (final partialFailure in [false, true]) {
    testWidgets(
      'Seleccionar todos asigna en lotes y conserva asignados; error parcial=$partialFailure',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final data = AssignmentStore()..failSecondBatch = partialFailure;
        store = data;
        data.jornadas = [
          {
            'jornadaId': 5,
            'estado': 'ABIERTA',
            'fechaInicio': '2026-10-10',
            'fechaFin': '2026-10-11',
          },
        ];
        final p = Product(
          'Aguachile',
          120,
          'Aguachiles',
          Icons.restaurant,
          Colors.green,
        );
        for (var id = 1; id <= 101; id++) {
          data.orders.add(
            Order(id, null, '10:00', [OrderLine(p, 1)], OrderStatus.pending),
          );
        }
        data.orders.add(
          Order(200, null, '10:00', [OrderLine(p, 1)], OrderStatus.pending)
            ..jornadaId = 7,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: buildKosteoTheme(),
            home: const Scaffold(body: OrdersScreen()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Seleccionar sin jornada'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();
        expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, true);
        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();
        expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, false);
        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Asignar jornada'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('2026-10-10 · 2026-10-11'));
        await tester.pumpAndSettle();
        expect(data.batchSizes, [100, 1]);
        expect(data.orders.last.jornadaId, 7);
        if (partialFailure) {
          expect(data.assigned.length, 100);
          expect(
            find.textContaining('Se asignaron 100 pedidos.'),
            findsOneWidget,
          );
        } else {
          expect(data.assigned.length, 101);
          expect(find.text('Pedidos asignados a la jornada'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
      },
    );
  }
  test(
    'Pedidos sin jornada no cuentan en cierre ni indicadores de jornada',
    () {
      final data = AssignmentStore()
        ..jornada = {'jornadaId': 5, 'estado': 'ABIERTA'};
      final p = Product(
        'Aguachile',
        120,
        'Aguachiles',
        Icons.restaurant,
        Colors.green,
      );
      data.orders.add(
        Order(1, null, '10:00', [OrderLine(p, 1)], OrderStatus.pending),
      );
      data.orders.add(
        Order(2, null, '10:00', [OrderLine(p, 1)], OrderStatus.delivered)
          ..jornadaId = 5,
      );
      expect(data.countByJornada(OrderStatus.pending), 0);
      expect(data.countByJornada(OrderStatus.delivered), 1);
      expect(data.ordersDeJornada.length, 1);
      data.api.dispose();
    },
  );
  for (final width in [390.0, 1194.0]) {
    for (final fail in [false, true]) {
      testWidgets('Asignación múltiple: $width, error=$fail', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final data = AssignmentStore()..fail = fail;
        store = data;
        final p = Product(
          'Aguachile',
          120.25,
          'Aguachiles',
          Icons.restaurant,
          Colors.green,
        );
        for (final id in [10, 11]) {
          data.orders.add(
            Order(id, 'Cliente $id', '10:00', [
              OrderLine(p, 1),
            ], OrderStatus.pending),
          );
        }
        await tester.pumpWidget(
          MaterialApp(
            theme: buildKosteoTheme(),
            home: const Scaffold(body: SafeArea(child: OrdersScreen())),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Sin jornada'), findsNWidgets(2));
        await tester.tap(find.bySemanticsLabel('Seleccionar sin jornada'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();
        expect(find.text('Seleccionado'), findsNWidgets(2));
        await tester.tap(find.text('Asignar jornada'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Todavía no hay jornada abierta'),
          findsOneWidget,
        );
        Navigator.of(tester.element(find.text('Asignar a jornada'))).pop();
        await tester.pumpAndSettle();
        data.jornadas = [
          {
            'jornadaId': 5,
            'estado': 'ABIERTA',
            'fechaInicio': '2026-10-10',
            'fechaFin': '2026-10-11',
          },
        ];
        await tester.tap(find.text('Asignar jornada'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('2026-10-10 · 2026-10-11'));
        await tester.pumpAndSettle();
        if (fail) {
          expect(find.text('La jornada ya está cerrada.'), findsOneWidget);
          expect(data.orders.every((o) => o.jornadaId == null), isTrue);
          expect(data.assigned, isEmpty);
        } else {
          expect(data.assigned.toSet(), {10, 11});
          expect(data.orders.every((o) => o.jornadaId == 5), isTrue);
          expect(find.text('Pedidos asignados a la jornada'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 6));
        data.api.dispose();
      });
    }
  }
}
