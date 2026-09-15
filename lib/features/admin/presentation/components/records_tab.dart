import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/admin_club_entity.dart';
import '../../domain/entity/booking_row_entity.dart';
import '../../domain/service/admin_pricing_service.dart';
import '../../domain/state/admin_bloc.dart';
import '../admin_format.dart';
import '../admin_theme.dart';
import 'admin_atoms.dart';
import 'admin_date_picker.dart';
import 'kpi_tile.dart';
import 'occupancy_grid.dart';

/// Вкладка «Записи» — KPI за день, сетка занятости и список броней.
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

    final List<List<BookingRowEntity>> orders = state.dayOrders;
    final List<List<BookingRowEntity>> live = orders
        .where((List<BookingRowEntity> o) => !state.isCancelled(o.first.id))
        .toList(growable: false);
    final int cancelled = orders.length - live.length;

    int total = 0;
    for (final List<BookingRowEntity> o in live) {
      for (final BookingRowEntity r in o) {
        total += pricing.rowCost(
          row: r,
          price: state.priceOf(r.hallId),
          packages: state.packages,
        );
      }
    }

    final Color tint = AdminColors.tintFor(state.accentSlug);
    final List<({String label, String value, String note})> kpis =
        <({String label, String value, String note})>[
      (
        label: 'броней за день',
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
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const AdminLabel('День'),
                const SizedBox(width: 12),
                AdminDatePicker(
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
            _RefreshButton(
              refreshing: state.refreshing,
              refreshedAt: state.refreshedAt,
              onTap: () => bloc.add(const AdminRefreshRequested()),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _DayList(state: state, orders: orders),
        const SizedBox(height: 14),
        OccupancyGrid(state: state, accent: accent, pricing: pricing),
      ],
    );
  }
}

/// «Обновить» + когда данные пришли с сервера. Брони и так перечитываются
/// раз в минуту — кнопка для тех, кто ждёт звонка «я только что записался».
class _RefreshButton extends StatelessWidget {
  const _RefreshButton({
    required this.refreshing,
    required this.refreshedAt,
    required this.onTap,
  });

  final bool refreshing;
  final DateTime? refreshedAt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DateTime? at = refreshedAt;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AdminGhostButton(
          label: refreshing ? 'Обновляю…' : 'Обновить',
          onTap: refreshing ? () {} : onTap,
        ),
        if (at != null) ...<Widget>[
          const SizedBox(width: 10),
          Text('обновлено в ${AdminFormat.hhmm(at.hour * 60 + at.minute)}',
              style: const TextStyle(fontSize: 12, color: AdminColors.textFaint)),
        ],
      ],
    );
  }
}

/// Брони на день списком — главный вид на телефоне: сетка там уезжает вбок,
/// а имена в ней обрезаются.
class _DayList extends StatelessWidget {
  const _DayList({required this.state, required this.orders});

  final AdminState state;
  final List<List<BookingRowEntity>> orders;

  @override
  Widget build(BuildContext context) {
    final AdminBloc bloc = context.read<AdminBloc>();
    return AdminCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AdminCardTitle(
            'Брони на день',
            subtitle: orders.isEmpty
                ? 'На этот день броней нет.'
                : 'Нажмите на бронь — откроется карточка с контактами и отменой.',
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < orders.length; i++)
            _OrderTile(
              state: state,
              parts: orders[i],
              divider: i > 0,
              onTap: () => bloc.add(AdminRowOpened(orders[i].first.id)),
            ),
        ],
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({
    required this.state,
    required this.parts,
    required this.divider,
    required this.onTap,
  });

  final AdminState state;
  final List<BookingRowEntity> parts;
  final bool divider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final BookingRowEntity head = parts.first;
    final bool cancelled = state.isCancelled(head.id);
    int start = head.startMinutes;
    int end = head.endMinutes;
    for (final BookingRowEntity r in parts) {
      if (r.startMinutes < start) start = r.startMinutes;
      if (r.endMinutes > end) end = r.endMinutes;
    }
    String hallName(String id) => state.clubHalls
        .firstWhere((AdminHallEntity h) => h.id == id,
            orElse: () => state.clubHalls.first)
        .name;
    final String composition = parts
        .map((BookingRowEntity r) =>
            '${hallName(r.hallId)}: ${AdminFormat.composition(r.maxHeadsets, r.maxConsoles)}')
        .join(' · ');

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: divider
              ? const Border(top: BorderSide(color: AdminColors.rowDivider))
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 96,
              child: Text(
                AdminFormat.span(start, end),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                  color: cancelled ? AdminColors.textFaint : AdminColors.text,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    head.clientName.isEmpty ? 'Без имени' : head.clientName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cancelled ? AdminColors.textFaint : AdminColors.text,
                      decoration: cancelled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$composition · ${head.source.label}',
                    style: const TextStyle(fontSize: 12, height: 1.35, color: AdminColors.textFaint),
                  ),
                ],
              ),
            ),
            if (cancelled)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text('отменена',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AdminColors.danger)),
              )
            else
              const Padding(
                padding: EdgeInsets.only(left: 8, top: 1),
                child: Icon(Icons.chevron_right, size: 18, color: AdminColors.textFaint),
              ),
          ],
        ),
      ),
    );
  }
}
