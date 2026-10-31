// [PATCH PERF-21] 新增文件，上游没有。
// 页面进场动画（路由 animation）结束后再构建重量级子树，
// 避免列表/网格的首次构建和图片解码挤在转场的同一时间里，造成掉帧。
import 'package:flutter/widgets.dart';

class DeferUntilRouteSettled extends StatefulWidget {
  const DeferUntilRouteSettled({
    super.key,
    required this.builder,
    required this.placeholder,
  });

  /// 转场结束后构建的真实内容
  final WidgetBuilder builder;

  /// 转场期间显示的轻量占位（例如骨架屏）
  final Widget placeholder;

  @override
  State<DeferUntilRouteSettled> createState() => _DeferUntilRouteSettledState();
}

class _DeferUntilRouteSettledState extends State<DeferUntilRouteSettled> {
  bool _ready = false;
  Animation<double>? _animation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready || _animation != null) return;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.status != AnimationStatus.forward) {
      _ready = true;
      return;
    }
    _animation = animation..addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.forward) return;
    _detach();
    if (mounted && !_ready) {
      setState(() => _ready = true);
    }
  }

  void _detach() {
    _animation?.removeStatusListener(_onStatus);
    _animation = null;
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _ready ? widget.builder(context) : widget.placeholder;
}
