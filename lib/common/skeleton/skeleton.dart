import 'package:material_ui/material_ui.dart';

/// [PATCH PERF-24] 移除每卡独立的 120Hz AnimationController 与 ShaderMask 离屏合成，
/// 直接返回静态骨架占位，消除转场与首屏加载期间的多重 Ticker/saveLayer 开销。
class Skeleton extends StatelessWidget {
  final Widget child;

  const Skeleton({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}
