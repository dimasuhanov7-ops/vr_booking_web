import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../booking_format.dart';

/// Липкий нижний бар: контекст, итоговая цена и CTA.
class BookingBottomBar extends StatelessWidget {
  /// Создаёт бар.
  const BookingBottomBar({
    required this.line,
    required this.net,
    required this.gross,
    required this.hasDiscount,
    required this.cta,
    required this.enabled,
    required this.busy,
    required this.accent,
    required this.onPressed,
    super.key,
  });

  /// Строка-контекст слева.
  final String line;

  /// Итоговая сумма (0 — показать «—»).
  final num net;

  /// Сумма без скидки.
  final num gross;

  /// Есть ли скидка.
  final bool hasDiscount;

  /// Подпись кнопки.
  final String cta;

  /// Активна ли кнопка.
  final bool enabled;

  /// Идёт отправка.
  final bool busy;

  /// Акцент клуба.
  final Color accent;

  /// Обработчик.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bool showTotal = net > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: const BoxDecoration(
        color: Color(0xF0101015),
        border: Border(top: BorderSide(color: BookingColors.borderSoft)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: BookingColors.textMuted),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Text(
                      showTotal ? BookingFormat.money(net) : '—',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    if (hasDiscount) ...<Widget>[
                      const SizedBox(width: 8),
                      Text(
                        BookingFormat.money(gross),
                        style: const TextStyle(
                          fontSize: 13,
                          color: BookingColors.textDim,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          _Cta(label: cta, enabled: enabled, busy: busy, accent: accent, onPressed: onPressed),
        ],
      ),
    );
  }
}

class _Cta extends StatelessWidget {
  const _Cta({
    required this.label,
    required this.enabled,
    required this.busy,
    required this.accent,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final bool busy;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled && !busy ? onPressed : null,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: enabled ? accent : const Color(0xFF202027),
          borderRadius: BorderRadius.circular(13),
        ),
        child: busy
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: BookingColors.bg),
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: enabled ? BookingColors.bg : BookingColors.textDim,
                ),
              ),
      ),
    );
  }
}
