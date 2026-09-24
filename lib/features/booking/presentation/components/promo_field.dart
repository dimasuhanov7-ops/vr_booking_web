import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entity/discount_entity.dart';

/// Промокод: свёрнутая ссылка «Есть промокод?» → поле с «Применить» →
/// применённый код с эффектом и «Убрать».
class PromoField extends StatefulWidget {
  /// Создаёт поле.
  const PromoField({
    required this.input,
    required this.promo,
    required this.applies,
    required this.checking,
    required this.error,
    required this.accent,
    required this.onChanged,
    required this.onSubmit,
    required this.onClear,
    super.key,
  });

  /// Текст в поле.
  final String input;

  /// Принятый сервером промокод.
  final DiscountEntity? promo;

  /// Промокод применяется к выбору (хватает станций).
  final bool applies;

  /// Идёт проверка.
  final bool checking;

  /// Почему код не принят.
  final String? error;

  /// Акцент клуба.
  final Color accent;

  /// Ввод.
  final ValueChanged<String> onChanged;

  /// «Применить».
  final VoidCallback onSubmit;

  /// «Убрать».
  final VoidCallback onClear;

  @override
  State<PromoField> createState() => _PromoFieldState();
}

class _PromoFieldState extends State<PromoField> {
  late final TextEditingController _c = TextEditingController(text: widget.input);
  late bool _open = widget.input.isNotEmpty;

  @override
  void didUpdateWidget(covariant PromoField old) {
    super.didUpdateWidget(old);
    if (widget.input != _c.text && widget.input.isEmpty) _c.clear();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DiscountEntity? promo = widget.promo;
    if (promo != null) return _applied(promo);

    if (!_open) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => setState(() => _open = true),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 36),
            foregroundColor: BookingColors.textSoft,
          ),
          child: const Text('Есть промокод?',
              style: TextStyle(fontSize: 14, decoration: TextDecoration.underline)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text('Промокод',
              style: TextStyle(fontSize: 12, color: BookingColors.textMuted)),
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _c,
                onChanged: widget.onChanged,
                onSubmitted: (_) => widget.onSubmit(),
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(fontSize: 16, color: BookingColors.text),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Например, VRPARTY',
                  hintStyle: const TextStyle(color: BookingColors.textFaint),
                  filled: true,
                  fillColor: BookingColors.surface,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  border: _border(BookingColors.border),
                  enabledBorder: _border(BookingColors.border),
                  focusedBorder: _border(BookingColors.textSoft),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 46,
              child: OutlinedButton(
                onPressed: widget.checking || widget.input.trim().isEmpty
                    ? null
                    : widget.onSubmit,
                style: OutlinedButton.styleFrom(
                  foregroundColor: BookingColors.text,
                  side: const BorderSide(color: BookingColors.podBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(widget.checking ? 'Проверяю…' : 'Применить'),
              ),
            ),
          ],
        ),
        if (widget.error != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(widget.error!,
              style: const TextStyle(fontSize: 13, color: BookingColors.warn)),
        ],
      ],
    );
  }

  Widget _applied(DiscountEntity promo) {
    final String name = promo.code ?? promo.title ?? 'Промокод';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.accent.withValues(alpha: 0.5)),
        color: widget.accent.withValues(alpha: 0.08),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Промокод $name · ${promo.effectLabel}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700, color: BookingColors.text)),
                if (!widget.applies)
                  Text('Действует от ${promo.minStations} мест — добавьте станции.',
                      style: const TextStyle(fontSize: 12, color: BookingColors.warn)),
              ],
            ),
          ),
          TextButton(
            onPressed: widget.onClear,
            style: TextButton.styleFrom(foregroundColor: BookingColors.textSoft),
            child: const Text('Убрать'),
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c),
      );
}
