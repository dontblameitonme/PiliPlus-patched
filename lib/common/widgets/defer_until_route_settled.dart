// [PATCH PERF-21] 新增文件，上游没有。
// 页面进场动画（路由 animation）结束后再构建重量级子树，
// 避免列表/网格的首次构建和图片解码挤在转场的同一时间里，造成掉帧。
import 'dart:async' show Completer, Timer;

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
  PushTransitionGate? _gate;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready || _gate != null) return;
    final gate = PushTransitionGate()..attachRoute(context);
    if (gate.isSettled) {
      _ready = true;
      return;
    }
    _gate = gate;
    gate.waitSettled().then((_) {
      if (mounted && !_ready) {
        setState(() => _ready = true);
      }
    });
  }

  @override
  void dispose() {
    _gate?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _ready ? widget.builder(context) : widget.placeholder;
}

/// [PATCH PERF-24] 控制器侧首入路由转场门禁：
/// 网络请求在 initState/onInit 照常第一时间发出，原生播放器初始化/挂载
/// 推迟至路由推入动画完成后执行；且带 450ms 超时与 dispose 安全唤醒兜底。
class PushTransitionGate {
  Completer<void>? _completer;
  Animation<double>? _animation;
  Timer? _failsafeTimer;
  bool _settled = false;
  bool _attached = false;
  bool _awaitingOffstage = false;

  bool get isSettled => _settled;

  /// 从 [BuildContext] 绑定当前 [ModalRoute] 的动画，并处理 HeroController
  /// 首帧 `offstage == true`（动画临时代理为 completed）的情况。
  void attachRoute(BuildContext context) {
    final route = ModalRoute.of(context);
    attach(route?.animation, offstage: route?.offstage ?? false);
  }

  void attach(Animation<double>? animation, {bool offstage = false}) {
    if (_settled || _attached) return;
    _attached = true;
    if (animation == null) {
      markSettled();
      return;
    }
    if (!offstage && animation.status != AnimationStatus.forward) {
      markSettled();
      return;
    }
    _awaitingOffstage = offstage;
    _animation = animation..addStatusListener(_onStatus);
    _failsafeTimer ??= Timer(const Duration(milliseconds: 450), markSettled);
    if (offstage) {
      // HeroController 在首帧 didPush 末尾注册了 postFrameCallback 恢复 offstage=false；
      // 此处排在其后的回调若发现并非 forward（例如 0ms 转场）会立即放行。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_settled || !_awaitingOffstage) return;
        _awaitingOffstage = false;
        if (_animation?.status != AnimationStatus.forward) {
          markSettled();
        }
      });
    }
  }

  void _onStatus(AnimationStatus status) {
    if (_awaitingOffstage) {
      if (status == AnimationStatus.forward) {
        _awaitingOffstage = false;
        return;
      }
      if (status == AnimationStatus.completed) {
        return;
      }
    }
    if (status != AnimationStatus.forward) {
      markSettled();
    }
  }

  Future<void> waitSettled() {
    if (_settled) return Future.value();
    _failsafeTimer ??= Timer(const Duration(milliseconds: 450), markSettled);
    return (_completer ??= Completer<void>()).future;
  }

  void markSettled() {
    if (_settled) return;
    _settled = true;
    _failsafeTimer?.cancel();
    _failsafeTimer = null;
    _animation?.removeStatusListener(_onStatus);
    _animation = null;
    final completer = _completer;
    _completer = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  void dispose() {
    markSettled();
  }
}
