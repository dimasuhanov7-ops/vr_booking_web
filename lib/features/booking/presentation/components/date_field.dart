import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../booking_format.dart';
import 'calendar_sheet.dart';

/// Кнопка выбора даты, открывающая календарь (шаг 2).
class DateField extends StatelessWidget {
  /// Создаёт поле даты.
  const DateField({
    required this.date,
    required this.accent,
    required this.daysAhead,
    required this.onSelected,
    this.tariffNote,
    super.key,
  });

  /// Выбранная дата.
  final DateTime date;

  /// Акцент клуба.
  final Color accent;

  /// На сколько дней вперёд открыта запись.
  final int daysAhead;

  /// Колбэк выбора даты.
  final ValueChanged<DateTime> onSelected;

  /// Подпись тарифа под датой («тариф будней» / «тариф выходного дня»).
  final String? tariffNote;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final DateTime? picked = await showModalBottomSheet<DateTime>(
          context: context,
          backgroundColor: BookingColors.frame,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          builder: (_) => CalendarSheet(
            initial: date,
            accent: accent,
            daysAhead: daysAhead,
          ),
        );
        if (picked != null) onSelected(picked);
      },
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: const Color(0xFF191920),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFF34343E)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    _cap(BookingFormat.dayLong(date)),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  if (tariffNote != null) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(tariffNote!,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: BookingColors.textMuted)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF101014),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFF3A3A45)),
              ),
              child: const Text('изменить',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: BookingColors.textSoft)),
            ),
          ],
        ),
      ),
    );
  }

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
