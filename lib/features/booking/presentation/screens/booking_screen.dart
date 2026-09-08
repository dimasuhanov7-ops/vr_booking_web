import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/embed/embed_channel.dart';
import '../../../../app/embed/measure_size.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/state/booking_bloc.dart';
import 'booking_view.dart';

/// Публичный экран онлайн-бронирования (без авторизации персонала).
///
/// Помимо самой формы отвечает за общение с родительским `<iframe>`:
/// высота контента, шаг мастера, успешная бронь (см. `docs/EMBED.md`).
class BookingScreen extends StatefulWidget {
  /// Создаёт экран.
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  /// Вертикальные отступы прокручиваемой области (сверху + снизу).
  static const double _pagePadding = 56;

  bool _ready = false;
  int _lastHeight = 0;
  int _lastStep = 0;
  String? _lastOrderId;
  Timer? _heightDebounce;
  int _pendingHeight = 0;

  @override
  void dispose() {
    _heightDebounce?.cancel();
    super.dispose();
  }

  // Высоту шлём с дебаунсом: при первом кадре и смене шага лэйаут проходит
  // несколько промежуточных состояний (в т.ч. переходные всплески) — родителю
  // отдаём только устоявшееся значение.
  void _onContentResize(Size size) {
    if (!_ready) {
      _ready = true;
      EmbedChannel.ready();
    }
    final int h = (size.height + _pagePadding).ceil().clamp(120, 5000);
    if (h == _pendingHeight) return;
    _pendingHeight = h;
    _heightDebounce?.cancel();
    _heightDebounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted || _pendingHeight == _lastHeight) return;
      _lastHeight = _pendingHeight;
      EmbedChannel.height(_pendingHeight.toDouble());
    });
  }

  void _onState(BuildContext context, BookingState state) {
    if (state.stepNo != _lastStep) {
      _lastStep = state.stepNo;
      EmbedChannel.step(state.stepNo);
    }
    final String? orderId = state.createdOrderId;
    if (orderId != null && orderId != _lastOrderId) {
      _lastOrderId = orderId;
      EmbedChannel.success(
        orderId: orderId,
        clubSlug: state.club?.slug ?? '',
        stationCount: state.pickedIds.length,
        minutes: state.durationMinutes,
        amount: state.quote.gross,
      );
    }
  }

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
            child: Center(
              child: BlocListener<BookingBloc, BookingState>(
                listenWhen: (BookingState p, BookingState c) =>
                    p.stepNo != c.stepNo || p.createdOrderId != c.createdOrderId,
                listener: _onState,
                child: MeasureSize(
                  onChange: _onContentResize,
                  child: const BookingView(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
