import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/modules/follow_user/follow_user_controller.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/follow_service.dart';

class _TestSettings extends AppSettingsController {
  @override
  Future<void> onInit() async {}
}

class _TestDBService extends DBService {
  @override
  Future<void> addFollow(FollowUser follow) async {}
}

class _TestFollowService extends FollowService {
  @override
  Future<void> onInit() async {}

  @override
  Future<void> loadData({bool updateStatus = true, int? cycle}) async {
    filterData();
  }
}

FollowUser _user(String roomId, {int status = 2}) => FollowUser(
      id: 'bilibili_$roomId',
      roomId: roomId,
      siteId: 'bilibili',
      userName: roomId,
      face: '',
      addTime: DateTime(2026),
    )..liveStatus.value = status;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppSettingsController settings;
  late FollowService service;
  late FollowUserController controller;

  setUp(() {
    Get.testMode = true;
    settings = Get.put<AppSettingsController>(_TestSettings());
    Get.put<DBService>(_TestDBService());
    service = Get.put<FollowService>(_TestFollowService());
    controller = Get.put(FollowUserController());
  });

  tearDown(() async {
    await Get.reset();
  });

  test('adding a follow after an empty first load preserves service data', () async {
    await controller.refreshData();
    expect(controller.pageEmpty.value, isTrue);

    final user = _user('1');
    // Use the real mutation and its update stream, without a room-page event.
    await service.addFollow(user);
    await Future<void>.delayed(Duration.zero);

    expect(service.followList, [user]);
    expect(controller.list, [user]);
    expect(controller.pageEmpty.value, isFalse);
    expect(controller.canLoadMore.value, isFalse);

    controller.list.clear();
    expect(service.followList, [user]);
  });

  test('removing the last follow restores the empty state', () async {
    final user = _user('1');
    await service.addFollow(user);
    await Future<void>.delayed(Duration.zero);
    expect(controller.pageEmpty.value, isFalse);

    await service.removeFollowUser(user.id);
    await Future<void>.delayed(Duration.zero);

    expect(controller.list, isEmpty);
    expect(controller.pageEmpty.value, isTrue);
  });

  test('filtering and refreshing never remove users from the service', () async {
    final live = _user('1');
    final offline = _user('2', status: 1);
    service.followList.assignAll([live, offline]);
    service.filterData();
    await Future<void>.delayed(Duration.zero);
    settings.hideOfflineFollow.value = true;

    await controller.refreshData();
    expect(controller.list, [live]);
    expect(service.followList, containsAll([live, offline]));

    controller.setFilterMode(controller.tagList[2]);
    expect(controller.list, [offline]);
    expect(controller.pageEmpty.value, isFalse);
    expect(service.followList, containsAll([live, offline]));

    controller.setFilterMode(controller.tagList[1]);
    await controller.refreshData();
    expect(controller.list, [live]);
    expect(controller.canLoadMore.value, isFalse);
  });

  test('an empty filtered result clears when matching users arrive', () async {
    final offline = _user('1', status: 1);
    service.followList.add(offline);
    service.filterData();
    controller.setFilterMode(controller.tagList[1]);
    await controller.refreshData();
    expect(controller.pageEmpty.value, isTrue);

    final live = _user('2');
    await service.addFollow(live);
    await Future<void>.delayed(Duration.zero);

    expect(controller.list, [live]);
    expect(controller.pageEmpty.value, isFalse);
    expect(service.followList, containsAll([live, offline]));
  });

  test('existing follows are visible before the first automatic refresh', () {
    final user = _user('1');
    service.followList.add(user);
    final initialController = FollowUserController()..onInit();
    addTearDown(initialController.onClose);

    expect(initialController.list, [user]);
    expect(initialController.pageEmpty.value, isFalse);
    expect(initialController.canLoadMore.value, isFalse);
  });
}
