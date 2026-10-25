/**
 * @file: app_theme.dart
 * @description: 爱彼迎 (Airbnb) 设计语言规范与主题令牌中心
 * @author: Antigravity
 * @version: 2.0.0
 * 
 * 核心设计原则：
 * 1. 经典珊瑚红主色（#FF385C）与深黑字阶（#222222）营造高质感轻奢感。
 * 2. 大圆角卡片（16~24dp）配合超细灰度描边（#EBEBEB）与柔和弥散阴影。
 * 3. 充足的呼吸留白与大尺寸粗体标题。
 */

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'core/security_storage.dart';

class AirbnbTheme {
  /// 全局主题模式状态 ('system' | 'light' | 'dark')
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  /// 当前是否处于深色模式
  static bool get isDark {
    final mode = themeModeNotifier.value;
    if (mode == ThemeMode.dark) return true;
    if (mode == ThemeMode.light) return false;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  }

  /// 启动时读取持久化的主题设置
  static Future<void> initThemeMode() async {
    final saved = await SecurityStorage.getThemeMode();
    themeModeNotifier.value = _parseMode(saved);
    syncSystemUiOverlay();
  }

  /// 切换并持久化主题模式 ('light' | 'dark' | 'system')
  /// 同步优先更新 themeModeNotifier，确保当前页面 setState 时立即拿到新主题色
  static Future<void> setThemeModeString(String modeStr) async {
    themeModeNotifier.value = _parseMode(modeStr);
    syncSystemUiOverlay();
    await SecurityStorage.setThemeMode(modeStr);
  }

  static String get currentModeString {
    switch (themeModeNotifier.value) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static ThemeMode _parseMode(String modeStr) {
    switch (modeStr) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  /// 同步系统状态栏与导航栏图标反色
  static void syncSystemUiOverlay() {
    final dark = isDark;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          dark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ));
  }

  // ── 品牌色彩体系 (支持深浅色自适应) ──────────────────────────────
  /// 爱彼迎核心珊瑚红（Rausch）
  static const Color primary = Color(0xFFFF385C);
  /// 深阶珊瑚红（按压、渐变态）
  static const Color primaryDark = Color(0xFFE00B41);
  /// 浅粉/暗红背景（标签、高亮微底色）
  static Color get primaryLight =>
      isDark ? const Color(0xFF3A1822) : const Color(0xFFFFF0F2);

  /// 主正文字色
  static Color get textMain =>
      isDark ? const Color(0xFFF3F4F6) : const Color(0xFF222222);
  /// 次级说明文字、时间戳、图标灰
  static Color get textSecondary =>
      isDark ? const Color(0xFF9CA3AF) : const Color(0xFF717171);
  /// 弱灰（占位符、失效文字）
  static Color get textTertiary =>
      isDark ? const Color(0xFF6B7280) : const Color(0xFFB0B0B0);

  /// 页面底色
  static Color get background =>
      isDark ? const Color(0xFF121212) : const Color(0xFFF7F7F7);
  /// 卡片与容器底色
  static Color get surface =>
      isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF);
  /// 超细分割线与边框线
  static Color get border =>
      isDark ? const Color(0xFF2E2E2E) : const Color(0xFFEBEBEB);

  /// 辅助功能色
  static const Color success = Color(0xFF008A05);
  static const Color warning = Color(0xFFFFB400);
  static const Color error = Color(0xFFC13515);

  // ── 圆角常量 ──────────────────────────────────────────────────
  static const double radiusSm = 8.0;
  static const double radiusMd = 16.0;
  static const double radiusLg = 24.0;
  static const double radiusCapsule = 999.0;

  // ── 阴影体系 (Airbnb Diffused Shadows) ─────────────────────────
  /// 极轻微悬浮阴影（小卡片、次级组件）
  static List<BoxShadow> get shadowSm => [
        BoxShadow(
          color: isDark ? const Color(0x33000000) : const Color(0x0A000000),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  /// 经典爱彼迎卡片悬浮阴影（大卡片、浮动胶囊）
  static List<BoxShadow> get shadowMd => [
        BoxShadow(
          color: isDark ? const Color(0x4D000000) : const Color(0x12000000),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  /// 模态底栏阴影
  static List<BoxShadow> get shadowLg => [
        BoxShadow(
          color: isDark ? const Color(0x66000000) : const Color(0x1F000000),
          blurRadius: 28,
          offset: const Offset(0, 10),
        ),
      ];

  /// 预测式返回全局页面转场配置 (对齐 ChatGPT / Android 15+ 原生卡片缩放跟手预览，当前页绝不中途消失)
  static const PageTransitionsTheme _pageTransitionsTheme =
      PageTransitionsTheme(
    builders: {
      TargetPlatform.android: SmoothPredictiveBackPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    },
  );

  // ── 全局 ThemeData 构造器 ──────────────────────────────────────
  static ThemeData get lightTheme {
    const lightBg = Color(0xFFF7F7F7);
    const lightSurface = Color(0xFFFFFFFF);
    const lightText = Color(0xFF222222);
    const lightBorder = Color(0xFFEBEBEB);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      pageTransitionsTheme: _pageTransitionsTheme,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: primaryDark,
        surface: lightSurface,
        error: error,
      ),
      fontFamily: 'System',
      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurface,
        foregroundColor: lightText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: lightText,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardTheme(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: lightBorder, width: 1.0),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: lightBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    const darkBg = Color(0xFF121212);
    const darkSurface = Color(0xFF1E1E1E);
    const darkText = Color(0xFFF3F4F6);
    const darkBorder = Color(0xFF2E2E2E);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      pageTransitionsTheme: _pageTransitionsTheme,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: primaryDark,
        surface: darkSurface,
        error: error,
      ),
      fontFamily: 'System',
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: darkText,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      cardTheme: CardTheme(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: darkBorder, width: 1.0),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }
}

/// 仿 ChatGPT 页面级预测式返回转场构建器：
/// 1. 物理弹簧阻尼跟手 + 对数空间阻尼：告别硬绑定手指路径，采用二阶临界阻尼弹簧与对数张力曲线，具备柔韧油压阻尼感；
/// 2. 二级界面渐隐 -> 中间态颜色 -> 一级界面从 0% 渐显：
///    - 前段：二级界面向右阻尼微移并渐隐，一级界面保持 0% 透明度，显露柔和中间态底色；
///    - 中后段：随着手指继续拖拉，从中间态底色中将一级界面从 0% 平滑渐显至 100%。
class SmoothPredictiveBackPageTransitionsBuilder extends PageTransitionsBuilder {
  const SmoothPredictiveBackPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _SmoothPredictiveBackGestureWrapper(
      route: route,
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

class _SmoothPredictiveBackGestureWrapper<T> extends StatefulWidget {
  const _SmoothPredictiveBackGestureWrapper({
    required this.route,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final PageRoute<T> route;
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  State<_SmoothPredictiveBackGestureWrapper<T>> createState() =>
      _SmoothPredictiveBackGestureWrapperState<T>();
}

class _SmoothPredictiveBackGestureWrapperState<T>
    extends State<_SmoothPredictiveBackGestureWrapper<T>>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  Ticker? _springTicker;
  Duration? _lastTickTime;
  bool _isDragging = false;

  /// 手指目标进度 (0.0: 起始二级界面 -> 1.0: 完全返回一级界面)
  double _targetBackProgress = 0.0;

  /// 经二阶弹簧阻尼器平滑后的实际渲染进度 (0.0 -> 1.0)
  double _currentBackProgress = 0.0;

  /// 弹簧当前速度
  double _velocity = 0.0;

  bool get _isEnabled =>
      widget.route.isCurrent && widget.route.popGestureEnabled;

  /// 将原始手指进度映射为带阻尼张力的目标进度
  double _computeDampedTarget(double rawProgress) {
    final clamped = rawProgress.clamp(0.0, 1.0);
    // 对数张力映射：前段细腻有韧性，中段平滑进入中间态，后段顺畅推向一级界面
    return (math.log(1.0 + 2.4 * clamped) / math.log(3.4)).clamp(0.0, 0.96);
  }

  void _onTick(Duration elapsed) {
    if (!_isDragging) return;

    final prev = _lastTickTime;
    _lastTickTime = elapsed;
    if (prev == null) return;

    final double dt =
        ((elapsed - prev).inMicroseconds / 1000000.0).clamp(0.001, 0.033);

    // 二阶弹簧阻尼物理模型：赋予手势真实的质量感与流体粘滞阻尼感，彻底消除硬绑定手指的生硬感
    const double stiffness = 115.0;
    const double damping = 19.0;

    final double displacement = _targetBackProgress - _currentBackProgress;
    final double springForce = stiffness * displacement;
    final double dampingForce = -damping * _velocity;
    final double acceleration = springForce + dampingForce;

    _velocity += acceleration * dt;
    _currentBackProgress =
        (_currentBackProgress + _velocity * dt).clamp(0.0, 0.98);

    widget.route.handleUpdateBackGestureProgress(
      progress: (1.0 - _currentBackProgress).clamp(0.01, 0.999),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _springTicker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _springTicker?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    if (backEvent.isButtonEvent || !_isEnabled) {
      return false;
    }
    _isDragging = true;
    _targetBackProgress = _computeDampedTarget(backEvent.progress);
    _currentBackProgress = 0.0;
    _velocity = 0.0;
    _lastTickTime = null;

    widget.route.handleStartBackGesture(progress: 1.0);
    if (!(_springTicker?.isActive ?? false)) {
      _springTicker?.start();
    }
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    if (!_isDragging) return;
    _targetBackProgress = _computeDampedTarget(backEvent.progress);
  }

  @override
  void handleCancelBackGesture() {
    _isDragging = false;
    _springTicker?.stop();
    _lastTickTime = null;
    widget.route.handleCancelBackGesture();
  }

  @override
  void handleCommitBackGesture() {
    _isDragging = false;
    _springTicker?.stop();
    _lastTickTime = null;
    widget.route.handleCommitBackGesture();
  }

  @override
  Widget build(BuildContext context) {
    return _ChatGptSlideFadeTransition(
      animation: widget.animation,
      secondaryAnimation: widget.secondaryAnimation,
      child: widget.child,
    );
  }
}

class _ChatGptSlideFadeTransition extends StatelessWidget {
  const _ChatGptSlideFadeTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  /// 对数空间橡皮筋阻尼：位移随拖拉距离增大而产生渐进阻力，绝不 1:1 死板跟随手指
  static double _dampedDisplacement(double progress) {
    final p = progress.clamp(0.0, 1.0);
    return math.log(1.0 + 4.5 * p) / math.log(5.5);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AirbnbTheme.themeModeNotifier,
      builder: (context, _, __) {
        // 中间态底色直接跟随当前界面默认背景色设置（不写死额外杂色，实时同步浅色/深色/自动模式）
        final bgColor = AirbnbTheme.background;

        return AnimatedBuilder(
          animation: Listenable.merge([animation, secondaryAnimation]),
          builder: (context, _) {
            Widget current = child;

            // 1. 当该路由作为底层【一级界面】时（p = 1.0 - secondaryAnimation.value: 0.0 刚开始返回 -> 1.0 完全返回）
            final secValue = secondaryAnimation.value;
            if (secValue > 0.0) {
              final p = (1.0 - secValue).clamp(0.0, 1.0);

              // 前 36% 进度内一级界面严格保持 0% 透明度；36% -> 100% 期间随手指拖拉从 0% 平滑渐显至 100%
              final bgStageRaw = ((p - 0.36) / 0.64).clamp(0.0, 1.0);
              final bgOpacity = Curves.easeInOutCubic.transform(bgStageRaw);

              // 一级界面伴随柔和阻尼从左侧微移归位 (-8% 屏幕宽度 -> 0)
              final bgShift = 1.0 - _dampedDisplacement(bgStageRaw);
              final bgDx = -screenWidth * 0.08 * bgShift;

              current = ColoredBox(
                color: bgColor,
                child: Opacity(
                  opacity: bgOpacity,
                  child: Transform.translate(
                    offset: Offset(bgDx, 0),
                    child: current,
                  ),
                ),
              );
            }

            // 2. 当该路由作为顶层【二级界面】时（p = 1.0 - animation.value: 0.0 刚开始返回 -> 1.0 完全退出）
            final animValue = animation.value;
            if (animValue < 1.0) {
              final p = (1.0 - animValue).clamp(0.0, 1.0);

              // 二级界面在前 46% 进度内向右阻尼微移并平滑渐隐至 0%，显露中间态默认背景底色
              final fgStageRaw = (1.0 - (p / 0.46)).clamp(0.0, 1.0);
              final fgOpacity = Curves.easeOutCubic.transform(fgStageRaw);

              // 对数橡皮筋阻尼位移：最大仅右移 13% 屏幕宽度，具备明显拉拽阻尼感
              final fgDx = screenWidth * 0.13 * _dampedDisplacement(p);

              // 全屏中间态背景遮罩层（颜色与界面默认底色一致）：
              // - 在 p ∈ [0.0, 0.36] 期间保持 100% 不透明，确保一级界面为 0%，呈现纯净的界面底色中间态；
              // - 在 p ∈ [0.36, 1.0] 期间随手指继续拖拉从 100% 消退至 0%，使底下一级界面从 0% 渐显至 100%。
              final maskFadeOut = ((p - 0.36) / 0.64).clamp(0.0, 1.0);
              final maskOpacity =
                  (1.0 - Curves.easeInOutCubic.transform(maskFadeOut))
                      .clamp(0.0, 1.0);

              current = Stack(
                fit: StackFit.expand,
                children: [
                  if (maskOpacity > 0.001)
                    IgnorePointer(
                      child: Opacity(
                        opacity: maskOpacity,
                        child: ColoredBox(color: bgColor),
                      ),
                    ),
                  Opacity(
                    opacity: fgOpacity,
                    child: Transform.translate(
                      offset: Offset(fgDx, 0),
                      child: current,
                    ),
                  ),
                ],
              );
            }

            return current;
          },
        );
      },
    );
  }
}
