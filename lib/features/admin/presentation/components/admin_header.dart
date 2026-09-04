import 'package:flutter/material.dart';

import '../../domain/entity/admin_club_entity.dart';
import '../admin_theme.dart';

/// Шапка админки: «АДМИНКА» + подзаголовок + переключатель клуба.
class AdminHeader extends StatelessWidget {
  /// Создаёт шапку.
  const AdminHeader({
    required this.clubs,
    required this.selectedClubId,
    required this.accent,
    required this.onClubSelected,
    super.key,
  });

  /// Клубы.
  final List<AdminClubEntity> clubs;

  /// Выбранный клуб.
  final String selectedClubId;

  /// Акцент выбранного клуба.
  final Color accent;

  /// Колбэк выбора клуба.
  final ValueChanged<String> onClubSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AdminColors.divider)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Flexible(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              children: <Widget>[
                Text(
                  'АДМИНКА',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.9,
                    color: accent,
                  ),
                ),
                const Text('бронирование Effect VR / V-Ray',
                    style: TextStyle(fontSize: 13, color: AdminColors.textFaint)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final AdminClubEntity c in clubs)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _ClubButton(
                    club: c,
                    selected: c.id == selectedClubId,
                    onTap: () => onClubSelected(c.id),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClubButton extends StatelessWidget {
  const _ClubButton({
    required this.club,
    required this.selected,
    required this.onTap,
  });

  final AdminClubEntity club;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = AdminColors.accentFor(club.slug);
    final Color tint = AdminColors.tintFor(club.slug);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: selected ? accent : AdminColors.borderInput),
        ),
        child: Text(
          club.name,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? tint : AdminColors.textMuted,
          ),
        ),
      ),
    );
  }
}
