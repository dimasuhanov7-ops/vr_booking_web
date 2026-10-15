import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../di/injection.dart';
import '../features/booking/domain/state/booking_bloc.dart';
import '../features/booking/presentation/screens/booking_screen.dart';
import 'embed/launch_params.dart';
import 'l10n/ru_localizations.dart';
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
      // Только русский: стандартные делегаты тащат в бандл все языки.
      locale: RuLocalizations.locale,
      supportedLocales: const <Locale>[RuLocalizations.locale],
      localizationsDelegates: RuLocalizations.delegates,
      home: params.adminMode
          ? Injection.instance.adminHome()
          : BlocProvider<BookingBloc>(
              create: (_) => BookingBloc(
                repository: Injection.instance.bookingRepository,
                accountStore: Injection.instance.accountStore,
                source: params.source,
                lockedClubSlug: params.clubSlug,
                initialDate: params.initialDate,
                initialDurationMinutes: params.initialDurationMinutes,
                utm: params.utm,
              )..add(const BookingStarted()),
              child: const BookingScreen(),
            ),
    );
  }
}
