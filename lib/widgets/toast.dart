import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/icons.dart';

import '../theme/tokens.dart';
import 'glass.dart';

OverlayEntry? _current;

/// Confirmación flotante de vidrio que baja desde arriba y se va sola.
void showToast(
  BuildContext context,
  String message, {
  IconData? icon,
  Color color = KColors.success,
}) {
  HapticFeedback.mediumImpact();
  _current?.remove();
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Toast(
      message: message,
      icon: icon ?? KIcons.checkCircleStrong,
      color: color,
      onDone: () {
        if (_current == entry) _current = null;
        if (entry.mounted) entry.remove();
      },
    ),
  );
  _current = entry;
  overlay.insert(entry);
}

class _Toast extends StatefulWidget {
  const _Toast({
    required this.message,
    required this.icon,
    required this.color,
    required this.onDone,
  });
  final String message;
  final IconData icon;
  final Color color;
  final VoidCallback onDone;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void initState() {
    super.initState();
    _c.forward();
    Future.delayed(const Duration(milliseconds: 2200), () async {
      if (!mounted) return;
      await _c.reverse();
      widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anim = CurvedAnimation(
      parent: _c,
      curve: KMotion.spring,
      reverseCurve: Curves.easeIn,
    );
    return Positioned(
      top: MediaQuery.paddingOf(context).top + KSpace.m,
      left: KSpace.l,
      right: KSpace.l,
      child: IgnorePointer(
        child: Center(
          child: FadeTransition(
            opacity: _c,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, -0.8),
                end: Offset.zero,
              ).animate(anim),
              child: ScaleTransition(
                scale: Tween(begin: 0.9, end: 1.0).animate(anim),
                child: Glass(
                  radius: KRadius.chip,
                  opacity: 0.78,
                  padding: const EdgeInsets.fromLTRB(
                    KSpace.m,
                    KSpace.m,
                    KSpace.xl,
                    KSpace.m,
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(widget.icon, color: widget.color, size: 24),
                        const SizedBox(width: KSpace.s),
                        Flexible(
                          child: Text(
                            widget.message,
                            style: KText.bodyStrong.copyWith(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
