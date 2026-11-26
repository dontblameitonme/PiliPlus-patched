import 'package:material_ui/material_ui.dart';

/// [PATCH PERF-24] 隔离分页 loadingState.refresh() 触发的可视区卡片/评论全量重建。
/// 通过自身 State 与 didChangeDependencies() 感知主题/亮度/字号缩放/窗口尺寸变化，
/// 且生命周期跟随 Sliver 回收自动释放；仅在 [data] 或结构版本 [revision] 变化时重构子树。
class MemoizedScrollItem extends StatefulWidget {
  const MemoizedScrollItem({
    super.key,
    required this.data,
    required this.revision,
    required this.builder,
  });

  final Object? data;
  final int revision;
  final WidgetBuilder builder;

  @override
  State<MemoizedScrollItem> createState() => _MemoizedScrollItemState();
}

class _MemoizedScrollItemState extends State<MemoizedScrollItem> {
  Widget? _cached;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    Theme.of(context);
    MediaQuery.maybeSizeOf(context);
    MediaQuery.maybeTextScalerOf(context);
    DefaultTextStyle.of(context);
    _cached = null;
  }

  @override
  void didUpdateWidget(covariant MemoizedScrollItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data || widget.revision != oldWidget.revision) {
      _cached = null;
    }
  }

  @override
  void dispose() {
    _cached = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _cached ??= widget.builder(context);
}
