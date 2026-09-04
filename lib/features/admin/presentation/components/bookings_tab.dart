import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/admin_club_entity.dart';
import '../../domain/entity/booking_row_entity.dart';
import '../../domain/service/admin_pricing_service.dart';
import '../../domain/state/admin_bloc.dart';
import '../admin_format.dart';
import '../admin_theme.dart';
import 'admin_atoms.dart';

/// Вкладка «Брони» — операционный список на сегодня.
class BookingsTab extends StatelessWidget {
  /// Создаёт вкладку.
  const BookingsTab({
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
    final List<BookingRowEntity> rows = state.todayBookings;
    final int live = rows.where((BookingRowEntity r) => !state.isCancelled(r.id)).length;
    final bool weekend = pricing.isWeekend(0);
    final DateTime today = pricing.dateOf(0);

    return AdminCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text('Брони на ${AdminFormat.dayMonthLong(today)}',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                Text(
                  '$live активных из ${rows.length} · тариф ${weekend ? 'выходного дня' : 'будней'}',
                  style: const TextStyle(fontSize: 12, color: AdminColors.textFaint),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AdminColors.divider),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 34, 20, 34),
              child: Center(
                child: Column(
                  children: <Widget>[
                    Text('На этот день броней нет',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    SizedBox(height: 5),
                    Text('Выберите другой клуб в шапке.',
                        style: TextStyle(fontSize: 13, color: AdminColors.textMuted)),
                  ],
                ),
              ),
            )
          else
            for (int i = 0; i < rows.length; i++)
              _BookingRow(
                row: rows[i],
                hall: state.clubHalls.firstWhere(
                  (AdminHallEntity h) => h.id == rows[i].hallId,
                  orElse: () => state.clubHalls.first,
                ),
                cancelled: state.isCancelled(rows[i].id),
                last: i == rows.length - 1,
                accent: accent,
                cost: pricing.rowCost(
                  row: rows[i],
                  price: state.priceOf(rows[i].hallId),
                  packages: state.packages,
                ),
                hourly: pricing.hourlyCost(
                  headsets: rows[i].headsets,
                  consoles: rows[i].consoles,
                  minutes: rows[i].durationMinutes,
                  price: state.priceOf(rows[i].hallId),
                  weekend: weekend,
                ),
                matched: pricing.matchPackage(rows[i], state.packages) != null,
                onCancel: () => bloc.add(AdminRowCancelToggled(rows[i].id)),
              ),
        ],
      ),
    );
  }
}

class _BookingRow extends StatelessWidget {
  const _BookingRow({
    required this.row,
    required this.hall,
    required this.cancelled,
    required this.last,
    required this.accent,
    required this.cost,
    required this.hourly,
    required this.matched,
    required this.onCancel,
  });

  final BookingRowEntity row;
  final AdminHallEntity hall;
  final bool cancelled;
  final bool last;
  final Color accent;
  final int cost;
  final int hourly;
  final bool matched;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final Color tint = AdminColors.tintFor(
      accent == AdminColors.accentFor('v_ray') ? 'v_ray' : 'effect_vr',
    );
    final bool showGross = matched && hourly != cost;
    final String basis = matched ? 'пакет «${row.packageName}»' : 'почасовая оплата';

    return Opacity(
      opacity: cancelled ? 0.45 : 1,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: BorderSide(color: AdminColors.rowDivider)),
        ),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(row.clientName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      '${row.phone} · ${hall.name} · ${AdminFormat.seats(row.stationCount)} · ${row.durationMinutes ~/ 60} ч',
                      style: const TextStyle(fontSize: 12, color: AdminColors.textFaint),
                    ),
                  ],
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        if (showGross) ...<Widget>[
                          Text(AdminFormat.money(hourly),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AdminColors.textLabel,
                                  decoration: TextDecoration.lineThrough)),
                          const SizedBox(width: 6),
                        ],
                        Text(AdminFormat.money(cost),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                            )),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(basis,
                        style: TextStyle(
                            fontSize: 11,
                            color: matched ? tint : AdminColors.textLabel)),
                  ],
                ),
                const SizedBox(width: 10),
                AdminGhostButton(
                  label: cancelled ? 'Вернуть' : 'Отменить',
                  tone: cancelled ? AdminButtonTone.neutral : AdminButtonTone.danger,
                  filled: !cancelled,
                  onTap: cancelled ? onCancel : () => _confirm(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirm(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: AdminColors.panel,
        title: const Text('Отменить бронь?'),
        content: Text(
          '${row.clientName}, ${AdminFormat.span(row.startMinutes, row.endMinutes)}. '
          'Клиента об отмене админка не уведомляет.',
          style: const TextStyle(color: AdminColors.textMuted, fontSize: 14),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Оставить'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onCancel();
            },
            child: const Text('Отменить бронь',
                style: TextStyle(color: AdminColors.danger)),
          ),
        ],
      ),
    );
  }
}
