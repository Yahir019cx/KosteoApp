import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/icons.dart';

import '../theme/tokens.dart';
import 'motion.dart';

/// Campo de texto sin estilo Android: superficie blanca redondeada,
/// sin subrayado, borde agua al enfocar.
class KTextField extends StatefulWidget {
  const KTextField({
    super.key,
    required this.controller,
    this.hint,
    this.icon,
    this.autofocus = false,
    this.onChanged,
    this.keyboardType,
    this.prefix,
    this.suffix,
    this.big = false,
    this.textAlign = TextAlign.start,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String? hint;
  final IconData? icon;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final String? prefix;
  final String? suffix;
  final bool big;
  final TextAlign textAlign;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<KTextField> createState() => _KTextFieldState();
}

class _KTextFieldState extends State<KTextField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.big
        ? KText.display.copyWith(fontSize: 30)
        : KText.body.copyWith(fontSize: 16);
    final affix = (widget.big ? KText.title : KText.body).copyWith(
      color: KColors.inkMuted,
    );
    return GestureDetector(
      onTap: _focus.requestFocus,
      child: AnimatedContainer(
        duration: KMotion.base,
        height: widget.big ? 72 : 56,
        padding: const EdgeInsets.symmetric(horizontal: KSpace.l + 2),
        decoration: BoxDecoration(
          color: _focus.hasFocus ? Colors.white : KColors.mist,
          borderRadius: BorderRadius.circular(KRadius.button),
          border: Border.all(
            color: _focus.hasFocus ? KColors.sea : KColors.mist,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: 20, color: KColors.inkMuted),
              const SizedBox(width: KSpace.m),
            ],
            if (widget.prefix != null) ...[
              Text(widget.prefix!, style: affix),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                autofocus: widget.autofocus,
                onChanged: widget.onChanged,
                keyboardType: widget.keyboardType,
                inputFormatters: widget.inputFormatters,
                textAlign: widget.textAlign,
                style: style,
                cursorRadius: const Radius.circular(2),
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration.collapsed(
                  hintText: widget.hint,
                  hintStyle: style.copyWith(
                    color: KColors.inkMuted.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
            if (widget.suffix != null) ...[
              const SizedBox(width: KSpace.s),
              Text(widget.suffix!, style: affix),
            ],
          ],
        ),
      ),
    );
  }
}

/// Etiqueta de pregunta encima de un campo/selector.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.optional = false});
  final String text;
  final bool optional;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: KSpace.s + 2, left: 4),
    child: Row(
      children: [
        Text(text, style: KText.bodyStrong.copyWith(fontSize: 14)),
        if (optional) ...[
          const SizedBox(width: KSpace.s),
          Text('Opcional', style: KText.caption.copyWith(fontSize: 11.5)),
        ],
      ],
    ),
  );
}

/// Stepper − valor + con el valor editable a mano.
class QtyStepper extends StatefulWidget {
  const QtyStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.step = 1,
    this.min = 0,
    this.unit,
    this.compact = false,
    this.decimal = false,
  });

  final num value;
  final ValueChanged<num> onChanged;
  final int step;
  final int min;
  final String? unit;
  final bool compact;
  final bool decimal;

  @override
  State<QtyStepper> createState() => _QtyStepperState();
}

class _QtyStepperState extends State<QtyStepper> {
  late final _ctrl = TextEditingController(text: '${widget.value}');
  final _focus = FocusNode();

  @override
  void didUpdateWidget(QtyStepper old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && _ctrl.text != '${widget.value}') {
      _ctrl.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _bump(int d) {
    final v = (widget.value + d).clamp(widget.min, 999999);
    HapticFeedback.selectionClick();
    _ctrl.text = '$v';
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.compact ? 32.0 : 40.0;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: KColors.mist.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(KRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepBtn(
            icon: KIcons.minusStrong,
            size: s,
            onTap: () => _bump(-widget.step),
          ),
          SizedBox(
            width: widget.compact ? 40 : 64,
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.numberWithOptions(
                decimal: widget.decimal,
              ),
              inputFormatters: [
                widget.decimal
                    ? FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                    : FilteringTextInputFormatter.digitsOnly,
              ],
              style: KText.number.copyWith(fontSize: widget.compact ? 14 : 17),
              decoration: const InputDecoration.collapsed(hintText: '0'),
              onChanged: (t) =>
                  widget.onChanged(num.tryParse(t.replaceAll(',', '.')) ?? 0),
            ),
          ),
          if (widget.unit != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(widget.unit!, style: KText.caption),
            ),
          _StepBtn(
            icon: KIcons.plusStrong,
            size: s,
            onTap: () => _bump(widget.step),
            filled: true,
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({
    required this.icon,
    required this.onTap,
    required this.size,
    this.filled = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    scale: 0.85,
    haptic: false,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? KColors.sea : Colors.white,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: size * 0.42,
        color: filled ? Colors.white : KColors.ink,
      ),
    ),
  );
}
