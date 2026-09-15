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
                'Фиксированная цена за компанию и время вместо расчёта по часам. '
                'Пакеты свои у каждого клуба и зала — состав ограничен вместимостью. '
                'Изменения сохраняются сами.',
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
                border: Border.all(color: const Color(0xFF26282F)),
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
                    key: ValueKey<String>(p.id),
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
                      problem: bloc.packageProblem(p),
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
    required this.problem,
    required this.accent,
    required this.tint,
    required this.bloc,
  });

  final PackageEntity pack;
  final AdminHallEntity hall;
  final int hourly;
  final String? problem;
  final Color accent;
  final Color tint;
  final AdminBloc bloc;

  @override
  Widget build(BuildContext context) {
    final int save = hourly - pack.price;
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
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: pack.isEnabled ? AdminColors.tile : AdminColors.tileMuted,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: problem != null
                ? AdminColors.dangerBorder
                : pack.isEnabled
                    ? AdminColors.border
                    : AdminColors.rowDivider,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(pack.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(
              '${hall.name} · ${composition.isEmpty ? 'без станций' : composition} · ${pack.minutes ~/ 60} ч'
              '${pack.isEnabled ? '' : ' · выключен'}',
              style: const TextStyle(fontSize: 12, color: AdminColors.textFaint),
            ),
            const SizedBox(height: 3),
            Text(comp,
                style: TextStyle(
                    fontSize: 12, color: save > 0 ? tint : AdminColors.textFaint)),
            if (problem != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('$problem Изменения не сохраняются.',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AdminColors.danger)),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: <Widget>[
                for (final (String, PackageField, double) f in const <(String, PackageField, double)>[
                  ('шлемов', PackageField.headsets, 78),
                  ('PS5', PackageField.consoles, 70),
                  ('₽ за пакет', PackageField.price, 104),
                ])
                  AdminNumberField(
                    label: f.$1,
                    value: pack.value(f.$2),
                    width: f.$3,
                    onChanged: (int v) => bloc.add(AdminPackageFieldChanged(
                        packageId: pack.id, field: f.$2, value: v)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _MinutesPicker(
              value: pack.minutes,
              accent: accent,
              onSelected: (int m) => bloc.add(AdminPackageFieldChanged(
                  packageId: pack.id, field: PackageField.minutes, value: m)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _TogglePill(pack: pack, accent: accent, tint: tint, bloc: bloc),
                AdminGhostButton(
                  label: 'Удалить',
                  tone: AdminButtonTone.danger,
                  onTap: () async {
                    final bool ok = await confirmAdminAction(
                      context,
                      title: 'Удалить пакет «${pack.name}»?',
                      message: 'Пакет пропадёт из виджета навсегда. Уже созданные '
                          'брони останутся. Если убрать его на время — лучше «Выключить».',
                      confirmLabel: 'Удалить',
                    );
                    if (ok) bloc.add(AdminPackageDeleted(pack.id));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Длительность пакета — только из разрешённых (в БД ограничение 1–5 ч).
/// Свободное числовое поле пропускало «90» или «12» при наборе «120».
class _MinutesPicker extends StatelessWidget {
  const _MinutesPicker({
    required this.value,
    required this.accent,
    required this.onSelected,
  });

  final int value;
  final Color accent;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(bottom: 5),
          child: Text('длительность',
              style: TextStyle(fontSize: 11, color: AdminColors.textLabel)),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            for (final int m in AdminState.durations)
              AdminPill(
                label: '${m ~/ 60} ч',
                selected: m == value,
                accent: accent,
                compact: true,
                onTap: () => onSelected(m),
              ),
          ],
        ),
      ],
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
        const Text('Новый пакет',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: _NameField(
            initial: d.name,
            onChanged: (String v) => bloc.add(AdminNewPackageChanged(name: v)),
          ),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.only(bottom: 5),
          child: Text('зал', style: TextStyle(fontSize: 11, color: AdminColors.textLabel)),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            for (final AdminHallEntity h in state.clubHalls)
              AdminPill(
                label: h.name,
                selected: state.newPackageHallId == h.id,
                accent: accent,
                compact: true,
                onTap: () => bloc.add(AdminNewPackageChanged(hallId: h.id)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: <Widget>[
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
              label: 'цена, ₽',
              value: d.price,
              width: 106,
              onChanged: (int v) => bloc.add(AdminNewPackageChanged(price: v)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _MinutesPicker(
          value: d.minutes,
          accent: accent,
          onSelected: (int m) => bloc.add(AdminNewPackageChanged(minutes: m)),
        ),
        const SizedBox(height: 14),
        InkWell(
          onTap: ok ? () => bloc.add(const AdminNewPackageSubmitted()) : null,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: ok ? accent : const Color(0xFF22242A),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text('Добавить пакет',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ok ? AdminColors.bg : AdminColors.textFaint)),
          ),
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
        hintText: 'Название, например «Выпускной»',
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
