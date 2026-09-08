import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/service/admin_pricing_service.dart';
import '../admin_format.dart';
import '../admin_theme.dart';
import 'admin_month_calendar.dart';

/// Компактное поле-«таблетка» с датой; по тапу — всплывающий календарь.
class AdminDatePicker extends StatefulWidget {
  /// Создаёт поле.
  const AdminDatePicker({
    required this.selectedDayIndex,
    required this.onPick,
    required this.accent,
    required this.slug,
    this.pricing = const AdminPricingService(),
    super.key,
  });

  /// Выбранный день (смещение от сегодняшнего).
  final int selectedDayIndex;

  /// Колбэк выбора дня.
  final ValueChanged<int> onPick;

  /// Акцент клуба.
  final Color accent;

  /// Slug клуба.
  final String slug;

  /// Сервис дат.
  final AdminPricingService pricing;

  @override
  State<AdminDatePicker> createState() => _AdminDatePickerState();
}

class _AdminDatePickerState extends State<AdminDatePicker> {
  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();

  @override
  Widget build(BuildContext context) {
    final int di = widget.selectedDayIndex < 0 ? 0 : widget.selectedDayIndex;
    final DateTime date = widget.pricing.dateOf(di);
    final Color tint = AdminColors.tintFor(widget.slug);
    final double screenW = MediaQuery.sizeOf(context).width;
    final double panelW = math.min(320, screenW - 32);

    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (BuildContext context) {
          return Stack(
            children: <Widget>[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _portal.hide,
                ),
              ),
              CompositedTransformFollower(
                link: _link,
                targetAnchor: Alignment.bottomLeft,
                followerAnchor: Alignment.topLeft,
                offset: const Offset(0, 6),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: panelW,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1115),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF262830)),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 30,
                              offset: Offset(0, 12)),
                        ],
                      ),
                      padding: const EdgeInsets.all(10),
                      child: AdminMonthCalendar(
                        selectedDayIndex: widget.selectedDayIndex,
                        accent: widget.accent,
                        slug: widget.slug,
                        pricing: widget.pricing,
                        showFootnote: false,
                        onPick: (int d) {
                          widget.onPick(d);
                          _portal.hide();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        child: InkWell(
          onTap: _portal.toggle,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: AdminColors.input,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AdminColors.borderInput),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.calendar_today_outlined, size: 15, color: tint),
                const SizedBox(width: 9),
                Text(
                  '${AdminFormat.dowShort(date)}, ${AdminFormat.dayMonthLong(date)}',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AdminColors.text),
                ),
                if (di == 0) ...<Widget>[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('сегодня',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: tint)),
                  ),
                ],
                const SizedBox(width: 6),
                const Icon(Icons.expand_more,
                    size: 16, color: AdminColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
