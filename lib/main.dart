import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/shell.dart';
import 'theme/tokens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const KosteoApp());
}

class KosteoApp extends StatelessWidget {
  const KosteoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kosteo',
      debugShowCheckedModeBanner: false,
      theme: buildKosteoTheme(),
      scrollBehavior: const KosteoScrollBehavior(),
      home: const HomeShell(),
    );
  }
}
