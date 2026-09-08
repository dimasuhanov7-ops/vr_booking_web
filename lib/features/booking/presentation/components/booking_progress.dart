import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// Заголовок шага: «Шаг N из M» + название + подсказка.
///
/// При [steps] == 3 (клуб зафиксирован через `?club=`) первый шаг «выбор клуба»
/// не показывается — заголовки берутся со сдвигом.
class BookingProgress extends StatelessWidget {
  /// Создаёт заголовок.
  const BookingProgress({
    required this.step,
    required this.accent,
    this.steps = 4,
    super.key,
  });

  /// Номер текущего шага (1..[steps]).
  final int step;

  /// Всего шагов (3 или 4).
  final int steps;

  /// Акцент клуба.
  final Color accent;

  static const List<String> _titles = <String>[
    'Куда идём играть?',
    'Когда и на сколько',
    'Кто где стоит',
    'Последний шаг',
  ];

  static const List<String> _hints = <String>[
    'Два клуба, разная вместимость. Оплата на месте — сейчас только держим за вами станции.',
    'Сначала выберите время: под каждым слотом видно, сколько станций в этом зале свободно.',
    'Отметьте станции для своей компании — одна станция на человека.',
    'Оставьте контакты, мы перезвоним только если что-то изменится.',
  ];

  @override
  Widget build(BuildContext context) {
    final int total = steps.clamp(1, 4);
    final int offset = 4 - total; // 0 при 4 шагах, 1 при 3
    final int i = (step - 1).clamp(0, total - 1);
    final int titleIndex = (i + offset).clamp(0, 3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: List<Widget>.generate(total, (int k) {
            final bool on = k <= i;
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: k < total - 1 ? 4 : 0),
                decoration: BoxDecoration(
                  color: on ? accent : Colors.white12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        Text('ШАГ ${i + 1} ИЗ $total',
            style: const TextStyle(
                fontSize: 11, letterSpacing: 1.4, color: BookingColors.textFaint)),
        const SizedBox(height: 6),
        Text(_titles[titleIndex],
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.4, height: 1.15)),
        const SizedBox(height: 6),
        Text(_hints[titleIndex],
            style: const TextStyle(fontSize: 14, height: 1.4, color: BookingColors.textMuted)),
      ],
    );
  }
}
