# PiliPlus-patched 改动说明

本仓库基于上游 [bggRGjQaUbCoE/PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)，在提交 `cb1773944`（upgrade deps）之上做了下面这些修改。

代码里每处改动都加了 `[PATCH <编号>]` 注释，用下面的命令就能找到全部改动：

```bash
grep -rn "\[PATCH" lib            # 全部改动
grep -rn "\[PATCH BUG-09\]" lib   # 某一项
git diff cb1773944 -- lib         # 和上游基线对比
```

## 合并上游更新的建议

1. `git remote add upstream https://github.com/bggRGjQaUbCoE/PiliPlus.git && git fetch upstream`
2. `git merge upstream/main`（或者 rebase）。遇到冲突时，先 grep 冲突文件里的 `[PATCH`，确认每一处补丁都还在。
3. 冲突比较多的文件：`lib/plugin/pl_player/view/view.dart`、`lib/plugin/pl_player/controller.dart`、`lib/pages/video/reply/widgets/reply_item_grpc.dart`、`lib/pages/video/view.dart`。
4. 如果上游已经修掉同一个问题，删掉对应的 PATCH，以上游为准。
5. 合并后先跑 `flutter analyze`，再手动测一下：画面比例菜单、评论区加载更多、直播间公屏、侧滑返回。

## 一、自定义画幅（定框消黑边）

| 文件 | 说明 |
| --- | --- |
| `lib/plugin/pl_player/models/video_fit_type.dart` | `ratio_16x9` 标记为 `isCustomFramed`，作为“自定义画框”入口 |
| `lib/utils/storage_key.dart` / `storage_pref.dart` | 新增 `customAspectRatioValue / customAspectRatioLabel / framedPinchScale` 三个存储键，读取时校验 |
| `lib/plugin/pl_player/controller.dart` | 画框比例、标签、捏合缩放倍数（0.5~3.0，1.0=铺满画框，停止变化 400ms 后全局保存）的状态；`updateCustomAspectRatio` / `resetCustomAspectRatio` / `videoFitDesc` |
| `lib/plugin/pl_player/widgets/custom_aspect_ratio_dialog.dart` | **新文件**：比例菜单项构建、设置弹窗（只设比例，缩放靠捏合） |
| `lib/plugin/pl_player/view/view.dart` | 画框渲染（视频 `BoxFit.cover` 铺满画框、画框外纯黑）、双指捏合缩放（始终居中）、双击/还原按钮恢复铺满 |
| `lib/common/widgets/gesture/mouse_interactive_viewer.dart` | 新增 `onExternalScale` / `externalScale` 外部缩放钩子 |
| `lib/pages/live_room/widgets/bottom_control.dart` | 直播间比例菜单接入同一套逻辑 |

## 二、Bug 修复（BUG-xx 对应审计报告编号）

| 编号 | 文件 | 说明 |
| --- | --- | --- |
| BUG-01 | `pages/video/introduction/pgc/controller.dart`, `pages/save_panel/view.dart` | 番剧 episodes/sections 可能为空；`findEpisode` 改为可空 |
| BUG-02 | `pages/episode_panel/view.dart` | 合集 `seasonId!` 空断言 |
| BUG-03 | — | 核对后不是 bug，**没改** |
| BUG-04 | `pages/danmaku/controller.dart` | 合并弹幕改为 5 秒窗口去重 |
| BUG-05 | `pages/common/slide/common_slide_page.dart` | 侧滑 onCancel 和退页阈值 |
| BUG-06 | `common/widgets/flutter/live_list_view.dart` | 补齐 `updateRenderObject` |
| BUG-07 | `pages/video/view.dart` | 旧的 TabController 改到帧结束后再 dispose |
| BUG-08 | `tcp/live.dart` | 包头长度校验 16 字节，递归改为有边界的循环 |
| BUG-09 | `plugin/pl_player/controller.dart`, `view/view.dart` | `isAnim` 改为 getter，监听器遍历快照，Timer 清理，音量监听归属 |
| BUG-10 | `pages/whisper_detail/controller.dart`, `pages/dynamics_detail/controller.dart`, `pages/article/controller.dart` | 私信发送卡死、`late int oid`、别名 Tag 泄漏 |
| BUG-11 | `utils/push_guard.dart`（新）, `video_card_v/h.dart` | 视频卡片连点防重入 |
| BUG-12 | `zan_grpc.dart`, `reply_item_grpc.dart` | 点赞、翻译防重失效 |
| BUG-13 | `pages/common/reply/reply_controller.dart` | 置顶后同步 hasUpTop，加越界保护 |
| BUG-14 | `reply_item_grpc.dart`, `reply_reply/view.dart`, `video/reply/controller.dart` | 楼中楼 heroTag 透传，菜单关闭后用外部 context 弹窗 |
| BUG-15 | `pages/video/introduction/ugc/widgets/page.dart` | 监听器重复注册 |
| BUG-16 | `common/widgets/route_aware_mixin.dart`, `utils/utils.dart` | 订阅真实的 ModalRoute；`makeHeroTag` 改用自增序号（格式 `<v>_<n>`） |
| BUG-17 | `image_viewer/viewer.dart`, `pl_player/view/widgets.dart` | `_downPos` 空安全，进度条预览雪碧图行列计算，ui.Image 释放 |
| BUG-18 | `animated_height.dart`, `pl_player/view/view.dart`, `search/member/whisper_detail` 页面 | reverseDuration 生效，mounted 检查，dispose 时显式 Get.delete |
| BUG-19 | `services/audio_handler.dart` | `_lastPos` 去重失效 |
| BUG-20 | `text_more/paragraph_more.dart` | 列表复用后短文本误触“查看更多” |
| BUG-21 | `text_ellipsis/paragraph_ellipsis.dart`, `superchat_card.dart` | `.last` 越界；延迟移除 Timer |

## 三、性能优化（PERF-xx）

| 编号 | 说明 | 状态 |
| --- | --- | --- |
| PERF-02 | MiniScaffold / 侧滑页改用 ClipRect + FractionalTranslation + RepaintBoundary | ✅ |
| PERF-03 | 视频页 didPopNext 等返回动画结束后再初始化播放器 | ✅ |
| PERF-04 | VideoHeader maxExtent 短路 | ⛔ 没改：上游作者特意注释掉了，展开/收起动画依赖它 |
| PERF-05 | 首页顶栏 RepaintBoundary，缩短动画时长 | ✅（只做了保守部分） |
| PERF-06 | 评论分词正则缓存，build 中不再 try-catch | ✅ |
| PERF-07 | 加载更多失败重试，提前 4 项预加载（62 个列表页） | ✅ |
| PERF-08 | 弹幕 AnimatedOpacity | ⛔ 没改：canvas_danmaku 的 DanmakuOption 没有 opacity |
| PERF-09 | 评论列表 gRPC 后台解析（阈值 64KB），离线弹幕 compute 解析 | ✅ 部分（没有全局默认 isolate，HTTP 压缩方式未改） |
| PERF-10 | CustomHeightWidget minHeight=0；PublishRoute 时长和曲线 | ✅ |
| PERF-11 | GalleryViewer GlobalKey / Hero tag | ⛔ 没改：GlobalKey 是 Hero 动画需要的；按 url 生成 tag 会导致重复 Hero 崩溃 |
| PERF-12 | 主评论区 SuperSliverList | ✅（动态卡片 ValueKey 没加） |
| PERF-13 | AppBarAni 隐藏时 Offstage；迷你进度条隐藏时不构建 | ✅ |
| PERF-14 | 直播公屏表情正则缓存；滚到底改为尾缘触发 | ✅ |
| PERF-15 | 内存不足时清空图片缓存；**按显示尺寸请求 CDN 缩略图**（`ImageUtils.thumbnailUrl` / `NetworkImgLayer`，尺寸按 40px 向上取整，gif 除外，设置 → 外观 →“按显示尺寸加载图片”，默认开） | ✅（推荐页圆角裁剪保留） |
| PERF-16 | 弹幕 100ms 分桶补齐 | ✅ |
| PERF-17 | 下载/离线页不再在 build 里调用 existsSync | ✅ |
| PERF-18 | Android Impeller 开关（设置 → 外观 →“启用 Impeller 渲染（实验性）”，默认关，重启生效）。Dart 端写入标记文件 `<filesDir>/enable_impeller`，`MainActivity.onCreate` 在引擎创建前带 `--enable-impeller=true` 初始化 FlutterLoader | ✅ |
| PERF-19 | 在线人数只在播放时轮询 | ✅ |
| PERF-20 | `_round` 数值化；挂件尺寸取整 | ✅ |
| PERF-21 | 新增 `DeferUntilRouteSettled`：页面进场动画结束后再构建视频页的相关推荐网格、动态/专栏/音乐等详情页的评论列表；播放器底部控制栏（`AppBarAni(lazy: true)`）首次显示时才构建 | ✅ |
| PERF-22 | 视频评论区、楼中楼、推荐流、动态流、动态详情的 `scrollCacheExtent` 设为 0.5 屏 | ✅ |
| PERF-23 | 评论正文 InlineSpan 按 (Content, Element, ColorScheme) 缓存，加载更多刷新列表时不再重新排版可见评论 | ✅ |

## 四、界面调整

| 编号 | 文件 | 说明 |
| --- | --- | --- |
| UI-01 | `pages/video/introduction/ugc/view.dart` | 移除视频下方操作栏的“缓存”按钮（右上角菜单仍有“缓存视频”） |
| UI-02 | `plugin/pl_player/view/view.dart`、`plugin/pl_player/controller.dart`、`utils/storage_*.dart`、`pages/setting/models/style_settings.dart` | 新增设置“全屏时避让挖孔/屏下摄像头”（默认关）：全屏播放时控件不再按挖孔区域内缩，铺满左右边缘 |
| UI-03 | `pages/mine/widgets/fav_item.dart` | 收藏夹卡片“文件夹”观感改为方案 B：封面正上方叠两层逐渐变窄、左右对称居中的边（替换原单边偏移投影）；信息行改为「▶ 播放数 · 公开/私密」，数据来源不变（`mediaCount`） |

## 五、新视频默认画面比例 + “保持上次使用的画面比例”开关（R1）

| 文件 | 说明 |
| --- | --- |
| `utils/storage_key.dart` | `VideoBoxKey` 新增 `rememberVideoFit` 存储键 |
| `utils/storage_pref.dart` | `Pref.rememberVideoFit`，默认 `false` |
| `plugin/pl_player/controller.dart` | `rememberVideoFit`（Rx）、`setRememberVideoFit()`；`setDataSource` 中按 `aid/bvid+cid+epid`（或 `FileSource.dir`）识别“新视频”（含分 P/分集切换，不含清晰度切换等同一视频重新初始化），关闭开关时新视频强制使用「默认」（`contain`）比例，不读取也不覆盖已保存的 `_prefFit`；直播不参与该判断，行为不变 |
| `plugin/pl_player/widgets/custom_aspect_ratio_dialog.dart` | 弹窗内新增“保持上次使用的画面比例”开关（切换立即生效并持久化）；“恢复默认 16:9”同时关闭该开关，提示语改为“已恢复默认设置” |

行为：开关默认关闭，每个新打开的视频（无论从哪个入口进入、含分 P/分集切换）都以「默认」比例呈现，不继承上一次播放设置的比例；同一次播放内手动切换比例仍立即生效且不受影响；开关打开后恢复为开启前的原始“全局记忆上一次比例”行为。升级后已保存的比例记录不会被删除，打开开关即可继续沿用。

## 六、播放详情页操作栏左右对齐（R2）

| 文件 | 说明 |
| --- | --- |
| `pages/video/introduction/ugc/widgets/action_item.dart` | `ActionItem` 新增 `alignment`（`CrossAxisAlignment`，默认 `center`），用于控制图标+文字在竖屏整行布局下的左右对齐 |
| `pages/video/introduction/ugc/view.dart` | `actionGrid` 新增 `isHorizontal` 参数；竖屏独占一行时，首项（点赞）左对齐、末项（分享）右对齐，与头像/标题、推荐卡片的左右边距（`Style.safeSpace`）对齐；横屏嵌入头像行的布局不变 |
| `pages/video/introduction/pgc/view.dart` | 番剧/影视详情页操作栏同样首项左对齐、末项右对齐，与 UGC 规则一致 |

## 七、构建

`.github/workflows/android_arm64.yml`：手动触发，只编译 arm64-v8a 的 APK。如果填了 tag，会同时发布到 GitHub Release。
没有配置签名 Secrets（`SIGN_KEYSTORE_BASE64` / `KEYSTORE_PASSWORD` / `KEY_ALIAS` / `KEY_PASSWORD`）时，用 runner 自动生成的 debug 签名，每次构建的签名都不一样。
