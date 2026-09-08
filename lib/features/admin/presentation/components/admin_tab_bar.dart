import 'package:flutter/material.dart';

import '../../domain/state/admin_bloc.dart';
import '../admin_theme.dart';

/// Панель вкладок админки: скроллящийся ряд табов + необязательное действие
/// справа («＋ Новая запись»).
class AdminTabBar extends StatelessWidget {
  /// Создаёт панель вкладок.
  const AdminTabBar({
    required this.current,
    required this.accent,
    required this.onSelected,
    this.trailing,
    super.key,
  });

  /// Активная вкладка.
  final AdminTab current;

  /// Акцент клуба.
  final Color accent;

  /// Колбэк выбора.
  final ValueChanged<AdminTab> onSelected;

  /// Виджет-действие справа.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final Color tint = AdminColors.tintFor(
      accent == AdminColors.accentFor('v_ray') ? 'v_ray' : 'effect_vr',
    );

    final Widget tabs = SingleChildScrollView(
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
                    color: t == current
                        ? accent.withValues(alpha: 0.16)
                        : Colors.transparent,
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

    if (trailing == null) return tabs;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        if (c.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              tabs,
              const SizedBox(height: 12),
              trailing!,
            ],
          );
        }
        return Row(
          children: <Widget>[
            Expanded(child: tabs),
            const SizedBox(width: 10),
            trailing!,
          ],
        );
      },
    );
  }
}

/// Залитая акцентом кнопка «＋ Новая запись» для [AdminTabBar.trailing].
class AdminPrimaryButton extends StatelessWidget {
  /// Создаёт кнопку.
  const AdminPrimaryButton({
    required this.label,
    required this.accent,
    required this.onTap,
    super.key,
  });

  /// Подпись.
  final String label;

  /// Акцент клуба.
  final Color accent;

  /// Обработчик.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AdminColors.bg,
          ),
        ),
      ),
    );
  }
}
