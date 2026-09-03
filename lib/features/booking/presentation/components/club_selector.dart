import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entity/club_entity.dart';
import '../booking_format.dart';

/// Карточки выбора клуба (шаг 1).
class ClubSelector extends StatelessWidget {
  /// Создаёт селектор клуба.
  const ClubSelector({
    required this.clubs,
    required this.stationsByClub,
    required this.selectedClubId,
    required this.onSelected,
    super.key,
  });

  /// Клубы.
  final List<ClubEntity> clubs;

  /// Число VR/PS5 по клубу: `{clubId: (headsets, consoles, capacity)}`.
  final Map<String, ({int headsets, int consoles, int capacity})> stationsByClub;

  /// Выбранный клуб.
  final String? selectedClubId;

  /// Колбэк выбора.
  final ValueChanged<ClubEntity> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (final ClubEntity club in clubs)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _Card(
              club: club,
              kit: stationsByClub[club.id],
              selected: club.id == selectedClubId,
              onTap: () => onSelected(club),
            ),
          ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.club,
    required this.kit,
    required this.selected,
    required this.onTap,
  });

  final ClubEntity club;
  final ({int headsets, int consoles, int capacity})? kit;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = BookingColors.accentFor(club.slug);
    final int headsets = kit?.headsets ?? 0;
    final int consoles = kit?.consoles ?? 0;
    final int capacity = kit?.capacity ?? 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.10) : BookingColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? accent : BookingColors.borderSoft,
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              club.name,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _Tag(
                            text: club.slug == 'v_ray' ? 'два зала' : 'один зал',
                            accent: accent,
                            active: selected,
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _desc(club),
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: BookingColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      '$capacity',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'МЕСТ СРАЗУ',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.6,
                        color: BookingColors.textFaint,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 13),
            const Divider(height: 1, color: BookingColors.borderSoft),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: <Widget>[
                _Kit(
                  glyph: _headsetGlyph(accent),
                  label:
                      '$headsets ${BookingFormat.plural(headsets, 'VR-шлем', 'VR-шлема', 'VR-шлемов')}',
                ),
                if (consoles > 0)
                  _Kit(glyph: _ps5Glyph(), label: '$consoles PS5'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _hours(club),
              style: const TextStyle(fontSize: 12, color: BookingColors.textFaint),
            ),
          ],
        ),
      ),
    );
  }

  static String _desc(ClubEntity c) => c.slug == 'v_ray'
      ? 'Флагманский зал на 12 шлемов для больших групп плюс отдельный зал с PS5.'
      : 'Один зал: 4 шлема и 2 приставки PS5. Хорошо для компании до шести человек.';

  static String _hours(ClubEntity c) {
    String f(Duration d) =>
        '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}';
    return 'Ежедневно ${f(c.openTime)} – ${f(c.closeTime)}';
  }

  static Widget _headsetGlyph(Color accent) => Container(
        width: 20,
        height: 12,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(6),
            bottom: Radius.circular(3),
          ),
          border: Border.all(color: accent, width: 1.5),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[accent.withValues(alpha: 0.35), Colors.transparent],
          ),
        ),
      );

  static Widget _ps5Glyph() => Container(
        width: 18,
        height: 11,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          border: const Border(
            top: BorderSide(color: BookingColors.textDim, width: 1.5),
            bottom: BorderSide(color: BookingColors.textDim, width: 1.5),
            left: BorderSide(color: BookingColors.textDim, width: 5),
            right: BorderSide(color: BookingColors.textDim, width: 5),
          ),
        ),
      );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.accent, required this.active});

  final String text;
  final Color accent;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: active ? accent : BookingColors.borderSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          letterSpacing: 1,
          fontWeight: FontWeight.w600,
          color: active ? BookingColors.bg : const Color(0xFF9A9AA6),
        ),
      ),
    );
  }
}

class _Kit extends StatelessWidget {
  const _Kit({required this.glyph, required this.label});

  final Widget glyph;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        glyph,
        const SizedBox(width: 7),
        Text(label,
            style: const TextStyle(fontSize: 13, color: BookingColors.textSoft)),
      ],
    );
  }
}
