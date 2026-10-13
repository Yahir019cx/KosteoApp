import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'outbox.dart';
import 'api_client.dart';

Future<Outbox> openOutbox(
  ApiClient api,
  void Function(PendingSend) onSaved, {
  Directory? directory,
}) async {
  final dir = directory ?? await getApplicationSupportDirectory();
  await dir.create(recursive: true);
  // Separar colas por backend evita enviar capturas al ambiente equivocado.
  final file = File(
    '${dir.path}/kosteo-envios-${Uri.encodeComponent(api.baseUrl)}.json',
  );
  final outbox = Outbox(
    api,
    onSaved: onSaved,
    persist: (data) async {
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(data, flush: true);
      await temp.rename(file.path);
    },
  );
  outbox.restore(await file.exists() ? await file.readAsString() : null);
  return outbox;
}
