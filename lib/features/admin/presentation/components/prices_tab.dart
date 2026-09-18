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
          accent: accent,
          onChanged: (PriceField f, int v) => bloc.add(
            AdminPriceChanged(hallId: hallId, field: f, value: v),
          ),
          onTiers: (List<VrTierEntity> t) => bloc.add(AdminVrTiersChanged(t)),
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
    required this.accent,
    required this.onChanged,
    required this.onTiers,
  });

  final String clubId;
  final String clubName;
  final List<AdminHallEntity> halls;
  final HallPriceEntity price;
  final Color accent;
  final void Function(PriceField, int) onChanged;
  final ValueChanged<List<VrTierEntity>> onTiers;

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
          const SizedBox(height: 16),
          _VrTiers(
            clubId: clubId,
            price: price,
            maxHeadsets: halls.fold<int>(
                0, (int a, AdminHallEntity h) => h.headsets > a ? h.headsets : a),
            onChanged: onTiers,
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

/// Ступени цены шлемов: «от N штук — другая цена за место».
///
/// Цена ступени применяется ко всем шлемам сеанса сразу (решение заказчика):
/// 8 шлемов при ступени «от 6» считаются по её цене все восемь. Ступеней может
/// быть несколько — берётся самая высокая, до которой дотягивает компания.
class _VrTiers extends StatelessWidget {
  const _VrTiers({
    required this.clubId,
    required this.price,
    required this.maxHeadsets,
    required this.onChanged,
  });

  final String clubId;
  final HallPriceEntity price;
  final int maxHeadsets;
  final ValueChanged<List<VrTierEntity>> onChanged;

  /// Порог первой ступени по умолчанию — чуть больше половины зала.
  int get _suggested => maxHeadsets > 2 ? (maxHeadsets ~/ 2) + 1 : 2;

  List<VrTierEntity> get _tiers => price.vrTiers;

  /// Порог новой ступени — следующий за последним.
  int get _nextFrom => _tiers.isEmpty ? _suggested : _tiers.last.from + 1;

  void _replace(int i, VrTierEntity t) =>
      onChanged(<VrTierEntity>[..._tiers]..[i] = t);

  void _remove(int i) => onChanged(<VrTierEntity>[..._tiers]..removeAt(i));

  void _add() {
    // Цены новой ступени — как у предыдущей (или базовые): поле не должно
    // уйти в базу с нулём, а поправить цифру быстрее, чем набрать с нуля.
    final VrTierEntity? last = _tiers.isEmpty ? null : _tiers.last;
    onChanged(<VrTierEntity>[
      ..._tiers,
      VrTierEntity(
        from: _nextFrom,
        weekday: last?.weekday ?? price.vrWeekday,
        weekend: last?.weekend ?? price.vrWeekend,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final List<VrTierEntity> tiers = _tiers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Divider(height: 1, color: AdminColors.border),
        const SizedBox(height: 12),
        const Text('Дешевле за количество',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        Text(
          tiers.isEmpty
              ? 'сейчас одна цена при любом количестве шлемов'
              : 'цена ступени — за все шлемы сеанса; берётся самая высокая подходящая',
          style: const TextStyle(fontSize: 12, color: AdminColors.textFaint),
        ),
        for (int i = 0; i < tiers.length; i++) _row(i, tiers),
        const SizedBox(height: 12),
        if (_nextFrom <= maxHeadsets)
          AdminGhostButton(label: '+ Добавить ступень', onTap: _add)
        else
          Text(
            'Больше ступеней не поместится: порог уже равен числу шлемов '
            'в зале ($maxHeadsets).',
            style: const TextStyle(fontSize: 12, color: AdminColors.textFaint),
          ),
      ],
    );
  }

  Widget _row(int i, List<VrTierEntity> tiers) {
    final VrTierEntity t = tiers[i];
    // Пороги строго по возрастанию: ступень не может обогнать соседей.
    final int lo = i == 0 ? 2 : tiers[i - 1].from + 1;
    final int hi = i == tiers.length - 1 ? maxHeadsets : tiers[i + 1].from - 1;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('Ступень ${i + 1}',
                    style: const TextStyle(fontSize: 13, color: AdminColors.textMuted)),
              ),
              _Step(
                label: 'от ${t.from}',
                onMinus: t.from > lo
                    ? () => _replace(i, t.copyWith(from: t.from - 1))
                    : null,
                onPlus: t.from < hi
                    ? () => _replace(i, t.copyWith(from: t.from + 1))
                    : null,
              ),
              const SizedBox(width: 8),
              _StepButton(
                icon: Icons.delete_outline_rounded,
                onTap: () => _remove(i),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('VR-шлем от ${t.from} шт.',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const Text('за 1 час, одна станция',
                        style: TextStyle(fontSize: 12, color: AdminColors.textFaint)),
                  ],
                ),
              ),
              // Ключ с порогом: после «−/+» поле перечитывает значение ступени.
              _PriceInput(
                key: ValueKey<String>('$clubId-tier-$i-${t.from}-weekday'),
                value: t.weekday,
                onChanged: (int v) => _replace(i, t.copyWith(weekday: v)),
              ),
              const SizedBox(width: 10),
              _PriceInput(
                key: ValueKey<String>('$clubId-tier-$i-${t.from}-weekend'),
                value: t.weekend,
                onChanged: (int v) => _replace(i, t.copyWith(weekend: v)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Кнопки «−» и «+» вокруг значения порога.
class _Step extends StatelessWidget {
  const _Step({required this.label, this.onMinus, this.onPlus});

  final String label;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _StepButton(icon: Icons.remove_rounded, onTap: onMinus),
        SizedBox(
          width: 74,
          child: Text(
            '$label шт.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        _StepButton(icon: Icons.add_rounded, onTap: onPlus),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool on = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AdminColors.border),
        ),
        child: Icon(icon,
            size: 18,
            color: on ? AdminColors.text : AdminColors.textFaint),
      ),
    );
  }
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
