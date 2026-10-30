import 'dart:async' show Completer;

import 'package:PiliPlus/common/widgets/scaffold/bottom_sheet.dart';
import 'package:PiliPlus/common/widgets/scaffold/bottom_sheet_layout.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:material_ui/material_ui.dart';

class MiniScaffold extends StatefulWidget {
  const MiniScaffold({
    super.key,
    required this.body,
  });

  final Widget body;

  static MiniScaffoldState of(BuildContext context) {
    return context.findAncestorStateOfType<MiniScaffoldState>()!;
  }

  static MiniScaffoldState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<MiniScaffoldState>();
  }

  @override
  State<MiniScaffold> createState() => MiniScaffoldState();
}

class MiniScaffoldState extends State<MiniScaffold>
    with TickerProviderStateMixin {
  PersistentBottomSheetController? _currentBottomSheet;

  void _closeCurrentBottomSheet() {
    if (_currentBottomSheet != null) {
      if (!_currentBottomSheet!.isLocalHistoryEntry) {
        _currentBottomSheet!.close();
      }
      assert(() {
        _currentBottomSheet?.completer.future.whenComplete(() {
          assert(_currentBottomSheet == null);
        });
        return true;
      }());
    }
  }

  PersistentBottomSheetController _buildBottomSheet(
    WidgetBuilder builder, {
    required AnimationController animationController,
    BoxConstraints? constraints,
    bool? enableDrag,
    bool shouldDisposeAnimationController = true,
    double dragHeight = kBottomSheetDragHeight,
  }) {
    final completer = Completer<void>();
    final bottomSheetKey = GlobalKey<StandardBottomSheetState>();
    late StandardBottomSheet bottomSheet;

    var removedEntry = false;
    var doingDispose = false;

    void removeCurrentBottomSheet() {
      removedEntry = true;
      if (_currentBottomSheet == null) {
        return;
      }
      assert(_currentBottomSheet!.widget == bottomSheet);
      assert(bottomSheetKey.currentState != null);

      bottomSheetKey.currentState!.close();

      completer.complete();
    }

    final LocalHistoryEntry entry = LocalHistoryEntry(
      onRemove: () {
        if (!removedEntry &&
            _currentBottomSheet?.widget == bottomSheet &&
            !doingDispose) {
          removeCurrentBottomSheet();
        }
      },
    );

    void removeEntryIfNeeded() {
      if (!removedEntry) {
        entry.remove();
        removedEntry = true;
      }
    }

    bottomSheet = _StandardBottomSheet(
      key: bottomSheetKey,
      animationController: animationController,
      enableDrag: enableDrag ?? true,
      dragHeight: dragHeight,
      onClosing: () {
        if (_currentBottomSheet == null) {
          return;
        }
        assert(_currentBottomSheet!.widget == bottomSheet);
        removeEntryIfNeeded();
      },
      onDismissed: () {
        if (bottomSheet == _currentBottomSheet?.widget) {
          _currentBottomSheet = null;
          if (mounted) {
            setState(() {});
          }
        }
      },
      onDispose: () {
        doingDispose = true;
        removeEntryIfNeeded();
        if (shouldDisposeAnimationController) {
          animationController.dispose();
        }
      },
      builder: builder,
      isPersistent: false,
      constraints: constraints,
    );

    (Get.routing.route! as ModalRoute).addLocalHistoryEntry(entry);

    return PersistentBottomSheetController(
      bottomSheet,
      completer,
      entry.remove,
      (VoidCallback fn) {
        bottomSheetKey.currentState?.setState(fn);
      },
      true,
    );
  }

  PersistentBottomSheetController showBottomSheet(
    WidgetBuilder builder, {
    BoxConstraints? constraints,
    bool? enableDrag,
    AnimationController? transitionAnimationController,
    AnimationStyle? sheetAnimationStyle,
    double dragHeight = kBottomSheetDragHeight,
  }) {
    _closeCurrentBottomSheet();
    final AnimationController controller =
        (transitionAnimationController ??
              BottomSheet.createAnimationController(
                this,
                sheetAnimationStyle: sheetAnimationStyle,
              ))
          ..forward();
    setState(() {
      _currentBottomSheet = _buildBottomSheet(
        builder,
        animationController: controller,
        constraints: constraints,
        enableDrag: enableDrag,
        dragHeight: dragHeight,
        shouldDisposeAnimationController: transitionAnimationController == null,
      );
    });
    return _currentBottomSheet!;
  }

  @override
  Widget build(BuildContext context) {
    final bottomSheet = _currentBottomSheet?.widget;
    return BottomSheetLayout(
      // 隔离主页面与弹出面板的绘制，避免面板动画时重绘底层整个页面
      body: RepaintBoundary(child: widget.body),
      bottomSheet: bottomSheet != null
          ? RepaintBoundary(child: bottomSheet)
          : null,
    );
  }
}

class _StandardBottomSheet extends StandardBottomSheet {
  const _StandardBottomSheet({
    super.key,
    required super.animationController,
    super.enableDrag,
    required super.onClosing,
    required super.onDismissed,
    required super.builder,
    super.isPersistent,
    super.constraints,
    super.onDispose,
    this.dragHeight = kBottomSheetDragHeight,
  });

  final double dragHeight;

  @override
  StandardBottomSheetState<_StandardBottomSheet> createState() =>
      _StandardBottomSheetState();
}

class _StandardBottomSheetState
    extends StandardBottomSheetState<_StandardBottomSheet> {
  @override
  Widget build(BuildContext context) {
    final child = BottomSheet_(
      animationController: widget.animationController,
      enableDrag: widget.enableDrag,
      onDragStart: handleDragStart,
      onDragEnd: handleDragEnd,
      onClosing: widget.onClosing!,
      builder: widget.builder,
      constraints: widget.constraints,
      dragHeight: widget.dragHeight,
    );
    if (widget.enableDrag) {
      // 使用 ClipRect + FractionalTranslation 走合成层位移动画，替代
      // Align(heightFactor) 每帧触发的布局
      return ClipRect(
        child: AnimatedBuilder(
          animation: widget.animationController,
          builder: (context, child) => FractionalTranslation(
            translation: Offset(
              0.0,
              1.0 - animationCurve.transform(widget.animationController.value),
            ),
            child: child,
          ),
          child: RepaintBoundary(child: child),
        ),
      );
    }
    return AnimatedBuilder(
      animation: widget.animationController,
      builder: (context, child) => Opacity(
        opacity: widget.animationController.value,
        child: child,
      ),
      child: child,
    );
  }
}
