import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/state/admin_bloc.dart';
import '../admin_theme.dart';
import '../components/admin_atoms.dart';
import '../components/admin_header.dart';
import '../components/admin_tab_bar.dart';
import '../components/availability_tab.dart';
import '../components/booking_detail_drawer.dart';
import '../components/log_tab.dart';
import '../components/new_booking_drawer.dart';
import '../components/packages_tab.dart';
import '../components/prices_tab.dart';
import '../components/records_tab.dart';

/// Экран админки (панель персонала). Доступ — по `?admin=1` или из
/// приложения «VR Админка».
class AdminScreen extends StatelessWidget {
  /// Создаёт экран.
  const AdminScreen({this.onLogout, super.key});

  /// Колбэк «Выйти» (если авторизация включена).
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return _RefreshOnResume(
      child: Scaffold(
        backgroundColor: AdminColors.bg,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.6, -1.7),
              radius: 1.3,
              colors: <Color>[Color(0xFF062018), AdminColors.bg],
              stops: <double>[0.0, 0.68],
            ),
          ),
          child: SafeArea(
            child: BlocBuilder<AdminBloc, AdminState>(
              builder: (BuildContext context, AdminState state) {
                final AdminBloc bloc = context.read<AdminBloc>();
                if (state.status == AdminStatus.failure) {
                  return _LoadFailure(
                    message: state.saveError ?? 'Не удалось загрузить данные.',
                    onRetry: () => bloc.add(const AdminStarted()),
                    onLogout: onLogout,
                  );
                }
                if (state.status == AdminStatus.loading ||
                    state.clubs.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                final Color accent = AdminColors.accentFor(state.accentSlug);
                // На телефоне поля по 20 px с каждой стороны заметно съедают
                // ширину таблиц и сетки занятости.
                final double pad = MediaQuery.sizeOf(context).width < 600
                    ? 12
                    : 20;

                return Stack(
                  children: <Widget>[
                    Column(
                      children: <Widget>[
                        // Закреплённая шапка — клуб можно переключить с любого места.
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1400),
                            // На всю ширину: без этого шапка сжималась по
                            // содержимому, вставала по центру и не совпадала
                            // с вкладками под ней.
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(horizontal: pad),
                              child: AdminHeader(
                                clubs: state.clubs,
                                selectedClubId: state.clubId,
                                accent: accent,
                                onClubSelected: (String id) =>
                                    bloc.add(AdminClubChanged(id)),
                                onLogout: onLogout,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(bottom: 44),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 1400,
                                ),
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(pad, 22, pad, 0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      AdminTabBar(
                                        current: state.tab,
                                        accent: accent,
                                        onSelected: (AdminTab t) =>
                                            bloc.add(AdminTabChanged(t)),
                                        trailing: AdminPrimaryButton(
                                          label: '+  Новая запись',
                                          accent: accent,
                                          onTap: () => bloc.add(
                                            const AdminNewBookingOpened(),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 22),
                                      if (state.saveError != null) ...<Widget>[
                                        AdminErrorBox(state.saveError!),
                                        const SizedBox(height: 14),
                                      ],
                                      // Пояснение, которое не ошибка: например,
                                      // пакет выключен вместо удаления.
                                      if (state.saveError == null &&
                                          state.saveNotice != null) ...<Widget>[
                                        AdminNoticeBox(state.saveNotice!),
                                        const SizedBox(height: 14),
                                      ],
                                      switch (state.tab) {
                                        AdminTab.records => RecordsTab(
                                          state: state,
                                          accent: accent,
                                        ),
                                        AdminTab.prices => PricesTab(
                                          state: state,
                                          accent: accent,
                                        ),
                                        AdminTab.packages => PackagesTab(
                                          state: state,
                                          accent: accent,
                                        ),
                                        AdminTab.availability =>
                                          AvailabilityTab(
                                            state: state,
                                            accent: accent,
                                          ),
                                        AdminTab.log => LogTab(state: state),
                                      },
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (state.openRow != null)
                      BookingDetailDrawer(state: state, accent: accent),
                    if (state.newBooking != null)
                      NewBookingDrawer(state: state, accent: accent),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Перечитывает данные, когда приложение снова на экране: пока телефон спал,
/// соединение Realtime могло оборваться, и события прошли мимо.
class _RefreshOnResume extends StatefulWidget {
  const _RefreshOnResume({required this.child});

  final Widget child;

  @override
  State<_RefreshOnResume> createState() => _RefreshOnResumeState();
}

class _RefreshOnResumeState extends State<_RefreshOnResume> {
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (mounted) {
          context.read<AdminBloc>().add(const AdminRefreshRequested());
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Стартовые данные не загрузились — объясняем и даём повторить.
class _LoadFailure extends StatelessWidget {
  const _LoadFailure({
    required this.message,
    required this.onRetry,
    this.onLogout,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Админка не загрузилась',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              AdminErrorBox(message),
              const SizedBox(height: 18),
              AdminPrimaryButton(
                label: 'Повторить',
                accent: const Color(0xFFA9F04A),
                onTap: onRetry,
              ),
              if (onLogout != null) ...<Widget>[
                const SizedBox(height: 10),
                AdminGhostButton(label: 'Выйти', onTap: onLogout!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
