import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entity/package_entity.dart';
import '../booking_format.dart';

/// Строка пакета: доступность, причина недоступности и сравнение с почасовой ценой.
typedef PackageRow = ({
  PackageEntity package,
  bool ok,
  String reason,
  num hourly,
});

/// Карточки пакетов в шаге «план зала».
class PackageCards extends StatelessWidget {
  /// Создаёт список карточек пакетов.
  const PackageCards({
    required this.rows,
    required this.selectedId,
    required this.accent,
    required this.onSelected,
    super.key,
  });

  /// Пакеты с рассчитанной доступностью.
  final List<PackageRow> rows;

  /// Id выбранного пакета.
  final String? selectedId;

  /// Акцент клуба.
  final Color accent;

  /// Колбэк выбора / снятия пакета.
  final ValueChanged<PackageEntity?> onSelected;

  @override
  Widget build(BuildContext context) {
    final Color tint = accent == BookingColors.emeraldAccent
        ? BookingColors.emeraldTint
        : BookingColors.limeTint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final PackageRow r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _card(r, r.package.id == selectedId, tint),
          ),
      ],
    );
  }

  Widget _card(PackageRow r, bool selected, Color tint) {
    final PackageEntity p = r.package;
    final bool on = selected && r.ok;

    final String rightSub;
    final Color rightSubColor;
    final bool strike;
    if (r.ok) {
      final bool cheaper = r.hourly > p.price;
      rightSub = cheaper ? 'по часам — ${BookingFormat.money(r.hourly)}' : '';
      rightSubColor = BookingColors.textDim;
      strike = cheaper;
    } else {
      rightSub = r.reason;
      rightSubColor = const Color(0xFFFFB020);
      strike = false;
    }

    return InkWell(
      onTap: r.ok ? () => onSelected(selected ? null : p) : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: on ? accent : BookingColors.border),
          color: on
              ? accent.withValues(alpha: 0.14)
              : r.ok
                  ? BookingColors.surface
                  : BookingColors.fieldSurface,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(p.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: r.ok ? BookingColors.text : const Color(0xFF7C7C88),
                      )),
                  const SizedBox(height: 2),
                  Text(p.note,
                      style: const TextStyle(fontSize: 12, color: BookingColors.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    BookingFormat.money(p.price),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: r.ok ? BookingColors.text : const Color(0xFF7C7C88),
                      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                    ),
                  ),
                  if (rightSub.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      rightSub,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        color: rightSubColor,
                        decoration: strike ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
