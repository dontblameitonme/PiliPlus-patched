import 'dart:collection';
import 'dart:io' show File;
import 'dart:typed_data' show Uint8List;

import 'package:PiliPlus/grpc/bilibili/community/service/dm/v1.pb.dart';
import 'package:PiliPlus/grpc/dm.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/data_source.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/danmaku_utils.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:path/path.dart' as path;

class PlDanmakuController {
  PlDanmakuController(
    this._cid,
    this._plPlayerController,
    this._isFileSource,
  ) : _mergeDanmaku = _plPlayerController.mergeDanmaku;

  final int _cid;
  final PlPlayerController _plPlayerController;
  final bool _mergeDanmaku;
  final bool _isFileSource;

  late final _isLogin = Accounts.main.isLogin;

  final Map<int, List<DanmakuElem>> _dmSegMap = HashMap();
  // 已请求的段落标记
  late final Set<int> _requestedSeg = HashSet();

  // [PATCH PERF-09] 异步解析离线弹幕期间若已销毁则丢弃结果
  bool _disposed = false;

  void dispose() {
    _disposed = true;
    _dmSegMap.clear();
    _requestedSeg.clear();
  }

  Future<void> queryDanmaku(int segmentIndex) async {
    if (_isFileSource) {
      return;
    }
    if (_requestedSeg.contains(segmentIndex)) {
      return;
    }
    _requestedSeg.add(segmentIndex);
    final res = await DmGrpc.dmSegMobile(
      cid: _cid,
      segmentIndex: segmentIndex + 1,
    );

    if (res case Success(:final response)) {
      if (response.state == 1) {
        _plPlayerController.dmState.add(_cid);
      }
      handleDanmaku(response.elems);
    } else {
      _requestedSeg.remove(segmentIndex);
    }
  }

  /// 弹幕合并的时间窗口：仅合并 5 秒内出现的同文弹幕
  // [PATCH BUG-04] 合并弹幕改为 5 秒窗口内去重（上游为整段全局去重，会吞弹幕）
  static const int _mergeWindowMs = 5000;

  void handleDanmaku(List<DanmakuElem> elems) {
    if (elems.isEmpty) return;
    final uniques = HashMap<String, DanmakuElem>();
    // [PATCH BUG-04]
    if (_mergeDanmaku) {
      // 按时间排序，保证合并窗口以最早出现的那条为基准
      elems = elems.toList()..sort((a, b) => a.progress.compareTo(b.progress));
    }

    final filters = _plPlayerController.filters;
    final shouldFilter = filters.count != 0;
    for (final element in elems) {
      if (_isLogin) {
        element.isSelf = element.midHash == _plPlayerController.midHash;
      }

      if (!element.isSelf) {
        if (_mergeDanmaku) {
          final elem = uniques[element.content];
          if (elem != null &&
              element.progress - elem.progress <= _mergeWindowMs) {
            elem.count++;
            continue;
          }
          uniques[element.content] = element..count = 1;
        }

        if (shouldFilter && filters.remove(element)) {
          continue;
        }
      }

      final int pos = element.progress ~/ 100; //每0.1秒存储一次
      (_dmSegMap[pos] ??= []).add(element);
    }
  }

  List<DanmakuElem>? getCurrentDanmaku(int progress) {
    if (_isFileSource) {
      initFileDmIfNeeded();
    } else {
      final int segmentIndex = DmUtils.calcSegment(progress);
      if (!_requestedSeg.contains(segmentIndex)) {
        queryDanmaku(segmentIndex);
        return null;
      }
    }
    return _dmSegMap[progress ~/ 100];
  }

  bool _fileDmLoaded = false;

  // [PATCH PERF-09] 用于 compute 的顶层解析函数
  static List<DanmakuElem> _parseDmElems(Uint8List bytes) =>
      DmSegMobileReply.fromBuffer(bytes).elems;

  void initFileDmIfNeeded() {
    if (_fileDmLoaded) return;
    _fileDmLoaded = true;
    _initFileDm();
  }

  @pragma('vm:notify-debugger-on-exception')
  Future<void> _initFileDm() async {
    try {
      final file = File(
        path.join(
          (_plPlayerController.dataSource as FileSource).dir,
          PathUtils.danmakuName,
        ),
      );
      if (!file.existsSync()) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || _disposed) return;
      // [PATCH PERF-09] parse the whole offline danmaku file off the UI isolate.
      final elem = await compute(_parseDmElems, bytes);
      if (_disposed) return;
      handleDanmaku(elem);
    } catch (e, s) {
      Utils.reportError(e, s);
    }
  }
}
