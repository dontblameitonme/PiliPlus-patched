import 'package:PiliPlus/common/widgets/view_safe_area.dart';
import 'package:material_ui/material_ui.dart';

class AppBarAni extends StatefulWidget {
  const AppBarAni({
    super.key,
    required this.child,
    required this.controller,
    required this.isTop,
    required this.isFullScreen,
    required this.removeSafeArea,
    this.lazy = false,
  });

  /// [PATCH PERF-21] 为 true 时，第一次显示控制栏之前不构建 [child]，
  /// 减少打开视频页第一帧要构建的控件数量。用于底部控制栏
  final bool lazy;

  final Widget child;
  final AnimationController controller;
  final bool isTop;
  final bool isFullScreen;
  final bool removeSafeArea;

  static final _topPos = Tween<Offset>(
    begin: const Offset(0.0, -1.0),
    end: Offset.zero,
  );

  static const _topDecoration = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: <Color>[
      Colors.transparent,
      Color(0xBF000000),
    ],
    tileMode: TileMode.mirror,
  );

  static final _bottomPos = Tween<Offset>(
    begin: const Offset(0, 1.2),
    end: Offset.zero,
  );

  static const _bottomDecoration = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      Colors.transparent,
      Color(0xBF000000),
    ],
    tileMode: TileMode.mirror,
  );

  @override
  State<AppBarAni> createState() => _AppBarAniState();
}

class _AppBarAniState extends State<AppBarAni> {
  bool _hasShown = false;

  @override
  Widget build(BuildContext context) {
    // [PATCH PERF-13] skip painting the bar while it is fully hidden.
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        final dismissed = widget.controller.isDismissed;
        if (!dismissed) _hasShown = true;
        // [PATCH PERF-21] 还没显示过的懒加载控制栏先用空盒占位
        if (widget.lazy && !_hasShown) return const SizedBox.shrink();
        return Offstage(offstage: dismissed, child: child);
      },
      child: SlideTransition(
        position: widget.controller.drive(
          widget.isTop ? AppBarAni._topPos : AppBarAni._bottomPos,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: widget.isTop
                ? AppBarAni._topDecoration
                : AppBarAni._bottomDecoration,
          ),
          child: widget.removeSafeArea
              ? widget.child
              : ViewSafeArea(
                  left: widget.isFullScreen,
                  right: widget.isFullScreen,
                  child: widget.child,
                ),
        ),
      ),
    );
  }
}
