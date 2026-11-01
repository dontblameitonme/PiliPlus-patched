import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/models_new/fav/fav_folder/list.dart';
import 'package:PiliPlus/utils/bili_utils.dart';
import 'package:PiliPlus/utils/num_utils.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

// [PATCH UI-03] 收藏夹卡片“文件夹”观感（方案 B）：
// 原先用单边偏移的 BoxShadow 暗示“文件夹”堆叠，左右不对称、容易被误认成渲染错误；
// 改为在封面正上方叠两层逐渐变窄、左右对称居中的“边”，层次更清晰且不抢封面视觉。
// 两层经由正常 Column 布局（而非 Positioned 叠加）挤占的高度，通过等量缩小下方
// 封面与标题间距来抵消，卡片总高度与改动前基本一致，不影响横向列表的排版与滚动。
class FavFolderItem extends StatelessWidget {
  const FavFolderItem({
    super.key,
    required this.item,
    required this.onPop,
  });

  final FavFolderInfo item;
  final VoidCallback onPop;

  static const double _coverWidth = 180;
  static const double _coverHeight = 110;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heroTag = Utils.makeHeroTag(item.id);
    return GestureDetector(
      onTap: () => Get.toNamed(
        '/favDetail',
        arguments: item,
        parameters: {
          'mediaId': item.id.toString(),
          'heroTag': heroTag,
        },
      )?.whenComplete(onPop),
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _coverWidth,
            child: Column(
              children: [
                // 最上层：更窄的一条边
                _folderEdge(
                  theme,
                  width: _coverWidth * 0.46,
                  height: 4,
                  alpha: 0.3,
                ),
                const SizedBox(height: 2),
                // 紧贴封面的一层：更宽的一条边
                _folderEdge(
                  theme,
                  width: _coverWidth * 0.68,
                  height: 5,
                  alpha: 0.5,
                ),
                const SizedBox(height: 3),
                Hero(
                  tag: heroTag,
                  child: NetworkImgLayer(
                    src: item.cover,
                    width: _coverWidth,
                    height: _coverHeight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            ' ${item.title}',
            maxLines: 1,
            overflow: .ellipsis,
            style: const TextStyle(height: 1.42, letterSpacing: 0.3),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.play_arrow,
                  size: 12,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 2),
                Text(
                  '${NumUtils.numFormat(item.mediaCount)}  ·  '
                  '${BiliUtils.isPublicFavText(item.attr)}',
                  style: theme.textTheme.labelSmall!.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 文件夹叠层的一条“边”：左右对称居中，颜色取自主题中性色阶
  Widget _folderEdge(
    ThemeData theme, {
    required double width,
    required double height,
    required double alpha,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.onInverseSurface.withValues(alpha: alpha),
        borderRadius: BorderRadius.vertical(top: Radius.circular(height / 2)),
      ),
    );
  }
}
