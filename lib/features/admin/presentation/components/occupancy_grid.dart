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
/// оттенками из [AdminColors.hue]. Наведение подсвечивает бронь и приглушает
/// остальные; тап — открывает карточку.
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

  static const double cellW = 34;
  static const double cellH = 24;
  static const double labelW = 66;
  static const double gap = 3;
  static const double rowH = cellH + gap;

  @override
  Widget build(BuildContext context) {
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

/// Одна ячейка сетки: занята ли и какой бронью.
typedef _Cell = ({BookingRowEntity row, int hue})?;

/// Голова брони — где рисуется её имя (левый-верхний занятый юнит).
typedef _Head = ({int unit, int slot, int span, BookingRowEntity row, int hue});

class _HallOccupancy extends StatefulWidget {
  const _HallOccupancy({
    required this.hall,
    required this.state,
    required this.accent,
  });

  final AdminHallEntity hall;
  final AdminState state;
  final Color accent;

  @override
  State<_HallOccupancy> createState() => _HallOccupancyState();
}

class _HallOccupancyState extends State<_HallOccupancy> {
  String? _hoverId;

  /// Ширина ячейки-часа — считается по доступному месту в [LayoutBuilder],
  /// поэтому мутируется в начале builder'а (всё чтение — синхронно там же).
  double _cw = OccupancyGrid.cellW;

  void _hover(String? id) {
    if (_hoverId != id) setState(() => _hoverId = id);
  }

  @override
  Widget build(BuildContext context) {
    final AdminBloc bloc = context.read<AdminBloc>();
    final AdminHallEntity hall = widget.hall;
    final AdminState state = widget.state;
    final AdminClubEntity club = state.club;
    const int step = 60;

    final List<int> slots = <int>[];
    for (int t = club.openMinutes; t + step <= club.closeMinutes; t += step) {
      slots.add(t);
    }

    final List<({bool ps5, String label})> units = <({bool ps5, String label})>[
      for (int i = 0; i < hall.headsets; i++) (ps5: false, label: 'Шлем ${i + 1}'),
      for (int i = 0; i < hall.consoles; i++) (ps5: true, label: 'PS5 ${i + 1}'),
    ];

    final List<BookingRowEntity> bookings = state.occupancyRows(hall.id);

    final List<List<_Cell>> grid = List<List<_Cell>>.generate(
      units.length,
      (_) => List<_Cell>.filled(slots.length, null),
    );
    final List<_Head> heads = <_Head>[];

    for (int ri = 0; ri < bookings.length; ri++) {
      final BookingRowEntity e = bookings[ri];
      final List<int> cover = <int>[];
      for (int si = 0; si < slots.length; si++) {
        final int s = slots[si];
        if (e.startMinutes < s + step && e.endMinutes > s) cover.add(si);
      }
      if (cover.isEmpty) continue;
      ({int u, int s})? first;
      for (final bool wantPs5 in <bool>[false, true]) {
        int need = wantPs5 ? e.consoles : e.headsets;
        for (int ui = 0; ui < units.length && need > 0; ui++) {
          if (units[ui].ps5 != wantPs5) continue;
          if (cover.any((int si) => grid[ui][si] != null)) continue;
          for (final int si in cover) {
            grid[ui][si] = (row: e, hue: ri);
          }
          final ({int u, int s})? cur = first;
          if (cur == null || ui < cur.u) first = (u: ui, s: cover.first);
          need--;
        }
      }
      final ({int u, int s})? f = first;
      if (f != null) {
        heads.add((unit: f.u, slot: f.s, span: cover.length, row: e, hue: ri));
      }
    }

    final int totalCells = units.length * slots.length;
    int busyCells = 0;
    for (final List<_Cell> r in grid) {
      busyCells += r.where((_Cell c) => c != null).length;
    }
    final int load = totalCells == 0 ? 0 : (busyCells * 100 / totalCells).round();

    final List<Widget> legend = <Widget>[
      for (int ri = 0; ri < bookings.length; ri++)
        _LegendRow(
          row: bookings[ri],
          hue: AdminColors.hue(ri),
          dim: _hoverId != null && _hoverId != bookings[ri].id,
          highlighted: _hoverId == bookings[ri].id,
          onHover: _hover,
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
                color: load >= 60
                    ? widget.accent.withValues(alpha: 0.10)
                    : AdminColors.tile,
                border: Border.all(
                  color: load >= 60
                      ? widget.accent.withValues(alpha: 0.35)
                      : AdminColors.borderInput,
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
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            const double minCw = 30;
            final int n = slots.length;
            // −2 запас, чтобы сетка гарантированно не вылезала за карточку.
            final double avail = c.maxWidth - 2;
            final double ideal =
                (avail - OccupancyGrid.labelW - OccupancyGrid.gap * n) / n;
            _cw = ideal >= minCw ? ideal : minCw;
            final double contentW =
                OccupancyGrid.labelW + n * (_cw + OccupancyGrid.gap);
            final double gridH = (units.length + 2) * OccupancyGrid.rowH;

            final Widget stack = SizedBox(
              width: contentW,
              height: gridH,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _timeRow(slots),
                      for (int ui = 0; ui < units.length; ui++)
                        _unitRow(ui, units[ui], slots.length, grid[ui], bloc),
                      _freeRow(slots.length, units.length, grid),
                    ],
                  ),
                  for (final _Head h in heads) _nameLabel(h),
                ],
              ),
            );

            return contentW > avail + 0.5
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal, child: stack)
                : stack;
          },
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
            child: Wrap(spacing: 16, runSpacing: 6, children: legend),
          ),
      ],
    );
  }

  Widget _box(Widget child) => Container(
        width: _cw,
        height: OccupancyGrid.cellH,
        margin: const EdgeInsets.only(
            right: OccupancyGrid.gap, bottom: OccupancyGrid.gap),
        alignment: Alignment.center,
        child: child,
      );

  Widget _timeRow(List<int> slots) => Row(children: <Widget>[
        const SizedBox(width: OccupancyGrid.labelW),
        for (final int s in slots)
          _box(Text(AdminFormat.hhmm(s),
              style: const TextStyle(fontSize: 10, color: AdminColors.textMuted))),
      ]);

  Widget _unitRow(
    int ui,
    ({bool ps5, String label}) unit,
    int slotCount,
    List<_Cell> row,
    AdminBloc bloc,
  ) =>
      Row(children: <Widget>[
        SizedBox(
          width: OccupancyGrid.labelW,
          child: Text(unit.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: unit.ps5 ? FontWeight.w700 : FontWeight.w400,
                color:
                    unit.ps5 ? const Color(0xFF7FA6FF) : AdminColors.textFaint,
              )),
        ),
        for (int si = 0; si < slotCount; si++)
          _box(_OccCell(
            data: row[si],
            ps5: unit.ps5,
            hoverId: _hoverId,
            onHover: _hover,
            onOpen: (String id) => bloc.add(AdminRowOpened(id)),
          )),
      ]);

  Widget _freeRow(int slotCount, int unitCount, List<List<_Cell>> grid) =>
      Row(children: <Widget>[
        const SizedBox(
          width: OccupancyGrid.labelW,
          child: Text('свободно',
              style: TextStyle(fontSize: 11, color: AdminColors.textFaint)),
        ),
        for (int si = 0; si < slotCount; si++)
          Builder(builder: (BuildContext context) {
            int free = 0;
            for (int ui = 0; ui < unitCount; ui++) {
              if (grid[ui][si] == null) free++;
            }
            return _box(Text('$free',
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
      ]);

  Widget _nameLabel(_Head h) {
    final bool dim = _hoverId != null && _hoverId != h.row.id;
    final ({Color bg, Color border, Color text}) hue = AdminColors.hue(h.hue);
    final double left =
        OccupancyGrid.labelW + h.slot * (_cw + OccupancyGrid.gap) + 4;
    final double top = (1 + h.unit) * OccupancyGrid.rowH;
    final double width = h.span * (_cw + OccupancyGrid.gap) - OccupancyGrid.gap - 8;

    return Positioned(
      left: left,
      top: top,
      width: width < 16 ? 16 : width,
      height: OccupancyGrid.cellH,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: dim ? 0.5 : 1,
          duration: _hoverAnim,
          curve: _hoverCurve,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              h.row.clientName,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
                color: hue.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Плавные hover-переходы в сетке занятости.
const Duration _hoverAnim = Duration(milliseconds: 200);
const Curve _hoverCurve = Curves.easeOutCubic;

class _OccCell extends StatelessWidget {
  const _OccCell({
    required this.data,
    required this.ps5,
    required this.hoverId,
    required this.onHover,
    required this.onOpen,
  });

  final _Cell data;
  final bool ps5;
  final String? hoverId;
  final ValueChanged<String?> onHover;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final _Cell d = data;
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
    final bool active = hoverId == d.row.id;
    final bool dim = hoverId != null && !active;

    return MouseRegion(
      onEnter: (_) => onHover(d.row.id),
      onExit: (_) => onHover(null),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onOpen(d.row.id),
        child: AnimatedOpacity(
          opacity: dim ? 0.5 : 1,
          duration: _hoverAnim,
          curve: _hoverCurve,
          child: AnimatedContainer(
            duration: _hoverAnim,
            curve: _hoverCurve,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ps5 ? 12 : 6),
              // Подсвеченная бронь — чуть плотнее заливка и рамка её же цвета,
              // без свечения: фокус создаётся приглушением остальных.
              color: active
                  ? h.bg.withValues(alpha: (h.bg.a + 0.12).clamp(0.0, 1.0))
                  : h.bg,
              border: Border.all(
                color: active ? h.border.withValues(alpha: 0.95) : h.border,
                width: active ? 1.5 : (ps5 ? 1.4 : 1),
              ),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.row,
    required this.hue,
    required this.dim,
    required this.highlighted,
    required this.onHover,
    required this.onTap,
  });

  final BookingRowEntity row;
  final ({Color bg, Color border, Color text}) hue;
  final bool dim;
  final bool highlighted;
  final ValueChanged<String?> onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => onHover(row.id),
      onExit: (_) => onHover(null),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: _hoverAnim,
          curve: _hoverCurve,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            color: highlighted ? const Color(0xFF191C22) : Colors.transparent,
          ),
          child: AnimatedOpacity(
            opacity: dim ? 0.5 : 1,
            duration: _hoverAnim,
            curve: _hoverCurve,
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
                  '${row.clientName} · '
                  '${AdminFormat.span(row.startMinutes, row.endMinutes)} · '
                  '${AdminFormat.composition(row.headsets, row.consoles)}',
                  style: const TextStyle(fontSize: 12, color: AdminColors.textMid),
                ),
              ],
            ),
          ),
        ),
      ),
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
            Text(label,
                style: const TextStyle(fontSize: 12, color: AdminColors.textMuted)),
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
