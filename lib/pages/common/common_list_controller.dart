import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/common/common_controller.dart';
import 'package:get/get.dart';

abstract class CommonListController<R, T> extends CommonController<R, T> {
  int page = 1;
  bool isEnd = false;
  bool get endIfNullOrEmpty => true;
  bool get hasFooter => false;

  /// 加载下一页失败（如网络波动、风控 -412），用于在列表底部展示「点击重试」
  // [PATCH PERF-07] 加载更多失败标记（配合列表底部重试）
  bool loadMoreFailed = false;

  /// [PATCH PERF-24] 仅在列表重排/删除/整表刷新时递增；单纯末尾追加页时保持不变，
  /// 配合 MemoizedScrollItem 避免 loadingState.refresh() 引起已显示卡片全量重绘。
  int listRevision = 0;

  @override
  Rx<LoadingState<List<T>?>> loadingState =
      LoadingState<List<T>?>.loading().obs;

  void handleListResponse(List<T> dataList) {}

  List<T>? getDataList(R response) {
    return response as List<T>?;
  }

  void checkIsEnd(int length) {}

  @override
  Future<void> queryData([bool isRefresh = true]) async {
    if (isLoading || (!isRefresh && isEnd)) return;
    isLoading = true;
    final LoadingState<R> res = await customGetData();
    if (res case Success(:final response)) {
      loadMoreFailed = false;
      if (!customHandleResponse(isRefresh, res)) {
        final dataList = getDataList(response);
        if (dataList == null || dataList.isEmpty) {
          if (endIfNullOrEmpty) isEnd = true;
          if (isRefresh) {
            loadingState.value = Success(dataList);
          } else if (hasFooter) {
            loadingState.refresh();
          }
          isLoading = false;
          return;
        }
        handleListResponse(dataList);
        if (isRefresh) {
          listRevision++;
          checkIsEnd(dataList.length);
          loadingState.value = Success(dataList);
        } else if (loadingState.value case Success(:final response)) {
          response!.addAll(dataList);
          checkIsEnd(response.length);
          loadingState.refresh();
        }
      }
      page++;
    } else {
      // [PATCH PERF-07] 刷新失败显示错误页；加载更多失败只标记 loadMoreFailed
      if (isRefresh) {
        if (!handleError(res is Error ? res.errMsg : null)) {
          loadingState.value = res as Error;
        }
      } else {
        // 加载更多失败：标记失败态并刷新列表，使底部不再永久停留在「加载中」
        loadMoreFailed = true;
        handleError(res is Error ? res.errMsg : null);
        if (hasFooter) loadingState.refresh();
      }
    }
    isLoading = false;
  }

  @override
  Future<void> onRefresh() {
    page = 1;
    isEnd = false;
    loadMoreFailed = false;
    listRevision++;
    return super.onRefresh();
  }

  @override
  Future<void> onReload() {
    listRevision++;
    loadingState.value = LoadingState<List<T>?>.loading();
    return super.onReload();
  }
}
