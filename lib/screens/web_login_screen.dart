/**
 * @file: web_login_screen.dart
 * @description: 内置 WebView 登录获取 Cookie 页面 (爱彼迎极简风格)
 * @author: Antigravity
 * @version: 2.1.0
 * 
 * 核心逻辑：
 * 1. 采用桌面端 (Desktop) User-Agent 伪装，避免平台服务端将移动浏览器直接重定向到“下载官方APP”的导流推广页。
 * 2. 针对小红书直连官方 /login 纯净登录流，支持扫码登录与手机短信验证码登录。
 * 3. 针对抖音直连官方主站并智能自动唤起居中登录弹窗，支持抖音扫码与手机短信验证码登录。
 * 4. 拦截外部 App Scheme 唤起，防止中途跳出应用。
 * 5. 通过底层原生 CookieManager 与 JS 双重探查，自动提取包含 HttpOnly 属性的核心身份凭据 (web_session, a1, sessionid 等)。
 */

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../app_theme.dart';
import '../models/platform_type.dart';
import '../services/cookie_service.dart';
import '../widgets/floating_top_bar.dart';
import '../widgets/snap_toast.dart';

class WebLoginScreen extends StatefulWidget {
  final PlatformType platform;

  const WebLoginScreen({
    super.key,
    required this.platform,
  });

  @override
  State<WebLoginScreen> createState() => _WebLoginScreenState();
}

class _WebLoginScreenState extends State<WebLoginScreen> {
  static const MethodChannel _channel =
      MethodChannel('com.example.douyin_downloader/floating');

  /// 抖音官方独立登录页 (/login_page) 会根据移动端 UA 自动开启原生 H5 触屏登录模式 (isH5: true)
  static const String _mobileUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36';

  /// 小红书 /login 仅对桌面端 UA 开放，配合 CSS 视口裁剪可在手机上仅呈现纯净登录卡片
  static const String _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36';

  late final WebViewController _controller;
  Timer? _cookiePollTimer;
  bool _isLoading = true;
  String _pageTitle = '';
  bool _hasSavedSuccess = false;
  bool _sessionPrepared = false;

  /// 记录小红书未登录状态下由 /login/activate 自动下发的匿名访客 web_session，防止误判为已登录
  final Set<String> _guestWebSessions = <String>{};

  @override
  void initState() {
    super.initState();
    _pageTitle = '登录 ${widget.platform.displayName}';

    final userAgent = widget.platform == PlatformType.douyin
        ? _mobileUserAgent
        : _desktopUserAgent;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(userAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
              // 阻止唤醒外部应用协议 (如 xhsdiscover://, snssdk1128://, market://)
              return NavigationDecision.prevent;
            }
            // 抖音登录成功后会从 /login_page 重定向回 www.douyin.com 主站，此时立即检测并拦截重型 PC 首页加载
            if (widget.platform == PlatformType.douyin &&
                uri.host.contains('douyin.com') &&
                !uri.path.contains('login') &&
                !uri.path.contains('passport')) {
              _autoDetectCookie(request.url);
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (url) async {
            if (mounted) setState(() => _isLoading = false);
            await _injectOptimizationScripts();
            await _autoDetectCookie(url);
          },
        ),
      );

    _prepareAndLoad();
  }

  /// 初始化前清理 WebView 残留 Cookie，确保每次进入登录页均为全新登录会话
  Future<void> _prepareAndLoad() async {
    try {
      await _channel.invokeMethod('clearCookies');
    } catch (_) {}
    try {
      await WebViewCookieManager().clearCookies();
    } catch (_) {}

    if (!mounted) return;
    _sessionPrepared = true;
    await _controller.loadRequest(Uri.parse(widget.platform.loginUrl));

    // 启动轻量轮询，及时捕获短信验证码等 XHR 异步下发的 HttpOnly 登录 Cookie
    _cookiePollTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (mounted && !_hasSavedSuccess && _sessionPrepared) {
        _autoDetectCookie('');
      }
    });
  }

  @override
  void dispose() {
    _cookiePollTimer?.cancel();
    super.dispose();
  }

  /// 注入移动端视口与纯净登录卡片样式适配
  Future<void> _injectOptimizationScripts() async {
    try {
      if (widget.platform == PlatformType.xiaohongshu) {
        // 小红书 /login 隐藏桌面端左侧宣传海报与底部多余导航，仅居中展示手机号/扫码登录框
        await _controller.runJavaScript('''
          (function() {
            var meta = document.querySelector('meta[name="viewport"]');
            if (!meta) {
              meta = document.createElement('meta');
              meta.name = 'viewport';
              document.head.appendChild(meta);
            }
            meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';

            var styleId = 'kabu-xhs-mobile-style';
            if (!document.getElementById(styleId)) {
              var style = document.createElement('style');
              style.id = styleId;
              style.innerHTML = `
                html, body {
                  width: 100vw !important;
                  min-width: 0 !important;
                  overflow-x: hidden !important;
                  background: #FFFFFF !important;
                }
                .video-container, .description-container, .left-box, .reds-modal-close {
                  display: none !important;
                }
                .login-container, .reds-modal-content {
                  width: 100vw !important;
                  max-width: 100vw !important;
                  min-width: 0 !important;
                  height: auto !important;
                  min-height: 100vh !important;
                  margin: 0 !important;
                  padding: 16px !important;
                  box-shadow: none !important;
                  border-radius: 0 !important;
                  display: flex !important;
                  flex-direction: column !important;
                  justify-content: center !important;
                  align-items: center !important;
                }
                .login-box-container, .right-box {
                  width: 100% !important;
                  max-width: 360px !important;
                  padding: 12px 8px !important;
                  margin: 0 auto !important;
                }
              `;
              document.head.appendChild(style);
            }
          })();
        ''');
      } else if (widget.platform == PlatformType.douyin) {
        // 抖音 /login_page 移动端全屏紧凑排版微调
        await _controller.runJavaScript('''
          (function() {
            var styleId = 'kabu-dy-mobile-style';
            if (!document.getElementById(styleId)) {
              var style = document.createElement('style');
              style.id = styleId;
              style.innerHTML = `
                html, body {
                  width: 100vw !important;
                  min-width: 0 !important;
                  overflow-x: hidden !important;
                }
              `;
              document.head.appendChild(style);
            }
          })();
        ''');
      }
    } catch (_) {}
  }

  /// 提取当前网页的完整 Cookie (通过原生 CookieManager 多域合并，包含 HttpOnly 核心会话字段)
  Future<String> _extractCurrentCookies() async {
    final currentUrl = await _controller.currentUrl() ?? widget.platform.loginUrl;
    final Map<String, String> mergedCookies = {};

    void parseInto(String cookieStr) {
      final parsed = CookieService.parseCookieMap(cookieStr);
      mergedCookies.addAll(parsed);
    }

    try {
      final urlsToQuery = widget.platform == PlatformType.douyin
          ? <String>[
              currentUrl,
              'https://www.douyin.com/',
              'https://sso.douyin.com/',
            ]
          : <String>[
              currentUrl,
              'https://www.xiaohongshu.com/',
              'https://edith.xiaohongshu.com/',
            ];

      for (final targetUrl in urlsToQuery.toSet()) {
        if (targetUrl.isEmpty) continue;
        final raw = await _channel.invokeMethod<String>('getCookies', {'url': targetUrl});
        if (raw != null && raw.isNotEmpty) {
          parseInto(raw);
        }
      }
    } catch (_) {}

    try {
      final jsCookie = await _controller.runJavaScriptReturningResult('document.cookie');
      final s = jsCookie.toString().replaceAll('"', '').trim();
      if (s.isNotEmpty && s != 'null') parseInto(s);
    } catch (_) {}

    return mergedCookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  /// 严格校验当前是否真正完成了用户登录（彻底过滤未登录时的访客/CSRF/设备指纹 Cookie）
  Future<bool> _verifyRealLoginState(String cookieStr, String currentUrl) async {
    if (!CookieService.isAuthenticatedCookie(widget.platform, cookieStr)) {
      return false;
    }

    if (widget.platform == PlatformType.douyin) {
      // 抖音：只有真正登录成功后才会由服务端下发 HttpOnly 的 sessionid / sessionid_ss / sid_tt / uid_tt
      return true;
    }

    if (widget.platform == PlatformType.xiaohongshu) {
      final cookieMap = CookieService.parseCookieMap(cookieStr);
      final webSession = cookieMap['web_session'] ?? '';
      if (webSession.length < 20) return false;

      final uri = Uri.tryParse(currentUrl);
      final isStillOnLoginPage = uri == null || uri.path.startsWith('/login');

      // 检查页面 JS 状态是否已标记为用户登录
      bool jsLoggedIn = false;
      try {
        final res = await _controller.runJavaScriptReturningResult('''
          (function() {
            try {
              if (window.__INITIAL_STATE__ &&
                  window.__INITIAL_STATE__.user &&
                  window.__INITIAL_STATE__.user.loggedIn) {
                var v = window.__INITIAL_STATE__.user.loggedIn;
                return (v === true || v._value === true || v.value === true) ? 'true' : 'false';
              }
            } catch (e) {}
            return 'false';
          })()
        ''');
        jsLoggedIn = res.toString().replaceAll('"', '').trim() == 'true';
      } catch (_) {}

      if (isStillOnLoginPage && !jsLoggedIn) {
        // 小红书在进入 /login 页面时会通过 /api/sns/web/v1/login/activate 下发匿名访客 web_session
        // 将该未登录态的访客 web_session 加入黑名单，绝不触发误报登录
        _guestWebSessions.add(webSession);
        return false;
      }

      if (_guestWebSessions.contains(webSession)) {
        return false;
      }

      return !isStillOnLoginPage || jsLoggedIn;
    }

    return false;
  }

  /// 探查并自动提取 Cookie，仅当确认已获得真实用户登录态时才自动保存并退出
  Future<void> _autoDetectCookie(String urlHint) async {
    if (_hasSavedSuccess || !_sessionPrepared) return;
    try {
      final currentUrl = urlHint.isNotEmpty
          ? urlHint
          : (await _controller.currentUrl() ?? widget.platform.loginUrl);
      final cookieStr = await _extractCurrentCookies();
      if (cookieStr.isEmpty) return;

      final isLoggedIn = await _verifyRealLoginState(cookieStr, currentUrl);
      if (isLoggedIn && !_hasSavedSuccess) {
        _hasSavedSuccess = true;
        _cookiePollTimer?.cancel();
        await CookieService.saveCookie(widget.platform, cookieStr);
        if (mounted) {
          SnapToast.success(
            context,
            '${widget.platform.displayName} 账号登录成功，凭据已自动同步！',
          );
          Future.delayed(const Duration(milliseconds: 900), () {
            if (mounted) Navigator.of(context).pop(true);
          });
        }
      }
    } catch (_) {}
  }

  /// 手动点击“完成登录”按钮提取并校验 Cookie
  Future<void> _manualSaveCookie() async {
    try {
      final currentUrl = await _controller.currentUrl() ?? widget.platform.loginUrl;
      final cookieStr = await _extractCurrentCookies();

      if (cookieStr.trim().isEmpty) {
        _showSnack('尚未检测到登录状态，请先在页面内完成登录', isError: true);
        return;
      }

      final isLoggedIn = await _verifyRealLoginState(cookieStr, currentUrl);
      if (!isLoggedIn) {
        _showSnack('尚未检测到有效登录凭据，请先完成手机号验证码或扫码登录', isError: true);
        return;
      }

      _hasSavedSuccess = true;
      _cookiePollTimer?.cancel();
      await CookieService.saveCookie(widget.platform, cookieStr);

      if (mounted) {
        SnapToast.success(
          context,
          '${widget.platform.displayName} 登录凭据保存成功！已启用高清原画解析',
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      _showSnack('获取 Cookie 失败: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      SnapToast.error(context, msg);
    } else {
      SnapToast.info(context, msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return FloatingPageScaffold(
      title: _pageTitle,
      extendBodyBehindTop: false,
      actions: [
        FloatingPill(
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: 44,
            child: FloatingPillIconButton(
              icon: Icons.refresh_rounded,
              tooltip: '刷新页面',
              onPressed: () => _controller.reload(),
            ),
          ),
        ),
      ],
      topBottomHeight: _isLoading ? 3.0 : 0.0,
      topBottom: _isLoading
          ? ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                minHeight: 3.0,
                color: AirbnbTheme.primary,
                backgroundColor: AirbnbTheme.border,
              ),
            )
          : null,
      bottomBarHeight: 54,
      bottomBar: FloatingPill(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(
                    Icons.security_rounded,
                    size: 16,
                    color: AirbnbTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '支持短信验证码或扫码，登录后自动保存',
                      style: TextStyle(
                        fontSize: 12,
                        color: AirbnbTheme.textSecondary,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 38,
              child: ElevatedButton(
                onPressed: _manualSaveCookie,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AirbnbTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AirbnbTheme.radiusCapsule),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.white),
                    SizedBox(width: 5),
                    Text(
                      '完成登录',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      builder: (context, insets) => Padding(
        padding: EdgeInsets.only(bottom: insets.bottom),
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}
