import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entity/club_entity.dart';
import '../../domain/state/booking_bloc.dart';
import '../booking_format.dart';
import 'booking_atoms.dart';
import 'hall_plan.dart';

/// Многочасовой план: вкладка на каждый час сеанса — можно держать разное
/// число станций (12 шлемов в первый час, 6 во второй).
class SessionHours extends StatefulWidget {
  /// Создаёт блок.
  const SessionHours({
    required this.state,
    required this.club,
    required this.accent,
    super.key,
  });

  /// Состояние брони.
  final BookingState state;

  /// Клуб (для перевода времени в часовой пояс клуба).
  final ClubEntity club;

  /// Акцент клуба.
  final Color accent;

  @override
  State<SessionHours> createState() => _SessionHoursState();
}

class _SessionHoursState extends State<SessionHours> {
  int _hour = 0;

  @override
  void didUpdateWidget(covariant SessionHours old) {
    super.didUpdateWidget(old);
    if (_hour >= widget.state.hourCount) {
      _hour = widget.state.hourCount - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final BookingBloc bloc = context.read<BookingBloc>();
    final BookingState s = widget.state;
    final int hc = s.hourCount;
    final int hour = _hour.clamp(0, hc - 1);

    final (DateTime, DateTime)? win = s.hourWindow(hour);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionLabel('Станции по часам'),
        const SizedBox(height: 6),
        Text(
          'Для каждого часа выберите свой состав — можно освободить часть станций.',
          style: const TextStyle(fontSize: 13, color: BookingColors.textMuted),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (int h = 0; h < hc; h++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _HourTab(
                    label: '${h + 1}-й час',
                    count: s.pickedCountAt(h),
                    selected: h == hour,
                    accent: widget.accent,
                    onTap: () => setState(() => _hour = h),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                win == null
                    ? '${hour + 1}-й час'
                    : '${BookingFormat.range(widget.club, win.$1, win.$2)} · '
                        'выбрано ${s.pickedCountAt(hour)} из ${s.freeHallStationsAt(hour).length}',
                style: const TextStyle(fontSize: 14, color: BookingColors.textSoft),
              ),
            ),
            if (hour > 0)
              PillButton(
                label: 'как в 1-м часе',
                selected: false,
                accent: widget.accent,
                onTap: () => bloc.add(BookingHourCopied(from: 0, to: hour)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        HallPlan(
          stations: s.hallStations,
          isFree: (String id) => s.isFreeAt(hour, id),
          pickedIds: s.pickedAt(hour),
          takenIds: s.takenIds,
          isCombo: s.hall!.isCombo,
          accent: widget.accent,
          freeCount: s.freeHallStationsAt(hour).length,
          quickLabel: 'Взять в этот час:',
          onToggle: (String id) =>
              bloc.add(BookingStationToggled(id, hour: hour)),
          onQuickPick: (int n) => bloc.add(BookingQuickPicked(n, hour: hour)),
          onClear: () => bloc.add(BookingSelectionCleared(hour: hour)),
        ),
      ],
    );
  }
}

class _HourTab extends StatelessWidget {
  const _HourTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final int count;
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
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: selected ? accent : BookingColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? tint : BookingColors.textMuted,
                )),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: 0.22)
                    : BookingColors.surface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('$count',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                    color: selected ? tint : BookingColors.textDim,
                  )),
            ),
          ],
        ),
      ),
    );
  }
}
