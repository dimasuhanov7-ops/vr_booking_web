import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/config/booking_config.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entity/club_entity.dart';
import '../../domain/entity/hall_option_entity.dart';
import '../../domain/entity/station_entity.dart';
import '../../domain/entity/time_slot_entity.dart';
import '../../domain/state/booking_bloc.dart';
import '../booking_format.dart';
import '../components/booking_atoms.dart';
import '../components/booking_bottom_bar.dart';
import '../components/booking_progress.dart';
import '../components/club_selector.dart';
import '../components/conflict_banner.dart';
import '../components/contact_form.dart';
import '../components/date_field.dart';
import '../components/duration_selector.dart';
import '../components/empty_day_state.dart';
import '../components/hall_plan.dart';
import '../components/hall_selector.dart';
import '../components/slot_grid.dart';
import '../components/success_view.dart';

/// Содержимое виджета бронирования (один прокручиваемый экран).
class BookingView extends StatelessWidget {
  /// Создаёт представление.
  const BookingView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BookingBloc, BookingState>(
      listenWhen: (BookingState p, BookingState c) =>
          p.errorMessage != c.errorMessage && c.errorMessage != null,
      listener: (BuildContext context, BookingState state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(state.errorMessage!),
            backgroundColor: Colors.redAccent.shade700,
            behavior: SnackBarBehavior.floating,
          ));
      },
      builder: (BuildContext context, BookingState state) {
        if (state.status == BookingStatus.loading && state.clubs.isEmpty) {
          return const _Frame(
            child: Padding(
              padding: EdgeInsets.all(60),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (state.status == BookingStatus.failure && state.clubs.isEmpty) {
          return _Frame(child: _Retry(onRetry: () =>
              context.read<BookingBloc>().add(const BookingStarted())));
        }

        final Color accent = BookingColors.accentFor(state.club?.slug);

        if (state.view == BookingStage.done && state.createdOrderId != null) {
          return _Frame(
            child: SuccessView(
              orderId: state.createdOrderId!,
              club: state.club!,
              hall: state.hall!,
              slot: state.slot!,
              durationMinutes: state.durationMinutes,
              quote: state.quote,
              peopleLabel: _peopleLabel(state),
              contact: '${state.clientName}, ${state.clientPhone}',
              onRestart: () =>
                  context.read<BookingBloc>().add(const BookingResetRequested()),
            ),
          );
        }

        return _Frame(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 26),
                child: _FormBody(state: state, accent: accent),
              ),
              BookingBottomBar(
                line: _barLine(state),
                net: state.quote.net,
                gross: state.quote.gross,
                hasDiscount: state.quote.hasDiscount,
                cta: _cta(state),
                enabled: state.canSubmit,
                busy: state.status == BookingStatus.submitting,
                accent: accent,
                onPressed: () =>
                    context.read<BookingBloc>().add(const BookingSubmitted()),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _cta(BookingState s) {
    if (s.pickedIds.isEmpty) return 'Далее';
    return s.isContactValid ? 'Забронировать' : 'Заполните контакты';
  }

  static String _barLine(BookingState s) {
    if (s.club == null) return 'Выберите клуб';
    if (s.slot == null) return '${s.club!.name} · ${s.hall?.name ?? ''}';
    if (s.pickedIds.isEmpty) return 'Отметьте станции на плане';
    final int n = s.pickedIds.length;
    return '$n ${BookingFormat.plural(n, 'станция', 'станции', 'станций')} · '
        '${BookingFormat.range(s.club!, s.slot!.startsAt, s.slot!.endsAt)}';
  }

  static String _peopleLabel(BookingState s) {
    final int n = int.tryParse(s.peopleInput.trim()) ?? s.pickedIds.length;
    return '$n ${BookingFormat.plural(n, 'человека', 'человек', 'человек')}';
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 460),
      decoration: BoxDecoration(
        color: BookingColors.frame,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: BookingColors.borderSoft),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x8C000000), blurRadius: 80, offset: Offset(0, 30)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.wifi_off_rounded, color: BookingColors.textDim, size: 44),
          const SizedBox(height: 12),
          const Text('Не удалось загрузить данные',
              textAlign: TextAlign.center,
              style: TextStyle(color: BookingColors.textSoft)),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Повторить')),
        ],
      ),
    );
  }
}

class _FormBody extends StatelessWidget {
  const _FormBody({required this.state, required this.accent});

  final BookingState state;
  final Color accent;

  BookingBloc _bloc(BuildContext c) => c.read<BookingBloc>();

  @override
  Widget build(BuildContext context) {
    final BookingBloc bloc = _bloc(context);
    final ClubEntity? club = state.club;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        BookingProgress(step: state.stepNo, accent: accent),
        const SizedBox(height: 22),

        if (state.conflictShown) _conflict(bloc),

        // ── Шаг 1: клубы
        ClubSelector(
          clubs: state.clubs,
          stationsByClub: _kits(),
          selectedClubId: club?.id,
          onSelected: (ClubEntity c) => bloc.add(BookingClubSelected(c)),
        ),

        // ── Шаг 2: зал / дата / длительность / время
        if (club != null) ...<Widget>[
          _divider(),
          if (state.hallOptions.length > 1) ...<Widget>[
            const SectionLabel('Зал'),
            const SizedBox(height: 10),
            HallSelector(
              options: state.hallOptions,
              selectedId: state.hall?.id,
              accent: accent,
              onSelected: (HallOptionEntity h) => bloc.add(BookingHallSelected(h)),
            ),
            const SizedBox(height: 20),
          ],
          const SectionLabel('Дата'),
          const SizedBox(height: 10),
          DateField(
            date: state.date ?? DateTime.now(),
            accent: accent,
            daysAhead: BookingConfig.bookingHorizonDays,
            onSelected: (DateTime d) => bloc.add(BookingDateSelected(d)),
          ),
          const SizedBox(height: 20),
          const SectionLabel('Длительность сеанса'),
          const SizedBox(height: 10),
          DurationSelector(
            options: BookingBloc.durations,
            selected: state.durationMinutes,
            accent: accent,
            onSelected: (int m) => bloc.add(BookingDurationSelected(m)),
          ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              const Expanded(child: SectionLabel('Время начала')),
              Text('свободных мест из ${state.hallCapacity}',
                  style: const TextStyle(fontSize: 12, color: BookingColors.textDim)),
            ],
          ),
          const SizedBox(height: 12),
          if (state.hall == null)
            const _Hint('Выберите зал.')
          else if (state.status == BookingStatus.loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.dayEmpty)
            EmptyDayState(
              title: 'На ${BookingFormat.dayShort(state.date!)} всё занято',
              accent: accent,
              actions: _emptyActions(bloc),
            )
          else if (state.slots.isEmpty)
            const _Hint('На эту дату сеансов уже нет — выберите другой день.')
          else
            SlotGrid(
              club: club,
              slots: state.slots,
              selected: state.slot,
              capacity: state.hallCapacity,
              freeCountAt: state.freeCountAt,
              accent: accent,
              onSelected: (TimeSlotEntity s) => bloc.add(BookingSlotSelected(s)),
            ),
        ],

        // ── Шаг 3: план зала
        if (state.slot != null && state.hall != null) ...<Widget>[
          _divider(),
          SectionLabel('План зала · ${BookingFormat.range(club!, state.slot!.startsAt, state.slot!.endsAt)}'),
          const SizedBox(height: 6),
          Text(
            'Свободно ${state.freeHallStations.length} из ${state.hallCapacity} · выбрано ${state.pickedIds.length}',
            style: const TextStyle(fontSize: 14, color: BookingColors.textSoft),
          ),
          const SizedBox(height: 14),
          HallPlan(
            stations: state.hallStations,
            isFree: state.isFree,
            pickedIds: state.pickedIds,
            takenIds: state.takenIds,
            isCombo: state.hall!.isCombo,
            accent: accent,
            freeCount: state.freeHallStations.length,
            onToggle: (String id) => bloc.add(BookingStationToggled(id)),
            onQuickPick: (int n) => bloc.add(BookingQuickPicked(n)),
            onClear: () => bloc.add(const BookingSelectionCleared()),
          ),
        ],

        // ── Шаг 4: контакты
        if (state.pickedIds.isNotEmpty) ...<Widget>[
          _divider(),
          const SectionLabel('Кто бронирует'),
          const SizedBox(height: 12),
          ContactForm(
            name: state.clientName,
            phone: state.clientPhone,
            people: state.peopleInput,
            pickedCount: state.pickedIds.length,
            onNameChanged: (String v) => bloc.add(BookingContactChanged(name: v)),
            onPhoneChanged: (String v) => bloc.add(BookingContactChanged(phone: v)),
            onPeopleChanged: (String v) => bloc.add(BookingContactChanged(people: v)),
          ),
        ],
      ],
    );
  }

  Widget _conflict(BookingBloc bloc) {
    final StationEntity? alt = state.conflictAlternative;
    final int kept = state.pickedIds.length;
    final String keepLabel = alt != null
        ? 'Взять ${alt.label}'
        : kept == 0
            ? 'Выбрать другое время'
            : 'Продолжить без неё';
    final String text = alt != null
        ? (kept == 0
            ? 'Свободна ${alt.label} в этом же зале.'
            : 'Остальные $kept ${BookingFormat.plural(kept, 'станцию', 'станции', 'станций')} держим за вами — свободна ${alt.label} в этом же зале.')
        : (kept == 0
            ? 'Свободных станций в этом зале на это время больше нет.'
            : 'Остальные $kept ${BookingFormat.plural(kept, 'станцию', 'станции', 'станций')} держим за вами, свободных в этом зале больше нет.');

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: ConflictBanner(
        title: 'Одну станцию забрали, пока вы оформляли',
        text: text,
        keepLabel: keepLabel,
        onKeep: () => bloc.add(const BookingConflictResolved()),
        onDismiss: () => bloc.add(const BookingConflictDismissed()),
      ),
    );
  }

  List<EmptyDayAction> _emptyActions(BookingBloc bloc) {
    final BookingState s = state;
    final DateTime next = s.date!.add(const Duration(days: 1));
    return <EmptyDayAction>[
      (
        label: 'Посмотреть ${BookingFormat.dayShort(next)}',
        primary: true,
        onTap: () => bloc.add(BookingDateSelected(next)),
      ),
      if (s.hallOptions.length > 1)
        (
          label: 'Другой зал ${s.club!.name}',
          primary: false,
          onTap: () {
            final HallOptionEntity other = s.hallOptions.firstWhere(
              (HallOptionEntity h) => h.id != s.hall?.id && !h.isCombo,
              orElse: () => s.hallOptions.first,
            );
            bloc.add(BookingHallSelected(other));
          },
        )
      else
        (
          label: 'Посмотреть другой клуб',
          primary: false,
          onTap: () {
            final ClubEntity other = s.clubs.firstWhere(
              (ClubEntity c) => c.id != s.club!.id,
              orElse: () => s.clubs.first,
            );
            bloc.add(BookingClubSelected(other));
          },
        ),
      if (s.durationMinutes != 60)
        (
          label: 'Сеанс на 1 час — слотов больше',
          primary: false,
          onTap: () => bloc.add(const BookingDurationSelected(60)),
        ),
    ];
  }

  Map<String, ({int headsets, int consoles, int capacity})> _kits() {
    // Для карточек клуба на шаге 1 используем данные уже выбранного клуба,
    // остальным подставляем фиксированный состав из макета.
    final Map<String, ({int headsets, int consoles, int capacity})> out = {};
    for (final ClubEntity c in state.clubs) {
      if (c.id == state.club?.id && state.stations.isNotEmpty) {
        final int h = state.stations
            .where((StationEntity s) => s.type == StationType.vrHeadset)
            .length;
        final int p = state.stations.length - h;
        // «мест сразу» = максимум по одному залу
        final Map<String, int> perRoom = <String, int>{};
        for (final StationEntity s in state.stations) {
          perRoom.update(s.roomId, (int v) => v + 1, ifAbsent: () => 1);
        }
        final int cap = perRoom.values.fold(0, (int a, int b) => a > b ? a : b);
        out[c.id] = (headsets: h, consoles: p, capacity: cap);
      } else {
        out[c.id] = c.slug == 'v_ray'
            ? (headsets: 16, consoles: 2, capacity: 12)
            : (headsets: 4, consoles: 2, capacity: 6);
      }
    }
    return out;
  }

  Widget _divider() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 22),
        child: Divider(height: 1, color: BookingColors.borderFaint),
      );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text,
          style: const TextStyle(fontSize: 13, color: BookingColors.textFaint)),
    );
  }
}
