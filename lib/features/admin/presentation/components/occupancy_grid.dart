import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/admin_club_entity.dart';
import '../../domain/entity/booking_row_entity.dart';
import '../../domain/service/admin_pricing_service.dart';
import '../../domain/state/admin_bloc.dart';
import '../admin_format.dart';
import '../admin_theme.dart';
import 'admin_atoms.dart';

/// Сетка занятости вкладки «Записи»: по строке на каждый шлем / PS5, по столбцу
/// на каждый час. Брони раскладываются по свободным станциям и красятся
/// оттенками из [AdminColors.hue]. Тап по брони — открывает карточку.
class OccupancyGrid extends StatelessWidget {
  /// Создаёт сетку.
  const OccupancyGrid({
    required this.state,
    required this.accent,
    this.pricing = const AdminPricingService(),
    super.key,
  });

  /// Состояние.
  final AdminState state;

  /// Акцент клуба.
  final Color accent;

  /// Сервис расчётов (даты).
  final AdminPricingService pricing;

  static const double _cellW = 34;
  static const double _cellH = 24;
  static const double _labelW = 66;
  static const double _gap = 3;

  @override
  Widget build(BuildContext context) {
    final bool needDay = state.filterDay < 0;
    final DateTime date = pricing.dateOf(state.occupancyDayIndex);
    final List<AdminHallEntity> halls = state.clubHalls
        .where((AdminHallEntity h) =>
            state.filterHallId.isEmpty || h.id == state.filterHallId)
        .toList(growable: false);

    return AdminCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Expanded(
                child: Text('Занятость по часам',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              Text(
                '${state.club.name} · ${AdminFormat.dowShort(date)}, '
                '${date.day} ${AdminFormat.monShort(date)}',
                style: const TextStyle(fontSize: 12, color: AdminColors.textFaint),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (needDay)
            _DashedHint(
              'Выберите день в фильтре выше — покажу сетку занятости.',
            )
          else
            for (int i = 0; i < halls.length; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 22),
                child: _HallOccupancy(
                  hall: halls[i],
                  state: state,
                  accent: accent,
                ),
              ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AdminColors.divider),
          const SizedBox(height: 12),
          const _GlobalLegend(),
        ],
      ),
    );
  }
}

class _HallOccupancy extends StatelessWidget {
  const _HallOccupancy({
    required this.hall,
    required this.state,
    required this.accent,
  });

  final AdminHallEntity hall;
  final AdminState state;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final AdminBloc bloc = context.read<AdminBloc>();
    final AdminClubEntity club = state.club;
    const int step = 60;

    final List<int> slots = <int>[];
    for (int t = club.openMinutes; t + step <= club.closeMinutes; t += step) {
      slots.add(t);
    }

    // Юниты: сначала шлемы, потом PS5.
    final List<({bool ps5, String label})> units = <({bool ps5, String label})>[
      for (int i = 0; i < hall.headsets; i++) (ps5: false, label: 'Шлем ${i + 1}'),
      for (int i = 0; i < hall.consoles; i++) (ps5: true, label: 'PS5 ${i + 1}'),
    ];

    final List<BookingRowEntity> bookings = state.occupancyRows(hall.id);

    // grid[unit][slot] -> (booking, hueIndex, head) | null
    final List<List<({BookingRowEntity row, int hue, bool head})?>> grid =
        List<List<({BookingRowEntity row, int hue, bool head})?>>.generate(
      units.length,
      (_) => List<({BookingRowEntity row, int hue, bool head})?>.filled(
          slots.length, null),
    );

    for (int ri = 0; ri < bookings.length; ri++) {
      final BookingRowEntity e = bookings[ri];
      final List<int> cover = <int>[];
      for (int si = 0; si < slots.length; si++) {
        final int s = slots[si];
        if (e.startMinutes < s + step && e.endMinutes > s) cover.add(si);
      }
      if (cover.isEmpty) continue;
      ({int u, int s})? firstCell;
      for (final bool wantPs5 in <bool>[false, true]) {
        int need = wantPs5 ? e.consoles : e.headsets;
        for (int ui = 0; ui < units.length && need > 0; ui++) {
          if (units[ui].ps5 != wantPs5) continue;
          final bool busy = cover.any((int si) => grid[ui][si] != null);
          if (busy) continue;
          for (final int si in cover) {
            grid[ui][si] = (row: e, hue: ri, head: false);
          }
          final ({int u, int s})? current = firstCell;
          if (current == null || ui < current.u) {
            firstCell = (u: ui, s: cover.first);
          }
          need--;
        }
      }
      final ({int u, int s})? fc = firstCell;
      if (fc != null) {
        final ({BookingRowEntity row, int hue, bool head}) c = grid[fc.u][fc.s]!;
        grid[fc.u][fc.s] = (row: c.row, hue: c.hue, head: true);
      }
    }

    final int totalCells = units.length * slots.length;
    int busyCells = 0;
    for (final List<({BookingRowEntity row, int hue, bool head})?> r in grid) {
      busyCells += r.where((Object? c) => c != null).length;
    }
    final int load = totalCells == 0 ? 0 : (busyCells * 100 / totalCells).round();

    Widget cell(Widget child) => Container(
          width: OccupancyGrid._cellW,
          height: OccupancyGrid._cellH,
          margin: const EdgeInsets.only(right: OccupancyGrid._gap, bottom: OccupancyGrid._gap),
          alignment: Alignment.center,
          child: child,
        );

    final List<Widget> rows = <Widget>[];

    // Шапка времени.
    rows.add(Row(children: <Widget>[
      const SizedBox(width: OccupancyGrid._labelW),
      for (final int s in slots)
        cell(Text(AdminFormat.hhmm(s),
            style: const TextStyle(fontSize: 10, color: AdminColors.textMuted))),
    ]));

    // Строки юнитов.
    for (int ui = 0; ui < units.length; ui++) {
      rows.add(Row(children: <Widget>[
        SizedBox(
          width: OccupancyGrid._labelW,
          child: Text(units[ui].label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: units[ui].ps5 ? FontWeight.w700 : FontWeight.w400,
                color: units[ui].ps5 ? const Color(0xFF7FA6FF) : AdminColors.textFaint,
              )),
        ),
        for (int si = 0; si < slots.length; si++)
          cell(_OccCell(
            data: grid[ui][si],
            ps5: units[ui].ps5,
            onOpen: (String id) => bloc.add(AdminRowOpened(id)),
          )),
      ]));
    }

    // «свободно».
    rows.add(Row(children: <Widget>[
      const SizedBox(
        width: OccupancyGrid._labelW,
        child: Text('свободно',
            style: TextStyle(fontSize: 11, color: AdminColors.textFaint)),
      ),
      for (int si = 0; si < slots.length; si++)
        Builder(builder: (BuildContext context) {
          int free = 0;
          for (int ui = 0; ui < units.length; ui++) {
            if (grid[ui][si] == null) free++;
          }
          return cell(Text('$free',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: free == 0
                    ? AdminColors.danger
                    : free <= 2
                        ? AdminColors.warn
                        : AdminColors.textDim,
              )));
        }),
    ]));

    final List<Widget> legend = <Widget>[
      for (int ri = 0; ri < bookings.length; ri++)
        _LegendRow(
          row: bookings[ri],
          hue: AdminColors.hue(ri),
          onTap: () => bloc.add(AdminRowOpened(bookings[ri].id)),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Text(hall.name,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                '${AdminFormat.helmets(hall.headsets)}'
                '${hall.consoles > 0 ? ' и ${hall.consoles} PS5' : ', без PS5'}',
                style: const TextStyle(fontSize: 12, color: AdminColors.textFaint),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: load >= 60 ? accent.withValues(alpha: 0.10) : AdminColors.tile,
                border: Border.all(
                  color: load >= 60 ? accent.withValues(alpha: 0.35) : AdminColors.borderInput,
                ),
              ),
              child: Text('загрузка $load %',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: load >= 60
                        ? AdminColors.tintFor(state.accentSlug)
                        : AdminColors.textMuted,
                  )),
            ),
          ],
        ),
        const SizedBox(height: 11),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
        ),
        if (legend.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('На этот день записей в зале нет.',
                style: TextStyle(fontSize: 12, color: AdminColors.textFaint)),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 11),
            child: Wrap(spacing: 16, runSpacing: 8, children: legend),
          ),
      ],
    );
  }
}

class _OccCell extends StatelessWidget {
  const _OccCell({required this.data, required this.ps5, required this.onOpen});

  final ({BookingRowEntity row, int hue, bool head})? data;
  final bool ps5;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final ({BookingRowEntity row, int hue, bool head})? d = data;
    if (d == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ps5 ? 12 : 6),
          border: Border.all(color: const Color(0xFF1F2127)),
          color: const Color(0xFF0B0D10),
        ),
        child: const SizedBox.expand(),
      );
    }
    final ({Color bg, Color border, Color text}) h = AdminColors.hue(d.hue);
    return GestureDetector(
      onTap: () => onOpen(d.row.id),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ps5 ? 12 : 6),
          color: h.bg,
          border: Border.all(color: h.border, width: ps5 ? 1.4 : 1),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.row, required this.hue, required this.onTap});

  final BookingRowEntity row;
  final ({Color bg, Color border, Color text}) hue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 22,
              height: 12,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: hue.bg,
                border: Border.all(color: hue.border),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              '${row.clientName} · ${AdminFormat.span(row.startMinutes, row.endMinutes)} · '
              '${AdminFormat.composition(row.headsets, row.consoles)}',
              style: const TextStyle(fontSize: 12, color: AdminColors.textMid),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedHint extends StatelessWidget {
  const _DashedHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF26282F)),
      ),
      child: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AdminColors.textMuted)),
    );
  }
}

class _GlobalLegend extends StatelessWidget {
  const _GlobalLegend();

  @override
  Widget build(BuildContext context) {
    Widget item(Widget swatch, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            swatch,
            const SizedBox(width: 7),
            Text(label, style: const TextStyle(fontSize: 12, color: AdminColors.textMuted)),
          ],
        );

    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: <Widget>[
        item(
          Container(
            width: 34,
            height: 12,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: const LinearGradient(colors: <Color>[
                Color(0x6BA9F04A),
                Color(0x6B7FA6FF),
                Color(0x6BFFA85C),
              ]),
              border: Border.all(color: AdminColors.borderInput),
            ),
          ),
          'цвет = отдельная запись',
        ),
        item(
          Container(
            width: 22,
            height: 14,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              color: const Color(0x6B7FA6FF),
              border: Border.all(color: const Color(0xBF7FA6FF), width: 1.4),
            ),
          ),
          'PS5 — скруглённая капсула',
        ),
        item(
          Container(
            width: 22,
            height: 12,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: const Color(0xFF0B0D10),
              border: Border.all(color: const Color(0xFF1F2127)),
            ),
          ),
          'свободно',
        ),
      ],
    );
  }
}
