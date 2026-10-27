/**
 * @file: constants.dart
 * @description: 全局常量与系统配置参数中心
 * @author: Antigravity
 * @version: 2.0.0
 */

class AppConstants {
  // ── 应用基本信息 ──────────────────────────────────────────────
  static const String appName = '咔捕';
  static const String appVersion = '1.0.0';

  // ── 咔捕品牌与吉祥物动作形象资源 ──────────────────────────────
  static const String brandLogo = 'assets/brand/logo.png';           // 01-放大镜侦察 (主Logo)
  static const String mascotWelcome = 'assets/brand/welcome.png';    // 02-挥手欢迎
  static const String mascotLike = 'assets/brand/like.png';          // 03-点赞认可
  static const String mascotLove = 'assets/brand/love.png';          // 04-比心喜欢
  static const String mascotDiscover = 'assets/brand/discover.png';  // 05-惊喜发现
  static const String mascotQuestion = 'assets/brand/question.png';  // 06-疑问求助
  static const String mascotSearching = 'assets/brand/searching.png';// 07-思考搜索
  static const String mascotCelebrate = 'assets/brand/celebrate.png';// 08-开心庆祝
  static const String mascotSprint = 'assets/brand/sprint.png';      // 09-下载冲刺
  static const String mascotSuccess = 'assets/brand/success.png';    // 10-成功完成
  static const String mascotSad = 'assets/brand/sad.png';            // 11-委屈失败

  // ── 默认相册与下载配置 ────────────────────────────────────────
  static const String defaultAlbumName = '咔捕';
  static const int defaultDownloadThreads = 4;
  static const int maxDownloadThreads = 8;
  static const int minDownloadThreads = 1;

  // ── 本地存储键值 ──────────────────────────────────────────────
  static const String keyAlbumName = 'snap_album_name';
  static const String keyDownloadThreads = 'snap_download_threads';
  static const String keyDouyinCookie = 'snap_douyin_cookie';
  static const String keyXhsCookie = 'snap_xhs_cookie';
  static const String keyFluidCloudEnabled = 'snap_fluid_cloud_enabled';
  static const String keyAutoCloseFluidDelay = 'snap_auto_close_fluid_delay';
  static const String keyGroupByAuthor = 'snap_group_by_author';
  static const String keyDownloadHistory = 'snap_download_history';
  static const String keyThemeMode = 'snap_theme_mode';

  // ── 常用 User-Agent 预设 ───────────────────────────────────────
  /// 抖音 H5 落地页推荐使用的 iPhone UA（可无签触发 routerData 数据注入）
  static const String uaIPhone =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) '
      'EdgiOS/121.0.2277.107 Version/17.0 Mobile/15E148 Safari/604.1';

  /// 桌面端 Chrome UA（小红书解析与大文件媒体 CDN 拉取推荐）
  static const String uaDesktop =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/122.0.0.0 Safari/537.36';

  /// 手机端移动浏览器 UA（WebView 登录推荐）
  static const String uaMobile =
      'Mozilla/5.0 (Linux; Android 14; Mobile) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/122.0.0.0 Mobile Safari/537.36';

  // ── 官方域名白名单 ───────────────────────────────────────────
  static const String domainDouyin = 'douyin.com';
  static const String domainDouyinShort = 'v.douyin.com';
  static const String domainXhs = 'xiaohongshu.com';
  static const String domainXhsShort = 'xhslink.com';
}
