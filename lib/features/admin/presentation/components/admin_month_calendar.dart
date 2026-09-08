import 'package:flutter/material.dart';

import '../../domain/service/admin_pricing_service.dart';
import '../../domain/state/admin_bloc.dart';
import '../admin_format.dart';
import '../admin_theme.dart';

/// Календарь-виджет для выбора дня (смещения от сегодняшнего).
///
/// Может работать как «управляемый» (передан [visibleMonth] + [onMonthChanged])
/// либо сам хранить видимый месяц.
class AdminMonthCalendar extends StatefulWidget {
  /// Создаёт календарь.
  const AdminMonthCalendar({
    required this.selectedDayIndex,
    required this.onPick,
    required this.accent,
    required this.slug,
    this.pricing = const AdminPricingService(),
    this.maxDays = AdminState.calendarDays,
    this.visibleMonth,
    this.onMonthChanged,
    this.showFootnote = true,
    super.key,
  });

  /// Выбранный день (смещение от сегодняшнего); `-1` — ничего не выбрано.
  final int selectedDayIndex;

  /// Колбэк выбора дня.
  final ValueChanged<int> onPick;

  /// Акцент клуба.
  final Color accent;

  /// Slug клуба (для tint).
  final String slug;

  /// Сервис дат.
  final AdminPricingService pricing;

  /// Горизонт выбора, дней.
  final int maxDays;

  /// Видимый месяц (первое число) — для управляемого режима.
  final DateTime? visibleMonth;

  /// Колбэк смены месяца — для управляемого режима.
  final ValueChanged<DateTime>? onMonthChanged;

  /// Показывать подпись под сеткой («Сегодня, вт, 8 сентября · тариф будней»).
  final bool showFootnote;

  @override
  State<AdminMonthCalendar> createState() => _AdminMonthCalendarState();
}

class _AdminMonthCalendarState extends State<AdminMonthCalendar> {
  late DateTime _month = _initialMonth();

  DateTime _initialMonth() {
    final int di = widget.selectedDayIndex < 0 ? 0 : widget.selectedDayIndex;
    final DateTime d = widget.pricing.dateOf(di);
    return DateTime(d.year, d.month);
  }

  DateTime get _visible => widget.visibleMonth ?? _month;

  void _goto(DateTime m) {
    final DateTime next = DateTime(m.year, m.month);
    if (widget.onMonthChanged != null) {
      widget.onMonthChanged!(next);
    } else {
      setState(() => _month = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color tint = AdminColors.tintFor(widget.slug);
    final DateTime base = AdminPricingService.baseDate();
    final DateTime last = base.add(Duration(days: widget.maxDays - 1));
    final DateTime firstMonth = DateTime(base.year, base.month);
    final DateTime lastMonth = DateTime(last.year, last.month);
    final DateTime month = _visible;

    final bool canPrev = month.isAfter(firstMonth);
    final bool canNext = month.isBefore(lastMonth);

    final DateTime monthFirst = DateTime(month.year, month.month);
    final int daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final int lead = monthFirst.weekday - 1; // Пн = 0.

    final int selDi = widget.selectedDayIndex;
    final DateTime selDate = widget.pricing.dateOf(selDi < 0 ? 0 : selDi);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF0B0D10),
        border: Border.all(color: AdminColors.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _Arrow(glyph: '‹', enabled: canPrev, onTap: () => _goto(DateTime(month.year, month.month - 1))),
              Expanded(
                child: Text(
                  AdminFormat.monthYear(month),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              _Arrow(glyph: '›', enabled: canNext, onTap: () => _goto(DateTime(month.year, month.month + 1))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              for (final String w in <String>['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'])
                Expanded(
                  child: Center(
                    child: Text(w,
                        style: const TextStyle(fontSize: 11, color: AdminColors.textLabel)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.35,
            children: <Widget>[
              for (int i = 0; i < lead; i++) const SizedBox.shrink(),
              for (int day = 1; day <= daysInMonth; day++)
                _DayCell(
                  day: day,
                  date: DateTime(month.year, month.month, day),
                  base: base,
                  maxDays: widget.maxDays,
                  selectedDayIndex: selDi,
                  accent: widget.accent,
                  tint: tint,
                  onPick: widget.onPick,
                ),
            ],
          ),
          if (widget.showFootnote) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              '${selDi == 0 ? 'Сегодня, ' : ''}'
              '${AdminFormat.dowShort(selDate)}, ${AdminFormat.dayMonthLong(selDate)}'
              ' · ${widget.pricing.isWeekend(selDi < 0 ? 0 : selDi) ? 'выходной тариф' : 'тариф будней'}',
              style: const TextStyle(fontSize: 12, color: AdminColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.date,
    required this.base,
    required this.maxDays,
    required this.selectedDayIndex,
    required this.accent,
    required this.tint,
    required this.onPick,
  });

  final int day;
  final DateTime date;
  final DateTime base;
  final int maxDays;
  final int selectedDayIndex;
  final Color accent;
  final Color tint;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final int di = DateTime(date.year, date.month, date.day).difference(base).inDays;
    final bool inRange = di >= 0 && di < maxDays;
    final bool selected = di == selectedDayIndex;
    final bool weekend =
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: InkWell(
        onTap: inRange ? () => onPick(di) : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: selected ? accent.withValues(alpha: 0.18) : Colors.transparent,
            border: Border.all(color: selected ? accent : Colors.transparent),
          ),
          child: Text(
            '$day',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              color: !inRange
                  ? AdminColors.textLabel
                  : selected
                      ? tint
                      : weekend
                          ? AdminColors.textMuted
                          : AdminColors.textSoft,
            ),
          ),
        ),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.glyph, required this.enabled, required this.onTap});

  final String glyph;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AdminColors.borderInput),
        ),
        child: Text(glyph,
            style: TextStyle(
                fontSize: 15,
                color: enabled ? AdminColors.textSoft : const Color(0xFF3E3E48))),
      ),
    );
  }
}
