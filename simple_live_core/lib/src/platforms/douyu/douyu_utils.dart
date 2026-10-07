import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:simple_live_core/src/common/http_client.dart';
import 'package:simple_live_core/src/common/parse_cookie.dart';

class DouyuUtils {
  // params
  static final String _did = '10000000000000000000000000001501';

  static final int _encCacheTTL = 5 * 60;

  static final Map<String, Map<String, dynamic>> _encKeys = {};
  static final Map<String, Future<Map<String, dynamic>>> _pendingEncKeys = {};

  static String deviceIdForCookie(String cookie) {
    final values = <String, String>{};
    for (final part in cookie.split(';')) {
      final separator = part.indexOf('=');
      if (separator <= 0) continue;
      values[part.substring(0, separator).trim()] =
          part.substring(separator + 1).trim();
    }
    return values['dy_did']?.isNotEmpty == true
        ? values['dy_did']!
        : values['acf_did']?.isNotEmpty == true
            ? values['acf_did']!
            : _did;
  }

  // api
  // douyu-enc
  static final _apiDouyuEnc =
      "https://www.douyu.com/wgapi/livenc/liveweb/websec/getEncryption";

  // safe auth
  static final _apiDouyuPassport =
      'https://passport.douyu.com/lapi/passport/iframe/safeAuth';

  static final douyuOrigin = 'https://www.douyu.com';

  // douyu-live-stream
  static Map<String, String> requestHeader(
      {String roomId = '', String cookie = ''}) {
    final did = deviceIdForCookie(cookie);
    var referer = roomId.isEmpty ? douyuOrigin : '$douyuOrigin/$roomId';
    var res = {
      'accept': '*/*',
      'accept-encoding': 'gzip, deflate, br, zstd',
      'accept-language':
          'zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6,zh-Hans;q=0.5',
      'origin': douyuOrigin,
      'referer': referer,
      "content-type": "application/x-www-form-urlencoded",
      'user-agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36 Edg/114.0.1823.43',
      'cookie': 'dy_did=$did; acf_did=$did',
    };
    if (cookie.isNotEmpty) {
      res['cookie'] = cookie;
    }
    return res;
  }

  static Future<String> refreshCookie(
      {String did = '', String ltp0 = '', String cookie = ''}) async {
    // expired-> refresh
    if (_isCookieExpired(cookie) && ltp0.isNotEmpty && did.isNotEmpty) {
      // milliseconds not sec
      final t = DateTime.now().millisecondsSinceEpoch.toString();
      final query = <String, dynamic>{
        'client_id': '1',
        't': t,
        '_': t,
        'callback': 'axiosJsonpCallback',
      };

      final resp = await HttpClient.instance.getResponse(
        _apiDouyuPassport,
        queryParameters: query,
        header: requestHeader(cookie: 'dy_did=$did;LTP0=$ltp0'),
      );
      final refreshed = resp.headers['set-cookie'] ?? const <String>[];
      if (refreshed.isNotEmpty) {
        // safeAuth usually returns auth cookies without dy_did; retain browser identity.
        final values = <String, String>{'dy_did': did, 'acf_did': did};
        for (final raw in refreshed) {
          final pair = raw.split(';').first.trim();
          final separator = pair.indexOf('=');
          if (separator > 0) {
            values[pair.substring(0, separator)] =
                pair.substring(separator + 1);
          }
        }
        cookie = values.entries
            .map((entry) => '${entry.key}=${entry.value}')
            .join('; ');
      }
    }
    return cookie;
  }

  // expired -> true
  static bool _isCookieExpired(String cookie) {
    final jwt = _getJwtToken(cookie);
    if (jwt == null) return true;
    try {
      var payload = decodeJwtPayload(jwt);
      var exp = payload['exp'];
      if (exp is! int) return true;
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return nowSec >= exp;
    } catch (_) {
      return true;
    }
  }

  static String? _getJwtToken(String cookie) {
    if (cookie.isNotEmpty) {
      for (final pair in cookie.split(';')) {
        final p = pair.trim();
        if (p.startsWith('acf_jwt_token=')) {
          return p.substring('acf_jwt_token='.length);
        }
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>> _encKeyUpdate(
      {String cookie = ''}) async {
    final did = deviceIdForCookie(cookie);
    final cached = _encKeys[did];
    if (cached != null &&
        (cached['expire_at'] as int) >
            DateTime.now().millisecondsSinceEpoch ~/ 1000) {
      return cached;
    }
    final pending = _pendingEncKeys[did];
    if (pending != null) return pending;
    final future = _fetchEncKey(did, cookie);
    _pendingEncKeys[did] = future;
    try {
      return await future;
    } finally {
      _pendingEncKeys.remove(did);
    }
  }

  static Future<Map<String, dynamic>> _fetchEncKey(
      String did, String cookie) async {
    final response = await HttpClient.instance.getJson(
      _apiDouyuEnc,
      queryParameters: {'did': did},
      header: requestHeader(cookie: cookie),
    );
    final payload = response is Map ? response['data'] : null;
    if (payload is! Map ||
        payload['key'] is! String ||
        payload['enc_data'] == null) {
      throw const FormatException('斗鱼返回了无效的签名参数');
    }
    final data = Map<String, dynamic>.from(payload);
    data['expire_at'] =
        DateTime.now().millisecondsSinceEpoch ~/ 1000 + _encCacheTTL;
    if (_encKeys.length >= 8) _encKeys.remove(_encKeys.keys.first);
    _encKeys[did] = data;
    return data;
  }

  // 用于流/登录/弹幕，暂时只需要流获取
  static Future<String> sign(String rid,
      {int rate = -1, String cdn = "hw-h5", String cookie = ''}) async {
    var ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final encKey = await _encKeyUpdate(cookie: cookie);
    final did = deviceIdForCookie(cookie);
    String randStr = encKey["rand_str"] ?? "";
    int encTime = encKey["enc_time"] ?? 1;
    String salt = (encKey['is_special'] ?? 0) == 1 ? "" : "$rid$ts";
    String key = encKey['key'];

    String secret = randStr;
    // 其实只有一次
    for (var i = 0; i < encTime; i++) {
      secret = md5.convert(utf8.encode("$secret$key")).toString();
    }
    String auth = md5.convert(utf8.encode("$secret$key$salt")).toString();
    var postData = Uri(
      queryParameters: {
        'enc_data': encKey['enc_data'],
        'tt': '$ts',
        'did': did,
        'auth': auth,
        'cdn': cdn,
        'ver': 'Douyu_new',
        'rate': '$rate',
        'hevc': '1',
        'fa': '0',
        'ive': '0',
      },
    ).query;
    return postData;
  }
  // todo: 获取real_rid 暂未发现 fake_id
}
