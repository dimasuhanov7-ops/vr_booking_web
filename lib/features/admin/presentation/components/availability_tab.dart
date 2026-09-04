import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/admin_club_entity.dart';
import '../../domain/service/admin_pricing_service.dart';
import '../../domain/state/admin_bloc.dart';
import '../admin_format.dart';
import '../admin_theme.dart';
import 'admin_atoms.dart';

/// Вкладка «Доступность».
class AvailabilityTab extends StatelessWidget {
  /// Создаёт вкладку.
  const AvailabilityTab({
    required this.state,
    required this.accent,
    this.pricing = const AdminPricingService(),
    super.key,
  });

  /// Состояние.
  final AdminState state;

  /// Акцент клуба.
  final Color accent;

  /// Сервис (для дат).
  final AdminPricingService pricing;

  @override
  Widget build(BuildContext context) {
    final AdminBloc bloc = context.read<AdminBloc>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: AdminCardTitle(
                      'Приём заявок',
                      subtitle: state.intakeOpen
                          ? 'Виджет принимает брони в обычном режиме.'
                          : 'Виджет открывается, но вместо сетки показывает «запись приостановлена».',
                    ),
                  ),
                  const SizedBox(width: 14),
                  AdminToggle(
                    value: state.intakeOpen,
                    accent: accent,
                    onTap: () => bloc.add(const AdminIntakeToggled()),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (final AdminHallEntity h in state.clubHalls)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _HallRow(
                    hall: h,
                    closed: state.closedHallIds.contains(h.id),
                    accent: accent,
                    onToggle: () => bloc.add(AdminHallClosureToggled(h.id)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AdminCardTitle('Закрыть отдельные слоты', subtitle: _slotHint()),
              const SizedBox(height: 16),
              _DayStrip(state: state, accent: accent, pricing: pricing,
                  onPick: (int i) => bloc.add(AdminAvailDayChanged(i))),
              const SizedBox(height: 14),
              _SlotGrid(state: state, accent: accent,
                  onToggle: (int m) => bloc.add(AdminSlotClosureToggled(m))),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AdminColors.divider),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  AdminGhostButton(
                    label: 'Закрыть весь день',
                    tone: AdminButtonTone.warn,
                    filled: true,
                    onTap: () => bloc.add(const AdminDayClosureChanged(closeAll: true)),
                  ),
                  AdminGhostButton(
                    label: 'Открыть весь день',
                    onTap: () => bloc.add(const AdminDayClosureChanged(closeAll: false)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _slotHint() {
    final AdminClubEntity c = state.club;
    final String tail = c.gapMinutes > 0
        ? ' · перерыв ${c.gapMinutes} минут между сеансами'
        : ' · сеансы подряд, без перерыва';
    return '${c.name}, ${c.hoursLabel}$tail';
  }
}

class _HallRow extends StatelessWidget {
  const _HallRow({
    required this.hall,
    required this.closed,
    required this.accent,
    required this.onToggle,
  });

  final AdminHallEntity hall;
  final bool closed;
  final Color accent;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final Color tint = AdminColors.tintFor(
      accent == AdminColors.accentFor('v_ray') ? 'v_ray' : 'effect_vr',
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: closed ? AdminColors.warnBgDeep : AdminColors.tile,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: closed ? AdminColors.warnBorder : AdminColors.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(hall.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  closed ? 'скрыт из виджета' : '${AdminFormat.seats(hall.capacity)}, доступен',
                  style: const TextStyle(fontSize: 12, color: AdminColors.textFaint),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                color: closed ? accent.withValues(alpha: 0.14) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: closed ? accent : AdminColors.borderInput),
              ),
              child: Text(
                closed ? 'Открыть зал' : 'Закрыть зал',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: closed ? tint : AdminColors.textSoft,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayStrip extends StatelessWidget {
  const _DayStrip({
    required this.state,
    required this.accent,
    required this.pricing,
    required this.onPick,
  });

  final AdminState state;
  final Color accent;
  final AdminPricingService pricing;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final Color tint = AdminColors.tintFor(state.accentSlug);
    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: AdminState.horizonDays,
        separatorBuilder: (BuildContext _, int _) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int i) {
          final DateTime d = pricing.dateOf(i);
          final bool on = state.availDayIndex == i;
          return InkWell(
            onTap: () => onPick(i),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? accent.withValues(alpha: 0.16) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: on ? accent : AdminColors.borderInput),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(AdminFormat.dowShort(d).toUpperCase(),
                      style: TextStyle(
                          fontSize: 11,
                          color: on ? tint : AdminColors.textMid)),
                  Text('${d.day}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                        color: on ? tint : AdminColors.textSoft,
                      )),
                  Text(AdminFormat.monShort(d),
                      style: TextStyle(
                          fontSize: 10,
                          color: on ? tint : AdminColors.textFaint)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SlotGrid extends StatelessWidget {
  const _SlotGrid({
    required this.state,
    required this.accent,
    required this.onToggle,
  });

  final AdminState state;
  final Color accent;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final List<int> starts = state.slotStarts;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final int cols = (c.maxWidth / 104).floor().clamp(2, 8);
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.9,
          children: <Widget>[
            for (final int m in starts)
              _SlotCell(
                minutes: m,
                closed: state.closedSlotKeys.contains(state.slotKey(m)),
                onTap: () => onToggle(m),
              ),
          ],
        );
      },
    );
  }
}

class _SlotCell extends StatelessWidget {
  const _SlotCell({
    required this.minutes,
    required this.closed,
    required this.onTap,
  });

  final int minutes;
  final bool closed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
        decoration: BoxDecoration(
          color: closed ? AdminColors.warnBgDeep : AdminColors.tile,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: closed ? AdminColors.warnBorder : AdminColors.borderInput),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              AdminFormat.hhmm(minutes),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                color: closed ? AdminColors.warn : AdminColors.textSoft,
              ),
            ),
            const SizedBox(height: 5),
            Text(closed ? 'закрыт' : 'открыт',
                style: TextStyle(
                    fontSize: 11,
                    color: closed ? AdminColors.warn : AdminColors.textDim)),
          ],
        ),
      ),
    );
  }
}
