import 'package:flutter/material.dart';

import '../booking_format.dart';
import 'booking_atoms.dart';

/// Чипы выбора длительности сеанса (шаг 2).
class DurationSelector extends StatelessWidget {
  /// Создаёт селектор длительности.
  const DurationSelector({
    required this.options,
    required this.selected,
    required this.accent,
    required this.onSelected,
    super.key,
  });

  /// Доступные длительности, минут.
  final List<int> options;

  /// Выбранная длительность, минут.
  final int selected;

  /// Акцент клуба.
  final Color accent;

  /// Колбэк выбора.
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < options.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 8),
          PillButton(
            label: BookingFormat.duration(options[i]),
            selected: options[i] == selected,
            accent: accent,
            expand: true,
            onTap: () => onSelected(options[i]),
          ),
        ],
      ],
    );
  }
}
