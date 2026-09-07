import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entity/hall_option_entity.dart';
import 'booking_atoms.dart';

/// Выбор зала / варианта «Весь клуб» (шаг 2).
class HallSelector extends StatelessWidget {
  /// Создаёт селектор зала.
  const HallSelector({
    required this.options,
    required this.selectedId,
    required this.accent,
    required this.onSelected,
    super.key,
  });

  /// Варианты зала.
  final List<HallOptionEntity> options;

  /// Id выбранного варианта.
  final String? selectedId;

  /// Акцент клуба.
  final Color accent;

  /// Колбэк выбора.
  final ValueChanged<HallOptionEntity> onSelected;

  @override
  Widget build(BuildContext context) {
    final List<HallOptionEntity> rooms =
        options.where((HallOptionEntity o) => !o.isCombo).toList();
    final HallOptionEntity? combo = options
        .where((HallOptionEntity o) => o.isCombo)
        .cast<HallOptionEntity?>()
        .firstWhere((HallOptionEntity? o) => true, orElse: () => null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int i = 0; i < rooms.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: _RoomChip(
                    option: rooms[i],
                    selected: rooms[i].id == selectedId,
                    accent: accent,
                    onTap: () => onSelected(rooms[i]),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (combo != null) ...<Widget>[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: PillButton(
              label: '${combo.name} · ${combo.kitLabel}',
              selected: combo.id == selectedId,
              accent: accent,
              dashed: true,
              onTap: () => onSelected(combo),
            ),
          ),
        ],
      ],
    );
  }
}

class _RoomChip extends StatelessWidget {
  const _RoomChip({
    required this.option,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final HallOptionEntity option;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color tint = accent == BookingColors.emeraldAccent
        ? BookingColors.emeraldTint
        : BookingColors.limeTint;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: selected ? accent : BookingColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              option.name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: selected ? tint : BookingColors.text,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              option.kitLabel,
              style: const TextStyle(fontSize: 12, color: BookingColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
