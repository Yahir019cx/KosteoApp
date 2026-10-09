import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kosteo/data/api_client.dart';
import 'package:kosteo/data/app_store.dart';

void main() {
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
