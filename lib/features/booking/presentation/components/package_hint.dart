import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entity/package_advice_entity.dart';
import '../../domain/entity/package_entity.dart';
import '../booking_format.dart';

/// Подсказка над кнопкой «Забронировать»: пакет побольше выйдет не дороже
/// текущего выбора («6 шлемов выйдет дешевле»).
class PackageUpgradeHint extends StatelessWidget {
  /// Создаёт подсказку.
  const PackageUpgradeHint({
    required this.advice,
    required this.accent,
    required this.onApply,
    super.key,
  });

  /// Совет: какой пакет и насколько он выгоднее.
  final PackageAdviceEntity advice;

  /// Акцент клуба.
  final Color accent;

  /// Взять пакет.
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final PackageEntity p = advice.package;
    final String target = _kit(p.headsets, p.consoles);
    final String current = _kit(advice.headsets, advice.consoles);
    final bool cheaper = advice.saving > 0;

    return _HintCard(
      accent: accent,
      icon: Icons.local_offer_outlined,
      title: cheaper ? '$target выйдет дешевле' : '$target — за ту же цену',
      text: 'Пакет «${p.name}»: $target за ${BookingFormat.money(p.price)} — '
          '${cheaper ? 'на ${BookingFormat.money(advice.saving)} меньше, чем '
              '$current сейчас (${BookingFormat.money(advice.currentPrice)})' : 'столько же, сколько $current сейчас'}.',
      action: _HintAction(label: 'Взять $target', accent: accent, onTap: onApply),
    );
  }
}

/// Пояснение, почему итог ниже почасового: цена посчитана по пакету.
class PackageAppliedHint extends StatelessWidget {
  /// Создаёт пояснение.
  const PackageAppliedHint({
    required this.label,
    required this.net,
    required this.gross,
    required this.accent,
    super.key,
  });

  /// Подпись пакета («Пакет «Команда»»).
  final String label;

  /// Итог по пакету, ₽.
  final num net;

  /// Сумма по часам, ₽.
  final num gross;

  /// Акцент клуба.
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return _HintCard(
      accent: accent,
      icon: Icons.check_circle_outline_rounded,
      title: 'Посчитали по пакету',
      text: '$label: ${BookingFormat.money(net)} вместо '
          '${BookingFormat.money(gross)} по часам.',
    );
  }
}

/// «6 шлемов», «4 шлема и 2 PS5», «2 PS5».
String _kit(int headsets, int consoles) => <String>[
      if (headsets > 0)
        '$headsets ${BookingFormat.plural(headsets, 'шлем', 'шлема', 'шлемов')}',
      if (consoles > 0) '$consoles PS5',
    ].join(' и ');

class _HintCard extends StatelessWidget {
  const _HintCard({
    required this.accent,
    required this.icon,
    required this.title,
    required this.text,
    this.action,
  });

  final Color accent;
  final IconData icon;
  final String title;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: BookingColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: BookingColors.textSoft,
                  ),
                ),
                if (action != null) ...<Widget>[
                  const SizedBox(height: 12),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HintAction extends StatelessWidget {
  const _HintAction({
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: BookingColors.bg,
            ),
          ),
        ),
      ),
    );
  }
}
