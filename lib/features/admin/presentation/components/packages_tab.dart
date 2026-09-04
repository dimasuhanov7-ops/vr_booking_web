import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/admin_club_entity.dart';
import '../../domain/entity/package_entity.dart';
import '../../domain/service/admin_pricing_service.dart';
import '../../domain/state/admin_bloc.dart';
import '../admin_format.dart';
import '../admin_theme.dart';
import 'admin_atoms.dart';

/// Вкладка «Пакеты».
class PackagesTab extends StatelessWidget {
  /// Создаёт вкладку.
  const PackagesTab({
    required this.state,
    required this.accent,
    this.pricing = const AdminPricingService(),
    super.key,
  });

  /// Состояние.
  final AdminState state;

  /// Акцент клуба.
  final Color accent;

  /// Сервис расчётов.
  final AdminPricingService pricing;

  @override
  Widget build(BuildContext context) {
    final AdminBloc bloc = context.read<AdminBloc>();
    final List<PackageEntity> packs = state.clubPackages;
    final Color tint = AdminColors.tintFor(state.accentSlug);

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const AdminCardTitle(
            'Пакеты',
            subtitle:
                'Фиксированная цена за компанию и время вместо расчёта по часам. Пакеты свои у каждого клуба и зала — состав ограничен вместимостью.',
          ),
          const SizedBox(height: 12),
          Text(
            state.clubHalls
                .map((AdminHallEntity h) =>
                    '${h.name} — ${AdminFormat.helmets(h.headsets)}${h.consoles > 0 ? ' и ${h.consoles} PS5' : ', без PS5'}')
                .join(' · '),
            style: const TextStyle(fontSize: 12, color: AdminColors.textFaint),
          ),
          const SizedBox(height: 16),
          if (packs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF26282F), style: BorderStyle.solid),
              ),
              child: const Text('У этого клуба пока нет пакетов.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AdminColors.textMuted)),
            )
          else
            Column(
              children: <Widget>[
                for (final PackageEntity p in packs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PackCard(
                      pack: p,
                      hall: state.clubHalls.firstWhere(
                        (AdminHallEntity h) => h.id == p.hallId,
                        orElse: () => state.clubHalls.first,
                      ),
                      hourly: pricing.packageHourly(
                        pkg: p,
                        price: state.priceOf(p.hallId),
                      ),
                      accent: accent,
                      tint: tint,
                      bloc: bloc,
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AdminColors.divider),
          const SizedBox(height: 16),
          _AddForm(state: state, accent: accent, tint: tint, bloc: bloc),
        ],
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.pack,
    required this.hall,
    required this.hourly,
    required this.accent,
    required this.tint,
    required this.bloc,
  });

  final PackageEntity pack;
  final AdminHallEntity hall;
  final int hourly;
  final Color accent;
  final Color tint;
  final AdminBloc bloc;

  @override
  Widget build(BuildContext context) {
    final int save = hourly - pack.price;
    final bool over = pack.headsets > hall.headsets || pack.consoles > hall.consoles;
    final String comp = save > 0
        ? 'по часам вышло бы ${AdminFormat.money(hourly)}'
        : save < 0
            ? 'дороже почасовой на ${AdminFormat.money(-save)}'
            : 'равно почасовой цене';
    final String composition = <String>[
      if (pack.headsets > 0) AdminFormat.helmets(pack.headsets),
      if (pack.consoles > 0) '${pack.consoles} PS5',
    ].join(' + ');

    return Opacity(
      opacity: pack.isEnabled ? 1 : 0.55,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: pack.isEnabled ? AdminColors.tile : AdminColors.tileMuted,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: pack.isEnabled ? AdminColors.border : AdminColors.rowDivider,
          ),
        ),
        child: Wrap(
          spacing: 14,
          runSpacing: 14,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(pack.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${hall.name} · $composition · ${pack.minutes ~/ 60} ч',
                  style: const TextStyle(fontSize: 12, color: AdminColors.textFaint),
                ),
                const SizedBox(height: 3),
                Text(comp,
                    style: TextStyle(
                        fontSize: 12,
                        color: save > 0 ? tint : AdminColors.textFaint)),
                if (over)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Не вмещается в зал',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AdminColors.danger)),
                  ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: <Widget>[
                for (final (String, PackageField, double) f in const <(String, PackageField, double)>[
                  ('шлемов', PackageField.headsets, 78),
                  ('PS5', PackageField.consoles, 70),
                  ('минут', PackageField.minutes, 84),
                  ('₽ за пакет', PackageField.price, 104),
                ])
                  AdminNumberField(
                    label: f.$1,
                    value: pack.value(f.$2),
                    width: f.$3,
                    onChanged: (int v) => bloc.add(AdminPackageFieldChanged(
                        packageId: pack.id, field: f.$2, value: v)),
                  ),
                _TogglePill(pack: pack, accent: accent, tint: tint, bloc: bloc),
                AdminGhostButton(
                  label: 'Удалить',
                  onTap: () => bloc.add(AdminPackageDeleted(pack.id)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TogglePill extends StatelessWidget {
  const _TogglePill({
    required this.pack,
    required this.accent,
    required this.tint,
    required this.bloc,
  });

  final PackageEntity pack;
  final Color accent;
  final Color tint;
  final AdminBloc bloc;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => bloc.add(AdminPackageToggled(pack.id)),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: pack.isEnabled ? Colors.transparent : accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: pack.isEnabled ? AdminColors.borderInput : accent),
        ),
        child: Text(
          pack.isEnabled ? 'Выключить' : 'Включить',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: pack.isEnabled ? AdminColors.textSoft : tint,
          ),
        ),
      ),
    );
  }
}

class _AddForm extends StatelessWidget {
  const _AddForm({
    required this.state,
    required this.accent,
    required this.tint,
    required this.bloc,
  });

  final AdminState state;
  final Color accent;
  final Color tint;
  final AdminBloc bloc;

  @override
  Widget build(BuildContext context) {
    final NewPackageDraft d = state.newPackage;
    final bool ok = d.isValid;
    final Color msgColor = d.message.contains('добавлен')
        ? tint
        : const Color(0xFFFFB020);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: <Widget>[
            SizedBox(
              width: 220,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text('Новый пакет',
                        style: TextStyle(fontSize: 12, color: AdminColors.textMuted)),
                  ),
                  _NameField(
                    initial: d.name,
                    onChanged: (String v) => bloc.add(AdminNewPackageChanged(name: v)),
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
                  child: Text('зал',
                      style: TextStyle(fontSize: 12, color: AdminColors.textMuted)),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final AdminHallEntity h in state.clubHalls)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: AdminPill(
                          label: h.name,
                          selected: state.newPackageHallId == h.id,
                          accent: accent,
                          onTap: () => bloc.add(AdminNewPackageChanged(hallId: h.id)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            AdminNumberField(
              label: 'шлемов',
              value: d.headsets,
              width: 86,
              onChanged: (int v) => bloc.add(AdminNewPackageChanged(headsets: v)),
            ),
            AdminNumberField(
              label: 'PS5',
              value: d.consoles,
              width: 86,
              onChanged: (int v) => bloc.add(AdminNewPackageChanged(consoles: v)),
            ),
            AdminNumberField(
              label: 'минут',
              value: d.minutes,
              width: 86,
              onChanged: (int v) => bloc.add(AdminNewPackageChanged(minutes: v)),
            ),
            AdminNumberField(
              label: 'цена, ₽',
              value: d.price,
              width: 106,
              onChanged: (int v) => bloc.add(AdminNewPackageChanged(price: v)),
            ),
            InkWell(
              onTap: ok ? () => bloc.add(const AdminNewPackageSubmitted()) : null,
              borderRadius: BorderRadius.circular(11),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: ok ? accent : const Color(0xFF22242A),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text('Добавить',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ok ? AdminColors.bg : AdminColors.textFaint)),
              ),
            ),
          ],
        ),
        if (d.message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(d.message,
                style: TextStyle(fontSize: 12, color: msgColor)),
          ),
      ],
    );
  }
}

class _NameField extends StatefulWidget {
  const _NameField({required this.initial, required this.onChanged});

  final String initial;
  final ValueChanged<String> onChanged;

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);

  @override
  void didUpdateWidget(covariant _NameField old) {
    super.didUpdateWidget(old);
    if (widget.initial != _c.text && !_c.selection.isValid) _c.text = widget.initial;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      inputFormatters: <TextInputFormatter>[LengthLimitingTextInputFormatter(40)],
      style: const TextStyle(fontSize: 15, color: AdminColors.text),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Например, Выпускной',
        hintStyle: const TextStyle(color: AdminColors.textLabel),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        filled: true,
        fillColor: AdminColors.input,
        border: _b,
        enabledBorder: _b,
        focusedBorder: _b,
      ),
      onChanged: widget.onChanged,
    );
  }

  OutlineInputBorder get _b => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AdminColors.borderInput),
      );
}
