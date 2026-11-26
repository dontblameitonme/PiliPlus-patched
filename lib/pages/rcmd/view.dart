import 'dart:math' as math;

import 'package:PiliPlus/common/skeleton/video_card_v.dart';
import 'package:PiliPlus/common/sliver_single_child_delegate.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/memoized_scroll_item.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_v.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/rcmd/controller.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class RcmdPage extends StatefulWidget {
  const RcmdPage({super.key});

  @override
  State<RcmdPage> createState() => _RcmdPageState();
}

class _RcmdPageState extends State<RcmdPage>
    with AutomaticKeepAliveClientMixin {
  final controller = Get.put(RcmdController());

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = ColorScheme.of(context);
    // [PATCH PERF-24] 移除包裹整屏 CustomScrollView 的整页圆角 hardEdge 裁剪，单卡自带圆角即可
    final child = Padding(
      padding: const .symmetric(horizontal: Style.safeSpace),
      child: refreshIndicator(
        key: controller.refreshKey,
        onRefresh: controller.onRefresh,
        child: CustomScrollView(
          // [PATCH PERF-22] 视口外多预构建半屏，快速滑动时少出空白和卡顿
          scrollCacheExtent: const ScrollCacheExtent.viewport(0.5),
          controller: controller.scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const .only(top: Style.cardSpace, bottom: 100),
              sliver: Obx(
                () => _buildBody(colorScheme, controller.loadingState.value),
              ),
            ),
          ],
        ),
      ),
    );
    if (PlatformUtils.isDesktop && Pref.showRefreshFAB) {
      return ScaffoldLayout(
        body: child,
        fab: Padding(
          padding: const .only(
            right: kFloatingActionButtonMargin,
            bottom: 80 + kFloatingActionButtonMargin,
          ),
          child: FloatingActionButton(
            tooltip: '刷新',
            onPressed: controller.toTopAndRefresh,
            backgroundColor: colorScheme.secondaryContainer,
            foregroundColor: colorScheme.onSecondaryContainer,
            child: const Icon(Icons.refresh),
          ),
        ),
      );
    }
    return child;
  }

  late final gridDelegate = SliverGridDelegateWithExtentAndRatio(
    mainAxisSpacing: Style.cardSpace,
    crossAxisSpacing: Style.cardSpace,
    maxCrossAxisExtent: Pref.recommendCardWidth,
    childAspectRatio: Style.aspectRatio,
    mainAxisExtent: MediaQuery.textScalerOf(context).scale(90),
  );

  Widget _buildBody(
    ColorScheme colorScheme,
    LoadingState<List<dynamic>?> loadingState,
  ) {
    return switch (loadingState) {
      Loading() => _buildSkeleton,
      Success(:final response) =>
        response != null && response.isNotEmpty
            // [PATCH PERF-24] 仅在外层 SliverLayoutBuilder 计算 1 次列宽与封面宽高并下传给子卡
            ? SliverLayoutBuilder(
                builder: (context, constraints) {
                  final crossExtent = constraints.crossAxisExtent;
                  final crossCount = math.max(
                    1,
                    (crossExtent /
                            (gridDelegate.maxCrossAxisExtent +
                                gridDelegate.crossAxisSpacing))
                        .ceil(),
                  );
                  final coverWidth =
                      math.max(
                        0.0,
                        crossExtent -
                            gridDelegate.crossAxisSpacing * (crossCount - 1),
                      ) /
                      crossCount;
                  final coverHeight = coverWidth / Style.aspectRatio;
                  return SliverGrid.builder(
                    gridDelegate: gridDelegate,
                    itemBuilder: (context, index) {
                      // [PATCH PERF-07] 提前 4 项预加载下一页（上游为 index == length - 1）
                      if (index >= response.length - 4) {
                        controller.onLoadMore();
                      }
                      if (controller.lastRefreshAt != null) {
                        if (controller.lastRefreshAt == index) {
                          return GestureDetector(
                            onTap: () => controller
                              ..animateToTop()
                              ..onRefresh(),
                            child: Card(
                              child: Container(
                                alignment: Alignment.center,
                                padding: const .symmetric(horizontal: 10),
                                child: Text(
                                  '上次看到这里\n点击刷新',
                                  textAlign: .center,
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        final actualIndex = index > controller.lastRefreshAt!
                            ? index - 1
                            : index;
                        final item = response[actualIndex];
                        return MemoizedScrollItem(
                          data: (item, coverWidth),
                          revision: controller.listRevision,
                          builder: (_) => VideoCardV(
                            videoItem: item,
                            coverWidth: coverWidth,
                            coverHeight: coverHeight,
                            onRemove: () {
                              if (controller.lastRefreshAt != null &&
                                  actualIndex < controller.lastRefreshAt!) {
                                controller.lastRefreshAt =
                                    controller.lastRefreshAt! - 1;
                              }
                              controller.listRevision++;
                              controller.loadingState
                                ..value.data!.removeAt(actualIndex)
                                ..refresh();
                            },
                          ),
                        );
                      } else {
                        final item = response[index];
                        return MemoizedScrollItem(
                          data: (item, coverWidth),
                          revision: controller.listRevision,
                          builder: (_) => VideoCardV(
                            videoItem: item,
                            coverWidth: coverWidth,
                            coverHeight: coverHeight,
                            onRemove: () {
                              controller.listRevision++;
                              controller.loadingState
                                ..value.data!.removeAt(index)
                                ..refresh();
                            },
                          ),
                        );
                      }
                    },
                    itemCount: controller.lastRefreshAt != null
                        ? response.length + 1
                        : response.length,
                  );
                },
              )
            : HttpError(onReload: controller.onReload),
      Error(:final errMsg) => HttpError(
        errMsg: errMsg,
        onReload: controller.onReload,
      ),
    };
  }

  Widget get _buildSkeleton => SliverGrid(
    gridDelegate: gridDelegate,
    delegate: const SliverSingleChildDelegate(
      count: 6,
      child: VideoCardVSkeleton(),
    ),
  );
}
