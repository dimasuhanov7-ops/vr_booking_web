import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/admin_club_entity.dart';
import '../../domain/entity/booking_row_entity.dart';
import '../../domain/entity/package_entity.dart';
import '../../domain/service/admin_pricing_service.dart';
import '../../domain/state/admin_bloc.dart';
import '../admin_format.dart';
import '../admin_theme.dart';
import 'admin_atoms.dart';
import 'admin_drawer_shell.dart';

/// Drawer «Карточка брони»: сводка, контакты и оплата, отмена.
///
/// Бронь на несколько залов показывается целиком — по всем своим строкам.
/// Контакты, комментарий и предоплата сохраняются в БД. Время и состав не
/// редактируются: для этого нужно заново подобрать станции, поэтому такую
/// бронь отменяют и создают новую. Раньше эти поля были, но правка жила только
/// на экране под надписью «сохранено» и пропадала при перезапуске.
/// Отметки визита в карточке: статус брони в БД — подпись на кнопке.
const List<(RecordStatus, String)> _visitStatuses = <(RecordStatus, String)>[
  (RecordStatus.confirmed, 'ждём'),
  (RecordStatus.visited, 'пришёл'),
  (RecordStatus.noShow, 'не пришёл'),
];

class BookingDetailDrawer extends StatelessWidget {
  /// Создаёт drawer.
  const BookingDetailDrawer({
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
    final BookingRowEntity? row = state.openRow;
    if (row == null) return const SizedBox.shrink();

    final List<BookingRowEntity> parts = state.rows
        .where((BookingRowEntity r) => r.orderId == row.orderId)
        .toList(growable: false);
    String hallName(String id) => state.clubHalls
        .firstWhere((AdminHallEntity h) => h.id == id,
            orElse: () => state.clubHalls.first)
        .name;

    final DateTime date = pricing.dateOf(row.dayIndex);
    final bool weekend = pricing.isWeekend(row.dayIndex);
    final PackageEntity? pkg =
        parts.length == 1 ? pricing.matchPackage(row, state.packages) : null;
    // Промокод — на заказ целиком: у брони в нескольких залах строк
    // несколько, и фиксированная скидка иначе вычлась бы на каждой.
    int base = 0;
    int start = row.startMinutes;
    int end = row.endMinutes;
    for (final BookingRowEntity r in parts) {
      base += pricing.baseCost(
        row: r,
        price: state.priceOf(r.hallId),
        packages: state.packages,
      );
      if (r.startMinutes < start) start = r.startMinutes;
      if (r.endMinutes > end) end = r.endMinutes;
    }
    final int promoOff = pricing.promoDiscount(row: row, base: base);
    final int full = base - promoOff;
    final int due = (full - row.prepay).clamp(0, full);
    final bool cancelled = state.isCancelled(row.id);
    final Color tint = AdminColors.tintFor(state.accentSlug);

    String composition(BookingRowEntity r) => r.variesByHour
        ? <String>[
            for (int h = 0; h < r.hourCount; h++)
              '${h + 1}ч ${r.headsetsAt(h) + r.consolesAt(h)}'
          ].join(' · ')
        : AdminFormat.composition(r.headsets, r.consoles);

    void edit({String? clientName, String? phone, int? prepay, String? note}) =>
        bloc.add(AdminRowEdited(
          rowId: row.id,
          clientName: clientName,
          phone: phone,
          prepay: prepay,
          note: note,
        ));

    final String name = row.clientName.trim();
    final String phone = row.phone.trim();

    return AdminDrawerShell(
      title: name.isEmpty ? 'Без имени' : row.clientName,
      subtitle: row.phone,
      onClose: () => bloc.add(const AdminRowClosed()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Плашка ошибки основного экрана скрыта под панелью — дублируем.
          if (state.saveError != null) ...<Widget>[
            AdminErrorBox(state.saveError!),
            const SizedBox(height: 14),
          ],
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              if (cancelled) _chip('отменена', danger: true),
              _chip(state.club.name),
              for (final BookingRowEntity r in parts) _chip(hallName(r.hallId)),
              _chip('источник: ${row.source.label}'),
            ],
          ),
          const SizedBox(height: 16),
          _InfoTable(rows: <(String, String)>[
            (
              'Дата',
              '${AdminFormat.dowShort(date)}, ${date.day} ${AdminFormat.monShort(date)}'
                  ' · ${weekend ? 'выходной тариф' : 'тариф будней'}'
            ),
            (
              'Сеанс',
              '${AdminFormat.span(start, end)} · ${AdminFormat.hours(end - start)}'
            ),
            for (final BookingRowEntity r in parts)
              (hallName(r.hallId), composition(r)),
            ('Расчёт', pkg != null ? 'пакет «${pkg.name}»' : 'почасовая оплата'),
          ]),
          const SizedBox(height: 10),
          _InfoTable(
            rows: <(String, String)>[
              if (row.promo != null)
                (
                  'Промокод',
                  '${row.promo!.code} · ${row.promo!.effectLabel}'
                      '${promoOff > 0 ? ' · −${AdminFormat.money(promoOff)}' : ''}'
                ),
              ('Стоимость', AdminFormat.money(full)),
              ('Предоплата', row.prepay > 0 ? AdminFormat.money(row.prepay) : 'нет'),
              ('К оплате на месте', AdminFormat.money(due)),
            ],
            valueColors: <Color?>[
              if (row.promo != null) null,
              tint,
              row.prepay > 0 ? null : AdminColors.warn,
              due > 0 ? AdminColors.warn : null,
            ],
            bold: true,
          ),
          if (!cancelled) ...<Widget>[
            const SizedBox(height: 16),
            _ChipGroup(
              label: 'Визит',
              options: <(String, int)>[
                for (int i = 0; i < _visitStatuses.length; i++)
                  (_visitStatuses[i].$2, i),
              ],
              value: _visitStatuses
                  .indexWhere(((RecordStatus, String) v) => v.$1 == row.status)
                  .clamp(0, _visitStatuses.length - 1),
              accent: accent,
              onSelected: (int i) =>
                  bloc.add(AdminVisitMarked(row.id, _visitStatuses[i].$1)),
            ),
          ],
          const SizedBox(height: 20),
          const AdminLabel('Контакты и оплата'),
          const SizedBox(height: 4),
          const Text('Сохраняется само через секунду после ввода.',
              style: TextStyle(fontSize: 12, color: AdminColors.textFaint)),
          const SizedBox(height: 12),
          AdminTextInput(
            label: 'Имя',
            value: row.clientName,
            onChanged: (String v) => edit(clientName: v),
          ),
          if (name.length < 2)
            const _FieldHint('Имя — от 2 букв, иначе не сохранится.'),
          const SizedBox(height: 13),
          AdminTextInput(
            label: 'Телефон',
            value: row.phone,
            keyboardType: TextInputType.phone,
            onChanged: (String v) => edit(phone: v),
          ),
          if (phone.isNotEmpty && phone.length < 5)
            const _FieldHint('Телефон слишком короткий — не сохранится.'),
          const SizedBox(height: 13),
          AdminNumberField(
            label: 'Предоплата, ₽',
            value: row.prepay,
            width: 140,
            onChanged: (int v) => edit(prepay: v),
          ),
          const SizedBox(height: 13),
          AdminTextInput(
            label: 'Комментарий',
            value: row.note,
            maxLines: 3,
            onChanged: (String v) => edit(note: v),
          ),
          const SizedBox(height: 20),
          if (cancelled)
            const SizedBox.shrink()
          else if (parts.length > 1 || !state.scheduleEditable)
            Text(
              parts.length > 1
                  ? 'Бронь в нескольких залах не переносится: отмените её и '
                      'создайте новую запись.'
                  : 'Время и состав брони здесь не меняются: отмените её и '
                      'создайте новую запись.',
              style: const TextStyle(
                  fontSize: 12, height: 1.4, color: AdminColors.textMuted),
            )
          else
            _Reschedule(
              key: ValueKey<String>('reschedule-${row.id}'),
              row: row,
              state: state,
              accent: accent,
            ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: _WideButton(
              label: cancelled ? 'Вернуть бронь' : 'Отменить бронь',
              danger: !cancelled,
              onTap: () async {
                if (!cancelled) {
                  final bool ok = await confirmAdminAction(
                    context,
                    title: 'Отменить бронь?',
                    message: '${name.isEmpty ? 'Гость' : name}, '
                        '${AdminFormat.span(start, end)}. Места освободятся и '
                        'станут доступны другим клиентам.',
                    confirmLabel: 'Отменить бронь',
                  );
                  if (!ok) return;
                }
                bloc.add(AdminRowCancelToggled(row.id));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, {bool danger = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          color: danger ? AdminColors.dangerBg : AdminColors.tile,
          border: Border.all(
              color: danger ? AdminColors.dangerBorder : AdminColors.borderInput),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: danger ? AdminColors.danger : AdminColors.textMid)),
      );
}

class _FieldHint extends StatelessWidget {
  const _FieldHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Text(text,
          style: const TextStyle(fontSize: 12, color: AdminColors.warn)),
    );
  }
}

class _InfoTable extends StatelessWidget {
  const _InfoTable({
    required this.rows,
    this.valueColors,
    this.bold = false,
  });

  final List<(String, String)> rows;
  final List<Color?>? valueColors;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0D10),
                border: i == 0
                    ? null
                    : const Border(top: BorderSide(color: Color(0xFF16171C))),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(rows[i].$1,
                      style: const TextStyle(fontSize: 13, color: AdminColors.textMuted)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      rows[i].$2,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: bold ? 15 : 13,
                        fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
                        color: valueColors != null &&
                                i < valueColors!.length &&
                                valueColors![i] != null
                            ? valueColors![i]
                            : AdminColors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _WideButton extends StatelessWidget {
  const _WideButton({
    required this.label,
    required this.onTap,
    this.danger = false,
    this.enabled = true,
    this.accent,
  });

  final String label;
  final VoidCallback onTap;
  final bool danger;
  final bool enabled;

  /// Залить кнопку акцентом клуба (главное действие блока).
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final Color? fill = enabled ? accent : null;
    if (fill != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: fill,
          ),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: AdminColors.bg)),
        ),
      );
    }
    if (!enabled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminColors.borderInput),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF4A4C55))),
      );
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: danger ? AdminColors.dangerBg : Colors.transparent,
          border: Border.all(
            color: danger ? AdminColors.dangerBorder : AdminColors.borderInput,
          ),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: danger ? AdminColors.danger : AdminColors.textSoft)),
      ),
    );
  }
}

/// Перенос брони и смена состава одного зала.
///
/// Черновик живёт в самом виджете и уходит на сервер только по «Перенести»:
/// места подбираются заново по актуальной занятости, при нехватке сервер
/// отказывает, и бронь остаётся как была.
class _Reschedule extends StatefulWidget {
  const _Reschedule({
    required this.row,
    required this.state,
    required this.accent,
    super.key,
  });

  final BookingRowEntity row;
  final AdminState state;
  final Color accent;

  @override
  State<_Reschedule> createState() => _RescheduleState();
}

class _RescheduleState extends State<_Reschedule> {
  late int _start;
  late int _duration;
  late int _vr;
  late int _ps;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(covariant _Reschedule old) {
    super.didUpdateWidget(old);
    // Бронь перечитали с сервера (перенесли тут или на другом телефоне) —
    // черновик начинаем с того, что есть сейчас.
    if (old.row.startMinutes != widget.row.startMinutes ||
        old.row.durationMinutes != widget.row.durationMinutes ||
        old.row.maxHeadsets != widget.row.maxHeadsets ||
        old.row.maxConsoles != widget.row.maxConsoles) {
      _reset();
    }
  }

  void _reset() {
    final BookingRowEntity r = widget.row;
    _start = r.startMinutes;
    _duration = r.durationMinutes;
    _vr = r.variesByHour ? r.maxHeadsets : r.headsets;
    _ps = r.variesByHour ? r.maxConsoles : r.consoles;
  }

  bool get _changed {
    final BookingRowEntity r = widget.row;
    return _start != r.startMinutes ||
        _duration != r.durationMinutes ||
        r.variesByHour ||
        _vr != r.headsets ||
        _ps != r.consoles;
  }

  @override
  Widget build(BuildContext context) {
    final BookingRowEntity r = widget.row;
    final AdminState state = widget.state;
    AdminHallEntity? hall;
    for (final AdminHallEntity h in state.clubHalls) {
      if (h.id == r.hallId) hall = h;
    }
    final int maxVr = hall?.headsets ?? r.maxHeadsets;
    final int maxPs = hall?.consoles ?? r.maxConsoles;

    // Та же часовая сетка, что в «Новой записи»; текущее начало оставляем
    // в списке, даже если оно не на сетке (брони до 16.09 шли по старой).
    final List<int> starts = <int>{
      ...state.sessionStarts(r.dayIndex, _duration),
      if (_duration == r.durationMinutes) r.startMinutes,
    }.toList()
      ..sort();
    final bool startOk = starts.contains(_start);
    final bool canSubmit = _changed && startOk && _vr + _ps > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const AdminLabel('Перенос и состав'),
        const SizedBox(height: 4),
        const Text(
          'Меняется только по кнопке «Перенести». Места подберутся заново; '
          'если их не хватит, бронь останется как была.',
          style: TextStyle(fontSize: 12, height: 1.4, color: AdminColors.textFaint),
        ),
        const SizedBox(height: 12),
        _ChipGroup(
          label: 'Длительность',
          options: <(String, int)>[
            for (final int m in AdminState.durations) ('${m ~/ 60} ч', m),
          ],
          value: _duration,
          accent: widget.accent,
          onSelected: (int m) => setState(() => _duration = m),
        ),
        const SizedBox(height: 13),
        if (starts.isEmpty)
          const Text('На этот день такой сеанс уже не влезает.',
              style: TextStyle(fontSize: 12, color: AdminColors.warn))
        else
          _ChipGroup(
            label: 'Начало',
            options: <(String, int)>[
              for (final int t in starts) (AdminFormat.hhmm(t), t),
            ],
            value: _start,
            accent: widget.accent,
            onSelected: (int t) => setState(() => _start = t),
          ),
        if (!startOk && starts.isNotEmpty)
          const _FieldHint(
              'Выберите начало: прежнее время с новой длительностью не влезает.'),
        const SizedBox(height: 13),
        _ChipGroup(
          label: 'Шлемов',
          options: <(String, int)>[
            for (int i = 0; i <= maxVr; i++) ('$i', i),
          ],
          value: _vr,
          accent: widget.accent,
          onSelected: (int v) => setState(() => _vr = v),
        ),
        if (maxPs > 0) ...<Widget>[
          const SizedBox(height: 13),
          _ChipGroup(
            label: 'PS5',
            options: <(String, int)>[
              for (int i = 0; i <= maxPs; i++) ('$i', i),
            ],
            value: _ps,
            accent: widget.accent,
            onSelected: (int v) => setState(() => _ps = v),
          ),
        ],
        if (r.variesByHour) ...<Widget>[
          const SizedBox(height: 10),
          const Text(
            'Сейчас состав разный по часам — перенос задаст один состав на весь сеанс.',
            style: TextStyle(fontSize: 12, color: AdminColors.warn),
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: _WideButton(
            label: 'Перенести',
            enabled: canSubmit,
            accent: widget.accent,
            onTap: () {
              if (!canSubmit) return;
              final int hours = _duration ~/ 60;
              context.read<AdminBloc>().add(AdminRowRescheduled(
                    rowId: r.id,
                    dayIndex: r.dayIndex,
                    startMinutes: _start,
                    headsetsByHour: List<int>.filled(hours, _vr),
                    consolesByHour: List<int>.filled(hours, _ps),
                  ));
            },
          ),
        ),
      ],
    );
  }
}

class _ChipGroup extends StatelessWidget {
  const _ChipGroup({
    required this.label,
    required this.options,
    required this.value,
    required this.accent,
    required this.onSelected,
  });

  final String label;
  final List<(String, int)> options;
  final int value;
  final Color accent;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
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
            for (final (String, int) o in options)
              AdminPill(
                label: o.$1,
                selected: value == o.$2,
                accent: accent,
                compact: true,
                onTap: () => onSelected(o.$2),
              ),
          ],
        ),
      ],
    );
  }
}
