import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/admin_club_entity.dart';
import '../../domain/entity/booking_row_entity.dart';
import '../../domain/service/admin_pricing_service.dart';
import '../../domain/state/admin_bloc.dart';
import '../admin_format.dart';
import '../admin_theme.dart';
import 'admin_atoms.dart';
import 'kpi_tile.dart';

/// Вкладка «Записи» — KPI, фильтры, журнал.
class RecordsTab extends StatelessWidget {
  /// Создаёт вкладку.
  const RecordsTab({
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
    final List<BookingRowEntity> filtered = state.filteredRows;
    final List<BookingRowEntity> live = state.liveFilteredRows;

    int sum(int Function(BookingRowEntity) f) =>
        live.fold(0, (int a, BookingRowEntity r) => a + f(r));

    final int total = live.fold(
      0,
      (int a, BookingRowEntity r) =>
          a +
          pricing.rowCost(
            row: r,
            price: state.priceOf(r.hallId),
            packages: state.packages,
          ),
    );
    final int cancelledInFilter = filtered.length - live.length;

    final List<({String label, String value, String note})> kpis =
        <({String label, String value, String note})>[
      (
        label: 'записей',
        value: '${live.length}',
        note: cancelledInFilter > 0 ? '+ $cancelledInFilter отменено' : 'по фильтрам',
      ),
      (label: 'шлемов занято', value: '${sum((BookingRowEntity r) => r.headsets)}', note: 'суммарно по записям'),
      (label: 'PS5 занято', value: '${sum((BookingRowEntity r) => r.consoles)}', note: 'суммарно по записям'),
      (label: 'часов сеансов', value: _h(sum((BookingRowEntity r) => r.durationMinutes) / 60), note: 'суммарная длительность'),
      (label: 'станций-часов', value: _h(sum((BookingRowEntity r) => r.stationCount * r.durationMinutes) / 60), note: 'станции × длительность'),
      (label: 'сумма', value: AdminFormat.money(total), note: 'по текущему тарифу'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final int cols = (c.maxWidth / 160).floor().clamp(2, 6);
            final double w = (c.maxWidth - 10 * (cols - 1)) / cols;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                for (final ({String label, String value, String note}) k in kpis)
                  SizedBox(
                    width: w,
                    child: KpiTile(
                      label: k.label,
                      value: k.value,
                      note: k.note,
                      valueColor: AdminColors.tintFor(state.accentSlug),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        _Filters(state: state, accent: accent, pricing: pricing, bloc: bloc),
        const SizedBox(height: 14),
        AdminCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 13),
                child: Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text('Записи',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    ),
                    Text('${state.club.name} · ${AdminFormat.active(live.length)}',
                        style: const TextStyle(fontSize: 12, color: AdminColors.textFaint)),
                  ],
                ),
              ),
              const Divider(height: 1, color: AdminColors.divider),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 32, 20, 32),
                  child: Center(
                    child: Column(
                      children: <Widget>[
                        Text('Ничего не найдено',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        SizedBox(height: 5),
                        Text('Смягчите фильтры выше или выберите другой клуб.',
                            style: TextStyle(fontSize: 13, color: AdminColors.textMuted)),
                      ],
                    ),
                  ),
                )
              else
                for (int i = 0; i < filtered.length; i++)
                  _RecordCard(
                    row: filtered[i],
                    hall: state.clubHalls.firstWhere(
                      (AdminHallEntity h) => h.id == filtered[i].hallId,
                      orElse: () => state.clubHalls.first,
                    ),
                    date: pricing.dateOf(filtered[i].dayIndex),
                    cancelled: state.isCancelled(filtered[i].id),
                    last: i == filtered.length - 1,
                    accent: accent,
                    slug: state.accentSlug,
                    cost: pricing.rowCost(
                      row: filtered[i],
                      price: state.priceOf(filtered[i].hallId),
                      packages: state.packages,
                    ),
                    matched: pricing.matchPackage(filtered[i], state.packages) != null,
                    onCancel: () => bloc.add(AdminRowCancelToggled(filtered[i].id)),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  static String _h(double v) => v == v.roundToDouble()
      ? v.toInt().toString()
      : v.toStringAsFixed(1).replaceAll('.', ',');
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.state,
    required this.accent,
    required this.pricing,
    required this.bloc,
  });

  final AdminState state;
  final Color accent;
  final AdminPricingService pricing;
  final AdminBloc bloc;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _row('день', <Widget>[
            _pill('все', state.filterDay < 0,
                () => bloc.add(AdminFilterChanged(day: -1, hallId: state.filterHallId, type: state.filterType, status: state.filterStatus))),
            for (int i = 0; i < 5; i++)
              _pill(
                '${AdminFormat.dowShort(pricing.dateOf(i))} ${pricing.dateOf(i).day}',
                state.filterDay == i,
                () => bloc.add(AdminFilterChanged(day: i, hallId: state.filterHallId, type: state.filterType, status: state.filterStatus)),
              ),
          ]),
          _row('зал', <Widget>[
            _pill('все залы', state.filterHallId.isEmpty,
                () => bloc.add(AdminFilterChanged(day: state.filterDay, hallId: '', type: state.filterType, status: state.filterStatus))),
            for (final AdminHallEntity h in state.clubHalls)
              _pill(h.name, state.filterHallId == h.id,
                  () => bloc.add(AdminFilterChanged(day: state.filterDay, hallId: h.id, type: state.filterType, status: state.filterStatus))),
          ]),
          _row('тип', <Widget>[
            for (final AdminTypeFilter t in AdminTypeFilter.values)
              _pill(t.label, state.filterType == t,
                  () => bloc.add(AdminFilterChanged(day: state.filterDay, hallId: state.filterHallId, type: t, status: state.filterStatus))),
          ]),
          _row('статус', <Widget>[
            for (final AdminStatusFilter s in AdminStatusFilter.values)
              _pill(s.label, state.filterStatus == s,
                  () => bloc.add(AdminFilterChanged(day: state.filterDay, hallId: state.filterHallId, type: state.filterType, status: s))),
          ], last: true),
        ],
      ),
    );
  }

  Widget _pill(String label, bool selected, VoidCallback onTap) =>
      AdminPill(label: label, selected: selected, accent: accent, compact: true, onTap: onTap);

  Widget _row(String label, List<Widget> pills, {bool last = false}) => Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(width: 74, child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: AdminLabel(label),
            )),
            Expanded(child: Wrap(spacing: 8, runSpacing: 8, children: pills)),
          ],
        ),
      );
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.row,
    required this.hall,
    required this.date,
    required this.cancelled,
    required this.last,
    required this.accent,
    required this.slug,
    required this.cost,
    required this.matched,
    required this.onCancel,
  });

  final BookingRowEntity row;
  final AdminHallEntity hall;
  final DateTime date;
  final bool cancelled;
  final bool last;
  final Color accent;
  final String slug;
  final int cost;
  final bool matched;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final Color tint = AdminColors.tintFor(slug);
    final (Color sc, Color sbg, Color sbd) = cancelled
        ? (AdminColors.danger, AdminColors.dangerBg, AdminColors.dangerBorder)
        : AdminColors.status(_statusKey(row.status));

    return Opacity(
      opacity: cancelled ? 0.45 : 1,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: BorderSide(color: AdminColors.rowDivider)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: cancelled ? const Color(0xFF15171B) : accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    AdminFormat.span(row.startMinutes, row.endMinutes),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                      color: cancelled ? AdminColors.textFaint : tint,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text('${AdminFormat.dowShort(date)}, ${date.day} ${AdminFormat.monShort(date)}',
                    style: const TextStyle(fontSize: 11, color: AdminColors.textLabel)),
              ],
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(row.clientName,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: sbg,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: sbd),
                        ),
                        child: Text(
                          (cancelled ? 'отменена' : row.status.label).toUpperCase(),
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: sc),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text('${row.phone} · ${row.source.label}',
                      style: const TextStyle(fontSize: 12, color: AdminColors.textDim)),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      _chip(hall.name, false, tint),
                      if (row.headsets > 0) _chip('VR ${AdminFormat.helmets(row.headsets)}', true, tint),
                      if (row.consoles > 0) _chip('PS5 × ${row.consoles}', true, tint),
                      _chip('${row.durationMinutes ~/ 60} ч', false, tint),
                      if (row.packageName != null) _chip('пакет «${row.packageName}»', false, tint),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 132,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(AdminFormat.money(cost),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                      )),
                  const SizedBox(height: 2),
                  Text(
                    matched
                        ? 'фикс. цена пакета'
                        : row.packageName != null
                            ? 'состав не совпал · по часам'
                            : 'почасовая оплата',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 11, color: AdminColors.textLabel),
                  ),
                  const SizedBox(height: 8),
                  AdminGhostButton(
                    label: cancelled ? 'Вернуть' : 'Отменить',
                    tone: cancelled ? AdminButtonTone.neutral : AdminButtonTone.danger,
                    filled: !cancelled,
                    onTap: onCancel,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool accented, Color tint) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: accented ? accent.withValues(alpha: 0.10) : AdminColors.tile,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: accented ? accent.withValues(alpha: 0.35) : AdminColors.borderInput,
          ),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: accented ? tint : AdminColors.textMid)),
      );

  static String _statusKey(RecordStatus s) => switch (s) {
        RecordStatus.newRequest => 'new',
        RecordStatus.confirmed => 'confirmed',
        RecordStatus.paid => 'paid',
      };
}
