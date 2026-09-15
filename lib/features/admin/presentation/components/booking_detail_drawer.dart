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
    int full = 0;
    int start = row.startMinutes;
    int end = row.endMinutes;
    for (final BookingRowEntity r in parts) {
      full += pricing.rowCost(
        row: r,
        price: state.priceOf(r.hallId),
        packages: state.packages,
      );
      if (r.startMinutes < start) start = r.startMinutes;
      if (r.endMinutes > end) end = r.endMinutes;
    }
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
          const SizedBox(height: 14),
          const Text(
            'Время и состав брони не меняются: отмените её и создайте новую '
            'запись — станции подберутся заново.',
            style: TextStyle(fontSize: 12, height: 1.4, color: AdminColors.textMuted),
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
  });

  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
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
