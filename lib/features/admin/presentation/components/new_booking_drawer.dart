import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/admin_booking_request_entity.dart';
import '../../domain/entity/admin_club_entity.dart';
import '../../domain/service/admin_pricing_service.dart';
import '../../domain/state/admin_bloc.dart';
import '../admin_format.dart';
import '../admin_theme.dart';
import 'admin_atoms.dart';
import 'admin_drawer_shell.dart';
import 'admin_month_calendar.dart';

/// Drawer «Новая запись»: календарь, параметры сеанса, состав по залам, контакты.
///
/// Состав задаётся для каждого зала клуба отдельно — одной бронью можно занять
/// места сразу в нескольких залах.
class NewBookingDrawer extends StatefulWidget {
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
  State<NewBookingDrawer> createState() => _NewBookingDrawerState();
}

class _NewBookingDrawerState extends State<NewBookingDrawer> {
  int _hour = 0;

  @override
  Widget build(BuildContext context) {
    final AdminState state = widget.state;
    final Color accent = widget.accent;
    final AdminPricingService pricing = widget.pricing;
    final AdminBloc bloc = context.read<AdminBloc>();
    final NewBookingDraft? d = state.newBooking;
    final List<AdminHallEntity> halls = state.clubHalls;
    if (d == null || halls.isEmpty) return const SizedBox.shrink();

    final int hc = d.hourCount;
    final int hour = _hour.clamp(0, hc - 1);

    final AdminClubEntity club = state.club;
    final DateTime date = pricing.dateOf(d.dayIndex);
    final bool weekend = pricing.isWeekend(d.dayIndex);
    // Свободная ёмкость каждого зала в текущем часе-вкладке.
    final Map<String, FreeUnits> free = <String, FreeUnits>{
      for (final AdminHallEntity h in halls)
        h.id: state.freeUnits(
          hallId: h.id,
          dayIndex: d.dayIndex,
          startMinutes: d.startMinutes + hour * 60,
          durationMinutes: 60,
        ),
    };
    final bool noRoom = free.values
        .every((FreeUnits f) => f.headsets + f.consoles == 0);

    // Начала сеансов — час + перерыв клуба; на сегодня только ещё не начавшиеся.
    final List<int> times = state.sessionStarts(d.dayIndex, d.durationMinutes);

    int total = 0;
    for (int h = 0; h < hc; h++) {
      for (final AdminHallEntity hall in halls) {
        final HallUnits u = d.unitsAt(hall.id, h);
        total += pricing.hourlyCost(
          headsets: u.headsets,
          consoles: u.consoles,
          minutes: 60,
          price: state.priceOf(hall.id),
          weekend: weekend,
        );
      }
    }

    void change({
      String? hallId,
      int? dayIndex,
      int? startMinutes,
      int? durationMinutes,
      int? headsets,
      int? consoles,
      int hourArg = 0,
      int? copyHourFromFirst,
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
          hour: hourArg,
          copyHourFromFirst: copyHourFromFirst,
          name: name,
          phone: phone,
          prepay: prepay,
          note: note,
        ));

    final String message = d.message.isNotEmpty
        ? d.message
        : times.isEmpty
            ? 'На этот день сеансы такой длительности уже не начать — выберите другой день.'
            : noRoom
                ? 'На это время всё занято — выберите другое время или день.'
                : '';
    // Пока запись уходит на сервер, повторное нажатие не должно создать дубль.
    final bool canSubmit = !noRoom && !d.saving && times.isNotEmpty;

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
            empty: 'Свободных начал на этот день нет.',
            options: <(String, bool, VoidCallback)>[
              for (final int t in times)
                (AdminFormat.hhmm(t), t == d.startMinutes, () => change(startMinutes: t)),
            ],
          ),
          if (hc > 1) ...<Widget>[
            const Text('Состав по часам',
                style: TextStyle(fontSize: 12, color: AdminColors.textMuted)),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (int h = 0; h < hc; h++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: AdminPill(
                        label: '${h + 1}-й · ${d.totalAt(h)}',
                        selected: h == hour,
                        accent: accent,
                        compact: true,
                        onTap: () => setState(() => _hour = h),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${AdminFormat.hhmm(d.startMinutes + hour * 60)}–'
              '${AdminFormat.hhmm(d.startMinutes + (hour + 1) * 60)}',
              style: const TextStyle(fontSize: 12, color: AdminColors.textFaint),
            ),
            const SizedBox(height: 10),
          ],
          if (halls.length > 1)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'Места можно занять сразу в нескольких залах — одной записью.',
                style: TextStyle(fontSize: 12, color: AdminColors.textFaint),
              ),
            ),
          for (final AdminHallEntity h in halls) ...<Widget>[
            if (halls.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  h.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            _CountGroup(
              label: 'Шлемов · свободно ${free[h.id]!.headsets} из ${h.headsets}',
              accent: accent,
              max: h.headsets,
              free: free[h.id]!.headsets,
              value: d.unitsAt(h.id, hour).headsets,
              onSelected: (int v) => change(hallId: h.id, headsets: v, hourArg: hour),
            ),
            if (h.consoles > 0)
              _CountGroup(
                label: 'PS5 · свободно ${free[h.id]!.consoles} из ${h.consoles}',
                accent: accent,
                max: h.consoles,
                free: free[h.id]!.consoles,
                value: d.unitsAt(h.id, hour).consoles,
                onSelected: (int v) => change(hallId: h.id, consoles: v, hourArg: hour),
              ),
          ],
          if (hc > 1 && hour > 0) ...<Widget>[
            const SizedBox(height: 8),
            AdminPill(
              label: 'как в 1-м часе',
              selected: false,
              accent: accent,
              compact: true,
              onTap: () => change(copyHourFromFirst: hour),
            ),
          ],
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
            hint: '+7 (900) 000-00-00 — можно оставить пустым',
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
            onTap: canSubmit ? () => bloc.add(const AdminNewBookingSubmitted()) : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: canSubmit ? accent : const Color(0xFF22242A),
              ),
              child: Text(d.saving ? 'Сохраняю…' : 'Создать запись',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: canSubmit ? AdminColors.bg : AdminColors.textFaint,
                  )),
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.label,
    required this.accent,
    required this.options,
    this.empty,
  });

  final String label;
  final Color accent;
  final List<(String, bool, VoidCallback)> options;

  /// Текст вместо пустого списка вариантов.
  final String? empty;

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
          if (options.isEmpty && empty != null)
            Text(empty!,
                style: const TextStyle(fontSize: 13, color: AdminColors.textFaint))
          else
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
