import 'dart:async';
import 'dart:math' as math;

import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/memoized_scroll_item.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/dynamic/dynamics_type.dart';
import 'package:PiliPlus/models/dynamics/result.dart';
import 'package:PiliPlus/pages/dynamics/controller.dart';
import 'package:PiliPlus/pages/dynamics/widgets/dynamic_panel.dart';
import 'package:PiliPlus/pages/dynamics_tab/controller.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/waterfall.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class DynamicsTabPage extends StatefulWidget {
  const DynamicsTabPage({super.key, required this.dynamicsType});

  final DynamicsTabType dynamicsType;

  @override
  State<DynamicsTabPage> createState() => _DynamicsTabPageState();
}

class _DynamicsTabPageState extends State<DynamicsTabPage>
    with AutomaticKeepAliveClientMixin, DynMixin {
  final dynamicsController = Get.putOrFind(DynamicsController.new);
  late final DynamicsTabController controller;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    controller = Get.putOrFind(
      () => DynamicsTabController(dynamicsType: widget.dynamicsType),
      tag: widget.dynamicsType.name,
    );
    super.initState();
  }

  Future<void> onRefresh() {
    dynamicsController.singleRefresh();
    return controller.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return refreshIndicator(
      key: controller.refreshKey,
      onRefresh: onRefresh,
      child: CustomScrollView(
        // [PATCH PERF-22] 视口外多预构建半屏，快速滑动时少出空白和卡顿
        scrollCacheExtent: const ScrollCacheExtent.viewport(0.5),
        physics: const AlwaysScrollableScrollPhysics(),
        controller: controller.scrollController,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 100),
            sliver: buildPage(
              Obx(() => _buildBody(controller.loadingState.value)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(LoadingState<List<DynamicItemModel>?> loadingState) {
    return switch (loadingState) {
      Loading() => dynSkeleton,
      Success(:final response) =>
        response != null && response.isNotEmpty
            // [PATCH PERF-24] 仅在外层 SliverLayoutBuilder 计算一次卡片列宽并下传，消除动态卡片 LayoutBuilder
            ? SliverLayoutBuilder(
                builder: (context, constraints) {
                  final crossExtent = constraints.crossAxisExtent;
                  final double cardWidth;
                  if (GlobalData().dynamicsWaterfallFlow) {
                    const crossSpacing = 4.0;
                    final crossCount = math.max(
                      1,
                      (crossExtent /
                              (dynGridDelegate.maxCrossAxisExtent +
                                  crossSpacing))
                          .ceil(),
                    );
                    cardWidth =
                        math.max(
                          0.0,
                          crossExtent - crossSpacing * (crossCount - 1),
                        ) /
                        crossCount;
                    return SliverMasonryGrid(
                      crossAxisSpacing: crossSpacing,
                      gridDelegate: dynGridDelegate,
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            _itemBuilder(response, index, cardWidth),
                        childCount: response.length,
                      ),
                    );
                  } else {
                    cardWidth = crossExtent;
                    return SliverList.builder(
                      itemBuilder: (context, index) =>
                          _itemBuilder(response, index, cardWidth),
                      itemCount: response.length,
                    );
                  }
                },
              )
            : HttpError(onReload: controller.onReload),
      Error(:final errMsg) => HttpError(
        errMsg: errMsg,
        onReload: controller.onReload,
      ),
    };
  }

  Widget _itemBuilder(
    List<DynamicItemModel> list,
    int index,
    double cardWidth,
  ) {
    // [PATCH PERF-07] 提前 4 项预加载下一页（上游为 index == length - 1）
    if (index >= list.length - 4) {
      controller.onLoadMore();
    }
    final item = list[index];
    return MemoizedScrollItem(
      data: (item, item.visible, item.modules.moduleFold == null, cardWidth),
      revision: controller.listRevision,
      builder: (_) => DynamicPanel(
        item: item,
        maxWidth: cardWidth,
        onRemove: (idStr) => controller.onRemove(index, idStr),
        onBlock: () => controller.onBlock(index),
        onUnfold: () => controller.onUnfold(item, index),
      ),
    );
  }
}
