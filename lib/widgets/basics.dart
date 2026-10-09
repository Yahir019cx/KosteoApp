import 'package:flutter/material.dart';

import '../theme/icons.dart';

import '../theme/tokens.dart';
import 'motion.dart';

/// Card base: superficie blanca, esquinas generosas y borde fino. Sin sombra.
class KosteoCard extends StatelessWidget {
  const KosteoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(KSpace.xl),
    this.onTap,
    this.color = KColors.surface,
    this.radius = KRadius.card,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: KColors.line),
      ),
      child: child,
    );
    return onTap == null
        ? card
        : Pressable(onTap: onTap, scale: 0.98, child: card);
  }
}

/// Encabezado de pantalla (sustituye al AppBar): título grande, subtítulo,
/// botón atrás circular y acciones.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.back = false,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final bool back;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.gutter,
        KSpace.l,
        context.gutter,
        KSpace.l,
      ),
      child: Row(
        children: [
          if (back) ...[
            CircleIconButton(
              icon: KIcons.caretLeft,
              onTap: () => Navigator.of(context).maybePop(),
              semanticLabel: 'Atrás',
            ),
            const SizedBox(width: KSpace.m),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: KText.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: KText.caption),
                ],
              ],
            ),
          ),
          for (final a in actions) ...[const SizedBox(width: KSpace.s), a],
        ],
      ),
    );
  }
}

class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.color = KColors.ink,
    this.background,
    this.size = 44,
    this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final Color? background;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.9,
      semanticLabel: semanticLabel,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background ?? KColors.mist,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: size * 0.45, color: color),
      ),
    );
  }
}

/// Botón principal: color agua sólido, sin sombras.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.trailing,
    this.color,
    this.height = 56,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Widget? trailing;
  final Color? color;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final c = color;
    return Pressable(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: KMotion.fast,
        opacity: enabled ? 1 : 0.45,
        child: Container(
          height: height,
          width: expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: KSpace.xl),
          decoration: BoxDecoration(
            color: c ?? KColors.sea,
            borderRadius: BorderRadius.circular(KRadius.button),
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: KSpace.s),
              ],
              Flexible(
                child: Text(
                  label,
                  style: KText.bodyStrong.copyWith(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: KSpace.s),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón secundario: tinte del color al 8%, sin sombra.
class SoftButton extends StatelessWidget {
  const SoftButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.color = KColors.sea,
    this.height = 48,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color color;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: KMotion.base,
        height: height,
        width: expand ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: KSpace.l),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(KRadius.button - 4),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: color, size: 18),
              const SizedBox(width: KSpace.s),
            ],
            Flexible(
              child: AnimatedSwitcher(
                duration: KMotion.fast,
                child: Text(
                  label,
                  key: ValueKey(label),
                  style: KText.bodyStrong.copyWith(color: color, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpace.m),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: KText.bodyStrong.copyWith(fontSize: 17)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Mosaico con icono sobre fondo suave del color de la categoría.
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, required this.tint, this.size = 44});
  final IconData icon;
  final Color tint;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Icon(
        icon,
        size: size * 0.48,
        color: Color.lerp(tint, KColors.ink, 0.25),
      ),
    );
  }
}

/// Píldora de estado con transición de color y texto.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: KMotion.base,
      curve: KMotion.ease,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(KRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: KMotion.base,
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          AnimatedSwitcher(
            duration: KMotion.base,
            child: Text(
              label,
              key: ValueKey(label),
              style: KText.caption.copyWith(
                color: Color.lerp(color, KColors.ink, 0.35),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Estado vacío con guía y siguiente paso (nunca una pantalla en blanco).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: KSpace.xxxl,
          horizontal: KSpace.xl,
        ),
        child: Column(
          children: [
            IconTile(icon, tint: KColors.sea, size: 72),
            const SizedBox(height: KSpace.l),
            Text(title, style: KText.bodyStrong, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: KSpace.xs),
              Text(message!, style: KText.caption, textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: KSpace.xl), action!],
          ],
        ),
      ),
    );
  }
}

/// Limita el ancho del contenido en tablet/Windows y lo centra.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 1180});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
