import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/state/admin_bloc.dart';
import '../admin_theme.dart';
import '../components/admin_header.dart';
import '../components/admin_tab_bar.dart';
import '../components/availability_tab.dart';
import '../components/bookings_tab.dart';
import '../components/packages_tab.dart';
import '../components/prices_tab.dart';
import '../components/records_tab.dart';

/// Экран админки (панель персонала). Доступ — по `?admin=1`.
class AdminScreen extends StatelessWidget {
  /// Создаёт экран.
  const AdminScreen({super.key});

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

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
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
                        ),
                        const SizedBox(height: 22),
                        AdminTabBar(
                          current: state.tab,
                          accent: accent,
                          onSelected: (AdminTab t) => bloc.add(AdminTabChanged(t)),
                        ),
                        const SizedBox(height: 22),
                        switch (state.tab) {
                          AdminTab.prices => PricesTab(state: state, accent: accent),
                          AdminTab.packages => PackagesTab(state: state, accent: accent),
                          AdminTab.availability => AvailabilityTab(state: state, accent: accent),
                          AdminTab.bookings => BookingsTab(state: state, accent: accent),
                          AdminTab.records => RecordsTab(state: state, accent: accent),
                        },
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
