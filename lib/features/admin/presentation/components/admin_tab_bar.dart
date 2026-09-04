import 'package:flutter/material.dart';

import '../../domain/state/admin_bloc.dart';
import '../admin_theme.dart';

/// Панель вкладок админки.
class AdminTabBar extends StatelessWidget {
  /// Создаёт панель вкладок.
  const AdminTabBar({
    required this.current,
    required this.accent,
    required this.onSelected,
    super.key,
  });

  /// Активная вкладка.
  final AdminTab current;

  /// Акцент клуба.
  final Color accent;

  /// Колбэк выбора.
  final ValueChanged<AdminTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final Color tint = AdminColors.tintFor(
      accent == AdminColors.accentFor('v_ray') ? 'v_ray' : 'effect_vr',
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final AdminTab t in AdminTab.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () => onSelected(t),
                borderRadius: BorderRadius.circular(11),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  decoration: BoxDecoration(
                    color: t == current ? accent.withValues(alpha: 0.16) : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: t == current ? accent : AdminColors.borderInput,
                    ),
                  ),
                  child: Text(
                    t.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: t == current ? tint : AdminColors.textMid,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
