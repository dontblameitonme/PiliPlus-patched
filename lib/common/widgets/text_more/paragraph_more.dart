import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/rendering.dart'
    show
        Size,
        Color,
        Offset,
        TextSpan,
        TextStyle,
        InlineSpan,
        TextScaler,
        TextPainter,
        VoidCallback,
        HitTestEntry,
        RenderParagraph,
        PaintingContext,
        BoxHitTestResult,
        RenderComparison;

class RenderParagraphMore extends RenderParagraph {
  RenderParagraphMore(
    super.text, {
    super.textAlign,
    required super.textDirection,
    super.softWrap,
    super.overflow,
    // ignore: deprecated_member_use
    super.textScaleFactor,
    super.textScaler,
    super.maxLines,
    super.locale,
    super.strutStyle,
    super.textWidthBasis,
    super.textHeightBehavior,
    super.children,
    super.selectionColor,
    super.registrar,
    required this._primary,
    this._onShowMore,
  });

  Color _primary;

  VoidCallback? _onShowMore;
  set onShowMore(VoidCallback? onShowMore) {
    if (_onShowMore != onShowMore) {
      _onShowMore = onShowMore;
      _tapGestureRecognizer?.onTap = onShowMore;
    }
  }

  TapGestureRecognizer? _tapGestureRecognizer;

  TextSpan _moreTextSpan([TextStyle? style]) => TextSpan(
    style: (style ?? text.style!).copyWith(color: _primary),
    text: '查看更多',
    recognizer: _tapGestureRecognizer,
  );
  TextPainter? _morePainter;
  double? _moreLaidOutWidth;

  bool didOverflowHeight = false;

  @override
  set textScaler(TextScaler value) {
    if (textPainter.textScaler == value) {
      return;
    }
    _morePainter?.textScaler = value;
    _moreLaidOutWidth = null;
    super.textScaler = value;
  }

  void setText(({InlineSpan text, Color primary}) params) {
    final newText = params.text;
    _primary = params.primary;
    if (_morePainter != null) {
      final textSpan = _moreTextSpan(newText.style);
      switch (_morePainter!.text!.compareTo(textSpan)) {
        case RenderComparison.paint:
          _morePainter!.text = textSpan;
        case RenderComparison.layout:
          _morePainter!.text = textSpan;
          _moreLaidOutWidth = null;
        default:
      }
    }
    super.text = newText;
  }

  @override
  void performLayout() {
    super.performLayout();

    if (didOverflowHeight = textPainter.didExceedMaxLines) {
      if (_onShowMore != null) {
        _tapGestureRecognizer ??= TapGestureRecognizer()..onTap = _onShowMore;
      }
      // [PATCH PERF-24] / [PATCH BUG-20] 仅在文本/缩放/约束宽度变化时重新 layout
      final maxWidth = constraints.maxWidth;
      if (_morePainter == null || _moreLaidOutWidth != maxWidth) {
        (_morePainter ??= TextPainter(
          text: _moreTextSpan(),
          textDirection: textDirection,
          textScaler: textScaler,
          locale: locale,
        )).layout(maxWidth: maxWidth);
        _moreLaidOutWidth = maxWidth;
      }
      size = Size(
        size.width,
        constraints.constrainHeight(size.height + _morePainter!.height),
      );
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);

    if (didOverflowHeight) {
      _morePainter?.paint(
        context.canvas,
        offset + Offset(0, textPainter.height),
      );
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    // [PATCH BUG-20] 未溢出时不响应“查看更多”点击（列表复用的旧 painter）
    if (didOverflowHeight && _tapGestureRecognizer != null) {
      if (_morePainter != null) {
        if (position.dx < _morePainter!.width) {
          final height = textPainter.height;
          if (position.dy > height &&
              position.dy < height + _morePainter!.height) {
            result.add(HitTestEntry(_morePainter!.text as TextSpan));
            return true;
          }
        }
      }
    }
    return super.hitTestChildren(result, position: position);
  }

  @override
  void dispose() {
    _tapGestureRecognizer?.dispose();
    _tapGestureRecognizer = null;
    _morePainter?.dispose();
    _morePainter = null;
    _moreLaidOutWidth = null;
    super.dispose();
  }
}
