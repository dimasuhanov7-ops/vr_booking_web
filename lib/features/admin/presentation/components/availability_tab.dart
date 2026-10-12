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
    final DateTime day = pricing.dateOf(state.availDayIndex);
    final String dayLabel =
        '${AdminFormat.dowShort(day)}, ${AdminFormat.dayMonthLong(day)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AdminColors.warnBg,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: AdminColors.warnBorder),
          ),
          child: const Text(
            'Изменения применяются сразу: закрытые залы и окна пропадают из '
            'публичного виджета, а на паузе он не принимает новые брони. '
            'Уже созданные брони не отменяются — отмените их вручную.',
            style: TextStyle(fontSize: 12, height: 1.4, color: AdminColors.warn),
          ),
        ),
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
                          : 'Пауза: виджет открывается, но вместо сетки показывает «запись приостановлена».',
                    ),
                  ),
                  const SizedBox(width: 14),
                  AdminToggle(
                    value: state.intakeOpen,
                    accent: accent,
                    onTap: () async {
                      // Включить обратно — без вопросов, поставить на паузу — с
                      // подтверждением: клиенты сразу перестанут записываться.
                      if (state.intakeOpen) {
                        final bool ok = await confirmAdminAction(
                          context,
                          title: 'Приостановить онлайн-запись?',
                          message: 'Клиенты ${state.club.name} не смогут записаться '
                              'через сайт и ВК, пока вы не включите приём снова.',
                          confirmLabel: 'Приостановить',
                          danger: false,
                        );
                        if (!ok) return;
                      }
                      bloc.add(const AdminIntakeToggled());
                    },
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
                    onToggle: () async {
                      if (!state.closedHallIds.contains(h.id)) {
                        final bool ok = await confirmAdminAction(
                          context,
                          title: 'Закрыть «${h.name}»?',
                          message: 'Зал пропадёт из виджета на все дни, пока вы его '
                              'не откроете. Уже созданные брони останутся.',
                          confirmLabel: 'Закрыть зал',
                          danger: false,
                        );
                        if (!ok) return;
                      }
                      bloc.add(AdminHallClosureToggled(h.id));
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _BookingSettingsCard(club: state.club, accent: accent),
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
                    onTap: () async {
                      final bool ok = await confirmAdminAction(
                        context,
                        title: 'Закрыть весь день?',
                        message: 'На $dayLabel клиенты не смогут записаться. '
                            'Уже созданные брони останутся — их нужно отменить вручную.',
                        confirmLabel: 'Закрыть день',
                        danger: false,
                      );
                      if (ok) bloc.add(const AdminDayClosureChanged(closeAll: true));
                    },
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
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
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
    // Высота — от масштаба шрифта: при крупном системном шрифте три строки
    // в фиксированные 62 px не помещались.
    final double height = MediaQuery.textScalerOf(context).scale(46) + 20;
    return SizedBox(
      height: height,
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
              width: 56,
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
                          height: 1.1,
                          color: on ? tint : AdminColors.textMid)),
                  Text('${d.day}',
                      style: TextStyle(
                        fontSize: 17,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                        color: on ? tint : AdminColors.textSoft,
                      )),
                  Text(AdminFormat.monShort(d),
                      style: TextStyle(
                          fontSize: 10,
                          height: 1.1,
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
    // Высота ячейки — по содержимому, а не пропорцией к ширине: на узком
    // экране пропорция давала слишком низкую ячейку, и подпись «открыт»
    // вылезала за край.
    final double extent = MediaQuery.textScalerOf(context).scale(38) + 24;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final int cols = (c.maxWidth / 104).floor().clamp(2, 8);
        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            mainAxisExtent: extent,
          ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                height: 1.2,
                fontWeight: FontWeight.w700,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                color: closed ? AdminColors.warn : AdminColors.textSoft,
              ),
            ),
            const SizedBox(height: 3),
            Text(closed ? 'закрыт' : 'открыт',
                style: TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    color: closed ? AdminColors.warn : AdminColors.textDim)),
          ],
        ),
      ),
    );
  }
}

/// «Онлайн-запись»: настройки, которые раньше были зашиты в код виджета.
///
/// Сохраняются через пару секунд после изменения, как цены. Сервер проверяет
/// брони по тем же значениям, поэтому обойти их из браузера нельзя.
class _BookingSettingsCard extends StatelessWidget {
  const _BookingSettingsCard({required this.club, required this.accent});

  final AdminClubEntity club;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final AdminBloc bloc = context.read<AdminBloc>();
    final bool urlOk = AdminClubEntity.isValidPrivacyUrl(club.privacyUrl);

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const AdminCardTitle(
            'Онлайн-запись',
            subtitle: 'Как клиенты записываются через сайт и ВК. Сотрудников '
                'эти ограничения не касаются.',
          ),
          const SizedBox(height: 16),
          _row(
            'Длительности сеанса',
            'Какие варианты видит клиент. Пакеты — только на них.',
            <Widget>[
              for (final int m in AdminClubEntity.allowedDurations)
                AdminPill(
                  label: '${m ~/ 60} ч',
                  selected: club.durations.contains(m),
                  accent: accent,
                  compact: true,
                  onTap: () => bloc.add(AdminClubSettingsChanged(toggleDuration: m)),
                ),
            ],
          ),
          _row(
            'Запись закрывается',
            'За сколько до начала сеанса виджет перестаёт его предлагать.',
            <Widget>[
              for (final int m in _with(AdminClubEntity.leadOptions, club.leadMinutes))
                AdminPill(
                  label: m == 0 ? 'к началу' : 'за ${_minutes(m)}',
                  selected: m == club.leadMinutes,
                  accent: accent,
                  compact: true,
                  onTap: () => bloc.add(AdminClubSettingsChanged(leadMinutes: m)),
                ),
            ],
          ),
          _row(
            'Запись открыта вперёд',
            'На сколько дней вперёд можно выбрать дату.',
            <Widget>[
              for (final int d in _with(AdminClubEntity.horizonOptions, club.horizonDays))
                AdminPill(
                  label: '$d дн.',
                  selected: d == club.horizonDays,
                  accent: accent,
                  compact: true,
                  onTap: () => bloc.add(AdminClubSettingsChanged(horizonDays: d)),
                ),
            ],
          ),
          _row(
            'Перерыв между сеансами',
            'Сеансы начинаются раз в час плюс перерыв: при 10 мин — 11:00, 12:10, 13:20…',
            <Widget>[
              for (final int m in _with(AdminClubEntity.gapOptions, club.gapMinutes))
                AdminPill(
                  label: m == 0 ? 'без перерыва' : '$m мин',
                  selected: m == club.gapMinutes,
                  accent: accent,
                  compact: true,
                  onTap: () => bloc.add(AdminClubSettingsChanged(gapMinutes: m)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          AdminTextInput(
            key: ValueKey<String>('privacy-${club.id}'),
            label: 'Ссылка на политику конфиденциальности',
            hint: 'https://${club.slug == 'v_ray' ? 'vrayarena.ru' : 'effectvr.ru'}/privacy',
            value: club.privacyUrl,
            keyboardType: TextInputType.url,
            onChanged: (String v) =>
                bloc.add(AdminClubSettingsChanged(privacyUrl: v.trim())),
          ),
          const SizedBox(height: 6),
          Text(
            urlOk
                ? 'Показывается под формой брони рядом с согласием на обработку '
                    'данных. Пусто — только текст согласия, без ссылки.'
                : 'Нужен полный адрес страницы, начиная с https:// — пока он не '
                    'введён, ссылка не сохраняется.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: urlOk ? AdminColors.textMuted : AdminColors.warn,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String title, String hint, List<Widget> pills) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(hint,
                style: const TextStyle(
                    fontSize: 12, height: 1.35, color: AdminColors.textMuted)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: pills),
          ],
        ),
      );

  /// Варианты плюс текущее значение, если его задали иначе (например, в базе).
  static List<int> _with(List<int> options, int current) =>
      (<int>{...options, current}.toList()..sort());

  static String _minutes(int m) {
    if (m % 60 == 0) return '${m ~/ 60} ч';
    return '$m мин';
  }
}
