import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entity/admin_club_entity.dart';
import '../../domain/entity/audit_entry_entity.dart';
import '../../domain/service/audit_describer.dart';
import '../../domain/state/admin_bloc.dart';
import '../admin_format.dart';
import '../admin_theme.dart';
import 'admin_atoms.dart';

/// Вкладка «Журнал» — кто, когда и что менял в ценах, пакетах, доступности,
/// настройках клуба и статусах броней выбранного клуба.
class LogTab extends StatelessWidget {
  /// Создаёт вкладку.
  const LogTab({required this.state, super.key});

  /// Состояние.
  final AdminState state;

  @override
  Widget build(BuildContext context) {
    final AdminBloc bloc = context.read<AdminBloc>();
    final List<AuditEntryEntity> entries = state.clubAuditEntries;
    final AuditDescriber describer = AuditDescriber(
      clubNames: <String, String>{
        for (final AdminClubEntity c in state.clubs) c.id: c.name,
      },
      hallNames: <String, String>{
        for (final AdminClubEntity c in state.clubs)
          for (final AdminHallEntity h in c.halls) h.id: h.name,
      },
    );

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AdminCardTitle(
            'Журнал действий',
            subtitle: 'Последние изменения цен, пакетов, доступности, настроек '
                'и статусов броней клуба ${state.club.name}. Новые сверху.',
            trailing: AdminGhostButton(
              label: state.auditLoading ? 'Загружаю…' : 'Обновить',
              onTap: () => bloc.add(const AdminAuditRequested()),
            ),
          ),
          const SizedBox(height: 16),
          if (state.auditError != null)
            Text(state.auditError!,
                style: const TextStyle(fontSize: 13, color: AdminColors.danger))
          else if (entries.isEmpty)
            Text(
              state.auditLoading ? 'Загружаю журнал…' : 'Изменений пока нет.',
              style: const TextStyle(fontSize: 14, color: AdminColors.textMuted),
            )
          else
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AdminColors.border),
              ),
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < entries.length; i++)
                    _Entry(
                      entry: entries[i],
                      line: describer.describe(entries[i]),
                      first: i == 0,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.entry, required this.line, required this.first});

  final AuditEntryEntity entry;
  final AuditLine line;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final DateTime t = entry.at.toLocal();
    final String when = '${t.day} ${AdminFormat.monShort(t)}, '
        '${AdminFormat.hhmm(t.hour * 60 + t.minute)}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AdminColors.tile,
        border: first
            ? null
            : const Border(top: BorderSide(color: AdminColors.rowDivider)),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 4,
        children: <Widget>[
          SizedBox(
            width: 170,
            child: Text(
              '$when · ${AuditDescriber.actorOf(entry)}',
              style: const TextStyle(fontSize: 12, color: AdminColors.textMuted),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(line.title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: AdminColors.text)),
                if (line.details != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(line.details!,
                      style: const TextStyle(fontSize: 13, color: AdminColors.textSoft)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
