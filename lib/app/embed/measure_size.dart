import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Сообщает [onChange] о фактическом размере [child] после каждого лэйаута,
/// когда размер изменился. Нужно, чтобы отдавать высоту контента родительскому
/// iframe (Flutter Web рендерит в canvas фикс. размера — `body.scrollHeight`
/// внутреннюю раскладку не отражает).
class MeasureSize extends SingleChildRenderObjectWidget {
  /// Создаёт обёртку-измеритель.
  const MeasureSize({required this.onChange, required Widget super.child, super.key});

  /// Вызывается при изменении размера ребёнка.
  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMeasureSize(onChange);

  @override
  void updateRenderObject(BuildContext context, covariant RenderObject renderObject) {
    (renderObject as _RenderMeasureSize).onChange = onChange;
  }
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize(this.onChange);

  ValueChanged<Size> onChange;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    final Size next = child?.size ?? Size.zero;
    if (next != _last) {
      _last = next;
      WidgetsBinding.instance.addPostFrameCallback((_) => onChange(next));
    }
  }
}
