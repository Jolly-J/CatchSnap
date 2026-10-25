/**
 * @file: cookie_service.dart
 * @description: 平台账号 Cookie 凭据管理中心
 * @author: Antigravity
 * @version: 2.0.0
 */

import '../core/security_storage.dart';
import '../models/platform_type.dart';

class CookieService {
  /// 将原始 Cookie 字符串解析为键值字典
  static Map<String, String> parseCookieMap(String rawCookie) {
    final map = <String, String>{};
    if (rawCookie.trim().isEmpty) return map;
    for (final segment in rawCookie.split(';')) {
      final part = segment.trim();
      if (part.isEmpty) continue;
      final eqIndex = part.indexOf('=');
      if (eqIndex <= 0) continue;
      final key = part.substring(0, eqIndex).trim();
      final value = part.substring(eqIndex + 1).trim();
      if (key.isNotEmpty && value.isNotEmpty) {
        map[key] = value;
      }
    }
    return map;
  }

  /// 严格校验 Cookie 字符串是否包含真实登录后的身份凭据（排除游客/设备指纹 Cookie）
  static bool isAuthenticatedCookie(PlatformType platform, String rawCookie) {
    final map = parseCookieMap(rawCookie);
    if (map.isEmpty) return false;

    if (platform == PlatformType.douyin) {
      // 严禁将 passport_csrf_token / ttwid / s_v_web_id 等未登录游客 Cookie 视为已登录
      // 只有真正完成手机号/扫码/密码登录后，服务端才会下发 HttpOnly 的 sessionid / sid_tt / uid_tt
      final sessionId = map['sessionid'] ?? '';
      final sessionIdSs = map['sessionid_ss'] ?? '';
      final sidTt = map['sid_tt'] ?? '';
      final uidTt = map['uid_tt'] ?? '';
      return sessionId.length >= 16 ||
          sessionIdSs.length >= 16 ||
          sidTt.length >= 16 ||
          uidTt.length >= 16;
    }

    if (platform == PlatformType.xiaohongshu) {
      // 严禁将 a1 / webId / gid 等未登录访客设备指纹 Cookie 视为已登录
      final webSession = map['web_session'] ?? '';
      return webSession.length >= 20;
    }

    return rawCookie.trim().isNotEmpty;
  }

  /// 获取指定平台的有效登录 Cookie
  static Future<String> getCookie(PlatformType platform) async {
    String cookie = '';
    switch (platform) {
      case PlatformType.douyin:
        cookie = await SecurityStorage.getDouyinCookie();
        break;
      case PlatformType.xiaohongshu:
        cookie = await SecurityStorage.getXhsCookie();
        break;
      default:
        return '';
    }
    if (cookie.isNotEmpty && !isAuthenticatedCookie(platform, cookie)) {
      await clearCookie(platform);
      return '';
    }
    return cookie;
  }

  /// 保存指定平台的 Cookie
  static Future<void> saveCookie(PlatformType platform, String cookie) async {
    switch (platform) {
      case PlatformType.douyin:
        await SecurityStorage.setDouyinCookie(cookie);
        break;
      case PlatformType.xiaohongshu:
        await SecurityStorage.setXhsCookie(cookie);
        break;
      default:
        break;
    }
  }

  /// 清空指定平台 Cookie
  static Future<void> clearCookie(PlatformType platform) async {
    await saveCookie(platform, '');
  }

  /// 判断该平台是否已存在真实有效的登录态 Cookie
  static Future<bool> hasCookie(PlatformType platform) async {
    final cookie = await getCookie(platform);
    if (cookie.isEmpty) return false;
    return isAuthenticatedCookie(platform, cookie);
  }
}
