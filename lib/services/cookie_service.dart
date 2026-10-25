/**
 * @file: cookie_service.dart
 * @description: 平台账号 Cookie 凭据管理中心
 * @author: Antigravity
 * @version: 2.0.0
 */

import '../core/security_storage.dart';
import '../models/platform_type.dart';

class CookieService {
  /// 获取指定平台的 Cookie
  static Future<String> getCookie(PlatformType platform) async {
    switch (platform) {
      case PlatformType.douyin:
        return SecurityStorage.getDouyinCookie();
      case PlatformType.xiaohongshu:
        return SecurityStorage.getXhsCookie();
      default:
        return '';
    }
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

  /// 判断该平台是否已存在有效登录态 Cookie
  static Future<bool> hasCookie(PlatformType platform) async {
    final cookie = await getCookie(platform);
    if (cookie.isEmpty) return false;

    // 抖音关键身份凭据字段为 sessionid 或 passport_csrf_token
    if (platform == PlatformType.douyin) {
      return cookie.contains('sessionid') || cookie.contains('passport_csrf_token');
    }
    // 小红书关键身份凭据字段为 web_session 或 a1
    if (platform == PlatformType.xiaohongshu) {
      return cookie.contains('web_session') || cookie.contains('a1');
    }
    return cookie.isNotEmpty;
  }
}
