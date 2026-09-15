import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entity/station_entity.dart';
import 'booking_atoms.dart';

/// Зазор между плитками станций.
const double _podGap = 8;

/// Ширина плитки станции: макет — 74, узкий телефон — до 56.
const double _podBaseWidth = 74;
const double _podMinWidth = 56;

/// До какой ширины растягивать плитки, если ряд пришлось разбить на строки.
const double _podStretchWidth = 104;

/// С какого размера два ряда VR считаются «половинами» зала.
const int _halfMinSize = 6;

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
    required this.onPickGroup,
    this.quickLabel = 'Взять сразу:',
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

  /// Взять (`pick: true`) или снять группу станций — половину арены.
  final void Function(Set<String> ids, {required bool pick}) onPickGroup;

  /// Подпись перед быстрым выбором («Взять сразу:» / «Или по часам:»).
  final String quickLabel;

  @override
  Widget build(BuildContext context) {
    final Map<String, List<StationEntity>> groups =
        <String, List<StationEntity>>{};
    for (final StationEntity s in stations) {
      groups
          .putIfAbsent(isCombo ? s.roomName : '_', () => <StationEntity>[])
          .add(s);
    }

    final List<int> quickOpts = <int>[
      2,
      4,
      6,
      8,
      12,
    ].where((int n) => n <= freeCount).toList();
    if (freeCount > 0 && !quickOpts.contains(freeCount)) {
      quickOpts.add(freeCount);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  quickLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: BookingColors.textDim,
                  ),
                ),
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
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            // Вычитаем padding (14+14) и рамку (1+1): плитки считаются от
            // ширины, реально доступной внутри контейнера.
            final double inner = c.maxWidth - 30;
            return Container(
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
                  for (final MapEntry<String, List<StationEntity>> g
                      in groups.entries) ...<Widget>[
                    if (isCombo) _groupHeader(g.key, g.value),
                    ..._rowsOf(g.value, inner),
                    const SizedBox(height: 6),
                  ],
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: BookingColors.borderSoft),
                  const SizedBox(height: 12),
                  _legend(),
                ],
              ),
            );
          },
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
            child: Text(
              name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '$free из ${list.length} свободно',
            style: const TextStyle(fontSize: 11, color: BookingColors.textDim),
          ),
        ],
      ),
    );
  }

  List<Widget> _rowsOf(List<StationEntity> list, double inner) {
    final Map<int, List<StationEntity>> rows = <int, List<StationEntity>>{};
    for (final StationEntity s in list) {
      rows.putIfAbsent(s.rowIndex, () => <StationEntity>[]).add(s);
    }
    final List<int> keys = rows.keys.toList()..sort();
    for (final List<StationEntity> r in rows.values) {
      r.sort(
        (StationEntity a, StationEntity b) =>
            a.positionInRow.compareTo(b.positionInRow),
      );
    }

    // Зал из двух больших рядов VR — это две половины арены. Половина —
    // готовый вариант для компании, поэтому называем её так и даём взять
    // одним нажатием.
    final bool halves =
        keys.length == 2 &&
        rows.values.every(
          (List<StationEntity> r) =>
              r.length >= _halfMinSize && r.first.type == StationType.vrHeadset,
        );

    return <Widget>[
      for (int i = 0; i < keys.length; i++)
        _row(
          rows[keys[i]]!,
          label: halves
              ? 'половина ${i + 1} · ${rows[keys[i]]!.length} шлемов'
              : rows[keys[i]]!.first.type == StationType.ps5
              ? 'приставки PS5 · диван'
              : 'ряд ${keys[i] + 1} · VR',
          groupAction: halves,
          inner: inner,
        ),
    ];
  }

  Widget _row(
    List<StationEntity> row, {
    required String label,
    required bool groupAction,
    required double inner,
  }) {
    final ({int cols, double pod}) fit = hallRowFit(row.length, inner);
    final Set<String> free = <String>{
      for (final StationEntity s in row)
        if (isFree(s.id) && !takenIds.contains(s.id)) s.id,
    };
    final bool allPicked = free.isNotEmpty && free.every(pickedIds.contains);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            height: 30,
            child: Row(
              children: <Widget>[
                Expanded(child: SectionLabel(label)),
                if (groupAction && (allPicked || free.length >= 2))
                  _GroupAction(
                    label: allPicked ? 'снять' : 'взять половину',
                    active: !allPicked,
                    accent: accent,
                    onTap: () => onPickGroup(free, pick: !allPicked),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Ширина задаёт, сколько плиток встанет в строку: Wrap переносит
          // ровно после [fit.cols], и половина арены на телефоне складывается
          // блоком 3×2, а не рвётся на 4+2.
          SizedBox(
            width: fit.cols * fit.pod + (fit.cols - 1) * _podGap + 0.5,
            child: Wrap(
              spacing: _podGap,
              runSpacing: _podGap,
              children: <Widget>[
                for (final StationEntity s in row)
                  _Pod(
                    station: s,
                    free: isFree(s.id),
                    picked: pickedIds.contains(s.id),
                    taken: takenIds.contains(s.id),
                    accent: accent,
                    width: fit.pod,
                    onTap: () => onToggle(s.id),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
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
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: BookingColors.textMuted),
        ),
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

/// Раскладка ряда из [count] станций в ширину [inner]: сколько плиток в строке
/// и какой они ширины.
///
/// Ряд ставится целиком, если плитки не уже [_podMinWidth]. Иначе он делится
/// пополам (6 → 3+3, 4 → 2+2), а не переносится как придётся: половина
/// остаётся цельным блоком. Разбитый ряд растягивает плитки на всю ширину,
/// чтобы блок не жался к левому краю; целый — не шире макета.
@visibleForTesting
({int cols, double pod}) hallRowFit(int count, double inner) {
  double podFor(int cols) =>
      ((inner - _podGap * (cols - 1)) / cols).floorToDouble();

  int cols = count < 1 ? 1 : count;
  while (cols > 1 && podFor(cols) < _podMinWidth) {
    cols = (cols / 2).ceil();
  }
  final double max = cols < count ? _podStretchWidth : _podBaseWidth;
  return (cols: cols, pod: podFor(cols).clamp(_podMinWidth, max));
}

/// Кнопка в заголовке ряда: «взять половину» / «снять».
class _GroupAction extends StatelessWidget {
  const _GroupAction({
    required this.label,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FocusRing(
      radius: 8,
      color: accent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? accent : BookingColors.textDim,
            ),
          ),
        ),
      ),
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
    required this.width,
    required this.onTap,
  });

  final StationEntity station;
  final bool free;
  final bool picked;
  final bool taken;
  final Color accent;

  /// Ширина плитки — считается от доступного места (см. [hallRowFit]).
  final double width;

  final VoidCallback onTap;

  /// Коэффициент сжатия относительно макетных 74 px. Растянутая плитка
  /// становится шире, но содержимое не крупнее макета.
  double get _k => (width / _podBaseWidth).clamp(0.0, 1.0);

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

    // Скринридер иначе прочитал бы «#5 свободно» без понимания, что это и
    // что с ним можно сделать.
    final String kind = station.type == StationType.ps5 ? 'PS5' : 'VR-шлем';
    final String stateLabel = taken
        ? 'только что заняли'
        : busy
        ? 'занято'
        : picked
        ? 'выбрано вами'
        : 'свободно';

    return Semantics(
      button: !busy,
      selected: picked,
      enabled: !busy,
      label: '$kind ${station.label}, $stateLabel',
      excludeSemantics: true,
      child: FocusRing(
        radius: 14,
        color: accent,
        child: InkWell(
          onTap: busy ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: width,
            padding: EdgeInsets.fromLTRB(4, 12 * _k, 4, 10 * _k),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border, width: picked ? 2 : 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _visor(
                  picked
                      ? tint
                      : (busy
                            ? const Color(0xFF3A3A44)
                            : const Color(0xFF7E7E8C)),
                ),
                SizedBox(height: 8 * _k),
                Text(
                  station.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13 * _k,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 3),
                // Галочка — иконкой из бандла, а не символом «✓»: его нет в Archivo,
                // и CanvasKit ради него тянул Noto Sans с fonts.gstatic.com.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (picked && !busy) ...<Widget>[
                      Icon(Icons.check, size: 10 * _k, color: tint),
                      SizedBox(width: 2 * _k),
                    ],
                    Flexible(
                      child: Text(
                        taken
                            ? 'заняли'
                            : busy
                            ? 'занято'
                            : picked
                            ? 'моя'
                            : 'свободно',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10 * _k,
                          letterSpacing: 0.2,
                          decoration: busy && !taken
                              ? TextDecoration.lineThrough
                              : null,
                          color: picked
                              ? tint
                              : busy
                              ? BookingColors.textDim
                              : const Color(0xFF7C7C88),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _visor(Color color) {
    if (station.type == StationType.ps5) {
      return Container(
        width: 34 * _k,
        height: 16 * _k,
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
      width: 38 * _k,
      height: 22 * _k,
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
                colors: <Color>[
                  accent.withValues(alpha: 0.45),
                  Colors.transparent,
                ],
              )
            : null,
      ),
    );
  }
}
