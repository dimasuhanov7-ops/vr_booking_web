import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/admin_club_entity.dart';
import '../../domain/service/admin_pricing_service.dart';
import '../../domain/state/admin_bloc.dart';
import '../admin_format.dart';
import '../admin_theme.dart';
import 'admin_atoms.dart';
import 'admin_drawer_shell.dart';
import 'admin_month_calendar.dart';

/// Drawer «Новая запись»: календарь + параметры сеанса + контакты.
class NewBookingDrawer extends StatelessWidget {
  /// Создаёт drawer.
  const NewBookingDrawer({
    required this.state,
    required this.accent,
    this.pricing = const AdminPricingService(),
    super.key,
  });

  /// Состояние.
  final AdminState state;

  /// Акцент клуба.
  final Color accent;

  /// Сервис расчётов.
  final AdminPricingService pricing;

  @override
  Widget build(BuildContext context) {
    final AdminBloc bloc = context.read<AdminBloc>();
    final NewBookingDraft? d = state.newBooking;
    final AdminHallEntity? hall = state.newBookingHall;
    if (d == null || hall == null) return const SizedBox.shrink();

    final AdminClubEntity club = state.club;
    final DateTime date = pricing.dateOf(d.dayIndex);
    final bool weekend = pricing.isWeekend(d.dayIndex);
    final FreeUnits free = state.freeUnits(
      hallId: d.hallId,
      dayIndex: d.dayIndex,
      startMinutes: d.startMinutes,
      durationMinutes: d.durationMinutes,
    );
    final bool noRoom = free.headsets + free.consoles == 0;

    final List<int> times = <int>[];
    for (int t = club.openMinutes; t + d.durationMinutes <= club.closeMinutes; t += 60) {
      times.add(t);
    }

    final int total = pricing.hourlyCost(
      headsets: d.headsets,
      consoles: d.consoles,
      minutes: d.durationMinutes,
      price: state.priceOf(hall.id),
      weekend: weekend,
    );

    void change({
      String? hallId,
      int? dayIndex,
      int? startMinutes,
      int? durationMinutes,
      int? headsets,
      int? consoles,
      String? name,
      String? phone,
      int? prepay,
      String? note,
    }) =>
        bloc.add(AdminNewBookingChanged(
          hallId: hallId,
          dayIndex: dayIndex,
          startMinutes: startMinutes,
          durationMinutes: durationMinutes,
          headsets: headsets,
          consoles: consoles,
          name: name,
          phone: phone,
          prepay: prepay,
          note: note,
        ));

    final String message = d.message.isNotEmpty
        ? d.message
        : noRoom
            ? 'На это время в зале всё занято — выберите другое время, день или зал.'
            : '';

    return AdminDrawerShell(
      title: 'Новая запись',
      subtitle: '${club.name} · ${AdminFormat.span(d.startMinutes, d.startMinutes + d.durationMinutes)}'
          ' · ${AdminFormat.dowShort(date)}, ${date.day} ${AdminFormat.monShort(date)}',
      onClose: () => bloc.add(const AdminNewBookingClosed()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('День',
              style: TextStyle(fontSize: 12, color: AdminColors.textMuted)),
          const SizedBox(height: 8),
          AdminMonthCalendar(
            selectedDayIndex: d.dayIndex,
            accent: accent,
            slug: state.accentSlug,
            pricing: pricing,
            visibleMonth: state.newBookingMonth,
            onMonthChanged: (DateTime m) => bloc.add(AdminNewBookingMonthChanged(m)),
            onPick: (int di) => change(dayIndex: di),
          ),
          const SizedBox(height: 14),
          if (club.halls.length > 1)
            _Group(
              label: 'Зал',
              accent: accent,
              options: <(String, bool, VoidCallback)>[
                for (final AdminHallEntity h in club.halls)
                  (h.name, h.id == d.hallId, () => change(hallId: h.id)),
              ],
            ),
          _Group(
            label: 'Длительность',
            accent: accent,
            options: <(String, bool, VoidCallback)>[
              for (final int m in AdminState.durations)
                ('${m ~/ 60} ч', m == d.durationMinutes, () => change(durationMinutes: m)),
            ],
          ),
          _Group(
            label: 'Начало сеанса',
            accent: accent,
            options: <(String, bool, VoidCallback)>[
              for (final int t in times)
                (AdminFormat.hhmm(t), t == d.startMinutes, () => change(startMinutes: t)),
            ],
          ),
          _CountGroup(
            label: 'Шлемов · свободно ${free.headsets} из ${hall.headsets}',
            accent: accent,
            max: hall.headsets,
            free: free.headsets,
            value: d.headsets,
            onSelected: (int v) => change(headsets: v),
          ),
          if (hall.consoles > 0)
            _CountGroup(
              label: 'PS5 · свободно ${free.consoles} из ${hall.consoles}',
              accent: accent,
              max: hall.consoles,
              free: free.consoles,
              value: d.consoles,
              onSelected: (int v) => change(consoles: v),
            ),
          const SizedBox(height: 4),
          AdminTextInput(
            label: 'Имя',
            value: d.name,
            hint: 'Кто бронирует',
            onChanged: (String v) => change(name: v),
          ),
          const SizedBox(height: 13),
          AdminTextInput(
            label: 'Телефон',
            value: d.phone,
            hint: '+7 (900) 000-00-00',
            keyboardType: TextInputType.phone,
            onChanged: (String v) => change(phone: v),
          ),
          const SizedBox(height: 13),
          AdminNumberField(
            label: 'Предоплата, ₽',
            value: d.prepay,
            width: 140,
            onChanged: (int v) => change(prepay: v),
          ),
          const SizedBox(height: 13),
          AdminTextInput(
            label: 'Комментарий',
            value: d.note,
            hint: 'Например, привезут торт',
            maxLines: 3,
            onChanged: (String v) => change(note: v),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFF0B0D10),
              border: Border.all(color: AdminColors.border),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    weekend ? 'Стоимость · выходной тариф' : 'Стоимость · тариф будней',
                    style: const TextStyle(fontSize: 13, color: AdminColors.textMuted),
                  ),
                ),
                Text(AdminFormat.money(total),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                    )),
              ],
            ),
          ),
          if (message.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Text(message,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFFFB020))),
          ],
          const SizedBox(height: 14),
          InkWell(
            onTap: noRoom ? null : () => bloc.add(const AdminNewBookingSubmitted()),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: noRoom ? const Color(0xFF22242A) : accent,
              ),
              child: Text('Создать запись',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: noRoom ? AdminColors.textFaint : AdminColors.bg,
                  )),
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.label, required this.accent, required this.options});

  final String label;
  final Color accent;
  final List<(String, bool, VoidCallback)> options;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: AdminColors.textMuted)),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final (String, bool, VoidCallback) o in options)
                AdminPill(
                    label: o.$1,
                    selected: o.$2,
                    accent: accent,
                    compact: true,
                    onTap: o.$3),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountGroup extends StatelessWidget {
  const _CountGroup({
    required this.label,
    required this.accent,
    required this.max,
    required this.free,
    required this.value,
    required this.onSelected,
  });

  final String label;
  final Color accent;
  final int max;
  final int free;
  final int value;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: AdminColors.textMuted)),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (int v = 0; v <= max; v++)
                AdminPill(
                  label: '$v',
                  selected: value == v,
                  enabled: v <= free,
                  accent: accent,
                  compact: true,
                  onTap: () => onSelected(v),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
