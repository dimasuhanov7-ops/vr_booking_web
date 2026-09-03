import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import 'booking_view.dart';

/// Публичный экран онлайн-бронирования (без авторизации персонала).
class BookingScreen extends StatelessWidget {
  /// Создаёт экран.
  const BookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BookingColors.bg,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -1.6),
            radius: 1.4,
            colors: <Color>[Color(0xFF062018), BookingColors.bg],
            stops: <double>[0.0, 0.7],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
            child: Center(child: BookingView()),
          ),
        ),
      ),
    );
  }
}
