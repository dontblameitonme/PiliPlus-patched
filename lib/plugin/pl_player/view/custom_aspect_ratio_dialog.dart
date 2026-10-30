import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/utils/feed_back.dart';

/// 预设立项定义
typedef _PresetRatio = ({String label, double width, double height, String? note});

const List<_PresetRatio> _presets = [
  (label: '16:9', width: 16.0, height: 9.0, note: null),
  (label: '17:9', width: 17.0, height: 9.0, note: null),
  (label: '17.5:9 ★', width: 17.5, height: 9.0, note: '长屏消除黑边黄金比例'),
  (label: '18:9', width: 18.0, height: 9.0, note: null),
  (label: '2.35:1', width: 2.35, height: 1.0, note: null),
];

/// 弹出自定义画框比例与消黑边缩放设置对话框
Future<void> showCustomAspectRatioDialog(
  BuildContext context,
  PlPlayerController controller,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => _CustomAspectRatioDialog(controller: controller),
  );
}

class _CustomAspectRatioDialog extends StatefulWidget {
  const _CustomAspectRatioDialog({required this.controller});

  final PlPlayerController controller;

  @override
  State<_CustomAspectRatioDialog> createState() =>
      _CustomAspectRatioDialogState();
}

class _CustomAspectRatioDialogState extends State<_CustomAspectRatioDialog> {
  late final TextEditingController _widthController;
  late final TextEditingController _heightController;
  late double _currentZoom;
  String? _selectedPreset;
  double? _calculatedRatio;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentZoom = widget.controller.framedZoomScale.value;

    final currentLabel = widget.controller.customAspectLabel.value;
    final currentRatio = widget.controller.customAspectRatio.value;

    // 解析当前比例文字，尝试提取宽与高
    String initialWidth = '16';
    String initialHeight = '9';
    if (currentLabel.contains(':')) {
      final parts = currentLabel.split(':');
      if (parts.length == 2) {
        initialWidth = parts[0].trim();
        initialHeight = parts[1].trim();
      }
    } else {
      initialWidth = currentRatio.toStringAsFixed(2);
      initialHeight = '1';
    }

    _widthController = TextEditingController(text: initialWidth);
    _heightController = TextEditingController(text: initialHeight);

    // 检查是否匹配某个预设
    for (final p in _presets) {
      if (currentLabel == p.label || currentLabel == p.label.replaceAll(' ★', '')) {
        _selectedPreset = p.label;
        break;
      }
    }

    _recalculateRatio();

    _widthController.addListener(_onInputChanged);
    _heightController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    setState(() {
      _recalculateRatio();
      // 输入框变化时，若已不在预设值范围内，取消预设 Chip 高亮
      _checkPresetMatch();
    });
  }

  void _checkPresetMatch() {
    final w = double.tryParse(_widthController.text.trim());
    final h = double.tryParse(_heightController.text.trim());
    if (w == null || h == null) {
      _selectedPreset = null;
      return;
    }
    for (final p in _presets) {
      if ((p.width - w).abs() < 0.001 && (p.height - h).abs() < 0.001) {
        _selectedPreset = p.label;
        return;
      }
    }
    _selectedPreset = null;
  }

  void _recalculateRatio() {
    final wText = _widthController.text.trim();
    final hText = _heightController.text.trim();
    final w = double.tryParse(wText);
    final h = double.tryParse(hText);

    if (w == null || h == null || h <= 0 || w <= 0) {
      _calculatedRatio = null;
      _errorMessage = '请输入大于 0 的有效数值';
      return;
    }

    final ratio = w / h;
    _calculatedRatio = ratio;

    if (ratio < 0.5 || ratio > 3.5) {
      _errorMessage = '比例必须介于 0.5 到 3.5 之间';
    } else {
      _errorMessage = null;
    }
  }

  void _selectPreset(_PresetRatio preset) {
    feedBack();
    setState(() {
      _selectedPreset = preset.label;
      _widthController.text =
          preset.width.toString().replaceAll(RegExp(r'\.0$'), '');
      _heightController.text =
          preset.height.toString().replaceAll(RegExp(r'\.0$'), '');
      _recalculateRatio();
    });
  }

  void _onResetDefault() {
    feedBack();
    widget.controller.resetCustomAspectRatio();
    SmartDialog.showToast('画框比例已恢复默认 16:9');
    Navigator.of(context).pop();
  }

  void _onSaveAndApply() {
    if (_calculatedRatio == null || _errorMessage != null) return;
    feedBack();

    final wText = _widthController.text.trim();
    final hText = _heightController.text.trim();
    final label = (hText == '1' || hText == '1.0') ? '$wText:1' : '$wText:$hText';

    widget.controller.updateCustomAspectRatio(
      _calculatedRatio!,
      label,
      zoomScale: _currentZoom,
    );

    SmartDialog.showToast('画框比例已设为 $label');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isValid = _calculatedRatio != null && _errorMessage == null;

    return AlertDialog(
      title: const Text(
        '自定义画框比例与缩放设置',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 常用预设画框
            const Text(
              '常用预设画框：',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets.map((preset) {
                final isSelected = _selectedPreset == preset.label;
                return ChoiceChip(
                  label: Text(
                    preset.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (_) => _selectPreset(preset),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // 手动输入比例
            const Text(
              '手动输入比例：',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('宽：', style: TextStyle(fontSize: 14)),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _widthController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('比', style: TextStyle(fontSize: 14)),
                ),
                const Text('高：', style: TextStyle(fontSize: 14)),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _heightController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // 当前比值与校验提示
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              )
            else if (_calculatedRatio != null)
              Text(
                '(当前比值：${_calculatedRatio!.toStringAsFixed(3)})',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),

            const SizedBox(height: 18),

            // 默认消黑边缩放倍率滑块
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '默认消黑边缩放 (Zoom)：',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  '(当前: ${_currentZoom.toStringAsFixed(2)}x)',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            Slider(
              value: _currentZoom,
              min: 1.0,
              max: 2.0,
              divisions: 20, // 步进 0.05
              label: '${_currentZoom.toStringAsFixed(2)}x',
              onChanged: (val) {
                setState(() {
                  _currentZoom = double.parse(val.toStringAsFixed(2));
                });
              },
            ),

            // 黄金方案提示
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.tips_and_updates_outlined,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '提示: 17.5:9 配合 1.25x 放大是消除多数电影上下黑边的黄金方案',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _onResetDefault,
          child: Text(
            '恢复默认 16:9',
            style: TextStyle(color: theme.colorScheme.outline),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: isValid ? _onSaveAndApply : null,
          child: const Text('保存并应用'),
        ),
      ],
    );
  }
}
