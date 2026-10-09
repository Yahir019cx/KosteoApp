import '../data/app_store.dart';
import '../widgets/toast.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Navega con transición iOS (deslizar para regresar incluido).
Future<T?> push<T>(BuildContext context, Widget screen) =>
    Navigator.of(context).push<T>(CupertinoPageRoute(builder: (_) => screen));

/// Esqueleto de pantallas empujadas (sin barra de navegación inferior):
/// fondo blanco, área segura y una acción inferior opcional.
class KScaffold extends StatelessWidget {
  const KScaffold({super.key, required this.body, this.bottom});
  final Widget body;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColors.white,
      resizeToAvoidBottomInset: true,
      body: ColoredBox(
        color: KColors.white,
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(child: body),
              if (bottom != null)
                Positioned(left: 0, right: 0, bottom: 0, child: bottom!),
            ],
          ),
        ),
      ),
    );
  }
}

/// Acción inferior (Guardar...): sin vidrio ni sombra, solo un desvanecido
/// a blanco para que el contenido no choque con el botón.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.child, this.maxWidth = 640});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.35],
          colors: [KColors.white.withValues(alpha: 0), KColors.white],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.gutter,
          KSpace.xl,
          context.gutter,
          safe + KSpace.l,
        ),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        ),
      ),
    );
  }
}

Future<void> runAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  if (store.saving) return;
  store.saving = true;
  store.productChanged();
  try {
    await action();
  } catch (e) {
    if (context.mounted) showToast(context, e.toString());
  } finally {
    store.saving = false;
    store.productChanged();
  }
}
