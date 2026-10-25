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

  /// 采用高版本桌面端 Chrome User-Agent 确保平台展示完整扫码与手机号登录窗，杜绝移动端强行跳转 APP 下载页
  static const String _desktopUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36';

  late final WebViewController _controller;
  bool _isLoading = true;
  String _pageTitle = '';
  bool _hasSavedSuccess = false;

  @override
  void initState() {
    super.initState();
    _pageTitle = '登录 ${widget.platform.displayName}';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_desktopUserAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final uri = Uri.tryParse(request.url);
            if (uri != null && (uri.isScheme('http') || uri.isScheme('https'))) {
              return NavigationDecision.navigate;
            }
            // 阻止唤醒外部应用协议 (如 xhsdiscover://, snssdk1128://, market://)
            return NavigationDecision.prevent;
          },
          onPageStarted: (url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (url) async {
            if (mounted) setState(() => _isLoading = false);
            // 注入移动端视口自适应与优化样式
            await _injectOptimizationScripts();
            // 自动探查 Cookie 状态
            await _autoDetectCookie(url);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.platform.loginUrl));
  }

  /// 注入视口 meta 与视口适配样式，并针对抖音自动唤起登录浮窗
  Future<void> _injectOptimizationScripts() async {
    try {
      // 1. 注入 Viewport 允许移动屏幕缩放自适应
      await _controller.runJavaScript('''
        (function() {
          var meta = document.querySelector('meta[name="viewport"]');
          if (!meta) {
            meta = document.createElement('meta');
            meta.name = 'viewport';
            document.head.appendChild(meta);
          }
          meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=3.0, user-scalable=yes';
        })();
      ''');

      // 2. 针对抖音：页面完全加载后，自动探查并触发“登录”按钮呼出弹窗
      if (widget.platform == PlatformType.douyin) {
        await _controller.runJavaScript('''
          (function() {
            function triggerDouyinLogin() {
              var btn = document.getElementById('douyin_login_comp_btn_id') ||
                Array.from(document.querySelectorAll('*')).find(function(el) {
                  return el.children.length === 0 && el.innerText && el.innerText.trim() === '登录';
                });
              if (btn) {
                btn.click();
                return true;
              }
              return false;
            }
            if (!triggerDouyinLogin()) {
              setTimeout(triggerDouyinLogin, 800);
              setTimeout(triggerDouyinLogin, 2000);
            }
          })();
        ''');
      }

      // 3. 注入居中与弹窗样式微调
      await _controller.runJavaScript('''
        (function() {
          var style = document.createElement('style');
          style.innerHTML = `
            /* 登录容器移动端自适应 */
            .login-container, .douyin_login_new_class, #login-panel-new {
              max-width: 95vw !important;
              margin: 0 auto !important;
            }
          `;
          document.head.appendChild(style);
        })();
      ''');
    } catch (_) {}
  }

  /// 提取当前网页的完整 Cookie (通过原生 CookieManager 多域合并，支持 HttpOnly 字段)
  Future<String> _extractCurrentCookies() async {
    final currentUrl = await _controller.currentUrl() ?? widget.platform.loginUrl;
    final Map<String, String> mergedCookies = {};

    void parseInto(String cookieStr) {
      if (cookieStr.isEmpty) return;
      for (final pair in cookieStr.split(';')) {
        final trimmed = pair.trim();
        if (trimmed.isEmpty) continue;
        final eqIdx = trimmed.indexOf('=');
        if (eqIdx != -1) {
          final k = trimmed.substring(0, eqIdx).trim();
          final v = trimmed.substring(eqIdx + 1).trim();
          if (k.isNotEmpty) mergedCookies[k] = v;
        }
      }
    }

    try {
      // 1. 获取当前页面 URL 的 Cookie
      final c1 = await _channel.invokeMethod<String>('getCookies', {'url': currentUrl});
      if (c1 != null) parseInto(c1);

      // 2. 获取平台主域名的 Cookie (确保根域名 HttpOnly 关键凭据完整捕获)
      final mainDomainUrl = widget.platform == PlatformType.douyin
          ? 'https://www.douyin.com/'
          : 'https://www.xiaohongshu.com/';
      if (currentUrl != mainDomainUrl) {
        final c2 = await _channel.invokeMethod<String>('getCookies', {'url': mainDomainUrl});
        if (c2 != null) parseInto(c2);
      }
    } catch (_) {}

    // 3. JS 兜底提取 document.cookie
    try {
      final jsCookie = await _controller.runJavaScriptReturningResult('document.cookie');
      final s = jsCookie.toString().replaceAll('"', '').trim();
      if (s.isNotEmpty && s != 'null') parseInto(s);
    } catch (_) {}

    return mergedCookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  /// 探查并自动提取 Cookie，若已获得有效登录态则自动保存
  Future<void> _autoDetectCookie(String url) async {
    if (_hasSavedSuccess) return;
    try {
      final cookieStr = await _extractCurrentCookies();
      if (cookieStr.isNotEmpty) {
        bool hasLoginToken = false;
        if (widget.platform == PlatformType.douyin &&
            (cookieStr.contains('sessionid') || cookieStr.contains('passport_csrf_token'))) {
          hasLoginToken = true;
        } else if (widget.platform == PlatformType.xiaohongshu &&
            (cookieStr.contains('web_session') || cookieStr.contains('a1'))) {
          hasLoginToken = true;
        }

        if (hasLoginToken) {
          _hasSavedSuccess = true;
          await CookieService.saveCookie(widget.platform, cookieStr);
          if (mounted) {
            SnapToast.success(
              context,
              '${widget.platform.displayName} 账号登录成功，凭据已自动同步！',
            );
            Future.delayed(const Duration(milliseconds: 1200), () {
              if (mounted) Navigator.of(context).pop(true);
            });
          }
        }
      }
    } catch (_) {}
  }

  /// 手动确认提取 Cookie
  Future<void> _manualSaveCookie() async {
    try {
      final cookieStr = await _extractCurrentCookies();

      if (cookieStr.trim().isEmpty) {
        _showSnack('暂未检测到 Cookie 凭据，请先在页面完成登录');
        return;
      }

      final hasLoginToken = (widget.platform == PlatformType.douyin &&
              (cookieStr.contains('sessionid') || cookieStr.contains('passport_csrf_token'))) ||
          (widget.platform == PlatformType.xiaohongshu &&
              (cookieStr.contains('web_session') || cookieStr.contains('a1')));

      await CookieService.saveCookie(widget.platform, cookieStr);
      _hasSavedSuccess = true;

      if (mounted) {
        SnapToast.success(
          context,
          hasLoginToken
              ? '${widget.platform.displayName} 凭据保存成功！已启用高清原画解析'
              : '${widget.platform.displayName} Cookie 已保存（访客模式）',
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '支持短信验证码或扫码，登录后自动保存',
                style: TextStyle(
                  fontSize: 13,
                  color: AirbnbTheme.textSecondary,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _manualSaveCookie,
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: const Text('完成登录'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AirbnbTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AirbnbTheme.radiusCapsule),
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
