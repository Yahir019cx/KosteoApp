import 'package:flutter/material.dart';

import '../theme/icons.dart';

import '../data/app_store.dart';
import '../theme/tokens.dart';
import 'basics.dart';

/// Card de pedido: solo lo esencial + una acción contextual de un toque.
class OrderCard extends StatefulWidget {
  const OrderCard({super.key, required this.order, required this.onAdvance});
  final Order order;
  final VoidCallback onAdvance;

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  bool _done = false;

  Future<void> _advance() async {
    if (_done) return;
    setState(() => _done = true);
    await Future.delayed(const Duration(milliseconds: 520));
    if (!mounted) return;
    widget.onAdvance();
    setState(() => _done = false);
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final status = o.status;
    final next = o.nextStep;

    return KosteoCard(
      padding: const EdgeInsets.all(KSpace.l + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(o.folio, style: KText.bodyStrong.copyWith(fontSize: 17)),
              const SizedBox(width: KSpace.s),
              Text(o.time, style: KText.caption),
              const Spacer(),
              StatusPill(label: status.label, color: status.color),
            ],
          ),
          const SizedBox(height: KSpace.s),
          Row(
            children: [
              const Icon(KIcons.user, size: 16, color: KColors.inkMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  o.customer ?? 'Sin nombre',
                  style: KText.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (o.tipoEntrega == 'ENTREGA' && (o.reference ?? '').isNotEmpty)
            Text(
              'Entrega · ${o.reference}',
              style: KText.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if ((o.notes ?? '').isNotEmpty)
            Text(
              o.notes!,
              style: KText.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: KSpace.l),
          for (final l in o.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${l.qty}×',
                      style: KText.number.copyWith(
                        color: KColors.sea,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: l.name,
                            style: KText.body.copyWith(fontSize: 14),
                          ),
                          if (l.detail.isNotEmpty)
                            TextSpan(
                              text: '  ${l.detail}',
                              style: KText.caption.copyWith(fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: KSpace.m),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total', style: KText.caption),
                  Text(
                    money(o.total),
                    style: KText.number.copyWith(fontSize: 20),
                  ),
                ],
              ),
              const SizedBox(width: KSpace.l),
              Expanded(
                child: next == null
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(
                            status == OrderStatus.cancelled
                                ? KIcons.x
                                : KIcons.checkCircleStrong,
                            color: status.color,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            status.label,
                            style: KText.bodyStrong.copyWith(
                              color: status.color,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      )
                    : SoftButton(
                        label: _done ? '¡Listo!' : next.$2,
                        icon: _done ? KIcons.checkStrong : _iconFor(next.$1),
                        color: _done ? KColors.success : next.$1.color,
                        onTap: _advance,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconFor(OrderStatus s) => switch (s) {
    OrderStatus.preparing => KIcons.playStrong,
    OrderStatus.ready => KIcons.bellRinging,
    OrderStatus.delivering => KIcons.moped,
    _ => KIcons.checks,
  };
}
