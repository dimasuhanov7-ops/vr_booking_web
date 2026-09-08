import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/config/booking_config.dart';
import '../../../../app/embed/nav.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entity/club_entity.dart';
import '../../domain/entity/hall_option_entity.dart';
import '../../domain/entity/package_entity.dart';
import '../../domain/entity/price_rate_entity.dart';
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
import '../components/account_block.dart';
import '../components/hall_plan.dart';
import '../components/hall_selector.dart';
import '../components/package_cards.dart';
import '../components/slot_grid.dart';
import '../components/success_view.dart';

/// Порог перехода на двухколоночную раскладку (десктоп/планшет), CSS-px.
const double _wideBreakpoint = 860;

/// Максимальная ширина «рамки» виджета для узкой и широкой раскладки.
const double _frameNarrow = 460;
const double _frameWide = 1000;

/// Ширина левой (sticky в макете) колонки на широкой раскладке.
const double _leftColWidth = 360;

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
        // Ширина области виджета (в iframe — размер фрейма, заданный родителем).
        final double vw = MediaQuery.sizeOf(context).width;
        final bool wide = vw >= _wideBreakpoint;
        final double frameW = wide ? _frameWide : _frameNarrow;

        final bool bootstrapping = (state.status == BookingStatus.loading &&
                state.clubs.isEmpty) ||
            (state.clubLocked && state.club == null &&
                state.status != BookingStatus.failure);
        if (bootstrapping) {
          // Высокий плейсхолдер: iframe не «схлопывается» на время загрузки
          // (см. docs/EMBED.md — сообщения vr-booking:height).
          return _Frame(
            maxWidth: frameW,
            child: const SizedBox(
              height: 420,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (state.status == BookingStatus.failure && state.clubs.isEmpty) {
          return _Frame(
            maxWidth: frameW,
            child: _Retry(onRetry: () =>
                context.read<BookingBloc>().add(const BookingStarted())),
          );
        }

        final Color accent = BookingColors.accentFor(state.club?.slug);

        if (state.view == BookingStage.done && state.createdOrderId != null) {
          return _Frame(
            maxWidth: frameW,
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
          maxWidth: frameW,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.fromLTRB(wide ? 24 : 18, 22, wide ? 24 : 18, 26),
                child: _FormBody(state: state, accent: accent, wide: wide),
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
  const _Frame({required this.child, this.maxWidth = _frameNarrow});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
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

/// Незаметный служебный вход: долгое нажатие на точку в углу → пароль → админка.
/// Заслон от случайных заходов; в боевой сборке админку защищает Supabase Auth.
class _AdminDoor extends StatelessWidget {
  const _AdminDoor();

  Future<void> _open(BuildContext context) async {
    final TextEditingController c = TextEditingController();
    final String? entered = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: BookingColors.frame,
        title: const Text('Служебный вход', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: c,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Пароль'),
          onSubmitted: (String v) => Navigator.of(ctx).pop(v),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(c.text),
              child: const Text('Войти')),
        ],
      ),
    );
    c.dispose();
    if (entered == null) return;
    if (entered == BookingConfig.adminGate) {
      Nav.toAdmin();
    } else if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Неверный пароль')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _open(context),
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Opacity(
          opacity: 0.3,
          child: SizedBox(
            width: 5,
            height: 5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: BookingColors.textFaint,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormBody extends StatelessWidget {
  const _FormBody({
    required this.state,
    required this.accent,
    required this.wide,
  });

  final BookingState state;
  final Color accent;

  /// Двухколоночная раскладка (десктоп/планшет).
  final bool wide;

  BookingBloc _bloc(BuildContext c) => c.read<BookingBloc>();

  @override
  Widget build(BuildContext context) {
    final BookingBloc bloc = _bloc(context);
    final ClubEntity? club = state.club;

    // Левая колонка: клуб + зал + дата. Правая: длительность/время + план + контакты.
    final List<List<Widget>> left = <List<Widget>>[
      if (!state.clubLocked) _clubBlock(bloc),
      if (club != null && state.hallOptions.length > 1) _hallBlock(bloc),
      if (club != null) _dateBlock(bloc),
    ];
    final List<List<Widget>> right = <List<Widget>>[
      if (club != null) _whenBlock(bloc, club),
      if (state.slot != null && state.hall != null) _planBlock(bloc, club!),
      if (state.pickedIds.isNotEmpty) _contactsBlock(bloc),
    ];
    if (wide && club == null) right.add(<Widget>[_idlePlaceholder()]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        BookingProgress(
          step: state.stepNo,
          steps: state.stepCount,
          accent: accent,
        ),
        const SizedBox(height: 18),
        AccountBlock(
          account: state.account,
          myBookings: state.myBookings,
          loginOpen: state.accountLoginOpen,
          loginPhone: state.accountLoginPhone,
          listOpen: state.accountListOpen,
          accent: accent,
          onPrimary: () => bloc.add(state.account != null
              ? const BookingAccountListToggled()
              : const BookingAccountLoginToggled()),
          onLogout: () => bloc.add(const BookingAccountLoggedOut()),
          onLoginPhoneChanged: (String v) =>
              bloc.add(BookingAccountLoginPhoneChanged(v)),
          onLoginSubmit: () => bloc.add(const BookingAccountLoginSubmitted()),
        ),
        const SizedBox(height: 20),
        if (state.conflictShown) ...<Widget>[
          _conflict(bloc),
          const SizedBox(height: 4),
        ],
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: _leftColWidth,
                child: _stack(left, gap: 24),
              ),
              const SizedBox(width: 28),
              Expanded(child: _stack(right, gap: 24)),
            ],
          )
        else
          _stack(<List<Widget>>[...left, ...right], divided: true),
        const SizedBox(height: 10),
        const Align(alignment: Alignment.centerRight, child: _AdminDoor()),
      ],
    );
  }

  /// Собирает непустые блоки в колонку, разделяя их либо линией (узкая
  /// раскладка), либо отступом.
  Widget _stack(
    List<List<Widget>> blocks, {
    double gap = 20,
    bool divided = false,
  }) {
    final List<List<Widget>> parts =
        blocks.where((List<Widget> b) => b.isNotEmpty).toList();
    final List<Widget> out = <Widget>[];
    for (int i = 0; i < parts.length; i++) {
      if (i > 0) {
        out.add(divided ? _divider() : SizedBox(height: gap));
      }
      out.addAll(parts[i]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: out);
  }

  List<Widget> _clubBlock(BookingBloc bloc) => <Widget>[
        ClubSelector(
          clubs: state.clubs,
          stationsByClub: _kits(),
          selectedClubId: state.club?.id,
          onSelected: (ClubEntity c) => bloc.add(BookingClubSelected(c)),
        ),
      ];

  List<Widget> _hallBlock(BookingBloc bloc) => <Widget>[
        const SectionLabel('Зал'),
        const SizedBox(height: 10),
        HallSelector(
          options: state.hallOptions,
          selectedId: state.hall?.id,
          accent: accent,
          onSelected: (HallOptionEntity h) => bloc.add(BookingHallSelected(h)),
        ),
      ];

  DayKind get _dayKind => DayKind.of(state.date ?? DateTime.now());

  bool get _weekend => _dayKind == DayKind.weekend;

  num _ratePerHour(StationType type) {
    for (final PriceRateEntity r in state.prices) {
      if (r.stationType == type && r.dayKind == _dayKind) return r.pricePerHour;
    }
    return 0;
  }

  List<Widget> _dateBlock(BookingBloc bloc) => <Widget>[
        FieldCard(
          label: 'Дата',
          trailing: _weekend ? 'тариф выходного дня' : 'тариф будних дней',
          child: DateField(
            date: state.date ?? DateTime.now(),
            accent: accent,
            daysAhead: BookingConfig.bookingHorizonDays,
            tariffNote: _weekend ? 'тариф выходного дня' : 'тариф будней',
            onSelected: (DateTime d) => bloc.add(BookingDateSelected(d)),
          ),
        ),
      ];

  List<Widget> _whenBlock(BookingBloc bloc, ClubEntity club) {
    final String durLabel = BookingFormat.duration(state.durationMinutes);
    final double hrs = state.durationMinutes / 60;
    final bool showPs = state.hall == null || state.hall!.consoles > 0;
    final List<({String label, String price})> rateLines = <({String label, String price})>[
      (
        label: '1 VR-шлем · $durLabel',
        price: BookingFormat.money((_ratePerHour(StationType.vrHeadset) * hrs).round()),
      ),
      if (showPs)
        (
          label: '1 PS5 · $durLabel',
          price: BookingFormat.money((_ratePerHour(StationType.ps5) * hrs).round()),
        ),
    ];

    return <Widget>[
      FieldCard(
        label: 'Длительность сеанса',
        trailing: 'целыми часами',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DurationSelector(
              options: BookingBloc.durations,
              selected: state.durationMinutes,
              accent: accent,
              onSelected: (int m) => bloc.add(BookingDurationSelected(m)),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: BookingColors.borderSoft),
            const SizedBox(height: 12),
            for (final ({String label, String price}) r in rateLines)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(r.label,
                          style: const TextStyle(fontSize: 13, color: BookingColors.textSoft)),
                    ),
                    Text(r.price,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            fontFeatures: <FontFeature>[FontFeature.tabularFigures()])),
                  ],
                ),
              ),
            const SizedBox(height: 2),
            Text(
              'Цена за одно место. Итог за компанию считается по числу выбранных '
              'шлемов и PS5 и виден внизу до подтверждения. '
              '${_weekend ? 'Тариф выходного дня.' : 'Тариф будних дней.'}',
              style: const TextStyle(fontSize: 12, height: 1.4, color: BookingColors.textDim),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Row(
        children: <Widget>[
          const Expanded(child: SectionLabel('Время начала', big: true)),
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
    ];
  }

  List<Widget> _planBlock(BookingBloc bloc, ClubEntity club) {
    final double vrRate = _ratePerHour(StationType.vrHeadset).toDouble();
    final double psRate = _ratePerHour(StationType.ps5).toDouble();
    final List<PackageRow> packRows = <PackageRow>[
      for (final PackageEntity p in state.hallPackages)
        (
          package: p,
          ok: state.packageFit(p).ok,
          reason: state.packageFit(p).reason,
          hourly: ((vrRate * p.headsets + psRate * p.consoles) * p.minutes / 60).round(),
        ),
    ];

    return <Widget>[
      SectionLabel(
          'План зала · ${BookingFormat.range(club, state.slot!.startsAt, state.slot!.endsAt)}'),
      const SizedBox(height: 6),
      Text(
        'Свободно ${state.freeHallStations.length} из ${state.hallCapacity} · выбрано ${state.pickedIds.length}',
        style: const TextStyle(fontSize: 14, color: BookingColors.textSoft),
      ),
      const SizedBox(height: 14),
      if (packRows.isNotEmpty) ...<Widget>[
        const SectionLabel('Пакеты'),
        const SizedBox(height: 10),
        PackageCards(
          rows: packRows,
          selectedId: state.selectedPackageId,
          accent: accent,
          onSelected: (PackageEntity? p) => bloc.add(BookingPackageSelected(p)),
        ),
        const SizedBox(height: 16),
      ],
      HallPlan(
        stations: state.hallStations,
        isFree: state.isFree,
        pickedIds: state.pickedIds,
        takenIds: state.takenIds,
        isCombo: state.hall!.isCombo,
        accent: accent,
        freeCount: state.freeHallStations.length,
        quickLabel: packRows.isNotEmpty ? 'Или по часам:' : 'Взять сразу:',
        onToggle: (String id) => bloc.add(BookingStationToggled(id)),
        onQuickPick: (int n) => bloc.add(BookingQuickPicked(n)),
        onClear: () => bloc.add(const BookingSelectionCleared()),
      ),
    ];
  }

  List<Widget> _contactsBlock(BookingBloc bloc) => <Widget>[
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
      ];

  Widget _idlePlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: BoxDecoration(
        color: BookingColors.fieldSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BookingColors.border),
      ),
      child: const Column(
        children: <Widget>[
          Text('Начните с клуба',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          SizedBox(height: 6),
          Text(
            'Выберите клуб слева — дата, длительность и свободное время появятся здесь.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.5, color: BookingColors.textMuted),
          ),
        ],
      ),
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
      // «Другой клуб» — только когда клуб не зафиксирован через ?club=.
      else if (!s.clubLocked && s.clubs.length > 1)
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
