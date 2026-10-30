import 'package:PiliPlus/common/style.dart';
import 'package:material_ui/material_ui.dart' show BoxFit;

enum VideoFitType {
  fill('拉伸', boxFit: BoxFit.fill),
  contain('自动', boxFit: BoxFit.contain),
  cover('裁剪', boxFit: BoxFit.cover),
  fitWidth('等宽', boxFit: BoxFit.fitWidth),
  fitHeight('等高', boxFit: BoxFit.fitHeight),
  none('原始', boxFit: BoxFit.none),
  scaleDown('限制', boxFit: BoxFit.scaleDown),
  ratio_4x3('4:3', aspectRatio: 4 / 3),
  // [Custom Framed Zoom / 16:9及自定义画框居中消黑边缩放]
  // 将原 ratio_16x9 升级为支持定框、自定义比例与内部等比居中消黑边缩放特性的条目
  ratio_16x9(
    '16:9',
    aspectRatio: Style.aspectRatio16x9,
    isCustomFramed: true,
  ),
  ;

  final String desc;
  final BoxFit boxFit;
  final double? aspectRatio;
  final bool isCustomFramed; // 标记是否使用定框居中裁剪缩放容器

  const VideoFitType(
    this.desc, {
    this.boxFit = BoxFit.contain,
    this.aspectRatio,
    this.isCustomFramed = false,
  });
}
