import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/booking_row_entity.dart';
import '../../domain/service/admin_pricing_service.dart';
import '../../domain/state/admin_bloc.dart';
import '../admin_format.dart';
import '../admin_theme.dart';
import 'admin_atoms.dart';
import 'admin_month_calendar.dart';
import 'kpi_tile.dart';
import 'occupancy_grid.dart';

/// Вкладка «Записи» — KPI за день, календарь и сетка занятости по часам.
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
    final int day = state.occupancyDayIndex;

    final List<BookingRowEntity> rows = state.effectiveRows
        .where((BookingRowEntity r) => r.clubId == state.clubId && r.dayIndex == day)
        .toList(growable: false);
    final List<BookingRowEntity> live = rows
        .where((BookingRowEntity r) => !state.isCancelled(r.id))
        .toList(growable: false);
    final int cancelled = rows.length - live.length;

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
        label: 'записей за день',
        value: '${live.length}',
        note: cancelled > 0 ? '+ $cancelled отменено' : 'на выбранный день',
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
        AdminCard(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const AdminLabel('День'),
              const SizedBox(height: 10),
              AdminMonthCalendar(
                selectedDayIndex: day,
                accent: accent,
                slug: state.accentSlug,
                pricing: pricing,
                onPick: (int di) => bloc.add(AdminFilterChanged(
                  day: di,
                  hallId: state.filterHallId,
                  type: state.filterType,
                )),
              ),
            ],
          ),
        ),
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
