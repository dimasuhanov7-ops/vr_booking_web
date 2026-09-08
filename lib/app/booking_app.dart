import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../di/injection.dart';
import '../features/admin/presentation/screens/admin_auth_gate.dart';
import '../features/booking/domain/state/booking_bloc.dart';
import '../features/booking/presentation/screens/booking_screen.dart';
import 'embed/launch_params.dart';
import 'theme/app_theme.dart';

/// Корневой виджет приложения. Публичный виджет бронирования и служебная
/// админка живут в одном бандле; раздел и предвыбор берутся из query
/// (см. [LaunchParams] и `docs/EMBED.md`).
class BookingApp extends StatelessWidget {
  /// Создаёт приложение.
  const BookingApp({this.params = const LaunchParams(), super.key});

  /// Параметры запуска (разобранный query-строкой URL).
  final LaunchParams params;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: params.adminMode ? 'Админка · Бронирование VR' : 'Бронирование VR',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      locale: const Locale('ru'),
      supportedLocales: const <Locale>[Locale('ru'), Locale('en')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: params.adminMode
          ? const AdminAuthGate()
          : BlocProvider<BookingBloc>(
              create: (_) => BookingBloc(
                repository: Injection.instance.bookingRepository,
                accountStore: Injection.instance.accountStore,
                source: params.source,
                lockedClubSlug: params.clubSlug,
                initialDate: params.initialDate,
                initialDurationMinutes: params.initialDurationMinutes,
              )..add(const BookingStarted()),
              child: const BookingScreen(),
            ),
    );
  }
}
