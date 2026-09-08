import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entity/club_entity.dart';
import '../../domain/entity/time_slot_entity.dart';
import '../booking_format.dart';
import 'booking_atoms.dart';

/// Сетка слотов времени с индикатором свободных станций (шаг 2).
class SlotGrid extends StatelessWidget {
  /// Создаёт сетку слотов.
  const SlotGrid({
    required this.club,
    required this.slots,
    required this.selected,
    required this.capacity,
    required this.freeCountAt,
    required this.accent,
    required this.onSelected,
    super.key,
  });

  /// Клуб (для перевода времени).
  final ClubEntity club;

  /// Слоты.
  final List<TimeSlotEntity> slots;

  /// Выбранный слот.
  final TimeSlotEntity? selected;

  /// Всего станций в зале.
  final int capacity;

  /// Функция «сколько свободно в слоте».
  final int Function(TimeSlotEntity) freeCountAt;

  /// Акцент клуба.
  final Color accent;

  /// Колбэк выбора слота.
  final ValueChanged<TimeSlotEntity> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        const double min = 104;
        final int cols = (c.maxWidth / (min + 8)).floor().clamp(2, 6);
        // Высоту задаём явно (а не через childAspectRatio): при системном
        // увеличении шрифта фиксированная пропорция переполняет чип.
        final TextScaler ts = MediaQuery.textScalerOf(context);
        final double extent =
            21 + ts.scale(16) * 1.25 + 18 + ts.scale(11) * 1.25;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: (c.maxWidth - 8 * (cols - 1)) / cols / extent,
          children: <Widget>[
            for (final TimeSlotEntity s in slots)
              _SlotChip(
                time: BookingFormat.clockAt(club, s.startsAt),
                free: freeCountAt(s),
                total: capacity,
                selected: s == selected,
                accent: accent,
                onTap: () => onSelected(s),
              ),
          ],
        );
      },
    );
  }
}

/// Заглушка сетки слотов на время загрузки занятости.
///
/// Повторяет раскладку [SlotGrid], поэтому при появлении данных блок не
/// прыгает: на его месте уже была сетка того же размера.
class SlotGridSkeleton extends StatelessWidget {
  /// Создаёт заглушку.
  const SlotGridSkeleton({this.count = 6, super.key});

  /// Сколько плиток показать.
  final int count;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        const double min = 104;
        final int cols = (c.maxWidth / (min + 8)).floor().clamp(2, 6);
        final TextScaler ts = MediaQuery.textScalerOf(context);
        final double extent =
            21 + ts.scale(16) * 1.25 + 18 + ts.scale(11) * 1.25;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: (c.maxWidth - 8 * (cols - 1)) / cols / extent,
          children: <Widget>[
            for (int i = 0; i < count; i++)
              SkeletonBox(height: extent, radius: 13),
          ],
        );
      },
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.time,
    required this.free,
    required this.total,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String time;
  final int free;
  final int total;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool out = free == 0;
    final Color tint = accent == BookingColors.emeraldAccent
        ? BookingColors.emeraldTint
        : BookingColors.limeTint;

    final BoxDecoration decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(13),
      border: Border.all(
        color: selected
            ? accent
            : out
            ? const Color(0xFF232329)
            : BookingColors.border,
      ),
      color: selected
          ? accent.withValues(alpha: 0.20)
          : out
          ? const Color(0xFF16161B)
          : BookingColors.surface,
    );

    return FocusRing(
      radius: 13,
      color: accent,
      child: InkWell(
        onTap: out ? null : onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
          decoration: decoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                time,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? BookingColors.text
                      : out
                      ? BookingColors.textOff
                      : BookingColors.textSoft,
                ),
              ),
              const SizedBox(height: 7),
              // 12 точек по 7 px не влезают в узкий чип — ужимаем, а не режем.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  children: <Widget>[
                    for (int i = 0; i < total.clamp(0, 12); i++)
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(right: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: i < free ? accent : BookingColors.podBorder,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                out ? 'занято' : '$free из $total',
                style: TextStyle(
                  fontSize: 11,
                  decoration: out ? TextDecoration.lineThrough : null,
                  color: out
                      ? BookingColors.textDim
                      : selected
                      ? tint
                      : BookingColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
