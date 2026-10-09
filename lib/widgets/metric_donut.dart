import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'motion.dart';

class DonutSegment {
  const DonutSegment(this.label, this.value, this.color);
  final String label;
  final num? value;
  final Color color;
}

/// Donut animado: barre al aparecer, interpola al cambiar de periodo y
/// resalta el segmento seleccionado (los demás se atenúan).
/// [ring] dibuja un arco exterior fino independiente (p. ej. inventario).
class MetricDonut extends StatefulWidget {
  const MetricDonut({
    super.key,
    required this.segments,
    required this.center,
    this.size = 220,
    this.stroke = 26,
    this.selected,
    this.ring,
    this.ringOf,
  });

  final List<DonutSegment> segments;
  final Widget center;
  final double size;
  final double stroke;
  final int? selected;
  final DonutSegment? ring;
  final num? ringOf; // total contra el que se mide el arco exterior

  @override
  State<MetricDonut> createState() => _MetricDonutState();
}

class _MetricDonutState extends State<MetricDonut>
    with SingleTickerProviderStateMixin {
  late final _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.reduceMotion) {
        _intro.value = 1;
      } else {
        _intro.forward();
      }
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final values = widget.segments
        .map((s) => (s.value ?? 0).clamp(0, double.infinity).toDouble())
        .toList();
    return SizedBox.square(
      dimension: widget.size,
      child: TweenAnimationBuilder<List<double>>(
        tween: _ListTween(end: values),
        duration: KMotion.slow,
        curve: KMotion.ease,
        builder: (context, animated, _) => AnimatedBuilder(
          animation: _intro,
          builder: (context, _) => CustomPaint(
            painter: _DonutPainter(
              values: animated,
              colors: widget.segments.map((s) => s.color).toList(),
              stroke: widget.stroke,
              progress: Curves.easeOutQuart.transform(_intro.value),
              selected: widget.selected,
              ring: widget.ring,
              ringFraction: widget.ring == null || (widget.ringOf ?? 0) == 0
                  ? 0
                  : ((widget.ring!.value ?? 0) / widget.ringOf!)
                        .clamp(0, 1)
                        .toDouble(),
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(
                  widget.stroke + (widget.ring == null ? 12 : 26),
                ),
                child: FittedBox(fit: BoxFit.scaleDown, child: widget.center),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ListTween extends Tween<List<double>> {
  _ListTween({super.end});

  @override
  List<double> lerp(double t) {
    final b = begin ?? end!;
    final e = end!;
    if (b.length != e.length) return e;
    return [for (var i = 0; i < e.length; i++) b[i] + (e[i] - b[i]) * t];
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.values,
    required this.colors,
    required this.stroke,
    required this.progress,
    required this.selected,
    required this.ring,
    required this.ringFraction,
  });

  final List<double> values;
  final List<Color> colors;
  final double stroke;
  final double progress;
  final int? selected;
  final DonutSegment? ring;
  final double ringFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final ringGap = ring == null ? 0.0 : 14.0;
    final r = (size.shortestSide - stroke) / 2 - ringGap;
    final c = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: c, radius: r);

    // pista
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = KColors.mist,
    );

    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;
    const gap = 0.045; // separación entre segmentos (rad)
    var start = -math.pi / 2;
    final sweepAll = 2 * math.pi * progress;

    for (var i = 0; i < values.length; i++) {
      final sweep = sweepAll * values[i] / total;
      final isSel = selected == i;
      final dim = selected != null && !isSel;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = isSel ? stroke + 6 : stroke
        ..color = dim ? colors[i].withValues(alpha: 0.28) : colors[i];
      final s = math.max(0.0, sweep - gap - stroke / r);
      if (s > 0) {
        canvas.drawArc(rect, start + (gap + stroke / r) / 2, s, false, paint);
      } else if (sweep > 0.01) {
        // Segmento muy pequeño: se dibuja como punto para que siga visible.
        final mid = start + sweep / 2;
        canvas.drawCircle(
          c + Offset(math.cos(mid), math.sin(mid)) * r,
          paint.strokeWidth / 2,
          Paint()..color = paint.color,
        );
      }
      start += sweep;
    }

    if (ring != null) {
      final rr = r + stroke / 2 + 10;
      final ringRect = Rect.fromCircle(center: c, radius: rr);
      canvas.drawCircle(
        c,
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = ring!.color.withValues(alpha: 0.15),
      );
      canvas.drawArc(
        ringRect,
        -math.pi / 2,
        2 * math.pi * ringFraction * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 5
          ..color = ring!.color,
      );
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress ||
      old.selected != selected ||
      old.values != values;
}

/// Fila de leyenda tocable: punto de color, etiqueta, porcentaje y valor.
class DonutLegendRow extends StatelessWidget {
  const DonutLegendRow({
    super.key,
    required this.segment,
    required this.total,
    this.selected = false,
    this.dimmed = false,
    this.onTap,
    this.hint,
  });

  final DonutSegment segment;
  final num total;
  final bool selected;
  final bool dimmed;
  final VoidCallback? onTap;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0 : ((segment.value ?? 0) / total * 100).round();
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: AnimatedContainer(
        duration: KMotion.base,
        curve: KMotion.ease,
        padding: const EdgeInsets.symmetric(
          horizontal: KSpace.m,
          vertical: KSpace.m,
        ),
        decoration: BoxDecoration(
          color: selected
              ? segment.color.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(KRadius.tile),
        ),
        child: AnimatedOpacity(
          duration: KMotion.base,
          opacity: dimmed ? 0.45 : 1,
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: segment.color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: KSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      segment.label,
                      style: KText.body.copyWith(fontSize: 14),
                    ),
                    if (hint != null)
                      Text(hint!, style: KText.caption.copyWith(fontSize: 11)),
                  ],
                ),
              ),
              if (total > 0) ...[
                Text(
                  segment.value == null ? '—' : '$pct%',
                  style: KText.caption,
                ),
                const SizedBox(width: KSpace.m),
              ],
              SizedBox(
                width: 92,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AnimatedMoney(segment.value, style: KText.number),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Texto auxiliar para el centro del donut.
class DonutCenter extends StatelessWidget {
  const DonutCenter({
    super.key,
    required this.value,
    required this.label,
    this.footer,
  });
  final num? value;
  final String label;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedMoney(value, style: KText.display),
        const SizedBox(height: 2),
        AnimatedSwitcher(
          duration: KMotion.fast,
          child: Text(label, key: ValueKey(label), style: KText.caption),
        ),
        if (footer != null) ...[const SizedBox(height: KSpace.s), footer!],
      ],
    );
  }
}
