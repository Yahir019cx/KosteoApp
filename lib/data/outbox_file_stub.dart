import 'outbox.dart';
import 'api_client.dart';

Future<Outbox> openOutbox(
  ApiClient api,
  void Function(PendingSend) onSaved,
) async => Outbox(api, onSaved: onSaved);
