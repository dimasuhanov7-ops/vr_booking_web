import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/promo_entity.dart';
import '../../domain/state/admin_bloc.dart';
import '../admin_theme.dart';
import 'admin_atoms.dart';

/// Карточка «Промокоды» во вкладке «Цены»: список кодов с включением и
/// удалением и форма нового кода. Коды общие для всех клубов.
class PromosCard extends StatelessWidget {
  /// Создаёт карточку.
  const PromosCard({required this.state, required this.accent, super.key});

  /// Состояние.
  final AdminState state;

  /// Акцент клуба.
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final AdminBloc bloc = context.read<AdminBloc>();
    final Color tint = AdminColors.tintFor(state.accentSlug);
    final DateTime now = DateTime.now().toUtc();

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const AdminCardTitle(
            'Промокоды',
            subtitle: 'Общие для всех клубов. Клиент вводит код в виджете, скидка '
                'считается от суммы брони или цены пакета; процент округляется до рубля.',
          ),
          const SizedBox(height: 16),
          if (state.promos.isEmpty)
            const Text('Промокодов пока нет.',
                style: TextStyle(fontSize: 14, color: AdminColors.textMuted))
          else
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AdminColors.border),
              ),
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < state.promos.length; i++)
                    _PromoRow(
                      promo: state.promos[i],
                      expired: state.promos[i].isExpiredAt(now),
                      first: i == 0,
                      accent: accent,
                      tint: tint,
                      bloc: bloc,
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AdminColors.divider),
          const SizedBox(height: 16),
          _AddForm(draft: state.newPromo, accent: accent, tint: tint, bloc: bloc),
        ],
      ),
    );
  }
}

class _PromoRow extends StatelessWidget {
  const _PromoRow({
    required this.promo,
    required this.expired,
    required this.first,
    required this.accent,
    required this.tint,
    required this.bloc,
  });

  final PromoEntity promo;
  final bool expired;
  final bool first;
  final Color accent;
  final Color tint;
  final AdminBloc bloc;

  @override
  Widget build(BuildContext context) {
    final bool live = promo.isActive && !expired;
    final String terms = <String>[
      if (promo.minStations > 1) 'от ${promo.minStations} мест',
      if (expired) 'срок истёк' else if (!promo.isActive) 'выключен',
    ].join(' · ');

    return Opacity(
      opacity: live ? 1 : 0.55,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: live ? AdminColors.tile : AdminColors.tileMuted,
          border: first
              ? null
              : const Border(top: BorderSide(color: AdminColors.rowDivider)),
        ),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(promo.code,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: AdminColors.text)),
                const SizedBox(width: 10),
                Text(promo.effectLabel,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: live ? tint : AdminColors.textFaint)),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (terms.isNotEmpty) ...<Widget>[
                  Text(terms,
                      style: const TextStyle(fontSize: 12, color: AdminColors.textFaint)),
                  const SizedBox(width: 12),
                ],
                AdminPill(
                  label: promo.isActive ? 'Выключить' : 'Включить',
                  selected: !promo.isActive,
                  accent: accent,
                  compact: true,
                  onTap: () => bloc.add(AdminPromoToggled(promo.id)),
                ),
                const SizedBox(width: 8),
                AdminGhostButton(
                  label: 'Удалить',
                  onTap: () => bloc.add(AdminPromoDeleted(promo.id)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddForm extends StatelessWidget {
  const _AddForm({
    required this.draft,
    required this.accent,
    required this.tint,
    required this.bloc,
  });

  final NewPromoDraft draft;
  final Color accent;
  final Color tint;
  final AdminBloc bloc;

  @override
  Widget build(BuildContext context) {
    final bool ok = draft.isValid;
    final bool percent = draft.kind == PromoKind.percent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: <Widget>[
            SizedBox(
              width: 200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text('Новый промокод',
                        style: TextStyle(fontSize: 12, color: AdminColors.textMuted)),
                  ),
                  _CodeField(
                    value: draft.code,
                    onChanged: (String v) => bloc.add(AdminNewPromoChanged(code: v)),
                    onSubmitted: ok ? () => bloc.add(const AdminNewPromoSubmitted()) : null,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text('скидка',
                      style: TextStyle(fontSize: 12, color: AdminColors.textMuted)),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    AdminPill(
                      label: '%',
                      selected: percent,
                      accent: accent,
                      onTap: () => bloc.add(const AdminNewPromoChanged(kind: PromoKind.percent)),
                    ),
                    const SizedBox(width: 6),
                    AdminPill(
                      label: '₽',
                      selected: !percent,
                      accent: accent,
                      onTap: () => bloc.add(const AdminNewPromoChanged(kind: PromoKind.fixed)),
                    ),
                  ],
                ),
              ],
            ),
            AdminNumberField(
              label: percent ? 'процент' : 'рублей',
              value: draft.value,
              width: 96,
              onChanged: (int v) => bloc.add(AdminNewPromoChanged(value: v)),
            ),
            AdminNumberField(
              label: 'от мест',
              value: draft.minStations,
              width: 80,
              onChanged: (int v) => bloc.add(AdminNewPromoChanged(minStations: v)),
            ),
            InkWell(
              onTap: ok ? () => bloc.add(const AdminNewPromoSubmitted()) : null,
              borderRadius: BorderRadius.circular(11),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: ok ? accent : const Color(0xFF22242A),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(draft.submitting ? 'Сохраняю…' : 'Добавить',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ok ? AdminColors.bg : AdminColors.textFaint)),
              ),
            ),
          ],
        ),
        if (draft.message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(draft.message,
                style: TextStyle(
                    fontSize: 12, color: draft.isError ? AdminColors.warn : tint)),
          ),
      ],
    );
  }
}

/// Поле кода: вводится заглавными, очищается после добавления.
class _CodeField extends StatefulWidget {
  const _CodeField({
    required this.value,
    required this.onChanged,
    required this.onSubmitted,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback? onSubmitted;

  @override
  State<_CodeField> createState() => _CodeFieldState();
}

class _CodeFieldState extends State<_CodeField> {
  late final TextEditingController _c = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _CodeField old) {
    super.didUpdateWidget(old);
    if (widget.value.isEmpty && _c.text.isNotEmpty) _c.clear();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final OutlineInputBorder b = OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: AdminColors.borderInput),
    );
    return TextField(
      controller: _c,
      textCapitalization: TextCapitalization.characters,
      inputFormatters: <TextInputFormatter>[
        LengthLimitingTextInputFormatter(32),
        FilteringTextInputFormatter.deny(RegExp(r'\s')),
      ],
      style: const TextStyle(
          fontSize: 15, letterSpacing: 0.6, color: AdminColors.text),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'VRPARTY',
        hintStyle: const TextStyle(color: AdminColors.textLabel),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        filled: true,
        fillColor: AdminColors.input,
        border: b,
        enabledBorder: b,
        focusedBorder: b,
      ),
      onChanged: widget.onChanged,
      onSubmitted: (_) => widget.onSubmitted?.call(),
    );
  }
}
