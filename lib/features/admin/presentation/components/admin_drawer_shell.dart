import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../admin_theme.dart';

/// Выезжающая справа панель (карточка брони / новая запись).
///
/// Затемняет фон, ловит тап по подложке и «×» для закрытия, при первом
/// появлении проигрывает выезд справа.
class AdminDrawerShell extends StatelessWidget {
  /// Создаёт панель.
  const AdminDrawerShell({
    required this.title,
    required this.onClose,
    required this.child,
    this.subtitle,
    this.trailingHeader,
    super.key,
  });

  /// Заголовок.
  final String title;

  /// Подпись под заголовком.
  final String? subtitle;

  /// Дополнительный виджет в шапке (над кнопкой закрытия).
  final Widget? trailingHeader;

  /// Закрытие.
  final VoidCallback onClose;

  /// Содержимое (ниже шапки).
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double panelWidth =
        math.min(560, MediaQuery.sizeOf(context).width);

    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        tween: Tween<double>(begin: 0, end: 1),
        builder: (BuildContext context, double t, Widget? _) {
          return Stack(
            children: <Widget>[
              Positioned.fill(
                child: GestureDetector(
                  onTap: onClose,
                  child: ColoredBox(color: Color.fromRGBO(4, 5, 6, 0.6 * t)),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FractionalTranslation(
                  translation: Offset(1 - t, 0),
                  child: SizedBox(
                    width: panelWidth,
                    height: double.infinity,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F1115),
                        border: Border(left: BorderSide(color: Color(0xFF262830))),
                      ),
                      child: SafeArea(
                        left: false,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
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
                                        Text(title,
                                            style: const TextStyle(
                                                fontSize: 22, fontWeight: FontWeight.w800)),
                                        if (subtitle != null) ...<Widget>[
                                          const SizedBox(height: 3),
                                          Text(subtitle!,
                                              style: const TextStyle(
                                                  fontSize: 13, color: AdminColors.textMuted)),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ?trailingHeader,
                                  _CloseButton(onTap: onClose),
                                ],
                              ),
                              const SizedBox(height: 18),
                              child,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AdminColors.borderInput),
        ),
        child: const Text('×',
            style: TextStyle(fontSize: 18, color: AdminColors.textMid)),
      ),
    );
  }
}
