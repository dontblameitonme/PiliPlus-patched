part of 'package:PiliPlus/pages/live_room/controller.dart';

mixin _LiveDMMixin
    on GetxController, _LiveDataMixin, _LiveSCMixin, _LiveBlockMixin {
  LiveDmInfoData? dmInfo;
  List<RichTextItem>? savedDanmaku;

  int builtLength = 0;
  final messages = <dynamic>[].obs;
  bool get shouldRefresh => builtLength != messages.length;

  bool autoScroll = true;
  late final disableAutoScroll = false.obs;
  late final ScrollController scrollController;

  @override
  void onInit() {
    scrollController = ScrollController()..addListener(_scrollListener);
    super.onInit();
  }

  Future<void> prefetchDM() async {
    final res = await LiveHttp.liveRoomDmPrefetch(roomId: roomId);
    if (res case Success(:final response)) {
      if (response != null && response.isNotEmpty) {
        messages.addAll(
          response.where((item) => !isBlocked(item.text, item.extra.mid)),
        );
        scrollToBottom();
      }
    } else {
      if (kDebugMode) {
        Utils.reportError(res.toString());
      }
    }
  }

  void refreshMsgIfNeeded() {
    if (shouldRefresh) {
      WidgetsBinding.instance.addPostFrameCallback((_) => messages.refresh());
    }
  }

  Timer? _scrollTimer;

  /// [PATCH PERF-14] trailing-edge scheduling so the last messages in a burst are
  /// always scrolled into view (the previous leading throttle dropped them).
  void scrollToBottom() {
    if (_scrollTimer?.isActive ?? false) return;
    _scrollTimer = Timer(const Duration(milliseconds: 200), () {
      _scrollTimer = null;
      WidgetsBinding.instance.addPostFrameCallback(_scrollToBottom);
    });
  }

  void _scrollToBottom([_]) {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.linearToEaseOut,
      );
    }
  }

  void handleJumpToBottom() {
    disableAutoScroll.value = false;
    if (shouldRefresh) {
      messages.refresh();
      WidgetsBinding.instance.addPostFrameCallback(_jumpToBottom);
    } else {
      _jumpToBottom();
    }
  }

  void _jumpToBottom([_]) {
    if (scrollController.hasClients) {
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
    }
  }

  void _scrollListener() {
    final userScrollDirection = scrollController.position.userScrollDirection;
    if (userScrollDirection == .forward) {
      disableAutoScroll.value = true;
    } else if (userScrollDirection == .reverse) {
      final pos = scrollController.position;
      if (pos.maxScrollExtent - pos.pixels <= 100 && disableAutoScroll.value) {
        disableAutoScroll.value = false;
        refreshMsgIfNeeded();
      }
    }
  }

  @override
  void onClose() {
    // [PATCH PERF-14]
    _scrollTimer?.cancel();
    _scrollTimer = null;
    messages.clear();
    savedDanmaku?.clear();
    savedDanmaku = null;
    scrollController
      ..removeListener(_scrollListener)
      ..dispose();
    super.onClose();
  }
}
