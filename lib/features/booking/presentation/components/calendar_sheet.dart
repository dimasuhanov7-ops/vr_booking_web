import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../booking_format.dart';

/// Календарь месяц-сеткой в нижнем листе. Возвращает выбранную дату.
class CalendarSheet extends StatefulWidget {
  /// Создаёт календарь.
  const CalendarSheet({
    required this.initial,
    required this.accent,
    required this.daysAhead,
    super.key,
  });

  /// Изначально выбранная дата.
  final DateTime initial;

  /// Акцент клуба.
  final Color accent;

  /// Горизонт записи в днях.
  final int daysAhead;

  @override
  State<CalendarSheet> createState() => _CalendarSheetState();
}

class _CalendarSheetState extends State<CalendarSheet> {
  late DateTime _month = DateTime(widget.initial.year, widget.initial.month);

  DateTime get _today {
    final DateTime n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTime get _last => _today.add(Duration(days: widget.daysAhead - 1));

  bool get _canPrev => _month.isAfter(DateTime(_today.year, _today.month));
  bool get _canNext => _month.isBefore(DateTime(_last.year, _last.month));

  @override
  Widget build(BuildContext context) {
    final Color tint = widget.accent == BookingColors.emeraldAccent
        ? BookingColors.emeraldTint
        : BookingColors.limeTint;
    final int daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final int lead = (DateTime(_month.year, _month.month, 1).weekday + 6) % 7;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: BookingColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: <Widget>[
                _Arrow(icon: Icons.chevron_left, enabled: _canPrev, onTap: () {
                  setState(() => _month = DateTime(_month.year, _month.month - 1));
                }),
                Expanded(
                  child: Text(
                    BookingFormat.monthTitle(_month),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                _Arrow(icon: Icons.chevron_right, enabled: _canNext, onTap: () {
                  setState(() => _month = DateTime(_month.year, _month.month + 1));
                }),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                for (final String h in const <String>['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'])
                  Expanded(
                    child: Center(
                      child: Text(h,
                          style: const TextStyle(fontSize: 11, color: BookingColors.textFaint)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.15,
              children: <Widget>[
                for (int i = 0; i < lead; i++) const SizedBox.shrink(),
                for (int d = 1; d <= daysInMonth; d++)
                  _dayCell(DateTime(_month.year, _month.month, d), tint),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayCell(DateTime day, Color tint) {
    final bool selected = day.year == widget.initial.year &&
        day.month == widget.initial.month &&
        day.day == widget.initial.day;
    final bool enabled = !day.isBefore(_today) && !day.isAfter(_last);
    final bool weekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: InkWell(
        onTap: enabled ? () => Navigator.of(context).pop(day) : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? widget.accent.withValues(alpha: 0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? widget.accent : Colors.transparent,
            ),
          ),
          child: Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: !enabled
                  ? BookingColors.textOff
                  : selected
                      ? tint
                      : weekend
                          ? BookingColors.textMuted
                          : const Color(0xFFE2E2E8),
            ),
          ),
        ),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.enabled, required this.onTap});

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon),
      color: BookingColors.textSoft,
      disabledColor: BookingColors.textOff,
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
          side: const BorderSide(color: BookingColors.border),
        ),
      ),
    );
  }
}
