import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/video_fit_type.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart';

typedef _AspectPreset = ({String label, double width, double height});

const List<_AspectPreset> _kAspectPresets = [
  (label: '16:9', width: 16, height: 9),
  (label: '17:9', width: 17, height: 9),
  (label: '17.5:9', width: 17.5, height: 9),
  (label: '18:9', width: 18, height: 9),
  (label: '2.35:1', width: 2.35, height: 1),
];

const double _kMinRatio = 0.5;
const double _kMaxRatio = 3.5;
const double _kMinZoom = 1.0;
const double _kMaxZoom = 2.0;
const double _kZoomStep = 0.05;

/// 构建「画面比例」菜单项。
///
/// 定框项（默认 `16:9`）的文字跟随用户自定义比例动态变化；
/// 短按立即激活定框消黑边模式，长按关闭菜单并触发 [onLongPressCustom]。
List<PopupMenuEntry<VideoFitType>> buildVideoFitMenuItems(
  BuildContext menuContext,
  PlPlayerController controller, {
  required VoidCallback onLongPressCustom,
}) {
  const textStyle = TextStyle(color: Colors.white, fontSize: 13);
  return VideoFitType.values.map((boxFit) {
    if (!boxFit.isCustomFramed) {
      return PopupMenuItem<VideoFitType>(
        height: 35,
        padding: const EdgeInsets.only(left: 30),
        value: boxFit,
        onTap: () => controller.toggleVideoFit(boxFit),
        child: Text(boxFit.desc, style: textStyle),
      );
    }
    final label = controller.customAspectLabel.value;
    return PopupMenuItem<VideoFitType>(
      height: 35,
      padding: EdgeInsets.zero,
      value: boxFit,
      onTap: () => controller.toggleVideoFit(boxFit),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () {
          // 关闭菜单后再弹出自定义设置对话框
          Navigator.of(menuContext).pop();
          onLongPressCustom();
        },
        child: Container(
          height: 35,
          width: double.infinity,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 30, right: 16),
          child: Text(label, style: textStyle),
        ),
      ),
    );
  }).toList();
}

/// 弹出「自定义画框比例与缩放设置」对话框
Future<void> showCustomAspectRatioDialog(
  BuildContext context,
  PlPlayerController controller,
) {
  return showDialog<void>(
    context: context,
    builder: (_) => CustomAspectRatioDialog(controller: controller),
  );
}

class CustomAspectRatioDialog extends StatefulWidget {
  const CustomAspectRatioDialog({super.key, required this.controller});

  final PlPlayerController controller;

  @override
  State<CustomAspectRatioDialog> createState() =>
      _CustomAspectRatioDialogState();
}

class _CustomAspectRatioDialogState extends State<CustomAspectRatioDialog> {
  late final TextEditingController _widthCtr;
  late final TextEditingController _heightCtr;
  late double _zoom;

  @override
  void initState() {
    super.initState();
    final (w, h) = _parseLabel(
      widget.controller.customAspectLabel.value,
      widget.controller.customAspectRatio.value,
    );
    _widthCtr = TextEditingController(text: _fmt(w));
    _heightCtr = TextEditingController(text: _fmt(h));
    _zoom = _snapZoom(widget.controller.defaultFramedZoomScale);
  }

  @override
  void dispose() {
    _widthCtr.dispose();
    _heightCtr.dispose();
    super.dispose();
  }

  static double _snapZoom(double value) {
    final snapped = (value / _kZoomStep).roundToDouble() * _kZoomStep;
    return snapped.clamp(_kMinZoom, _kMaxZoom);
  }

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  /// 从标签（如 `17.5:9`）中解析宽高；解析失败时用比值回退为 `x:1`
  static (double, double) _parseLabel(String label, double ratio) {
    final parts = label.split(RegExp(r'\s*[:：]\s*'));
    if (parts.length == 2) {
      final w = double.tryParse(parts[0].trim());
      final h = double.tryParse(parts[1].split(' ').first.trim());
      if (w != null && h != null && w > 0 && h > 0) {
        return (w, h);
      }
    }
    return (double.parse(ratio.toStringAsFixed(3)), 1);
  }

  double? get _width => double.tryParse(_widthCtr.text.trim());
  double? get _height => double.tryParse(_heightCtr.text.trim());

  double? get _ratio {
    final w = _width;
    final h = _height;
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    final r = w / h;
    return r.isFinite ? r : null;
  }

  String? get _errorText {
    final r = _ratio;
    if (_widthCtr.text.trim().isEmpty || _heightCtr.text.trim().isEmpty) {
      return '请输入宽和高';
    }
    if (r == null) return '请输入大于 0 的有效数字';
    if (r < _kMinRatio || r > _kMaxRatio) return '比例必须介于 0.5 到 3.5 之间';
    return null;
  }

  void _applyPreset(_AspectPreset preset) {
    setState(() {
      _widthCtr.text = _fmt(preset.width);
      _heightCtr.text = _fmt(preset.height);
    });
  }

  void _resetDefault() {
    widget.controller.resetCustomAspectRatio();
    Navigator.of(context).pop();
    SmartDialog.showToast('画框比例已恢复为 16:9');
  }

  void _save() {
    final r = _ratio;
    if (r == null || _errorText != null) return;
    final label = '${_fmt(_width!)}:${_fmt(_height!)}';
    widget.controller.updateCustomAspectRatio(r, label, zoomScale: _zoom);
    Navigator.of(context).pop();
    SmartDialog.showToast('画框比例已设为 $label');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ratio = _ratio;
    final error = _errorText;
    final currentLabel = ratio == null
        ? null
        : '${_fmt(_width!)}:${_fmt(_height!)}';

    final inputFormatters = [
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
    ];

    Widget numberField(TextEditingController ctr, String label) {
      return SizedBox(
        width: 72,
        child: TextField(
          controller: ctr,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: inputFormatters,
          textAlign: TextAlign.center,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            isDense: true,
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      );
    }

    return AlertDialog(
      title: const Text('自定义画框比例与缩放设置'),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('常用预设画框：', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _kAspectPresets.map((preset) {
                return ChoiceChip(
                  label: Text(
                    preset.label == '17.5:9'
                        ? '${preset.label} ★'
                        : preset.label,
                  ),
                  selected: currentLabel == preset.label,
                  onSelected: (_) => _applyPreset(preset),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text('手动输入比例：', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                numberField(_widthCtr, '宽'),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('比'),
                ),
                numberField(_heightCtr, '高'),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    ratio == null
                        ? '当前比值：-'
                        : '当前比值：${ratio.toStringAsFixed(3)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 6),
              Text(
                error,
                style: TextStyle(color: colorScheme.error, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              '默认画面消黑边缩放 (Zoom)：${_zoom.toStringAsFixed(2)}x',
              style: theme.textTheme.titleSmall,
            ),
            Row(
              children: [
                const Text('1.0x'),
                Expanded(
                  child: Slider(
                    min: _kMinZoom,
                    max: _kMaxZoom,
                    divisions: ((_kMaxZoom - _kMinZoom) / _kZoomStep).round(),
                    value: _zoom,
                    label: '${_zoom.toStringAsFixed(2)}x',
                    onChanged: (value) =>
                        setState(() => _zoom = _snapZoom(value)),
                  ),
                ),
                const Text('2.0x'),
              ],
            ),
            Text(
              '提示：17.5:9 配合 1.25x 放大是消除多数电影上下黑边的黄金方案',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _resetDefault,
          child: const Text('恢复默认 16:9'),
        ),
        TextButton(
          onPressed: Navigator.of(context).pop,
          child: const Text('取消'),
        ),
        FilledButton.tonal(
          onPressed: error == null ? _save : null,
          child: const Text('保存并应用'),
        ),
      ],
    );
  }
}
