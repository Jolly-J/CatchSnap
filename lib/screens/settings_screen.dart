/**
 * @file: settings_screen.dart
 * @description: 偏好设置、多线程并发调节与 Cookie 管理面板 (爱彼迎美学设计)
 * @author: Antigravity
 * @version: 2.0.0
 */

import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../core/constants.dart';
import '../core/security_storage.dart';
import '../models/platform_type.dart';
import '../services/cookie_service.dart';
import '../widgets/airbnb_card.dart';
import '../widgets/floating_top_bar.dart';
import 'web_login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _douyinHasCookie = false;
  bool _xhsHasCookie = false;

  int _threads = AppConstants.defaultDownloadThreads;
  bool _fluidCloudEnabled = true;
  bool _groupByAuthor = false;
  String _themeMode = 'system';
  final TextEditingController _albumCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _albumCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final dyCookie = await CookieService.hasCookie(PlatformType.douyin);
    final xhsCookie = await CookieService.hasCookie(PlatformType.xiaohongshu);
    final threads = await SecurityStorage.getDownloadThreads();
    final fluid = await SecurityStorage.isFluidCloudEnabled();
    final groupBy = await SecurityStorage.getGroupByAuthor();
    final album = await SecurityStorage.getAlbumName();
    final themeMode = await SecurityStorage.getThemeMode();

    if (mounted) {
      setState(() {
        _douyinHasCookie = dyCookie;
        _xhsHasCookie = xhsCookie;
        _threads = threads;
        _fluidCloudEnabled = fluid;
        _groupByAuthor = groupBy;
        _themeMode = themeMode;
        _albumCtrl.text = album;
      });
    }
  }

  Future<void> _loginPlatform(PlatformType platform) async {
    final success = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WebLoginScreen(platform: platform),
      ),
    );
    if (success == true) {
      _loadSettings();
    }
  }

  Future<void> _toggleFluidCloud(bool enabled) async {
    await SecurityStorage.setFluidCloudEnabled(enabled);
    setState(() => _fluidCloudEnabled = enabled);
  }

  Future<void> _changeThemeMode(String mode) async {
    await AirbnbTheme.setThemeModeString(mode);
    if (mounted) {
      setState(() => _themeMode = mode);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 绑定 InheritedTheme 依赖，确保全局切换主题时当前路由同步立即重绘
    Theme.of(context);
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AirbnbTheme.themeModeNotifier,
      builder: (context, _, __) => FloatingPageScaffold(
      title: '设置与偏好',
      builder: (context, insets) => ListView(
        padding: EdgeInsets.fromLTRB(
          20 + insets.left,
          insets.top + 8,
          20 + insets.right,
          16 + insets.bottom,
        ),
        children: [
          // ── 分组 1: 平台账号与 Cookie 凭据 ─────────────────────
          _buildSectionHeader('账号与高清凭据 (Cookie)'),
          const SizedBox(height: 8),
          AirbnbCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildPlatformCookieRow(
                  platform: PlatformType.douyin,
                  isConfigured: _douyinHasCookie,
                  onLogin: () => _loginPlatform(PlatformType.douyin),
                  onClear: () async {
                    await CookieService.clearCookie(PlatformType.douyin);
                    _loadSettings();
                  },
                ),
                const Divider(height: 24),
                _buildPlatformCookieRow(
                  platform: PlatformType.xiaohongshu,
                  isConfigured: _xhsHasCookie,
                  onLogin: () => _loginPlatform(PlatformType.xiaohongshu),
                  onClear: () async {
                    await CookieService.clearCookie(PlatformType.xiaohongshu);
                    _loadSettings();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '说明：呼出官方 Web 登录后会自动提取 Cookie 并加密存放在本机沙盒，用于解锁 1080p 超清原画及无水印视频源。',
              style: TextStyle(fontSize: 12, color: AirbnbTheme.textSecondary, height: 1.4),
            ),
          ),
          const SizedBox(height: 24),

          // ── 分组 2: 外观与深色模式 ──────────────────────────
          _buildSectionHeader('外观与深色模式'),
          const SizedBox(height: 8),
          AirbnbCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                _buildThemeOptionRow(
                  value: 'light',
                  title: '白色',
                  subtitle: '始终使用明亮浅色界面',
                  icon: Icons.light_mode_outlined,
                ),
                const Divider(height: 1),
                _buildThemeOptionRow(
                  value: 'dark',
                  title: '黑暗',
                  subtitle: '始终使用护眼深色界面',
                  icon: Icons.dark_mode_outlined,
                ),
                const Divider(height: 1),
                _buildThemeOptionRow(
                  value: 'system',
                  title: '自动（设备设置）',
                  subtitle: '跟随手机系统深浅色自动切换',
                  icon: Icons.brightness_auto_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── 分组 3: 多线程下载加速 ──────────────────────────
          _buildSectionHeader('多线程下载加速引擎'),
          const SizedBox(height: 8),
          AirbnbCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '并发下载分片数',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AirbnbTheme.textMain),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AirbnbTheme.primaryLight,
                        borderRadius: BorderRadius.circular(AirbnbTheme.radiusCapsule),
                      ),
                      child: Text(
                        '$_threads 线程',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AirbnbTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 6.0,
                    trackShape: const _UniformCapsuleTrackShape(),
                    thumbShape: const _DualRingSliderThumbShape(
                      outerRadius: 11.0,
                      innerRadius: 4.5,
                    ),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 20.0),
                    overlayColor: AirbnbTheme.primary.withValues(alpha: 0.12),
                    tickMarkShape: SliderTickMarkShape.noTickMark,
                    activeTrackColor: AirbnbTheme.primary,
                    inactiveTrackColor: AirbnbTheme.border,
                  ),
                  child: Slider(
                    value: _threads.toDouble(),
                    min: 1.0,
                    max: 8.0,
                    divisions: 7,
                    onChanged: (val) async {
                      final t = val.round();
                      setState(() => _threads = t);
                      await SecurityStorage.setDownloadThreads(t);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(8, (index) {
                      final step = index + 1;
                      final isSelected = step == _threads;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          setState(() => _threads = step);
                          await SecurityStorage.setDownloadThreads(step);
                        },
                        child: SizedBox(
                          width: 22,
                          child: Text(
                            '$step',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                              color: isSelected
                                  ? AirbnbTheme.primary
                                  : AirbnbTheme.textTertiary,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '将媒体切分为多个分片同时下载，可跑满网络带宽；弱网环境建议 4 线程。',
                  style: TextStyle(fontSize: 12, color: AirbnbTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── 分组 4: 流体云与实时通知 ────────────────────────
          _buildSectionHeader('系统流体云 (Fluid Cloud)'),
          const SizedBox(height: 8),
          AirbnbCard(
            padding: const EdgeInsets.all(16),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: AirbnbTheme.primary,
              title: Text(
                '开启系统级实时活动 / 流体云',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AirbnbTheme.textMain),
              ),
              subtitle: Text(
                '下载时在系统状态栏胶囊与流体云展示实时下载进度',
                style: TextStyle(fontSize: 12, color: AirbnbTheme.textSecondary),
              ),
              value: _fluidCloudEnabled,
              onChanged: _toggleFluidCloud,
            ),
          ),
          const SizedBox(height: 24),

          // ── 分组 5: 存储与相册归档 ──────────────────────────
          _buildSectionHeader('相册存储与归档'),
          const SizedBox(height: 8),
          AirbnbCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _albumCtrl,
                  style: TextStyle(color: AirbnbTheme.textMain),
                  decoration: const InputDecoration(
                    labelText: '保存相册目录名',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onSubmitted: (val) async {
                    await SecurityStorage.setAlbumName(val);
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: AirbnbTheme.primary,
                  title: Text('按创作者建立子相册', style: TextStyle(fontSize: 14, color: AirbnbTheme.textMain)),
                  subtitle: Text(
                    '例如：相册名/创作者昵称(ID)/视频.mp4',
                    style: TextStyle(fontSize: 12, color: AirbnbTheme.textSecondary),
                  ),
                  value: _groupByAuthor,
                  onChanged: (v) async {
                    setState(() => _groupByAuthor = v);
                    await SecurityStorage.setGroupByAuthor(v);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── 分组 6: 关于咔捕 ────────────────────────────────
          _buildSectionHeader('关于应用'),
          const SizedBox(height: 8),
          AirbnbCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Image.asset(
                  AppConstants.mascotLove,
                  width: 56,
                  height: 56,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '咔捕 · 极简无水印媒体捕捉工具',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AirbnbTheme.textMain),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '版本 v${AppConstants.appVersion} · 纯本地直连解析，安全守护隐私',
                        style: TextStyle(fontSize: 12, color: AirbnbTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    ),
    );
  }

  Widget _buildThemeOptionRow({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _themeMode == value;
    return InkWell(
      onTap: () => _changeThemeMode(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? AirbnbTheme.primary : AirbnbTheme.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: AirbnbTheme.textMain,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AirbnbTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AirbnbTheme.primary : AirbnbTheme.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AirbnbTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildPlatformCookieRow({
    required PlatformType platform,
    required bool isConfigured,
    required VoidCallback onLogin,
    required VoidCallback onClear,
  }) {
    return Row(
      children: [
        ClipOval(
          child: platform.iconAsset != null
              ? Image.asset(platform.iconAsset!, width: 36, height: 36, fit: BoxFit.cover)
              : Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: platform.brandColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.account_circle_rounded, color: platform.brandColor, size: 22),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                platform.displayName,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AirbnbTheme.textMain),
              ),
              const SizedBox(height: 2),
              Text(
                isConfigured ? '已保留登录态 (可提取高清原画)' : '未登录 (当前为访客清晰度)',
                style: TextStyle(
                  fontSize: 12,
                  color: isConfigured ? AirbnbTheme.success : AirbnbTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (isConfigured) ...[
          TextButton(
            onPressed: onClear,
            child: Text('清除', style: TextStyle(color: AirbnbTheme.textTertiary, fontSize: 13)),
          ),
        ],
        ElevatedButton(
          onPressed: onLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: AirbnbTheme.surface,
            foregroundColor: AirbnbTheme.primary,
            elevation: 0,
            side: const BorderSide(color: AirbnbTheme.primary, width: 1.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AirbnbTheme.radiusCapsule),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          child: Text(isConfigured ? '重新登录' : '呼出登录', style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}

/// 等高圆角胶囊轨道：消除 Material 3 默认轨道“左粗右细”与首尾刻度点破边的割裂感
class _UniformCapsuleTrackShape extends SliderTrackShape {
  const _UniformCapsuleTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight ?? 6.0;
    const double horizontalInset = 11.0;
    final double trackLeft = offset.dx + horizontalInset;
    final double trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width - horizontalInset * 2;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final Canvas canvas = context.canvas;
    final Radius radius = Radius.circular(trackRect.height / 2);

    // 1. 完整底轨（等高圆角胶囊）
    final Paint inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor ?? const Color(0xFFEBEBEB)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, radius),
      inactivePaint,
    );

    // 2. 激活左轨（与底轨完全等高）
    final double activeRight =
        thumbCenter.dx.clamp(trackRect.left, trackRect.right);
    if (activeRight > trackRect.left) {
      final Rect activeRect = Rect.fromLTRB(
        trackRect.left,
        trackRect.top,
        activeRight,
        trackRect.bottom,
      );
      final Paint activePaint = Paint()
        ..color = sliderTheme.activeTrackColor ?? AirbnbTheme.primary
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(activeRect, radius),
        activePaint,
      );
    }
  }
}

/// 双环高质感滑块手柄：外圈品牌色 + 内芯纯白圆点 + 柔和弥散阴影
class _DualRingSliderThumbShape extends SliderComponentShape {
  const _DualRingSliderThumbShape({
    this.outerRadius = 11.0,
    this.innerRadius = 4.5,
  });

  final double outerRadius;
  final double innerRadius;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      Size.fromRadius(outerRadius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;

    // 柔和外阴影
    final Path shadowPath = Path()
      ..addOval(Rect.fromCircle(center: center.translate(0, 1.5), radius: outerRadius));
    canvas.drawShadow(shadowPath, const Color(0x40FF385C), 4.0, true);

    // 外圈主色圆环
    final Paint outerPaint = Paint()
      ..color = sliderTheme.activeTrackColor ?? AirbnbTheme.primary
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, outerRadius, outerPaint);

    // 内圈纯白圆芯
    final Paint innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, innerRadius, innerPaint);
  }
}
