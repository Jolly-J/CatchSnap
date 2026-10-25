/**
 * @file: home_screen.dart
 * @description: 应用主页 (爱彼迎极简美学 + 大胶囊搜索 + 智能剪贴板唤起 + 顶部流体云灵动胶囊)
 * @author: Antigravity
 * @version: 2.0.0
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';
import '../core/constants.dart';
import '../models/platform_type.dart';
import '../parsers/parser_factory.dart';
import '../services/clipboard_service.dart';
import '../services/cookie_service.dart';
import '../services/download_task_manager.dart';
import '../services/permission_service.dart';
import '../utils/link_extractor.dart';
import '../widgets/airbnb_button.dart';
import '../widgets/airbnb_card.dart';
import '../widgets/clipboard_prompt_sheet.dart';
import '../widgets/floating_top_bar.dart';
import '../widgets/snap_toast.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'video_detail_screen.dart';
import 'web_login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final TextEditingController _inputCtrl = TextEditingController();
  bool _isParsing = false;
  bool _douyinCookieReady = false;
  bool _xhsCookieReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshCookieStatus();

    // 冷启动首次渲染后，先主动申请通知与相册权限，再静默检测一次剪贴板
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await PermissionService.requestInitialPermissions();
      if (mounted) {
        _checkClipboardOnResume();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inputCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 仅在用户切回前台时刻做单次检测，绝不在后台长轮询
    if (state == AppLifecycleState.resumed) {
      _checkClipboardOnResume();
      _refreshCookieStatus();
    }
  }

  Future<void> _refreshCookieStatus() async {
    final dy = await CookieService.hasCookie(PlatformType.douyin);
    final xhs = await CookieService.hasCookie(PlatformType.xiaohongshu);
    if (mounted) {
      setState(() {
        _douyinCookieReady = dy;
        _xhsCookieReady = xhs;
      });
    }
  }

  /// 进 App 时的单次剪贴板探查
  Future<void> _checkClipboardOnResume() async {
    final link = await ClipboardService.checkOnAppResume();
    if (link != null && mounted) {
      ClipboardPromptSheet.show(
        context: context,
        text: link,
        onConfirm: () {
          final clean = LinkExtractor.extractLink(link) ?? link;
          _inputCtrl.text = clean;
          _startParse(clean);
        },
      );
    }
  }

  /// 执行本地免服解析
  Future<void> _startParse([String? customInput]) async {
    final text = (customInput ?? _inputCtrl.text).trim();
    if (text.isEmpty) {
      _showSnack('请先粘贴或输入分享链接');
      return;
    }

    setState(() => _isParsing = true);
    FocusScope.of(context).unfocus();

    try {
      final cleanLink = LinkExtractor.extractLink(text) ?? text;
      final mediaItem = await ParserFactory.parse(cleanLink);

      if (mounted) {
        final startedDownload = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => VideoDetailScreen(item: mediaItem),
          ),
        );
        if (startedDownload == true && mounted) {
          setState(() => _inputCtrl.clear());
        }
      }
    } catch (e) {
      _showSnack('解析失败: ${e.toString().replaceAll('Exception: ', '')}',
          isError: true);
    } finally {
      if (mounted) {
        setState(() => _isParsing = false);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    if (isError) {
      SnapToast.error(context, msg);
    } else if (isSuccess) {
      SnapToast.success(context, msg);
    } else {
      SnapToast.info(context, msg);
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      final clean = LinkExtractor.extractLink(text) ?? text;
      setState(() => _inputCtrl.text = clean);
      _showSnack('已粘贴剪贴板内容', isSuccess: true);
    } else {
      _showSnack('剪贴板中暂无文字');
    }
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AirbnbTheme.themeModeNotifier,
      builder: (context, _, __) => FloatingTopBarOverlayRegion(
        child: Scaffold(
          backgroundColor: AirbnbTheme.background,
          body: Stack(
            children: [
              Positioned.fill(child: _buildBody(context)),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildFloatingTopBar(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 悬浮顶部栏：左侧品牌标识通透浮动，右侧下载中心与设置收纳为悬浮胶囊
  Widget _buildFloatingTopBar(BuildContext context) {
    return FloatingTopBar(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            AppConstants.brandLogo,
            width: 38,
            height: 38,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 8),
          Text(
            '咔捕',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: AirbnbTheme.textMain,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      actions: [
        FloatingPill(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<int>(
                valueListenable:
                    DownloadTaskManager.instance.activeCountNotifier,
                builder: (context, activeCount, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      FloatingPillIconButton(
                        icon: activeCount > 0
                            ? Icons.downloading_rounded
                            : Icons.download_done_rounded,
                        color: activeCount > 0
                            ? AirbnbTheme.primary
                            : AirbnbTheme.textMain,
                        tooltip: '下载任务中心',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const HistoryScreen()),
                          );
                        },
                      ),
                      if (activeCount > 0)
                        Positioned(
                          top: 2,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AirbnbTheme.primary,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: AirbnbTheme.primary.withOpacity(0.4),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            constraints: const BoxConstraints(
                                minWidth: 16, minHeight: 16),
                            child: Text(
                              '$activeCount',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              FloatingPillIconButton(
                icon: Icons.settings_outlined,
                tooltip: '设置',
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                  _refreshCookieStatus();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 主体内容：贯穿至状态栏后方，顶部预留悬浮栏高度，滑入顶部时由渐隐遮罩自然淡出
  Widget _buildBody(BuildContext context) {
    final mq = MediaQuery.paddingOf(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24.0,
        FloatingTopBar.contentTopInset(context) + 4.0,
        24.0,
        16.0 + mq.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          // ── 欢迎大标题与咔捕吉祥物 (Airbnb 经典排版) ────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '极简探索\n高清无水印下载',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: AirbnbTheme.textMain,
                        height: 1.25,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '支持抖音 1080p 原画、小红书 4K 图集与实况无水印提取',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AirbnbTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Image.asset(
                _isParsing
                    ? AppConstants.mascotSearching
                    : AppConstants.mascotWelcome,
                width: 82,
                height: 82,
                fit: BoxFit.contain,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── 核心搜索大胶囊输入卡片 ───────────────────────
          AirbnbCard(
            padding: const EdgeInsets.all(16),
            borderRadius: AirbnbTheme.radiusLg,
            child: Column(
              children: [
                TextField(
                  controller: _inputCtrl,
                  maxLines: 3,
                  minLines: 2,
                  style: TextStyle(color: AirbnbTheme.textMain, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '在此粘贴抖音或小红书的分享口令或网址...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: AirbnbTheme.textTertiary,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    suffixIcon: _inputCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => setState(() => _inputCtrl.clear()),
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _pasteFromClipboard,
                      icon: const Icon(Icons.paste_rounded, size: 16),
                      label: const Text('粘贴最新', style: TextStyle(fontSize: 13)),
                      style: TextButton.styleFrom(
                        foregroundColor: AirbnbTheme.textSecondary,
                      ),
                    ),
                    if (_inputCtrl.text.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(() => _inputCtrl.clear()),
                        child: Text('清空',
                            style: TextStyle(
                                color: AirbnbTheme.textTertiary, fontSize: 13)),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                AirbnbButton(
                  text: '开始极速解析',
                  isLoading: _isParsing,
                  onPressed: _isParsing ? null : () => _startParse(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── 平台高清状态快捷切换条 ─────────────────────────
          Text(
            '高清原画凭据状态',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AirbnbTheme.textMain,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildPlatformStatusBadge(
                  platform: PlatformType.douyin,
                  hasCookie: _douyinCookieReady,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPlatformStatusBadge(
                  platform: PlatformType.xiaohongshu,
                  hasCookie: _xhsCookieReady,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── 贴心使用指南小卡片 ─────────────────────────────
          AirbnbCard(
            backgroundColor: AirbnbTheme.surface,
            child: Row(
              children: [
                Image.asset(
                  AppConstants.mascotDiscover,
                  width: 50,
                  height: 50,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '咔捕免打扰自动侦测',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AirbnbTheme.textMain,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '在抖音/小红书复制链接后切回咔捕，系统将自动识别并弹出快速解析提示。',
                        style: TextStyle(
                          fontSize: 12,
                          color: AirbnbTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformStatusBadge({
    required PlatformType platform,
    required bool hasCookie,
  }) {
    return AirbnbCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => WebLoginScreen(platform: platform)),
        );
        _refreshCookieStatus();
      },
      child: Row(
        children: [
          ClipOval(
            child: platform.iconAsset != null
                ? Image.asset(
                    platform.iconAsset!,
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: platform.brandColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 18),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      platform.displayName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AirbnbTheme.textMain,
                      ),
                    ),
                    if (hasCookie) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded,
                          size: 14, color: AirbnbTheme.success),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  hasCookie ? '已解锁高清原画' : '访客画质·点击登录',
                  style: TextStyle(
                    fontSize: 11,
                    color: hasCookie
                        ? AirbnbTheme.success
                        : AirbnbTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
