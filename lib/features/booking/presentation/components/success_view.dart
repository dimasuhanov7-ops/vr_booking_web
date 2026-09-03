import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entity/club_entity.dart';
import '../../domain/entity/hall_option_entity.dart';
import '../../domain/entity/quote_entity.dart';
import '../../domain/entity/time_slot_entity.dart';
import '../booking_format.dart';

/// Экран успешной брони — чек с деталями.
class SuccessView extends StatelessWidget {
  /// Создаёт экран успеха.
  const SuccessView({
    required this.orderId,
    required this.club,
    required this.hall,
    required this.slot,
    required this.durationMinutes,
    required this.quote,
    required this.peopleLabel,
    required this.contact,
    required this.onRestart,
    super.key,
  });

  /// Идентификатор брони.
  final String orderId;

  /// Клуб.
  final ClubEntity club;

  /// Зал.
  final HallOptionEntity hall;

  /// Слот.
  final TimeSlotEntity slot;

  /// Длительность, минут.
  final int durationMinutes;

  /// Расчёт.
  final QuoteEntity quote;

  /// «на 5 человек».
  final String peopleLabel;

  /// Контакт клиента.
  final String contact;

  /// «Забронировать ещё сеанс».
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final Color accent = BookingColors.accentFor(club.slug);
    final String no = 'VR-${orderId.replaceAll(RegExp('[^0-9a-fA-F]'), '').substring(0, 6).toUpperCase()}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.check, color: BookingColors.bg, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('Бронь подтверждена',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                    Text('Номер $no · ждём вас',
                        style: const TextStyle(fontSize: 13, color: BookingColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: BookingColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: BookingColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _section('Где и когда', <Widget>[
                  Text('${club.name} · ${hall.name}',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    '${_cap(BookingFormat.dayLong(BookingFormat.wallDay(club, slot.startsAt)))}, '
                    '${BookingFormat.range(club, slot.startsAt, slot.endsAt)} · '
                    '${BookingFormat.duration(durationMinutes)}',
                    style: const TextStyle(fontSize: 15, color: BookingColors.textSoft),
                  ),
                ]),
                _dash(),
                _section('Забронировано', <Widget>[
                  for (final QuoteLineEntity l in quote.lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: <Widget>[
                          Expanded(child: Text(l.label, style: const TextStyle(fontSize: 15))),
                          Text(BookingFormat.money(l.price),
                              style: const TextStyle(fontSize: 15, color: BookingColors.textMuted)),
                        ],
                      ),
                    ),
                  Text('На $peopleLabel — по одному человеку на станцию, можно меняться внутри компании.',
                      style: const TextStyle(fontSize: 13, color: BookingColors.textMuted)),
                ]),
                if (quote.hasDiscount) ...<Widget>[
                  _dash(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    color: accent.withValues(alpha: 0.12),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(quote.discountLabel,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: BookingColors.accentTintFor(club.slug))),
                        ),
                        Text('−${BookingFormat.money(quote.discountAmount)}',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: BookingColors.accentTintFor(club.slug))),
                      ],
                    ),
                  ),
                ],
                _dash(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('К ОПЛАТЕ НА МЕСТЕ',
                                style: TextStyle(
                                    fontSize: 11,
                                    letterSpacing: 1.2,
                                    color: BookingColors.textFaint)),
                            SizedBox(height: 4),
                            Text('наличными или картой в клубе',
                                style: TextStyle(fontSize: 12, color: BookingColors.textMuted)),
                          ],
                        ),
                      ),
                      Text(BookingFormat.money(quote.net),
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: BookingColors.border),
            ),
            child: Text(
              'Придите за 10 минут до начала — инструктаж и настройка шлемов входят в сеанс. Контакт для связи: $contact.',
              style: const TextStyle(fontSize: 13, height: 1.5, color: BookingColors.textMuted),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: InkWell(
              onTap: onRestart,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BookingColors.border),
                ),
                child: const Text('Забронировать ещё сеанс',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: BookingColors.textSoft)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String label, List<Widget> children) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(label.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 11, letterSpacing: 1.2, color: BookingColors.textFaint)),
            ),
            ...children,
          ],
        ),
      );

  Widget _dash() => const DashedDivider();

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// Пунктирный разделитель чека.
class DashedDivider extends StatelessWidget {
  /// Создаёт разделитель.
  const DashedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final int count = (c.maxWidth / 6).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List<Widget>.generate(
            count,
            (_) => Container(width: 3, height: 1, color: BookingColors.border),
          ),
        );
      },
    );
  }
}
