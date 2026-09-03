import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entity/station_entity.dart';
import 'booking_atoms.dart';

/// «План зала»: ряды станций с состояниями свободно / занято / выбрано,
/// быстрый выбор и легенда (шаг 3).
class HallPlan extends StatelessWidget {
  /// Создаёт план зала.
  const HallPlan({
    required this.stations,
    required this.isFree,
    required this.pickedIds,
    required this.takenIds,
    required this.isCombo,
    required this.accent,
    required this.freeCount,
    required this.onToggle,
    required this.onQuickPick,
    required this.onClear,
    super.key,
  });

  /// Станции варианта зала (упорядочены).
  final List<StationEntity> stations;

  /// Свободна ли станция в выбранном слоте.
  final bool Function(String) isFree;

  /// Выбранные станции.
  final Set<String> pickedIds;

  /// Станции, занятые при конфликте.
  final Set<String> takenIds;

  /// Вариант «Весь клуб» (группировать по залам).
  final bool isCombo;

  /// Акцент клуба.
  final Color accent;

  /// Сколько станций свободно всего.
  final int freeCount;

  /// Переключение станции.
  final ValueChanged<String> onToggle;

  /// Быстрый выбор N станций (`-1` — все).
  final ValueChanged<int> onQuickPick;

  /// Сброс выбора.
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final Map<String, List<StationEntity>> groups = <String, List<StationEntity>>{};
    for (final StationEntity s in stations) {
      groups.putIfAbsent(isCombo ? s.roomName : '_', () => <StationEntity>[]).add(s);
    }

    final List<int> quickOpts = <int>[2, 4, 6, 8, 12]
        .where((int n) => n <= freeCount)
        .toList();
    if (freeCount > 0 && !quickOpts.contains(freeCount)) quickOpts.add(freeCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Text('Взять сразу:',
                    style: TextStyle(fontSize: 12, color: BookingColors.textDim)),
              ),
              for (final int n in quickOpts)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: PillButton(
                    label: n == freeCount ? 'все $n' : '$n',
                    selected: pickedIds.length == n,
                    accent: accent,
                    onTap: () => onQuickPick(n),
                  ),
                ),
              if (pickedIds.isNotEmpty)
                PillButton(
                  label: 'сбросить',
                  selected: false,
                  dim: true,
                  accent: accent,
                  onTap: onClear,
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: BookingColors.borderSoft),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFF16161C), Color(0xFF101015)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final MapEntry<String, List<StationEntity>> g in groups.entries) ...<Widget>[
                if (isCombo) _groupHeader(g.key, g.value),
                ..._rowsOf(g.value),
                const SizedBox(height: 6),
              ],
              const SizedBox(height: 8),
              const Divider(height: 1, color: BookingColors.borderSoft),
              const SizedBox(height: 12),
              _legend(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _groupHeader(String name, List<StationEntity> list) {
    final int free = list.where((StationEntity s) => isFree(s.id)).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(name,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          Text('$free из ${list.length} свободно',
              style: const TextStyle(fontSize: 11, color: BookingColors.textDim)),
        ],
      ),
    );
  }

  List<Widget> _rowsOf(List<StationEntity> list) {
    final Map<int, List<StationEntity>> rows = <int, List<StationEntity>>{};
    for (final StationEntity s in list) {
      rows.putIfAbsent(s.rowIndex, () => <StationEntity>[]).add(s);
    }
    final List<int> keys = rows.keys.toList()..sort();
    return <Widget>[
      for (final int k in keys)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SectionLabel(
                rows[k]!.first.type == StationType.ps5
                    ? 'приставки PS5 · диван'
                    : 'ряд ${k + 1} · VR',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final StationEntity s in rows[k]!..sort(
                      (StationEntity a, StationEntity b) =>
                          a.positionInRow.compareTo(b.positionInRow)))
                    _Pod(
                      station: s,
                      free: isFree(s.id),
                      picked: pickedIds.contains(s.id),
                      taken: takenIds.contains(s.id),
                      accent: accent,
                      onTap: () => onToggle(s.id),
                    ),
                ],
              ),
            ],
          ),
        ),
    ];
  }

  Widget _legend() {
    final Color tint = accent == BookingColors.emeraldAccent
        ? BookingColors.emeraldTint
        : BookingColors.limeTint;
    Widget item(Widget swatch, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            swatch,
            const SizedBox(width: 7),
            Text(label, style: const TextStyle(fontSize: 12, color: BookingColors.textMuted)),
          ],
        );
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: <Widget>[
        item(
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: BookingColors.pod,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: BookingColors.podBorder),
            ),
          ),
          'свободно',
        ),
        item(
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF232329)),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xFF17171C), Color(0xFF2E2E38)],
                stops: <double>[0.5, 0.5],
                tileMode: TileMode.repeated,
              ),
            ),
          ),
          'занято',
        ),
        item(
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: accent, width: 2),
            ),
            child: Icon(Icons.check, size: 11, color: tint),
          ),
          'выбрано мной',
        ),
      ],
    );
  }
}

class _Pod extends StatelessWidget {
  const _Pod({
    required this.station,
    required this.free,
    required this.picked,
    required this.taken,
    required this.accent,
    required this.onTap,
  });

  final StationEntity station;
  final bool free;
  final bool picked;
  final bool taken;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool busy = !free || taken;
    final Color tint = accent == BookingColors.emeraldAccent
        ? BookingColors.emeraldTint
        : BookingColors.limeTint;

    final Color border = picked
        ? accent
        : busy
            ? const Color(0xFF232329)
            : BookingColors.podBorder;
    final Color bg = picked
        ? accent.withValues(alpha: 0.22)
        : busy
            ? const Color(0xFF17171C)
            : BookingColors.pod;
    final Color fg = picked
        ? BookingColors.text
        : busy
            ? BookingColors.textOff
            : BookingColors.textSoft;

    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 74,
        padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: picked ? 2 : 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _visor(picked ? tint : (busy ? const Color(0xFF3A3A44) : const Color(0xFF7E7E8C))),
            const SizedBox(height: 8),
            Text(station.label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
            const SizedBox(height: 3),
            Text(
              taken ? 'заняли' : busy ? 'занято' : picked ? '✓ моя' : 'свободно',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 0.2,
                decoration: busy && !taken ? TextDecoration.lineThrough : null,
                color: picked
                    ? tint
                    : busy
                        ? BookingColors.textDim
                        : const Color(0xFF7C7C88),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _visor(Color color) {
    if (station.type == StationType.ps5) {
      return Container(
        width: 34,
        height: 16,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border(
            top: BorderSide(color: color, width: 2),
            bottom: BorderSide(color: color, width: 2),
            left: BorderSide(color: color, width: 8),
            right: BorderSide(color: color, width: 8),
          ),
        ),
      );
    }
    return Container(
      width: 38,
      height: 22,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(11),
          bottom: Radius.circular(5),
        ),
        border: Border.all(color: color, width: 2),
        gradient: picked
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[accent.withValues(alpha: 0.45), Colors.transparent],
              )
            : null,
      ),
    );
  }
}
