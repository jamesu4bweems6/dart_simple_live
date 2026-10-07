# v1.13.2-pre 功能融合

来源：[June6699/dart_simple_live v1.13.2-pre](https://github.com/June6699/dart_simple_live/releases/tag/v1.13.2-pre)，固定标签提交 `c67a138e`。本地继续保留 Slive 的应用标识、依赖、版本和 iOS 原生玻璃控件。

| 发布功能 | 本地处理 |
| --- | --- |
| 听直播 | Android/iOS 直播间的菜单和设置增加入口，关闭视频轨道和弹幕，支持 30/60/90/120 分钟或自定义关闭时间。Android 使用媒体前台服务与通知栏按钮；iOS 使用现有后台 audio 声明和音频会话，处理来电和拔耳机。 |
| 定时关闭修复 | 使用实际截止时间，返回前台时校正倒计时；先停止播放、弹幕和后台服务，再释放系统资源。Android 移除任务，iOS 返回首页，桌面关闭窗口；不再调用 `exit(0)`。 |
| 斗鱼断流、伪下播 | EOF/错误重新获取播放地址，卡流看门狗触发恢复；错误不会直接判为下播，要求连续三次确认。保留本分支较新的 H5PlayV1 签名接口，统一 Cookie、加密请求与播放签名的设备身份。签名缓存按设备隔离，刷新 Cookie 保留设备身份。 |
| 高弹幕性能 | 弹幕按 100ms 批处理、限制缓存和聊天列表容量，限制每批绘制数量；后台及听直播时跳过聊天处理，缓存屏蔽正则，切房时清空队列。保留现有 Rust 去重和房间屏蔽逻辑。 |
| 局域网账号同步 | 修复本地已有斗鱼入口的反向登录判断，兼容上游只发送 Cookie 的格式和本分支额外的 `dy_did` / `ltp0`。补齐快手发送、接收和持久化，保留 `kww` 与到期时间。 |
| 远程同步服务器 | 按要求排除：未修改远程同步模块、SignalR 服务或默认服务器，也未引入 june6699.top。 |

标签源码没有发布说明中的听直播入口，因此此流程按发布说明补齐，并接入标签中的后台播放服务。本地此前没有快手播放平台；快手新增入口用于配置、保存及局域网传输账号，没有改变原有播放平台列表。复用音视频的直播流关闭视频轨道能减少解码开销，实际网络流量取决于平台是否提供独立音频流。

## 验证

- 本次执行结果：App 47 项、斗鱼核心 8 项，共 55 项测试通过；静态分析没有新增错误。`git diff --check` 通过。
- App 回归：`flutter test --no-pub test/playback_release_test.dart test/lan_account_sync_test.dart test/live_room_recovery_test.dart test/native_ios_controls_test.dart test/native_dock_gesture_test.dart test/liquid_glass_ui_test.dart test/follow_user_controller_test.dart test/tool_test.dart`
- 斗鱼协议：在 `simple_live_core` 执行 `dart test test/douyu_playback_test.dart`，使用模拟 HTTP 响应验证设备身份、并发签名、Cookie 刷新、失效签名、房间状态及无效响应，无需真实账号。
- 静态分析检查改动的 Dart 模块；仓库原有未使用字段和命名提示不属于本次新增问题。
- Android/iOS 原生编译和真机息屏、来电、通知栏控制尚未验证。当前环境是 Windows，Android SDK 缺少 platforms，且没有 Xcode。单元测试不等同于真机长时间播放验证。
- 原有 `widget_test.dart` 是 Flutter 计数器模板，与应用实际入口不符，不作为本次回归用例。
