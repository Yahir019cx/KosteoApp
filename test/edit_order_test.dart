import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kosteo/data/api_client.dart';
import 'package:kosteo/data/app_store.dart';
import 'package:kosteo/screens/new_order_screen.dart';
import 'package:kosteo/theme/tokens.dart';
import 'package:kosteo/widgets/inputs.dart';
import 'package:kosteo/widgets/product_card.dart';

class EditingStore extends KosteoStore {
  List<OrderLine>? saved;
  String? savedCustomer, savedNotes;
  bool fail = false;
  @override
  Future<void> editOrder(
    Order order,
    List<OrderLine> lines, {
    String? customer,
    String? phone,
    String type = 'RECOGER',
    String? reference,
    String? notes,
  }) async {
    if (fail) throw ApiException('El pedido cambió. Actualiza la lista.');
    saved = lines;
    savedCustomer = customer;
    savedNotes = notes;
  }
}

void main() {
  for (final width in [390.0, 1194.0]) {
    for (final started in [false, true]) {
      testWidgets(
        'Editar solo nombre/notas sin agregar $width iniciado=$started',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final data = EditingStore();
          store = data;
          products.clear();
          final p = Product(
            'Producto prueba',
            120,
            'Especiales',
            Icons.restaurant,
            KColors.mist,
            hasOptions: false,
          );
          final original = OrderLine(p, 2)
            ..detailId = 10
            ..savedPresentationId = 1
            ..historicalPrice = 100;
          final order =
              Order(99, 'Ana', '12:00', [
                  original,
                ], started ? OrderStatus.preparing : OrderStatus.pending)
                ..revision = 'A' * 64
                ..notes = 'Nota anterior';
          data.orders.add(order);
          await tester.pumpWidget(
            MaterialApp(
              theme: buildKosteoTheme(),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => NewOrderScreen(order: order),
                      ),
                    ),
                    child: const Text('Abrir editor'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Abrir editor'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Ana'));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byWidgetPredicate(
              (w) => w is TextField && w.decoration?.hintText == 'Nombre',
            ),
            'Nuevo nombre',
          );
          await tester.enterText(
            find.byWidgetPredicate(
              (w) =>
                  w is TextField &&
                  w.decoration?.hintText == 'Notas (opcional)',
            ),
            'Agregar limón aparte',
          );
          await tester.tap(find.text('Listo'));
          await tester.pumpAndSettle();
          await tester.tap(
            find.text(width < 700 ? 'Guardar' : 'Guardar cambios'),
          );
          await tester.pumpAndSettle();
          expect(data.savedCustomer, 'Nuevo nombre');
          expect(data.savedNotes, 'Agregar limón aparte');
          expect(data.saved!.length, 1);
          expect(data.saved!.single.detailId, 10);
          expect(data.saved!.single.qty, 2);
          expect(data.saved!.single.unitPrice, 100);
          expect(order.customer, 'Ana');
          expect(order.notes, 'Nota anterior');
          expect(find.text('Pedido #0099 actualizado'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pump(const Duration(seconds: 6));
          await tester.pumpAndSettle();
        },
      );
    }
  }
  for (final width in [390.0, 1194.0]) {
    for (final started in [false, true]) {
      for (final fail in [false, true]) {
        testWidgets('Editar pedido $width iniciado=$started error=$fail', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final data = EditingStore()..fail = fail;
          store = data;
          final p =
              Product(
                  'Producto prueba',
                  120,
                  'Especiales',
                  Icons.restaurant,
                  KColors.mist,
                  hasOptions: false,
                )
                ..id = 1
                ..presentationIds = {'Individual': 1};
          products
            ..clear()
            ..add(p);
          final original = OrderLine(p, 1, size: 'Individual')
            ..detailId = 10
            ..savedPresentationId = 1
            ..historicalPrice = 100;
          final order = Order(
            99,
            'Ana',
            '12:00',
            [original],
            started ? OrderStatus.preparing : OrderStatus.pending,
          )..revision = 'A' * 64;
          data.orders.add(order);
          await tester.pumpWidget(
            MaterialApp(
              theme: buildKosteoTheme(),
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => NewOrderScreen(order: order),
                      ),
                    ),
                    child: const Text('Abrir editor'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Abrir editor'));
          await tester.pumpAndSettle();
          expect(find.text('Editar #0099'), findsOneWidget);
          // Adding the same product produces a separate line at today's price.
          await tester.tap(find.byType(ProductCard).first);
          await tester.pumpAndSettle();
          if (width < 700) {
            await tester.tap(find.text('2 productos'));
            await tester.pumpAndSettle();
          }
          expect(find.byType(QtyStepper), findsNWidgets(started ? 1 : 2));
          if (!started) {
            final field = find.descendant(
              of: find.byType(QtyStepper).first,
              matching: find.byType(TextField),
            );
            await tester.enterText(field, '2');
            await tester.pumpAndSettle();
          }
          expect(
            original.qty,
            1,
          ); // Dismissing/editing cannot mutate the actual order.
          await tester.tap(find.text('Guardar cambios').last);
          await tester.pumpAndSettle();
          if (fail) {
            expect(data.saved, isNull);
            expect(
              find.text('El pedido cambió. Actualiza la lista.'),
              findsOneWidget,
            );
            expect(find.text('Editar #0099'), findsOneWidget);
          } else {
            expect(data.saved!.length, 2);
            expect(data.saved!.first.detailId, 10);
            expect(data.saved!.first.qty, started ? 1 : 2);
            expect(data.saved!.first.unitPrice, 100);
            expect(data.saved!.last.detailId, isNull);
            expect(data.saved!.last.unitPrice, 120);
            expect(find.text('Pedido #0099 actualizado'), findsOneWidget);
            expect(find.text('Abrir editor'), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
          await tester.pump(const Duration(seconds: 6));
          await tester.pumpAndSettle();
        });
      }
    }
  }
}
