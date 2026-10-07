import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:simple_live_app/app/sites.dart';
import 'package:simple_live_app/modules/live_room/live_room_controller.dart';
import 'package:simple_live_core/simple_live_core.dart';
// Use the installed plugin's test interface without adding a production dependency.
// ignore: depend_on_referenced_packages
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

class FakeWakelock extends WakelockPlusPlatformInterface {
  @override
  Future<void> toggle({required bool enable}) async {}
}

LiveRoomDetail room(bool live) => LiveRoomDetail(
    roomId: '1', title: 'room', cover: '', userName: 'anchor', userAvatar: '', online: 0, status: live, url: '');

class FakeLiveSite extends LiveSite {
  bool live = true;
  int urlRequests = 0;
  int detailRequests = 0;
  @override
  Future<LiveRoomDetail> getRoomDetail({required String roomId}) async {
    detailRequests++;
    return room(live);
  }

  @override
  Future<LivePlayUrl> getPlayUrls({required LiveRoomDetail detail, required LivePlayQuality quality}) async {
    urlRequests++;
    return LivePlayUrl(urls: ['https://example.invalid/fresh-$urlRequests.flv']);
  }
}

class FakePlayback extends Fake implements Player {
  int stops = 0;
  @override
  PlayerState get state => const PlayerState(completed: true);
  @override
  Future<void> stop() async {
    stops++;
  }
}

class TestRoomController extends LiveRoomController {
  TestRoomController(FakeLiveSite site)
      : super(pRoomId: '1', pSite: Site(id: 'douyu', name: '斗鱼', logo: '', iconData: Icons.live_tv, liveSite: site));
  final fakePlayback = FakePlayback();
  int opens = 0;
  @override
  Player get player => fakePlayback;
  @override
  Future<void> initPlaylist() async {
    opens++;
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late WakelockPlusPlatformInterface originalWakelock;
  setUp(() {
    originalWakelock = WakelockPlusPlatformInterface.instance;
    WakelockPlusPlatformInterface.instance = FakeWakelock();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('window_manager'), (_) async => null);
  });
  tearDown(() {
    WakelockPlusPlatformInterface.instance = originalWakelock;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('window_manager'), null);
  });

  testWidgets('Douyu EOF opens freshly fetched URLs and stays live', (tester) async {
    final site = FakeLiveSite();
    final controller = TestRoomController(site);
    controller.detail.value = room(true);
    controller.liveStatus.value = true;
    controller.qualites.add(LivePlayQuality(quality: '原画', data: null));
    controller.currentQuality = 0;
    controller.playUrls.add('https://example.invalid/expired.flv');
    controller.mediaEnd();
    await tester.pump();
    expect(site.detailRequests, 1);
    expect(site.urlRequests, 1);
    expect(controller.playUrls.single, contains('fresh-1'));
    expect(controller.opens, 1);
    expect(controller.liveStatus.value, isTrue);
  });

  testWidgets('Douyu requires three offline confirmations before marking down', (tester) async {
    final site = FakeLiveSite()..live = false;
    final controller = TestRoomController(site);
    controller.detail.value = room(true);
    controller.liveStatus.value = true;
    controller.qualites.add(LivePlayQuality(quality: '原画', data: null));
    controller.currentQuality = 0;
    controller.mediaEnd();
    await tester.pump();
    expect(controller.liveStatus.value, isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect(controller.liveStatus.value, isTrue);
    await tester.pump(const Duration(seconds: 2));
    expect(site.detailRequests, 3);
    expect(controller.liveStatus.value, isFalse);
    expect(site.urlRequests, 0);
  });

  testWidgets('sleep timer stops playback once and ignores subsequent EOF', (tester) async {
    final controller = TestRoomController(FakeLiveSite());
    controller.autoExitMinutes.value = 1;
    controller.autoExitEnable.value = true;
    controller.setAutoExit();
    await tester.pump(const Duration(minutes: 1));
    await tester.pump();
    expect(controller.autoExitEnable.value, isFalse);
    expect(controller.fakePlayback.stops, 1);
    controller.mediaEnd();
    controller.mediaError('late EOF');
    await tester.pump(const Duration(minutes: 1));
    expect(controller.fakePlayback.stops, 1);
    expect(controller.opens, 0);
  });
}
