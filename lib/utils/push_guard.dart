/// 视频卡片连点防重入锁：
/// 防止异步获取 cid 期间或推入路由动画期间重复点击，同时推入多个视频页导致双重播放。
// [PATCH BUG-11] 新增文件，上游没有
abstract final class PushGuard {
  static bool _busy = false;

  static const _cooldown = Duration(milliseconds: 500);

  static Future<void> run(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    try {
      await action();
    } finally {
      Future.delayed(_cooldown, () => _busy = false);
    }
  }
}
