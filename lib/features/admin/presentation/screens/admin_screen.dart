import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/state/admin_bloc.dart';
import '../admin_theme.dart';
import '../components/admin_header.dart';
import '../components/admin_tab_bar.dart';
import '../components/availability_tab.dart';
import '../components/booking_detail_drawer.dart';
import '../components/new_booking_drawer.dart';
import '../components/packages_tab.dart';
import '../components/prices_tab.dart';
import '../components/records_tab.dart';

/// Экран админки (панель персонала). Доступ — по `?admin=1`.
class AdminScreen extends StatelessWidget {
  /// Создаёт экран.
  const AdminScreen({this.onLogout, super.key});

  /// Колбэк «Выйти» (если авторизация включена).
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              if (state.status == AdminStatus.loading || state.clubs.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              final AdminBloc bloc = context.read<AdminBloc>();
              final Color accent = AdminColors.accentFor(state.accentSlug);

              return Stack(
                children: <Widget>[
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1400),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 44),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            AdminHeader(
                              clubs: state.clubs,
                              selectedClubId: state.clubId,
                              accent: accent,
                              onClubSelected: (String id) =>
                                  bloc.add(AdminClubChanged(id)),
                              onLogout: onLogout,
                            ),
                            const SizedBox(height: 22),
                            AdminTabBar(
                              current: state.tab,
                              accent: accent,
                              onSelected: (AdminTab t) => bloc.add(AdminTabChanged(t)),
                              trailing: AdminPrimaryButton(
                                label: '＋ Новая запись',
                                accent: accent,
                                onTap: () => bloc.add(const AdminNewBookingOpened()),
                              ),
                            ),
                            const SizedBox(height: 22),
                            if (state.saveError != null) ...<Widget>[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AdminColors.dangerBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AdminColors.dangerBorder),
                                ),
                                child: Text(state.saveError!,
                                    style: const TextStyle(
                                        fontSize: 13, color: AdminColors.danger)),
                              ),
                              const SizedBox(height: 14),
                            ],
                            switch (state.tab) {
                              AdminTab.prices =>
                                PricesTab(state: state, accent: accent),
                              AdminTab.packages =>
                                PackagesTab(state: state, accent: accent),
                              AdminTab.availability =>
                                AvailabilityTab(state: state, accent: accent),
                              AdminTab.records =>
                                RecordsTab(state: state, accent: accent),
                            },
                          ],
                        ),
                      ),
                    ),
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
    );
  }
}
