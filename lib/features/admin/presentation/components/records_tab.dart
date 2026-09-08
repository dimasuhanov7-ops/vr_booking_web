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
import 'occupancy_grid.dart';

/// Вкладка «Записи» — KPI, фильтры, сетка занятости по часам.
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
    final int cancelledInFilter = filtered.length - live.length;

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

    final Color tint = AdminColors.tintFor(state.accentSlug);
    final List<({String label, String value, String note})> kpis =
        <({String label, String value, String note})>[
      (
        label: 'записей',
        value: '${live.length}',
        note: cancelledInFilter > 0 ? '+ $cancelledInFilter отменено' : 'по фильтрам',
      ),
      (label: 'сумма', value: AdminFormat.money(total), note: 'по текущему тарифу'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final bool wide = c.maxWidth >= 340;
            final double w = wide ? (c.maxWidth - 10) / 2 : c.maxWidth;
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
                      valueColor: tint,
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        _Filters(state: state, accent: accent, pricing: pricing, bloc: bloc),
        const SizedBox(height: 14),
        OccupancyGrid(state: state, accent: accent, pricing: pricing),
        const SizedBox(height: 10),
        const Text(
          'Нажмите на любую запись в сетке или в подписи под ней — откроется карточка брони.',
          style: TextStyle(fontSize: 12, color: AdminColors.textFaint),
        ),
      ],
    );
  }
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
            _pill('все дни', state.filterDay < 0,
                () => bloc.add(AdminFilterChanged(
                    day: -1, hallId: state.filterHallId, type: state.filterType))),
            for (int i = 0; i < 7; i++)
              _pill(
                i == 0
                    ? 'сегодня'
                    : '${AdminFormat.dowShort(pricing.dateOf(i))} ${pricing.dateOf(i).day}',
                state.filterDay == i,
                () => bloc.add(AdminFilterChanged(
                    day: i, hallId: state.filterHallId, type: state.filterType)),
              ),
          ]),
          _row('зал', <Widget>[
            _pill('все залы', state.filterHallId.isEmpty,
                () => bloc.add(AdminFilterChanged(
                    day: state.filterDay, hallId: '', type: state.filterType))),
            for (final AdminHallEntity h in state.clubHalls)
              _pill(h.name, state.filterHallId == h.id,
                  () => bloc.add(AdminFilterChanged(
                      day: state.filterDay, hallId: h.id, type: state.filterType))),
          ]),
          _row('тип', <Widget>[
            for (final AdminTypeFilter t in AdminTypeFilter.values)
              _pill(t.label, state.filterType == t,
                  () => bloc.add(AdminFilterChanged(
                      day: state.filterDay, hallId: state.filterHallId, type: t))),
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
            SizedBox(
              width: 74,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: AdminLabel(label),
              ),
            ),
            Expanded(child: Wrap(spacing: 8, runSpacing: 8, children: pills)),
          ],
        ),
      );
}
