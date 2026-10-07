import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:simple_live_core/simple_live_core.dart';
import 'package:simple_live_core/src/common/core_error.dart';
import 'package:simple_live_core/src/common/http_client.dart';
import 'package:simple_live_core/src/platforms/douyu/douyu_utils.dart';
import 'package:test/test.dart';

class DouyuAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  dynamic roomResponse = {
    'room': {
      'room_id': '1',
      'room_name': 'live',
      'show_status': '1',
      'videoLoop': '0'
    }
  };
  List<String> refreshCookies = ['acf_jwt_token=refreshed; Path=/; HttpOnly'];
  dynamic playbackResponse = {
    'error': 0,
    'data': {
      'rtmp_url': 'https://example.invalid',
      'rtmp_live': 'live.flv?a=1&amp;b=2',
      'cdnsWithName': [
        {'cdn': 'hw-h5'}
      ],
      'multirates': [
        {'rate': 0, 'name': '原画'}
      ],
    }
  };
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final response = options.uri.path.contains('/betard/')
        ? roomResponse
        : options.uri.path.endsWith('getEncryption')
            ? {
                'error': 0,
                'data': {
                  'key': 'key',
                  'enc_data': 'encrypted',
                  'rand_str': 'random',
                  'enc_time': 1
                }
              }
            : playbackResponse;
    return ResponseBody.fromString(jsonEncode(response), 200, headers: {
      Headers.contentTypeHeader: ['application/json'],
      if (options.uri.path.endsWith('safeAuth')) 'set-cookie': refreshCookies
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late DouyuAdapter adapter;
  late HttpClientAdapter original;
  final detail = LiveRoomDetail(
      roomId: '1',
      title: 'test',
      cover: '',
      userName: '',
      userAvatar: '',
      online: 0,
      status: true,
      url: '');
  setUp(() {
    CoreLog.enableLog = false;
    adapter = DouyuAdapter();
    original = HttpClient.instance.dio.httpClientAdapter;
    HttpClient.instance.dio.httpClientAdapter = adapter;
  });
  tearDown(() {
    HttpClient.instance.dio.httpClientAdapter = original;
    CoreLog.enableLog = true;
  });

  test('signing uses the logged-in browser device identity', () async {
    const cookie = 'dy_did=device-one; acf_did=other; token=example';
    final signed =
        Uri.splitQueryString(await DouyuUtils.sign('1', cookie: cookie));
    expect(signed['did'], 'device-one');
    expect(adapter.requests.single.queryParameters['did'], 'device-one');
    expect(adapter.requests.single.headers['cookie'], cookie);
    expect(DouyuUtils.deviceIdForCookie('acf_did=fallback'), 'fallback');
    expect(
        DouyuUtils.deviceIdForCookie(''), '10000000000000000000000000001501');
  });

  test('concurrent browser identities use their own encryption parameters',
      () async {
    final results = await Future.wait([
      DouyuUtils.sign('1', cookie: 'dy_did=device-two'),
      DouyuUtils.sign('1', cookie: 'dy_did=device-three'),
    ]);
    expect(results.map((s) => Uri.splitQueryString(s)['did']),
        ['device-two', 'device-three']);
    expect(adapter.requests.map((r) => r.queryParameters['did']).toSet(),
        {'device-two', 'device-three'});
  });

  test('expired or malformed playback responses are errors, never fake URLs',
      () async {
    final site = DouyuSite();
    await site.setSiteAttrs({'cookie': 'dy_did=device-validation'});
    adapter.playbackResponse = {'error': 102, 'msg': 'signature expired'};
    await expectLater(
        site.getPlayUrl('1', 0, 'hw-h5'), throwsA(isA<CoreError>()));
    adapter.playbackResponse = {'error': 0, 'data': {}};
    await expectLater(
        site.getPlayUrl('1', 0, 'hw-h5'), throwsA(isA<CoreError>()));
    await expectLater(
        site.getPlayQualites(detail: detail), throwsA(isA<CoreError>()));
  });

  test('playback requests preserve Cookie and decode URL escaping', () async {
    final site = DouyuSite();
    await site.setSiteAttrs({'cookie': 'dy_did=device-url; token=example'});
    expect(await site.getPlayUrl('1', 0, 'hw-h5'),
        'https://example.invalid/live.flv?a=1&b=2');
    expect(adapter.requests.last.headers['cookie'],
        'dy_did=device-url; token=example');
  });

  test('cookie refresh retains the browser device identity', () async {
    final cookie = await DouyuUtils.refreshCookie(
        did: 'refresh-device', ltp0: 'refresh-token', cookie: 'expired');
    expect(cookie, contains('acf_jwt_token=refreshed'));
    expect(DouyuUtils.deviceIdForCookie(cookie), 'refresh-device');
  });

  test('concurrent requests for one identity share encryption fetching',
      () async {
    await Future.wait(List.generate(
        5, (_) => DouyuUtils.sign('1', cookie: 'dy_did=shared-device')));
    expect(adapter.requests.length, 1);
  });

  test('string-valued live status does not produce a false offline report',
      () async {
    final site = DouyuSite();
    await site.setSiteAttrs({'cookie': 'dy_did=room-device'});
    expect((await site.getRoomDetail(roomId: '1')).status, isTrue);
    expect(adapter.requests.single.headers['cookie'], 'dy_did=room-device');
  });

  test('invalid room metadata is a fetch error instead of an offline room',
      () async {
    adapter.roomResponse = {'room': {}};
    await expectLater(
        DouyuSite().getRoomDetail(roomId: '1'), throwsA(isA<CoreError>()));
  });
}
