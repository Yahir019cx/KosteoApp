import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kosteo/data/api_client.dart';
import 'package:kosteo/data/app_store.dart';

void main() {
  test('Piña opcional suma consumo, nunca un adicional de venta', () {
    final p =
        Product('Aguachile', 120, 'Aguachiles', Icons.restaurant, Colors.white)
          ..options = [
            {'tipo': 'EXTRA', 'nombre': 'Piña', 'precioAdicional': 99},
          ];
    expect(p.optionPrice('Piña'), 0);
    expect(p.optionPriceOrNull('Piña'), 0);
    p.options.first['precioAdicional'] = null;
    expect(p.optionPriceOrNull('Piña'), 0);
    expect(OrderLine(p, 1, extras: ['Piña']).total, 120);
    expect(OrderLine(p, 1).total, 120);
  });
  test(
    'Recargar el menú conserva precioVenta, centavos y pendientes',
    () async {
      num? individual = 120.25;
      final api = ApiClient(
        client: MockClient((request) async {
          expect(request.url.path, '/platillos');
          return http.Response(
            jsonEncode([
              {
                'platilloId': 1,
                'nombre': 'Aguachile Verde',
                'categoria': 'AGUACHILES',
                'pausado': false,
                'opciones': [],
                'fotoBase64': null,
                'presentaciones': [
                  {
                    'presentacionId': 4,
                    'nombre': 'Pa Compartir',
                    'precioVenta': 190.50,
                    'activa': true,
                  },
                  {
                    'presentacionId': 1,
                    'nombre': 'Individual',
                    'precioVenta': individual,
                    'activa': true,
                  },
                ],
              },
              {
                'platilloId': 9,
                'nombre': 'Vaso preparado',
                'categoria': 'BEBIDAS',
                'pausado': false,
                'opciones': [],
                'fotoBase64': null,
                'presentaciones': [
                  {
                    'presentacionId': 12,
                    'nombre': 'Única',
                    'precioVenta': 54.56,
                    'activa': true,
                  },
                ],
              },
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final localStore = KosteoStore(client: api);
      try {
        await localStore.menu();
        expect(localStore.product(1).price, 120.25);
        expect(localStore.product(1).sizes?['Individual'], 120.25);
        expect(localStore.product(1).sizes?['Pa Compartir'], 190.50);
        expect(localStore.product(9).price, 54.56);
        individual = null;
        await localStore.menu();
        expect(localStore.product(1).price, isNull);
        expect(localStore.product(1).sizes?['Individual'], isNull);
      } finally {
        api.dispose();
        localStore.dispose();
        products.clear();
      }
    },
  );
  test('Una respuesta perdida conserva el UUID al reintentar', () async {
    final received = <String>[];
    final api = ApiClient(
      client: MockClient((request) async {
        received.add((jsonDecode(request.body) as Map)['claveOperacion']);
        if (received.length == 1) {
          throw http.ClientException('Respuesta perdida');
        }
        return http.Response('{"pedidoId":1}', 201);
      }),
    );
    Future<dynamic> attempt() => api.request(
      'POST',
      '/pedidos',
      body: {
        'claveOperacion': operationKey(),
        'tipoEntrega': 'RECOGER',
        'lineas': [
          {'presentacionId': 1, 'cantidad': 1},
        ],
      },
    );
    await expectLater(attempt(), throwsA(isA<ApiException>()));
    await attempt();
    expect(received[1], received[0]);
    await attempt();
    expect(received[2], isNot(received[0]));
    api.dispose();
  });
  test('Centavos y pendientes mantienen el contrato visual', () {
    expect(money(54.56), '\$54.56');
    expect(money(7.96), '\$7.96');
    expect(money(null), 'Pendiente');
  });
}
