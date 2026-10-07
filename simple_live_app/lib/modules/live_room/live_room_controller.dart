import 'package:simple_live_app/widgets/native_ios/native_time_picker.dart';
import 'package:simple_live_app/widgets/native_ios/native_text_field.dart';
import 'package:simple_live_app/widgets/native_ios/native_buttons.dart';
import 'package:simple_live_app/widgets/native_ios/native_rows.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:simple_live_app/routes/route_path.dart';
import 'package:simple_live_app/services/background_playback_service.dart';
import 'package:simple_live_app/services/ios_audio_session_service.dart';
import 'package:simple_live_app/modules/live_room/live_message_buffer.dart';
import 'package:simple_live_app/modules/live_room/playback_deadline.dart';
import 'package:simple_live_app/modules/live_room/live_status_refresh_policy.dart';

import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:share_plus/share_plus.dart';
import 'package:simple_live_app/app/app_style.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/app/utils/sandbox.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_block.dart';
import 'package:simple_live_app/models/db/history.dart';
import 'package:simple_live_app/modules/live_room/player/player_controller.dart';
import 'package:simple_live_app/modules/settings/danmu_settings_page.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/follow_block_service.dart';
import 'package:simple_live_app/services/follow_service.dart';
import 'package:simple_live_app/services/history_service.dart';
import 'package:simple_live_app/src/rust/api/danmaku_mask.dart';
import 'package:simple_live_app/widgets/desktop_refresh_button.dart';
import 'package:simple_live_app/widgets/follow_user_item.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class LiveRoomController extends PlayerController with WidgetsBindingObserver {
  StreamSubscription<dynamic>? subscription;
  final Site pSite;
  final String pRoomId;
  late LiveDanmaku liveDanmaku;
  late DanmakuMask rustDanmakuMask;

  final danmakuBuffer = LiveMessageBuffer<LiveMessage>();
  Timer? danmakuTimer;
  final _keywordPatterns = <String, Pattern?>{};
  bool _isProcessingBuffer = false;

  LiveRoomController({
    required this.pSite,
    required this.pRoomId,
  }) {
    rxSite = pSite.obs;
    rxRoomId = pRoomId.obs;
    liveDanmaku = site.liveSite.getDanmaku();
    // 抖音应该默认是竖屏的
    if (site.id == "douyin") {
      isVertical.value = true;
    }
  }

  late Rx<Site> rxSite;
  Site get site => rxSite.value;
  late Rx<String> rxRoomId;
  String get roomId => rxRoomId.value;

  Rx<LiveRoomDetail?> detail = Rx<LiveRoomDetail?>(null);
  var online = 0.obs;
  var followed = false.obs;
  var liveStatus = false.obs;
  RxList<LiveSuperChatMessage> superChats = RxList<LiveSuperChatMessage>();

  /// 滚动控制
  final ScrollController scrollController = ScrollController();

  /// 聊天信息
  RxList<LiveMessage> messages = RxList<LiveMessage>();

  /// 当前直播间屏蔽项
  Rx<FollowUserBlock?> followUserBlock = Rx<FollowUserBlock?>(null);

  /// 清晰度数据
  RxList<LivePlayQuality> qualites = RxList<LivePlayQuality>();

  /// 当前清晰度
  var currentQuality = -1;
  var currentQualityInfo = "".obs;

  /// 线路数据
  RxList<String> playUrls = RxList<String>();

  Map<String, String>? playHeaders;

  /// 当前线路
  var currentLineIndex = -1;
  var currentLineInfo = "".obs;

  /// 退出倒计时
  var countdown = 60.obs;

  Timer? autoExitTimer;

  /// 设置的自动关闭时间（分钟）
  var autoExitMinutes = 60.obs;

  ///是否延迟自动关闭
  var delayAutoExit = false.obs;

  /// 是否启用自动关闭
  var autoExitEnable = false.obs;

  /// 是否禁用自动滚动聊天栏
  /// - 当用户向上滚动聊天栏时，不再自动滚动
  var disableAutoScroll = false.obs;

  /// 是否处于后台
  var isBackground = false;

  /// 直播间加载失败
  var loadError = false.obs;
  Error? error;

  int _count = 0;
  int _roomGeneration = 0;
  bool _roomDisposed = false;
  bool _autoExitCompleting = false;
  bool _recoveringPlayback = false;
  bool _resumeAfterInterruption = false;
  bool _danmakuBeforeListening = false;
  final listeningMode = false.obs;
  final _deadline = PlaybackDeadline();
  final _offlinePolicy = LiveStatusRefreshPolicy();
  Timer? _autoExitDeadlineTimer;
  Timer? _reconnectTimer;
  Timer? _playbackWatchdog;
  Timer? _stablePlaybackTimer;
  DateTime _lastPlaybackProgress = DateTime.now();
  Duration _lastPosition = Duration.zero;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<bool>? _roomPlayingSubscription;
  StreamSubscription<BackgroundPlaybackEvent>? _backgroundEvents;
  StreamSubscription<IosAudioSessionEvent>? _iosAudioEvents;
  Future<void> _backgroundSync = Future<void>.value();

  @override
  bool get keepScreenAwake => !listeningMode.value;

  bool get _playbackClosed => _roomDisposed || _autoExitCompleting;
  bool _isCurrent(int generation) => !_playbackClosed && generation == _roomGeneration;

  @override
  void onInit() {
    WidgetsBinding.instance.addObserver(this);
    if (FollowService.instance.followList.isEmpty) {
      FollowService.instance.loadData();
    }
    initAutoExit();
    showDanmakuState.value = AppSettingsController.instance.danmuEnable.value;
    followed.value = FollowService.instance.getFollowExist("${site.id}_$roomId");
    // 解冻：更新 lastWatchTime 并从休眠列表移除
    FollowService.instance.resumeUser("${site.id}_$roomId");
    loadData();

    scrollController.addListener(scrollListener);
    subscription = EventBus.instance.listen(Constant.kUpdateDanmaku, (data) {
      if (danmakuController?.option.fontSize != data as double) {
        updateDanmuOption(danmakuController?.option.copyWith(fontSize: data));
      }
    });
    _initDanmakuMask();
    super.onInit();
    _initMobilePlayback();
  }

  void _initDanmakuMask() async {
    rustDanmakuMask = DanmakuMask(
      baseWindowMs: AppSettingsController.instance.danmuWindowMs.value * 1000,
      bucketCount: AppSettingsController.instance.danmuWindowMs.value,
      useNormalization: AppSettingsController.instance.danmuTextNormalization.value,
      useFrequencyControl: AppSettingsController.instance.danmuFrequencyControl.value,
      maxFrequency: AppSettingsController.instance.danmuMaxFrequency.value,
    );
    danmakuTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) {
        _processDanmakuBuffer();
        // sc同步计时调用 先刷后删
        _count = (_count + 1) % 10;
        if (_count == 0) {
          if (superChats.isNotEmpty) {
            removeSuperChats();
            superChats.refresh();
          }
        }
      },
    );
  }

  Future<void> _processDanmakuBuffer() async {
    if (_isProcessingBuffer || danmakuBuffer.isEmpty || _playbackClosed) return;
    if (isBackground || listeningMode.value) {
      danmakuBuffer.clear();
      return;
    }
    final generation = _roomGeneration;
    _isProcessingBuffer = true;
    try {
      final batch = danmakuBuffer.drain();
      var filteredBatch = batch;
      if (AppSettingsController.instance.danmakuMaskEnable.value && messages.length > 50) {
        final allowed = await rustDanmakuMask.allowListBatch(
          texts: batch.map((msg) => msg.message).toList(),
          nowMs: BigInt.from(DateTime.now().millisecondsSinceEpoch),
        );
        filteredBatch = [
          for (int i = 0; i < batch.length; i++)
            if (allowed[i] == 1) batch[i]
        ];
      }
      if (!_isCurrent(generation) || isBackground || listeningMode.value || filteredBatch.isEmpty) return;
      // One observable update per batch; manual scroll never allows unbounded growth.
      final combined = [...messages, ...filteredBatch];
      messages.assignAll(combined.skip(combined.length > 200 ? combined.length - 200 : 0));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isCurrent(generation)) chatScrollToBottom();
      });
      if (!liveStatus.value || !showDanmakuState.value) return;
      addDanmaku(filteredBatch
          .take(30)
          .map((msg) => DanmakuContentItem(
                msg.message,
                color: Color.fromARGB(255, msg.color.r, msg.color.g, msg.color.b),
              ))
          .toList());
    } catch (e) {
      Log.logPrint(e);
    } finally {
      _isProcessingBuffer = false;
    }
  }

  void scrollListener() {
    if (scrollController.position.userScrollDirection == ScrollDirection.forward) {
      disableAutoScroll.value = true;
    }
  }

  /// 初始化自动关闭倒计时
  void initAutoExit() {
    if (AppSettingsController.instance.autoExitEnable.value) {
      autoExitEnable.value = true;
      autoExitMinutes.value = AppSettingsController.instance.autoExitDuration.value;
      setAutoExit();
    } else {
      autoExitMinutes.value = AppSettingsController.instance.roomAutoExitDuration.value;
    }
  }

  void setAutoExit() {
    autoExitTimer?.cancel();
    _autoExitDeadlineTimer?.cancel();
    _deadline.stop();
    if (!autoExitEnable.value || _playbackClosed) return;
    final duration = Duration(minutes: autoExitMinutes.value.clamp(1, 1439));
    _deadline.start(duration, DateTime.now());
    _refreshAutoExitCountdown();
    autoExitTimer = Timer.periodic(const Duration(seconds: 1), (_) => _refreshAutoExitCountdown());
    _autoExitDeadlineTimer = Timer(duration, () => unawaited(_completeAutoExit()));
  }

  void _refreshAutoExitCountdown() {
    if (_playbackClosed || !autoExitEnable.value) return;
    countdown.value = _deadline.remainingSeconds(DateTime.now());
    if (_deadline.isDue(DateTime.now())) unawaited(_completeAutoExit());
  }

  Future<void> _completeAutoExit() async {
    if (_playbackClosed) return;
    _autoExitCompleting = true;
    autoExitTimer?.cancel();
    _autoExitDeadlineTimer?.cancel();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _deadline.stop();
    autoExitEnable.value = false;
    // Stop playback before leaving; a forced process exit caused cold-start crashes.
    for (final step in <Future<void> Function()>[
      () => BackgroundPlaybackService.instance.stop(),
      () async {
        liveDanmaku.stop();
      },
      () => player.stop(),
      () => IosAudioSessionService.instance.deactivate(),
      () => WakelockPlus.disable(),
    ]) {
      try {
        await step().timeout(const Duration(seconds: 2));
      } catch (e) {
        Log.logPrint(e);
      }
    }
    if (Platform.isIOS) {
      if (fullScreenState.value) await exitFull();
      Get.offAllNamed(RoutePath.kIndex);
    } else if (Platform.isAndroid) {
      try {
        final removed = await const MethodChannel('simple_live/app_window')
            .invokeMethod<bool>('finishAndRemoveTask')
            .timeout(const Duration(seconds: 2));
        if (removed == true) return;
      } catch (e) {
        Log.logPrint(e);
      }
      await SystemNavigator.pop();
    } else {
      await windowManager.destroy();
    }
  }

  // 弹窗逻辑

  void refreshRoom() {
    //messages.clear();
    danmakuBuffer.clear();
    mediaErrorRetryCount = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _offlinePolicy.reset();
    superChats.clear();
    liveDanmaku.stop();

    loadData();
  }

  /// 聊天栏始终滚动到底部
  void chatScrollToBottom() {
    if (scrollController.hasClients) {
      // 如果手动上拉过，就不自动滚动到底部
      if (disableAutoScroll.value) {
        return;
      }
      scrollController.jumpTo(scrollController.position.maxScrollExtent);
    }
  }

  /// 初始化弹幕接收事件
  void initDanmau() {
    liveDanmaku.onMessage = onWSMessage;
    liveDanmaku.onClose = onWSClose;
    liveDanmaku.onReady = onWSReady;
  }

  bool _matchesBlockedKeyword(String text, Iterable<String> keywords) {
    for (final keyword in keywords) {
      if (keyword.isEmpty) continue;
      if (!_keywordPatterns.containsKey(keyword)) {
        if (_keywordPatterns.length >= 512) _keywordPatterns.clear();
        Pattern? pattern;
        try {
          pattern = Utils.isRegexFormat(keyword) ? RegExp(Utils.removeRegexFormat(keyword)) : keyword;
        } catch (_) {/* Invalid patterns never match. */}
        _keywordPatterns[keyword] = pattern;
      }
      final pattern = _keywordPatterns[keyword];
      if (pattern != null && text.contains(pattern)) return true;
    }
    return false;
  }

  /// 接收到WebSocket信息
  void onWSMessage(LiveMessage msg) async {
    if (_playbackClosed) return;
    if (msg.type == LiveMessageType.chat) {
      if (isBackground || listeningMode.value) return;
      if (_matchesBlockedKeyword(msg.message, AppSettingsController.instance.shieldList) ||
          _matchesBlockedKeyword(msg.message, followUserBlock.value?.blockWords ?? <String>[])) {
        return;
      }
      // 当前直播间发言用户屏蔽
      // todo: 更精细化的uid匹配
      var accountInBlock = followUserBlock.value?.blockAccounts.any((item) => item.name == msg.userName);
      if (accountInBlock == true) {
        return;
      }

      danmakuBuffer.add(msg);
    } else if (msg.type == LiveMessageType.online) {
      online.value = msg.data;
    } else if (msg.type == LiveMessageType.superChat) {
      // set newest sc at the top， limit 20 better I think
      if (!isBackground && !listeningMode.value) {
        superChats.assignAll([msg.data as LiveSuperChatMessage, ...superChats].take(20));
      }
    }
  }

  /// 添加当前房间屏蔽词
  void addCurBlockWord(String word) {
    // 为剥离getx做准备
    if (!followUserBlock.value!.blockWords.contains(word) && word != "") {
      followUserBlock.value!.blockWords.add(word);
      FollowBlockService.instance.addBlockWord(siteId: site.id, roomId: roomId, word: word);
      followUserBlock.refresh();
    }
    SmartDialog.showToast("已屏蔽词:$word");
  }

  void delCurBlockWord(String word) {
    if (followUserBlock.value!.blockWords.contains(word)) {
      followUserBlock.value!.blockWords.remove(word);
      FollowBlockService.instance.removeBlockWord(siteId: site.id, roomId: roomId, word: word);
      followUserBlock.refresh();
    }
  }

  /// 添加当前房间屏蔽用户
  void addCurBlockAccount(String accName) {
    bool exists = followUserBlock.value!.blockAccounts.any((acc) => acc.name == accName);
    if (!exists && accName != "") {
      //todo: temp use uid == 0
      var accInMessage = messages.firstWhereOrNull((e) => e.userName == accName);
      var accId = accInMessage?.userId ?? "0";
      var acc = FollowUserBlockAccount(uid: accId, name: accName);
      followUserBlock.value!.blockAccounts.add(acc);
      FollowBlockService.instance.addBlockAccount(siteId: site.id, roomId: roomId, account: acc);
      followUserBlock.refresh();
    }
    SmartDialog.showToast("已屏蔽用户:$accName");
  }

  void delCurBlockAccount(String accName) {
    bool exists = followUserBlock.value!.blockAccounts.any((acc) => acc.name == accName);
    if (exists) {
      followUserBlock.value!.blockAccounts.removeWhere((e) => e.name == accName);
      FollowBlockService.instance.removeBlockAccount(siteId: site.id, roomId: roomId, name: accName);
      followUserBlock.refresh();
    }
  }

  /// 添加一条系统消息
  void addSysMsg(String msg) {
    messages.add(
      LiveMessage(
        type: LiveMessageType.chat,
        userName: "LiveSysMessage",
        message: msg,
        color: LiveMessageColor.white,
      ),
    );
  }

  /// 接收到WebSocket关闭信息
  void onWSClose(String msg) {
    addSysMsg(msg);
  }

  /// WebSocket准备就绪
  void onWSReady() {
    addSysMsg("弹幕服务器连接正常");
  }

  /// 加载直播间信息
  void loadData() async {
    final generation = ++_roomGeneration;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _offlinePolicy.reset();
    try {
      SmartDialog.showLoading(msg: "");
      loadError.value = false;
      addSysMsg("正在读取直播间信息");
      final room = await site.liveSite.getRoomDetail(roomId: roomId);
      if (!_isCurrent(generation)) return;
      detail.value = room;

      if (site.id == Constant.kDouyin) {
        // 1.6.0之前收藏的WebRid
        // 1.6.0收藏的RoomID
        // 1.6.0之后改回WebRid
        if (detail.value!.roomId != roomId) {
          var oldId = roomId;
          rxRoomId.value = detail.value!.roomId;
          if (followed.value) {
            // 更新关注列表
            DBService.instance.deleteFollow("${site.id}_$oldId");
            DBService.instance.addFollow(
              FollowUser(
                id: "${site.id}_$roomId",
                roomId: roomId,
                siteId: site.id,
                userName: detail.value!.userName,
                face: detail.value!.userAvatar,
                addTime: DateTime.now(),
              ),
            );
          } else {
            followed.value = DBService.instance.getFollowExist("${site.id}_$roomId");
          }
        }
      }

      addHistory();
      // 确认房间关注状态
      followed.value = FollowService.instance.getFollowExist("${site.id}_$roomId");
      online.value = detail.value!.online;
      liveStatus.value = detail.value!.status || detail.value!.isRecord;
      followUserBlock.value = FollowBlockService.instance.getBlock(siteId: site.id, roomId: roomId);
      if (liveStatus.value) {
        getSuperChatMessage();
        getPlayQualites();
        addSysMsg("开始连接弹幕服务器");
        initDanmau();
        liveDanmaku.start(detail.value?.danmakuData);
      }
      if (detail.value!.isRecord) {
        addSysMsg("当前主播未开播，正在轮播录像");
      }
    } catch (e) {
      if (!_isCurrent(generation)) return;
      Log.logPrint(e);
      //SmartDialog.showToast(e.toString());
      loadError.value = true;
      if (e is Error) {
        error = e;
      }
    } finally {
      SmartDialog.dismiss(status: SmartStatus.loading);
    }
  }

  /// 初始化播放器
  void getPlayQualites() async {
    final generation = _roomGeneration;
    currentQuality = -1;

    try {
      var playQualites = await site.liveSite.getPlayQualites(detail: detail.value!);
      if (!_isCurrent(generation)) return;

      if (playQualites.isEmpty) {
        SmartDialog.showToast("无法读取播放清晰度");
        return;
      }
      qualites.assignAll(playQualites);
      var qualityLevel = await getQualityLevel();
      if (!_isCurrent(generation)) return;
      if (qualityLevel == 2) {
        //最高
        currentQuality = 0;
      } else if (qualityLevel == 0) {
        //最低
        currentQuality = playQualites.length - 1;
      } else {
        //中间值
        int middle = (playQualites.length / 2).floor();
        currentQuality = middle;
      }
      await getPlayUrl();
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast("无法读取播放清晰度");
    }
  }

  Future<int> getQualityLevel() async {
    var qualityLevel = AppSettingsController.instance.qualityLevel.value;
    try {
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult.first == ConnectivityResult.mobile) {
        qualityLevel = AppSettingsController.instance.qualityLevelCellular.value;
      }
    } catch (e) {
      Log.logPrint(e);
    }
    return qualityLevel;
  }

  Future<void> getPlayUrl() async {
    final generation = _roomGeneration;
    currentQualityInfo.value = qualites[currentQuality].quality;
    currentLineInfo.value = "";
    currentLineIndex = -1;
    var playUrl = await site.liveSite.getPlayUrls(detail: detail.value!, quality: qualites[currentQuality]);
    if (!_isCurrent(generation)) return;
    if (playUrl.urls.isEmpty) {
      SmartDialog.showToast("无法读取播放地址");
      return;
    }
    playUrls.assignAll(playUrl.urls); // 深拷贝
    playHeaders = playUrl.headers;
    currentLineIndex = 0;
    currentLineInfo.value = "线路${currentLineIndex + 1}";
    //重置错误次数
    mediaErrorRetryCount = 0;
    await initPlaylist();
  }

  void changePlayLine(int index) {
    currentLineIndex = index;
    //重置错误次数
    mediaErrorRetryCount = 0;
    setPlayer();
  }

  Future<void> initPlaylist() async {
    final generation = _roomGeneration;
    currentLineInfo.value = "线路${currentLineIndex + 1}";
    errorMsg.value = "";

    final mediaList = playUrls.map((url) {
      var finalUrl = url;
      if (AppSettingsController.instance.playerForceHttps.value) {
        finalUrl = finalUrl.replaceAll("http://", "https://");
      }
      return Media(finalUrl, httpHeaders: playHeaders);
    }).toList();

    // 初始化播放器并设置 ao 参数
    await initializePlayer();

    if (!_isCurrent(generation)) return;
    await IosAudioSessionService.instance.activate();
    await player.setVideoTrack(listeningMode.value ? VideoTrack.no() : VideoTrack.auto());
    if (!_isCurrent(generation)) return;
    await player.open(Playlist(mediaList));
    _lastPlaybackProgress = DateTime.now();
  }

  void setPlayer() async {
    if (_playbackClosed || currentLineIndex < 0 || currentLineIndex >= playUrls.length) return;
    currentLineInfo.value = "线路${currentLineIndex + 1}";
    errorMsg.value = "";

    await player.jump(currentLineIndex);
  }

  int mediaErrorRetryCount = 0;

  @override
  void mediaEnd() => unawaited(_recoverPlayback('播放结束'));

  @override
  void mediaError(String error) => unawaited(_recoverPlayback(error));

  Future<void> _recoverPlayback(String reason) async {
    if (_playbackClosed || _recoveringPlayback || detail.value == null || currentQuality < 0) return;
    _recoveringPlayback = true;
    _stablePlaybackTimer?.cancel();
    final generation = _roomGeneration;
    var backgroundTask = -1;
    try {
      await _syncMobilePlayback();
      if (!_isCurrent(generation)) return;
      if (isBackground) {
        backgroundTask = await IosAudioSessionService.instance.beginBackgroundTask('live_reconnect');
      }
      mediaErrorRetryCount++;
      Log.d('重新取流（$mediaErrorRetryCount）：$reason');
      if (site.id == Constant.kDouyu) {
        // EOF can mean an expired signed stream; confirm offline more than once.
        final room = await site.liveSite.getRoomDetail(roomId: roomId);
        if (!_isCurrent(generation)) return;
        if (_offlinePolicy.confirmOffline(
            reportedLive: room.status || room.isRecord,
            hasActivePlaybackEvidence: player.state.playing &&
                !player.state.completed &&
                DateTime.now().difference(_lastPlaybackProgress) < const Duration(seconds: 5))) {
          liveStatus.value = false;
          await BackgroundPlaybackService.instance.stop();
          return;
        }
        if (!room.status && !room.isRecord) {
          _scheduleReconnect(generation);
          return;
        }
        detail.value = room;
        liveStatus.value = true;
      }
      if (mediaErrorRetryCount > 6) {
        // Stay in this room and offer manual refresh; never label network failure as offline.
        errorMsg.value = '播放中断，请刷新重试';
        return;
      }
      final result = await site.liveSite.getPlayUrls(detail: detail.value!, quality: qualites[currentQuality]);
      if (!_isCurrent(generation)) return;
      if (result.urls.isEmpty) throw StateError('无法读取播放地址');
      playUrls.assignAll(result.urls);
      playHeaders = result.headers;
      currentLineIndex = 0;
      await initPlaylist();
    } catch (e) {
      Log.logPrint(e);
      if (_isCurrent(generation)) {
        _offlinePolicy.reset();
        errorMsg.value = '正在重新连接';
        _scheduleReconnect(generation);
      }
    } finally {
      await IosAudioSessionService.instance.endBackgroundTask(backgroundTask);
      _recoveringPlayback = false;
      if (_isCurrent(generation)) unawaited(_syncMobilePlayback());
    }
  }

  void _scheduleReconnect(int generation) {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    if (mediaErrorRetryCount >= 6) {
      errorMsg.value = '播放中断，请刷新重试';
      return;
    }
    _reconnectTimer = Timer(Duration(seconds: mediaErrorRetryCount.clamp(1, 10)), () {
      _reconnectTimer = null;
      if (_isCurrent(generation)) unawaited(_recoverPlayback('连接重试'));
    });
  }

  /// 读取SC
  void getSuperChatMessage() async {
    final generation = _roomGeneration;
    try {
      var sc = await site.liveSite.getSuperChatMessage(roomId: detail.value!.roomId);
      if (!_isCurrent(generation)) return;
      superChats.assignAll([...superChats, ...sc].take(20));
    } catch (e) {
      Log.logPrint(e);
      addSysMsg("SC读取失败");
    }
  }

  /// 移除掉已到期的SC
  void removeSuperChats() async {
    var now = DateTime.now().millisecondsSinceEpoch;
    superChats.removeWhere((x) => x.endTime.millisecondsSinceEpoch <= now);
  }

  /// 添加历史记录
  void addHistory() {
    if (detail.value == null) {
      return;
    }
    var id = "${site.id}_$roomId";
    History history = History(
      id: id,
      roomId: roomId,
      siteId: site.id,
      userName: detail.value?.userName ?? "",
      face: detail.value?.userAvatar ?? "",
      updateTime: DateTime.now(),
    );
    HistoryService.instance.start(history);
  }

  /// 关注用户
  Future<void> followUser() async {
    if (detail.value == null) {
      return;
    }
    var id = "${site.id}_$roomId";
    var historyDurationSec = HistoryService.instance.getHistoryDurationSec(followUserId: id);
    await FollowService.instance.addFollow(
      FollowUser(
        id: id,
        roomId: roomId,
        siteId: site.id,
        userName: detail.value?.userName ?? "",
        face: detail.value?.userAvatar ?? "",
        addTime: DateTime.now(),
        lastWatchTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        watchDurationSec: historyDurationSec,
      )
        ..liveStatus.value = liveStatus.value ? 2 : 1
        ..cover.value = detail.value?.cover ?? "",
    );
    followed.value = true;
    EventBus.instance.emit(Constant.kUpdateFollow, id);
  }

  /// 取消关注用户
  void removeFollowUser() async {
    if (detail.value == null) {
      return;
    }
    if (!await Utils.showAlertDialog("确定要取消关注该用户吗？", title: "取消关注")) {
      return;
    }

    var id = "${site.id}_$roomId";
    await FollowService.instance.removeFollowUser(id);
    followed.value = false;
    EventBus.instance.emit(Constant.kUpdateFollow, id);
  }

  void share() {
    if (detail.value == null) {
      return;
    }
    SharePlus.instance.share(ShareParams(text: detail.value!.url));
  }

  void copyUrl() {
    if (detail.value == null) {
      return;
    }
    Utils.copyToClipboard(detail.value!.url);
    SmartDialog.showToast("已复制直播间链接");
  }

  Future<void> visitWebLive() async {
    Uri uri = Uri.parse(detail.value!.url);
    if (await canLaunchUrl(uri) || runningInSandbox()) {
      await launchUrl(uri);
    } else {
      throw '无法打开网页 $uri';
    }
  }

  /// 底部打开播放器设置
  void showDanmuSettingsSheet() {
    Utils.showBottomSheet(
      title: "弹幕设置",
      child: ListView(
        padding: AppStyle.edgeInsetsA12,
        children: [
          DanmuSettingsView(
            danmakuController: danmakuController,
            onTapDanmuShield: () {
              Get.back();
              showFollowBlockShield();
            },
          ),
        ],
      ),
    );
  }

  void showVolumeSlider(BuildContext targetContext) {
    SmartDialog.showAttach(
      targetContext: targetContext,
      alignment: Alignment.topCenter,
      displayTime: const Duration(seconds: 3),
      maskColor: const Color(0x00000000),
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: AppStyle.radius12,
            color: Theme.of(context).cardColor,
          ),
          padding: AppStyle.edgeInsetsA4,
          child: Obx(
            () => SizedBox(
              width: 200,
              child: NativeSlider(
                min: 0,
                max: 100,
                value: AppSettingsController.instance.playerVolume.value,
                onChanged: (newValue) {
                  player.setVolume(newValue);
                  AppSettingsController.instance.setPlayerVolume(newValue);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void showQualitySheet() {
    Utils.showBottomSheet(
      title: "切换清晰度",
      child: RadioGroup(
        groupValue: currentQuality,
        onChanged: (e) async {
          Get.back();
          currentQuality = e ?? 0;
          await getPlayUrl();
        },
        child: ListView.builder(
          itemCount: qualites.length,
          itemBuilder: (_, i) {
            var item = qualites[i];
            return NativeRadioListTile(
              value: i,
              title: Text(item.quality),
            );
          },
        ),
      ),
    );
  }

  void showPlayUrlsSheet() {
    Utils.showBottomSheet(
      title: "切换线路",
      child: RadioGroup(
        groupValue: currentLineIndex,
        onChanged: (e) {
          Get.back();
          //currentLineIndex = i;
          //setPlayer();
          changePlayLine(e ?? 0);
        },
        child: ListView.builder(
          itemCount: playUrls.length,
          itemBuilder: (_, i) {
            return NativeRadioListTile(
              value: i,
              title: Text("线路${i + 1}"),
              secondary: Text(
                playUrls[i].contains(".flv") ? "FLV" : "HLS",
              ),
            );
          },
        ),
      ),
    );
  }

  void showPlayerSettingsSheet() {
    Utils.showBottomSheet(
      title: "画面尺寸",
      child: Obx(
        () => ListView(
          padding: AppStyle.edgeInsetsV12,
          children: [
            RadioGroup(
              groupValue: AppSettingsController.instance.scaleMode.value,
              onChanged: (e) {
                AppSettingsController.instance.setScaleMode(e ?? 0);
                updateScaleMode();
              },
              child: Column(
                children: [
                  NativeRadioListTile(
                    value: 0,
                    title: const Text("适应"),
                    visualDensity: VisualDensity.compact,
                  ),
                  NativeRadioListTile(
                    value: 1,
                    title: const Text("拉伸"),
                    visualDensity: VisualDensity.compact,
                  ),
                  NativeRadioListTile(
                    value: 2,
                    title: const Text("铺满"),
                    visualDensity: VisualDensity.compact,
                  ),
                  NativeRadioListTile(
                    value: 3,
                    title: const Text("16:9"),
                    visualDensity: VisualDensity.compact,
                  ),
                  NativeRadioListTile(
                    value: 4,
                    title: const Text("4:3"),
                    visualDensity: VisualDensity.compact,
                  ),
                  NativeRadioListTile(
                    value: 5,
                    title: Obx(() => Text(
                        "自定义（${AppSettingsController.instance.aspectWidth.value}:${AppSettingsController.instance.aspectHeight.value}）")),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void showAspectRatioSheet() {
    final widthController = TextEditingController(text: AppSettingsController.instance.aspectWidth.value.toString());
    final heightController = TextEditingController(text: AppSettingsController.instance.aspectHeight.value.toString());
    Utils.showBottomSheet(
      title: "自定义缩放比例",
      child: Padding(
        padding: AppStyle.edgeInsetsH16,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: NativeTextField(
                    controller: widthController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "宽",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                AppStyle.hGap12,
                const Text("x", style: TextStyle(fontSize: 18)),
                AppStyle.hGap12,
                Expanded(
                  child: NativeTextField(
                    controller: heightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "高",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            AppStyle.vGap12,
            NativeTextButton(
              onPressed: () {
                final w = int.tryParse(widthController.text) ?? 16;
                final h = int.tryParse(heightController.text) ?? 9;
                if (w <= 0 || h <= 0) return;
                AppSettingsController.instance.setAspectWidth(w);
                AppSettingsController.instance.setAspectHeight(h);
                AppSettingsController.instance.setAspectByUser(w / h);
                AppSettingsController.instance.setScaleMode(5);
                updateScaleMode();
                Get.back();
              },
              child: const Text("确定"),
            ),
          ],
        ),
      ),
    );
  }

  void showFollowBlockShield({bool blockWords = true}) {
    TextEditingController keywordController = TextEditingController();

    void addKeyword() {
      if (keywordController.text.isEmpty) {
        SmartDialog.showToast("请输入${blockWords ? "关键词" : "用户名"}");
        return;
      }
      addCurBlockWord(keywordController.text.trim());
      keywordController.text = "";
    }

    Utils.showBottomSheet(
      title: "当前主播${blockWords ? "弹幕" : "用户"}屏蔽",
      child: ListView(
        padding: AppStyle.edgeInsetsA12,
        children: [
          NativeTextField(
            controller: keywordController,
            decoration: InputDecoration(
              contentPadding: AppStyle.edgeInsetsH12,
              border: const OutlineInputBorder(),
              hintText: "请输入${blockWords ? "关键词" : "用户名"}",
              suffixIcon: NativeTextButton.icon(
                onPressed: addKeyword,
                icon: const Icon(Icons.add),
                label: const Text("添加"),
              ),
            ),
            onSubmitted: (e) {
              addKeyword();
            },
          ),
          AppStyle.vGap12,
          Obx(() {
            var len =
                blockWords ? followUserBlock.value!.blockWords.length : followUserBlock.value!.blockAccounts.length;
            return Text(
              "已添加$len个${blockWords ? "关键词" : "用户"}（点击移除）",
              style: Get.textTheme.titleSmall,
            );
          }),
          AppStyle.vGap12,
          Obx(() {
            final block = followUserBlock.value!;

            final List<({String label, VoidCallback onTap})> items = blockWords
                ? block.blockWords
                    .map(
                      (item) => (
                        label: item,
                        onTap: () => delCurBlockWord(item),
                      ),
                    )
                    .toList()
                : block.blockAccounts
                    .map(
                      (item) => (
                        label: item.name,
                        onTap: () => delCurBlockAccount(item.name),
                      ),
                    )
                    .toList();

            return Wrap(
              runSpacing: 12,
              spacing: 12,
              children: items
                  .map(
                    (item) => InkWell(
                      borderRadius: AppStyle.radius24,
                      onTap: item.onTap,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: AppStyle.radius24,
                        ),
                        padding: AppStyle.edgeInsetsH12.copyWith(top: 4, bottom: 4),
                        child: Text(item.label, style: Get.textTheme.bodyMedium),
                      ),
                    ),
                  )
                  .toList(),
            );
          })
        ],
      ),
    );
  }

  void showFollowUserSheet() {
    Utils.showBottomSheet(
      title: "关注列表",
      child: Obx(
        () => Stack(
          children: [
            RefreshIndicator(
              onRefresh: FollowService.instance.loadData,
              child: ListView.builder(
                itemCount: FollowService.instance.liveList.length,
                itemBuilder: (_, i) {
                  var item = FollowService.instance.liveList[i];
                  return Obx(
                    () => FollowUserItem(
                      item: item,
                      playing: rxSite.value.id == item.siteId && rxRoomId.value == item.roomId,
                      onTap: () {
                        Get.back();
                        resetRoom(
                          Sites.allSites[item.siteId]!,
                          item.roomId,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            if (Platform.isLinux || Platform.isWindows || Platform.isMacOS)
              Positioned(
                right: 12,
                bottom: 12,
                child: Obx(
                  () => DesktopRefreshButton(
                    refreshing: FollowService.instance.updating.value,
                    onPressed: FollowService.instance.loadData,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void showAutoExitSheet() {
    Utils.showBottomSheet(
      title: "定时关闭",
      child: ListView(
        children: [
          Obx(
            () => NativeSwitchListTile(
              title: Text(
                "启用定时关闭",
                style: Get.textTheme.titleMedium,
              ),
              value: autoExitEnable.value,
              onChanged: (e) {
                autoExitEnable.value = e;

                setAutoExit();
                //controller.setAutoExitEnable(e);
              },
            ),
          ),
          Obx(
            () => NativeListTile(
              enabled: autoExitEnable.value,
              title: Text(
                "自动关闭时间：${autoExitMinutes.value ~/ 60}小时${autoExitMinutes.value % 60}分钟",
                style: Get.textTheme.titleMedium,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                var value = await showNativeTimePicker(
                  context: Get.context!,
                  initialTime: TimeOfDay(
                    hour: autoExitMinutes.value ~/ 60,
                    minute: autoExitMinutes.value % 60,
                  ),
                  initialEntryMode: TimePickerEntryMode.inputOnly,
                  builder: (_, child) {
                    return MediaQuery(
                      data: Get.mediaQuery.copyWith(
                        alwaysUse24HourFormat: true,
                      ),
                      child: child!,
                    );
                  },
                );
                if (value == null || (value.hour == 0 && value.minute == 0)) {
                  return;
                }
                var duration = Duration(hours: value.hour, minutes: value.minute);
                autoExitMinutes.value = duration.inMinutes;
                AppSettingsController.instance.setRoomAutoExitDuration(autoExitMinutes.value);
                //setAutoExitDuration(duration.inMinutes);
                setAutoExit();
              },
            ),
          ),
        ],
      ),
    );
  }

  void openNaviteAPP() async {
    var naviteUrl = "";
    var webUrl = "";
    if (site.id == Constant.kBiliBili) {
      naviteUrl = "bilibili://live/${detail.value?.roomId}";
      webUrl = "https://live.bilibili.com/${detail.value?.roomId}";
    } else if (site.id == Constant.kDouyin) {
      var args = detail.value?.danmakuData as DouyinDanmakuArgs;
      naviteUrl = "snssdk1128://webcast_room?room_id=${args.roomId}";
      webUrl = "https://live.douyin.com/${args.webRid}";
    } else if (site.id == Constant.kHuya) {
      var args = detail.value?.danmakuData as HuyaDanmakuArgs;
      naviteUrl =
          "yykiwi://homepage/index.html?banneraction=https%3A%2F%2Fdiy-front.cdn.huya.com%2Fzt%2Ffrontpage%2Fcc%2Fupdate.html%3Fhyaction%3Dlive%26channelid%3D${args.subSid}%26subid%3D${args.subSid}%26liveuid%3D${args.subSid}%26screentype%3D1%26sourcetype%3D0%26fromapp%3Dhuya_wap%252Fclick%252Fopen_app_guide%26&fromapp=huya_wap/click/open_app_guide";
      webUrl = "https://www.huya.com/${detail.value?.roomId}";
    } else if (site.id == Constant.kDouyu) {
      naviteUrl =
          "douyulink://?type=90001&schemeUrl=douyuapp%3A%2F%2Froom%3FliveType%3D0%26rid%3D${detail.value?.roomId}";
      webUrl = "https://www.douyu.com/${detail.value?.roomId}";
    }
    try {
      await launchUrlString(naviteUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast("无法打开APP，将使用浏览器打开");
      await launchUrlString(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  void resetRoom(Site site, String roomId) async {
    if (this.site == site && this.roomId == roomId) {
      return;
    }

    rxSite.value = site;
    rxRoomId.value = roomId;

    // 清除全部消息
    ++_roomGeneration;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stablePlaybackTimer?.cancel();
    danmakuBuffer.clear();
    _offlinePolicy.reset();
    liveDanmaku.stop();
    messages.clear();
    superChats.clear();
    danmakuController?.clear();

    // 重新设置LiveDanmaku
    liveDanmaku = site.liveSite.getDanmaku();
    rustDanmakuMask.reset();

    // 停止播放
    await player.stop();

    // 刷新信息
    loadData();
    HistoryService.instance.reset("${site.id}_$roomId");
  }

  void copyErrorDetail() {
    Utils.copyToClipboard('''直播平台：${rxSite.value.name}
房间号：${rxRoomId.value}
错误信息：
${error?.toString()}
----------------
${error?.stackTrace}''');
    SmartDialog.showToast("已复制错误信息");
  }

  void _initMobilePlayback() {
    _positionSubscription = player.stream.position.listen((position) {
      if (position != _lastPosition) {
        _lastPosition = position;
        _lastPlaybackProgress = DateTime.now();
      }
    });
    _roomPlayingSubscription = player.stream.playing.listen((playing) {
      _stablePlaybackTimer?.cancel();
      if (playing) {
        final generation = _roomGeneration;
        _stablePlaybackTimer = Timer(const Duration(seconds: 30), () {
          if (_isCurrent(generation) &&
              player.state.playing &&
              DateTime.now().difference(_lastPlaybackProgress) < const Duration(seconds: 5)) {
            mediaErrorRetryCount = 0;
          }
        });
      }
      if (!_playbackClosed) unawaited(_syncMobilePlayback());
    });
    _backgroundEvents = BackgroundPlaybackService.instance.events.listen((event) async {
      if (_playbackClosed || !listeningMode.value) return;
      if (event.type == 'mediaButton') {
        if (event.action == 'play') {
          await _resumeMobilePlayback();
        } else if (event.action == 'pause' || event.action == 'stop') {
          _resumeAfterInterruption = false;
          await player.pause();
        }
      } else if (event.type == 'audioFocus') {
        if (event.focusState == 'loss' || event.focusState == 'loss_transient') {
          _resumeAfterInterruption = event.focusState == 'loss_transient' && player.state.playing;
          await player.pause();
        } else if (event.focusState == 'gain') {
          await player.setVolume(AppSettingsController.instance.playerVolume.value);
          if (_resumeAfterInterruption) {
            _resumeAfterInterruption = false;
            await _resumeMobilePlayback();
          }
        } else if (event.focusState == 'can_duck') {
          await player.setVolume(AppSettingsController.instance.playerVolume.value * 0.3);
        }
      }
    });
    _iosAudioEvents = IosAudioSessionService.instance.events.listen((event) async {
      if (_playbackClosed) return;
      if (event.type == IosAudioEventType.interruptionBegan) {
        _resumeAfterInterruption = player.state.playing;
        await player.pause();
      } else if (event.type == IosAudioEventType.interruptionEnded) {
        final resume = _resumeAfterInterruption && event.shouldResume;
        _resumeAfterInterruption = false;
        if (resume) {
          await _resumeMobilePlayback();
        }
      } else if (event.shouldPause) {
        _resumeAfterInterruption = false;
        await player.pause();
      }
    });
    _playbackWatchdog = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_playbackClosed ||
          _recoveringPlayback ||
          _reconnectTimer != null ||
          !liveStatus.value ||
          !player.state.playing ||
          mediaErrorRetryCount >= 6) {
        return;
      }
      if (DateTime.now().difference(_lastPlaybackProgress) >= const Duration(seconds: 25)) {
        unawaited(_recoverPlayback('播放停滞'));
      }
    });
  }

  Future<void> _resumeMobilePlayback() async {
    if (_playbackClosed) return;
    await IosAudioSessionService.instance.activate();
    if (_playbackClosed) return;
    if (player.state.completed || _reconnectTimer != null || errorMsg.value.isNotEmpty) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _reconnectTimer = null;
      mediaErrorRetryCount = 0;
      await _recoverPlayback('恢复播放');
    } else {
      await player.play();
      _lastPlaybackProgress = DateTime.now();
    }
  }

  Future<void> _syncMobilePlayback() {
    // Serialize native service updates so a delayed start cannot outlive room teardown.
    _backgroundSync = _backgroundSync.then((_) async {
      final service = BackgroundPlaybackService.instance;
      if (_playbackClosed || !listeningMode.value || !liveStatus.value) {
        await service.stop();
        return;
      }
      final state = _recoveringPlayback || _reconnectTimer != null
          ? BackgroundPlaybackState.reconnecting
          : player.state.playing
              ? BackgroundPlaybackState.playing
              : BackgroundPlaybackState.paused;
      await service.start(state: state, title: detail.value?.userName ?? '', subtitle: '听直播 · ${site.name}');
      if (_playbackClosed || !listeningMode.value) await service.stop();
    }).catchError((Object e) {
      Log.logPrint(e);
    });
    return _backgroundSync;
  }

  Future<void> toggleListeningMode() async {
    if (!(Platform.isAndroid || Platform.isIOS) || _playbackClosed || !liveStatus.value) return;
    final enabled = !listeningMode.value;
    try {
      await player.setVideoTrack(enabled ? VideoTrack.no() : VideoTrack.auto());
      if (_playbackClosed) return;
      if (enabled) {
        _danmakuBeforeListening = showDanmakuState.value;
        showDanmakuState.value = false;
        danmakuController?.clear();
        danmakuBuffer.clear();
      } else {
        showDanmakuState.value = _danmakuBeforeListening;
      }
      listeningMode.value = enabled;
      await IosAudioSessionService.instance.activate();
      await _syncMobilePlayback();
      if (enabled) {
        await WakelockPlus.disable();
      } else if (player.state.playing) {
        await WakelockPlus.enable();
      }
    } catch (e) {
      Log.logPrint(e);
      SmartDialog.showToast('切换听直播失败');
    }
  }

  void showListeningSheet() {
    Utils.showBottomSheet(
        title: '听直播',
        child: ListView(children: [
          Obx(() => NativeSwitchListTile(
              title: const Text('听直播'),
              subtitle: const Text('只播放音频，支持息屏和后台播放'),
              value: listeningMode.value,
              onChanged: (_) => toggleListeningMode())),
          for (final minutes in [30, 60, 90, 120])
            NativeListTile(
                title: Text('$minutes 分钟后关闭'),
                onTap: () {
                  autoExitMinutes.value = minutes;
                  autoExitEnable.value = true;
                  setAutoExit();
                  Get.back();
                  SmartDialog.showToast('将在 $minutes 分钟后关闭');
                }),
          NativeListTile(
              title: const Text('自定义定时关闭'),
              onTap: () {
                Get.back();
                showAutoExitSheet();
              }),
          NativeListTile(
              title: const Text('取消定时关闭'),
              onTap: () {
                autoExitEnable.value = false;
                setAutoExit();
                Get.back();
              }),
          if (Platform.isAndroid)
            NativeListTile(
                title: const Text('后台播放电池设置'),
                subtitle: const Text('允许后台运行可减少息屏后中断'),
                onTap: () => BackgroundPlaybackService.instance.requestIgnoreBatteryOptimizations()),
        ]));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      isBackground = true;
      danmakuBuffer.clear();
      danmakuController?.clear();
      if (listeningMode.value) unawaited(_syncMobilePlayback());
    } else if (state == AppLifecycleState.resumed) {
      isBackground = false;
      _refreshAutoExitCountdown();
      if (_playbackClosed) return;
      danmakuController?.resume();
      unawaited(_syncMobilePlayback());
    }
  }

  @override
  void onClose() {
    _roomDisposed = true;
    ++_roomGeneration;
    WidgetsBinding.instance.removeObserver(this);
    scrollController.removeListener(scrollListener);
    autoExitTimer?.cancel();
    _autoExitDeadlineTimer?.cancel();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stablePlaybackTimer?.cancel();
    _playbackWatchdog?.cancel();
    _positionSubscription?.cancel();
    _roomPlayingSubscription?.cancel();
    _backgroundEvents?.cancel();
    _iosAudioEvents?.cancel();
    danmakuTimer?.cancel();
    subscription?.cancel();
    danmakuBuffer.clear();
    _deadline.stop();
    unawaited(_syncMobilePlayback());
    unawaited(IosAudioSessionService.instance.deactivate());
    HistoryService.instance.stop();
    liveDanmaku.stop();
    danmakuController = null;
    rustDanmakuMask.dispose();
    super.onClose();
  }
}
