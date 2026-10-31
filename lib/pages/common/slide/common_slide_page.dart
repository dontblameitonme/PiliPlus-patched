import 'dart:math' show max;

import 'package:PiliPlus/common/widgets/gesture/horizontal_drag_gesture_recognizer.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/gestures.dart' show HorizontalDragGestureRecognizer;
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

abstract class CommonSlidePage extends StatefulWidget {
  const CommonSlidePage({super.key, this.enableSlide = true});

  final bool enableSlide;
}

mixin CommonSlideMixin<T extends CommonSlidePage> on State<T>, TickerProvider {
  static const double offset = 30.0;
  double? _downDx;
  late double _maxWidth;
  double get maxWidth => _maxWidth;
  late bool _isRTL = false;
  late final bool enableSlide;
  late final AnimationController _animController;
  SlideDragGestureRecognizer? _slideDragGestureRecognizer;
  static bool slideDismissReplyPage = Pref.slideDismissReplyPage;

  bool isDxAllowed(double dx) {
    return enableSlide
        ? dx > CommonSlideMixin.offset &&
              dx < maxWidth - CommonSlideMixin.offset
        : true;
  }

  TabBarDragGestureRecognizer horizontalDragGestureRecognizer() {
    return TabBarDragGestureRecognizer(isDxAllowed: isDxAllowed);
  }

  late ThemeData theme;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    theme = Theme.of(context);
  }

  @override
  void initState() {
    super.initState();
    enableSlide = widget.enableSlide && slideDismissReplyPage;
    if (enableSlide) {
      _animController = AnimationController(
        vsync: this,
        // [PATCH PERF-02] 动画时长统一为 250ms
        duration: const Duration(milliseconds: 250),
        reverseDuration: const Duration(milliseconds: 250),
      );
      _slideDragGestureRecognizer =
          SlideDragGestureRecognizer(
              isDxAllowed: (double dx) {
                final isLTR = dx <= offset;
                final isRTL = dx >= _maxWidth - offset;
                if (isLTR || isRTL) {
                  _isRTL = isRTL;
                  return true;
                }
                return false;
              },
            )
            ..onStart = _onDragStart
            ..onUpdate = _onDragUpdate
            ..onEnd = _onDragEnd
            // [PATCH BUG-05] onCancel 只复位，不再走 onDragEnd 的退页判断
            ..onCancel = _onDragCancel;
    }
  }

  @override
  void dispose() {
    if (enableSlide) {
      _animController.dispose();
      _slideDragGestureRecognizer?.dispose();
      _slideDragGestureRecognizer = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (enableSlide) {
      return LayoutBuilder(
        builder: (context, constraints) {
          _maxWidth = constraints.maxWidth;
          // 使用合成层位移替代 Align(heightFactor)，避免每帧重排整个列表
          // [PATCH PERF-02] ClipRect + FractionalTranslation + RepaintBoundary
          return ClipRect(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return FractionalTranslation(
                  translation: Offset(0.0, _animController.value),
                  child: child,
                );
              },
              child: RepaintBoundary(child: buildPage()),
            ),
          );
        },
      );
    }
    return buildPage();
  }

  Widget buildPage();

  Widget buildList() => throw UnimplementedError();

  void _onDragCancel() {
    if (_downDx == null) return;
    _downDx = null;
    // 手势被系统打断时仅复位，不做退页判断
    _animController.reverse();
  }

  // [PATCH BUG-05] 退页阈值只算实际滑动距离，另外支持快速甩动
  void _onDragEnd(DragEndDetails details) {
    if (_downDx == null) return;
    _downDx = null;
    final double vx = details.velocity.pixelsPerSecond.dx * (_isRTL ? -1 : 1);
    // 仅以实际滑动距离（不混入初始触点位置）或快速甩动判断是否退页
    if (vx >= 500 || _animController.value * _maxWidth >= 100) {
      Get.back();
    } else {
      _animController.reverse();
    }
  }

  void _onDragStart(DragStartDetails details) {
    _downDx = details.localPosition.dx;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final from = _downDx!;
    final to = details.localPosition.dx;
    _animController.value = max(0, _isRTL ? from - to : to - from) / _maxWidth;
  }

  Widget slideList() => Listener(
    onPointerDown: (event) => _slideDragGestureRecognizer?.addPointer(event),
    child: buildList(),
  );
}

typedef IsDxAllowed = bool Function(double dx);

class SlideDragGestureRecognizer extends HorizontalDragGestureRecognizer {
  SlideDragGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
    required this.isDxAllowed,
  });

  final IsDxAllowed isDxAllowed;

  @override
  bool isPointerAllowed(PointerEvent event) {
    return isDxAllowed(event.localPosition.dx) && super.isPointerAllowed(event);
  }
}

class TabBarDragGestureRecognizer
    extends CustomHorizontalDragGestureRecognizer {
  TabBarDragGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
    required this.isDxAllowed,
  });

  final IsDxAllowed isDxAllowed;

  @override
  bool isPointerAllowed(PointerEvent event) {
    return isDxAllowed(event.localPosition.dx) && super.isPointerAllowed(event);
  }
}
