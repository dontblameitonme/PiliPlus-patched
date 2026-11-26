import 'package:PiliPlus/models/common/stat_type.dart';
import 'package:PiliPlus/utils/num_utils.dart';
import 'package:material_ui/material_ui.dart';

class StatWidget extends StatelessWidget {
  final StatType type;
  final dynamic value;
  final Color? color;
  final double iconSize;

  const StatWidget({
    super.key,
    required this.type,
    required this.value,
    this.color,
    this.iconSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    // [PATCH PERF-24] 使用 ColorScheme.of 避免订阅整个 ThemeData
    final color =
        this.color ??
        ColorScheme.of(context).outline.withValues(alpha: 0.8);
    return Row(
      spacing: 2,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          type.iconData,
          semanticLabel: type.label,
          size: iconSize,
          color: color,
        ),
        Text(
          NumUtils.numFormat(value),
          style: TextStyle(fontSize: 12, color: color),
        ),
      ],
    );
  }
}
