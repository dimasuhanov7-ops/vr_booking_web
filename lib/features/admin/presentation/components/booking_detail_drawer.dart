import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Drawer «Карточка брони»: просмотр + правка одной записи.
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

    final AdminHallEntity hall = state.clubHalls.firstWhere(
      (AdminHallEntity h) => h.id == row.hallId,
      orElse: () => state.clubHalls.first,
    );
    final DateTime date = pricing.dateOf(row.dayIndex);
    final bool weekend = pricing.isWeekend(row.dayIndex);
    final PackageEntity? pkg = pricing.matchPackage(row, state.packages);
    final int full = pricing.rowCost(
      row: row,
      price: state.priceOf(row.hallId),
      packages: state.packages,
    );
    final int due = (full - row.prepay).clamp(0, full);
    final bool edited = state.isEdited(row.id);
    final bool cancelled = state.isCancelled(row.id);
    final Color tint = AdminColors.tintFor(state.accentSlug);

    void edit({
      String? clientName,
      String? phone,
      int? startMinutes,
      int? durationMinutes,
      int? headsets,
      int? consoles,
      int? prepay,
      String? note,
    }) =>
        bloc.add(AdminRowEdited(
          rowId: row.id,
          clientName: clientName,
          phone: phone,
          startMinutes: startMinutes,
          durationMinutes: durationMinutes,
          headsets: headsets,
          consoles: consoles,
          prepay: prepay,
          note: note,
        ));

    return AdminDrawerShell(
      title: row.clientName,
      subtitle: row.phone,
      onClose: () => bloc.add(const AdminRowClosed()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              if (cancelled) _chip('отменена', danger: true),
              _chip(state.club.name),
              _chip(hall.name),
              _chip('источник: ${row.source.label}'),
            ],
          ),
          const SizedBox(height: 16),
          _InfoTable(rows: <(String, String)>[
            ('Клуб и зал', '${state.club.name} · ${hall.name}'),
            (
              'Дата',
              '${AdminFormat.dowShort(date)}, ${date.day} ${AdminFormat.monShort(date)}'
                  ' · ${weekend ? 'выходной тариф' : 'тариф будней'}'
            ),
            (
              'Сеанс',
              '${AdminFormat.span(row.startMinutes, row.endMinutes)}'
                  ' · ${AdminFormat.hours(row.durationMinutes)}'
            ),
            ('Состав', AdminFormat.composition(row.headsets, row.consoles)),
            ('Расчёт', pkg != null ? 'пакет «${pkg.name}»' : 'почасовая оплата'),
            ('Источник', row.source.label),
          ]),
          const SizedBox(height: 10),
          _InfoTable(
            rows: <(String, String)>[
              ('Стоимость', AdminFormat.money(full)),
              ('Предоплата', row.prepay > 0 ? AdminFormat.money(row.prepay) : 'нет'),
              ('К оплате на месте', AdminFormat.money(due)),
            ],
            valueColors: <Color?>[
              tint,
              row.prepay > 0 ? null : AdminColors.warn,
              due > 0 ? AdminColors.warn : null,
            ],
            bold: true,
          ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              const Expanded(child: AdminLabel('Редактирование')),
              if (edited)
                Text('изменено, сохранено',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: tint)),
            ],
          ),
          const SizedBox(height: 12),
          AdminTextInput(
            label: 'Имя',
            value: row.clientName,
            onChanged: (String v) => edit(clientName: v),
          ),
          const SizedBox(height: 13),
          AdminTextInput(
            label: 'Телефон',
            value: row.phone,
            keyboardType: TextInputType.phone,
            onChanged: (String v) => edit(phone: v),
          ),
          const SizedBox(height: 13),
          _TimeField(
            minutes: row.startMinutes,
            onChanged: (int m) => edit(startMinutes: m),
          ),
          const SizedBox(height: 13),
          _ChipGroup(
            label: 'Длительность',
            options: <(String, int)>[
              for (final int m in AdminState.durations) ('${m ~/ 60} ч', m),
            ],
            value: row.durationMinutes,
            accent: accent,
            onSelected: (int m) => edit(durationMinutes: m),
          ),
          const SizedBox(height: 13),
          _ChipGroup(
            label: 'Шлемов',
            options: <(String, int)>[
              for (int i = 0; i <= hall.headsets; i++) ('$i', i),
            ],
            value: row.headsets,
            accent: accent,
            onSelected: (int v) => edit(headsets: v),
          ),
          if (hall.consoles > 0) ...<Widget>[
            const SizedBox(height: 13),
            _ChipGroup(
              label: 'PS5',
              options: <(String, int)>[
                for (int i = 0; i <= hall.consoles; i++) ('$i', i),
              ],
              value: row.consoles,
              accent: accent,
              onSelected: (int v) => edit(consoles: v),
            ),
          ],
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
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: _WideButton(
                  label: 'Вернуть исходные',
                  enabled: edited,
                  onTap: () => bloc.add(AdminRowEditReset(row.id)),
                ),
              ),
              const SizedBox(width: 8),
              _WideButton(
                label: cancelled ? 'Вернуть бронь' : 'Отменить бронь',
                danger: !cancelled,
                onTap: () => bloc.add(AdminRowCancelToggled(row.id)),
              ),
            ],
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
                        color: valueColors != null && valueColors![i] != null
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

class _TimeField extends StatefulWidget {
  const _TimeField({required this.minutes, required this.onChanged});

  final int minutes;
  final ValueChanged<int> onChanged;

  @override
  State<_TimeField> createState() => _TimeFieldState();
}

class _TimeFieldState extends State<_TimeField> {
  late final TextEditingController _c =
      TextEditingController(text: AdminFormat.hhmm(widget.minutes));
  final FocusNode _focus = FocusNode();

  @override
  void didUpdateWidget(covariant _TimeField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus) {
      final String v = AdminFormat.hhmm(widget.minutes);
      if (v != _c.text) _c.text = v;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _parse(String s) {
    final RegExpMatch? m =
        RegExp(r'^(\d{1,2})[:.\s]?(\d{2})$').firstMatch(s.trim());
    if (m == null) return;
    final int mins = int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
    widget.onChanged(mins);
  }

  @override
  Widget build(BuildContext context) {
    final OutlineInputBorder b = OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: AdminColors.borderInput),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text('Начало (чч:мм)',
              style: TextStyle(fontSize: 12, color: AdminColors.textMuted)),
        ),
        SizedBox(
          width: 140,
          child: TextField(
            controller: _c,
            focusNode: _focus,
            keyboardType: TextInputType.datetime,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9:. ]')),
              LengthLimitingTextInputFormatter(5),
            ],
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              color: AdminColors.text,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              filled: true,
              fillColor: AdminColors.input,
              border: b,
              enabledBorder: b,
              focusedBorder: b,
            ),
            onChanged: _parse,
            onSubmitted: _parse,
          ),
        ),
      ],
    );
  }
}

class _WideButton extends StatelessWidget {
  const _WideButton({
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.danger = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color fg = !enabled
        ? const Color(0xFF4A4C55)
        : danger
            ? AdminColors.danger
            : AdminColors.textSoft;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: danger && enabled ? AdminColors.dangerBg : Colors.transparent,
          border: Border.all(
            color: danger && enabled ? AdminColors.dangerBorder : AdminColors.borderInput,
          ),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: fg)),
      ),
    );
  }
}
