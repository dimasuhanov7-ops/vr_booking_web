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

/// Вкладка «Записи» — поиск брони, KPI за день, календарь и сетка занятости
/// по часам.
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
    final int noShows =
        live.where((BookingRowEntity r) => r.status == RecordStatus.noShow).length;
    final String dayNote = <String>[
      if (cancelled > 0) '+ $cancelled отменено',
      if (noShows > 0) '$noShows не пришли',
    ].join(' · ');

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
        note: dayNote.isEmpty ? 'на выбранный день' : dayNote,
      ),
      (label: 'сумма', value: AdminFormat.money(total), note: 'по текущему тарифу'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Search(state: state, pricing: pricing),
        const SizedBox(height: 14),
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
        Row(
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

/// Поиск брони по имени или телефону во всех клубах и днях.
class _Search extends StatelessWidget {
  const _Search({required this.state, required this.pricing});

  final AdminState state;
  final AdminPricingService pricing;

  @override
  Widget build(BuildContext context) {
    final AdminBloc bloc = context.read<AdminBloc>();
    final bool active = state.searchQuery.trim().isNotEmpty;
    final List<BookingRowEntity> found = state.searchResults;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: AdminTextInput(
            label: 'Найти бронь',
            hint: 'Имя или телефон, например 912 344',
            value: state.searchQuery,
            onChanged: (String v) => bloc.add(AdminSearchChanged(v)),
          ),
        ),
        if (active) ...<Widget>[
          const SizedBox(height: 10),
          if (found.isEmpty)
            const Text('Ничего не найдено. Проверьте имя или последние цифры телефона.',
                style: TextStyle(fontSize: 13, color: AdminColors.textMuted))
          else
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AdminColors.border),
              ),
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < found.length; i++)
                    _ResultRow(
                      row: found[i],
                      state: state,
                      pricing: pricing,
                      first: i == 0,
                      onTap: () => bloc.add(AdminSearchResultOpened(found[i].id)),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.row,
    required this.state,
    required this.pricing,
    required this.first,
    required this.onTap,
  });

  final BookingRowEntity row;
  final AdminState state;
  final AdminPricingService pricing;
  final bool first;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DateTime date = pricing.dateOf(row.dayIndex);
    AdminClubEntity? club;
    for (final AdminClubEntity c in state.clubs) {
      if (c.id == row.clubId) club = c;
    }
    String hall = '';
    for (final AdminHallEntity h in club?.halls ?? const <AdminHallEntity>[]) {
      if (h.id == row.hallId) hall = h.name;
    }
    final bool cancelled = state.isCancelled(row.id);
    final bool past = row.dayIndex < 0;

    return Material(
      color: AdminColors.tile,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            border: first
                ? null
                : const Border(top: BorderSide(color: AdminColors.rowDivider)),
          ),
          child: Wrap(
            spacing: 14,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 150,
                child: Text(
                  '${AdminFormat.dowShort(date)}, ${date.day} ${AdminFormat.monShort(date)}'
                  ' · ${AdminFormat.hhmm(row.startMinutes)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: past ? AdminColors.textMuted : AdminColors.text,
                  ),
                ),
              ),
              Text(row.clientName,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: AdminColors.text)),
              Text(row.phone,
                  style: const TextStyle(fontSize: 13, color: AdminColors.textSoft)),
              Text(
                [club?.name ?? '', hall].where((String s) => s.isNotEmpty).join(' · '),
                style: const TextStyle(fontSize: 12, color: AdminColors.textMuted),
              ),
              if (cancelled)
                const Text('отменена',
                    style: TextStyle(fontSize: 12, color: AdminColors.danger)),
              if (past && !cancelled)
                const Text('прошла',
                    style: TextStyle(fontSize: 12, color: AdminColors.textFaint)),
            ],
          ),
        ),
      ),
    );
  }
}
