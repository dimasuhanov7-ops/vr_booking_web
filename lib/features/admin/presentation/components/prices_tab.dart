import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/config/booking_config.dart';
import '../../domain/entity/admin_club_entity.dart';
import '../../domain/entity/hall_price_entity.dart';
import '../../domain/state/admin_bloc.dart';
import '../admin_format.dart';
import '../admin_theme.dart';
import 'admin_atoms.dart';

/// Вкладка «Цены» — тарифы клуба и превью длительности.
///
/// В БД цены заданы на клуб, а не на зал, поэтому карточка одна. Раньше
/// показывалось по карточке на зал с одинаковыми полями: правка одной молча
/// меняла другую, и было непонятно, что к чему относится.
class PricesTab extends StatelessWidget {
  /// Создаёт вкладку.
  const PricesTab({required this.state, required this.accent, super.key});

  /// Состояние.
  final AdminState state;

  /// Акцент клуба.
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final AdminBloc bloc = context.read<AdminBloc>();
    final List<AdminHallEntity> halls = state.clubHalls;
    final String hallId = halls.first.id;
    final HallPriceEntity price = state.priceOf(hallId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ClubPriceCard(
          clubId: state.clubId,
          clubName: state.club.name,
          halls: halls,
          price: price,
          onChanged: (PriceField f, int v) => bloc.add(
            AdminPriceChanged(hallId: hallId, field: f, value: v),
          ),
        ),
        const SizedBox(height: 14),
        _DurationPreview(price: price),
      ],
    );
  }
}

class _ClubPriceCard extends StatelessWidget {
  const _ClubPriceCard({
    required this.clubId,
    required this.clubName,
    required this.halls,
    required this.price,
    required this.onChanged,
  });

  final String clubId;
  final String clubName;
  final List<AdminHallEntity> halls;
  final HallPriceEntity price;
  final void Function(PriceField, int) onChanged;

  @override
  Widget build(BuildContext context) {
    final bool hasPs5 = halls.any((AdminHallEntity h) => h.consoles > 0);
    final List<_PriceRow> rows = <_PriceRow>[
      _PriceRow('VR-шлем', 'за 1 час, одна станция', PriceField.vrWeekday,
          PriceField.vrWeekend),
      if (hasPs5)
        _PriceRow('PS5', 'за 1 час, одна приставка', PriceField.ps5Weekday,
            PriceField.ps5Weekend),
    ];

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AdminCardTitle(
            'Тарифы $clubName',
            subtitle: halls.length > 1
                ? 'Одна цена для всех залов: ${halls.map(_hallLabel).join(' · ')}.'
                : _hallLabel(halls.first),
          ),
          const SizedBox(height: 16),
          Row(
            children: const <Widget>[
              Expanded(child: SizedBox()),
              SizedBox(width: 96, child: Center(child: AdminLabel('будни'))),
              SizedBox(width: 10),
              SizedBox(width: 96, child: Center(child: AdminLabel('выходные'))),
            ],
          ),
          for (final _PriceRow r in rows)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(r.label,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        Text(r.sub,
                            style: const TextStyle(fontSize: 12, color: AdminColors.textFaint)),
                      ],
                    ),
                  ),
                  // Ключ по клубу: без него при переключении клуба поле
                  // оставалось со значением предыдущего клуба.
                  _PriceInput(
                    key: ValueKey<String>('$clubId-${r.weekday.name}'),
                    value: price.value(r.weekday),
                    onChanged: (int v) => onChanged(r.weekday, v),
                  ),
                  const SizedBox(width: 10),
                  _PriceInput(
                    key: ValueKey<String>('$clubId-${r.weekend.name}'),
                    value: price.value(r.weekend),
                    onChanged: (int v) => onChanged(r.weekend, v),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            'Выходные — суббота и воскресенье. Рубли за час. '
            'Сохраняется само через секунду после ввода.',
            style: TextStyle(fontSize: 12, height: 1.4, color: AdminColors.textLabel),
          ),
        ],
      ),
    );
  }

  static String _hallLabel(AdminHallEntity h) =>
      '${h.name} — ${AdminFormat.helmets(h.headsets)}'
      '${h.consoles > 0 ? ' и ${h.consoles} PS5' : ''}';
}

class _PriceRow {
  _PriceRow(this.label, this.sub, this.weekday, this.weekend);

  final String label;
  final String sub;
  final PriceField weekday;
  final PriceField weekend;
}

class _PriceInput extends StatefulWidget {
  const _PriceInput({required this.value, required this.onChanged, super.key});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_PriceInput> createState() => _PriceInputState();
}

class _PriceInputState extends State<_PriceInput> {
  late final TextEditingController _c =
      TextEditingController(text: widget.value.toString());
  final FocusNode _focus = FocusNode();

  @override
  void didUpdateWidget(covariant _PriceInput old) {
    super.didUpdateWidget(old);
    final String v = widget.value.toString();
    if (!_focus.hasFocus && v != _c.text) _c.text = v;
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: TextField(
        controller: _c,
        focusNode: _focus,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.right,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          filled: true,
          fillColor: AdminColors.input,
          border: _b,
          enabledBorder: _b,
          focusedBorder: _b,
        ),
        onChanged: (String s) {
          final int? n = int.tryParse(s);
          if (n != null) widget.onChanged(n);
        },
      ),
    );
  }

  OutlineInputBorder get _b => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AdminColors.borderInput),
      );
}

class _DurationPreview extends StatelessWidget {
  const _DurationPreview({required this.price});

  final HallPriceEntity price;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const AdminCardTitle(
            'Расчёт длительности',
            subtitle:
                'Цена указана за 1 час на одну станцию. Так виджет посчитает остальные сеансы:',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              for (final int m in BookingConfig.sessionDurations)
                Container(
                  constraints: const BoxConstraints(minWidth: 132),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AdminColors.tile,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: AdminColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text('${m ~/ 60} ч · один шлем',
                          style: const TextStyle(fontSize: 12, color: AdminColors.textFaint)),
                      const SizedBox(height: 4),
                      Text(
                        AdminFormat.money(price.vrWeekday * m / 60),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text('выходные — ${AdminFormat.money(price.vrWeekend * m / 60)}',
                          style: const TextStyle(fontSize: 11, color: AdminColors.textLabel)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
