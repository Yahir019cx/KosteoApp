import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/shell.dart';
import 'theme/tokens.dart';
import 'widgets/api_activity.dart';
import 'data/app_store.dart';
import 'data/outbox_file_stub.dart'
    if (dart.library.io) 'data/outbox_file.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  try {
    store.outbox = await openOutbox(store.api, store.onBackgroundSaved);
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'No se pudieron abrir los envíos pendientes. Reinicia la app; tus capturas no se borraron.',
            ),
          ),
        ),
      ),
    );
    return;
  }
  runApp(const KosteoApp());
}

class KosteoApp extends StatelessWidget {
  const KosteoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kosteo',
      navigatorKey: apiNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: buildKosteoTheme(),
      scrollBehavior: const KosteoScrollBehavior(),
      builder: (context, child) => ApiActivity(child: child!),
      home: const HomeShell(),
    );
  }
}
