/**
 * @file: floating_top_bar.dart
 * @description: 悬浮顶部栏 / 悬浮页面骨架（内容通顶 + 顶部背景色渐隐遮罩 + 悬浮胶囊元素 + Edge-to-Edge 适配）
 * @author: Antigravity
 * @version: 2.0.0
 *
 * 设计要点：
 * 1. 不再使用实体 AppBar，页面内容贯穿至状态栏与导航栏后方（Edge-to-Edge）；
 * 2. 顶部叠加一层"界面底色 → 透明"的渐隐遮罩，内容滑入顶部时自然淡出（零 BackdropFilter，无离屏渲染）；
 *    底部操作栏同理使用"透明 → 界面底色"的反向渐隐，并为手势条 / 三键导航栏预留安全距离；
 * 3. 顶部操作按钮收纳为悬浮胶囊，表面质感沿用 ChatGPT 共享 Surface 的明暗策略：
 *    - 浅色：97% 不透明表面 + 大半径零偏移柔影，不画描边；
 *    - 深色：97% 不透明表面 + 0.5dp 白 15% 细边，不画阴影。
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';

/// 多段 ease-in-out 渐隐采样，避免两段式线性渐变产生的"色带断层"。
/// [solidFraction] 之前为实色，之后平滑过渡到完全透明；[reverse] 为 true 时方向自下而上。
LinearGradient _buildFadeGradient(Color base, double solidFraction, {bool reverse = false}) {
  const samples = 16;
  final solidStop = solidFraction.clamp(0.0, 1.0);
  final colors = <Color>[base, base];
  final stops = <double>[0.0, solidStop];
  for (var i = 1; i <= samples; i++) {
    final t = i / samples;
    final alpha = 1.0 - Curves.easeInOut.transform(t);
    colors.add(base.withValues(alpha: alpha));
    stops.add(solidStop + (1.0 - solidStop) * t);
  }
  return LinearGradient(
    begin: reverse ? Alignment.bottomCenter : Alignment.topCenter,
    end: reverse ? Alignment.topCenter : Alignment.bottomCenter,
    colors: colors,
    stops: stops,
  );
}

class FloatingTopBar extends StatelessWidget {
  const FloatingTopBar({
    super.key,
    this.leading,
    this.actions = const [],
    this.bottom,
    this.bottomHeight = 0,
  });

  /// 顶部栏内容区高度（不含状态栏）
  static const double barHeight = 60.0;

  /// 渐隐遮罩在内容区下方额外延伸的过渡距离
  static const double fadeExtent = 36.0;

  /// 页面内容需要预留的顶部安全距离（状态栏 + 顶部栏 + 可选副栏）
  static double contentTopInset(BuildContext context, {double bottomHeight = 0}) =>
      MediaQuery.paddingOf(context).top + barHeight + bottomHeight;

  final Widget? leading;
  final List<Widget> actions;

  /// 顶部栏下方的悬浮副栏（如分段 Tab 胶囊）
  final Widget? bottom;
  final double bottomHeight;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final totalHeight = padding.top + barHeight + bottomHeight + fadeExtent;
    final solidHeight = padding.top + (barHeight + bottomHeight) * 0.45;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        children: [
          // 顶部底色渐隐遮罩（不拦截触摸，内容区下滑时仍可正常点击）
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: _buildFadeGradient(
                    AirbnbTheme.background,
                    solidHeight / totalHeight,
                  ),
                ),
              ),
            ),
          ),
          // 悬浮元素层（左右同时避让横屏刘海 / 挖孔）
          Positioned(
            top: padding.top,
            left: padding.left,
            right: padding.right,
            height: barHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: leading ?? const SizedBox.shrink(),
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
          ),
          if (bottom != null)
            Positioned(
              top: padding.top + barHeight,
              left: padding.left,
              right: padding.right,
              height: bottomHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(alignment: Alignment.topCenter, child: bottom),
              ),
            ),
        ],
      ),
    );
  }
}

/// 二级页面标准悬浮骨架：
/// - 顶部：圆形悬浮返回按钮 + 标题 + 右侧悬浮胶囊操作区，可选副栏；
/// - 内容：贯穿全屏，通过 [builder] 回调拿到需要预留的上下安全距离；
/// - 底部：可选悬浮操作栏，自带反向渐隐与导航栏避让。
class FloatingPageScaffold extends StatelessWidget {
  const FloatingPageScaffold({
    super.key,
    this.title,
    this.actions = const [],
    this.topBottom,
    this.topBottomHeight = 0,
    this.bottomBar,
    this.bottomBarHeight = 0,
    this.showBack = true,
    this.extendBodyBehindTop = true,
    required this.builder,
  });

  final String? title;
  final List<Widget> actions;
  final Widget? topBottom;
  final double topBottomHeight;

  /// 底部悬浮操作栏（不含导航栏安全距离，骨架会自动补齐）
  final Widget? bottomBar;

  /// 底部悬浮操作栏内容高度（用于计算内容区底部留白）
  final double bottomBarHeight;

  final bool showBack;

  /// 内容是否延伸到顶部栏后方。WebView 等无法预留内边距的平台视图应设为 false。
  final bool extendBodyBehindTop;

  /// [insets] 为内容区需要预留的上下安全距离（已含状态栏、顶部栏、底部栏与系统导航栏）
  final Widget Function(BuildContext context, EdgeInsets insets) builder;

  static const double _bottomBarVerticalPadding = 12.0;
  static const double _bottomFadeExtent = 28.0;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AirbnbTheme.themeModeNotifier,
      builder: (context, _, __) {
        final mq = MediaQuery.of(context);
        final padding = mq.padding;
        final topInset = FloatingTopBar.contentTopInset(
          context,
          bottomHeight: topBottomHeight,
        );
        final bottomBarTotal = bottomBar != null
            ? bottomBarHeight + _bottomBarVerticalPadding * 2
            : 0.0;
        final bottomInset = padding.bottom + bottomBarTotal;

        final insets = EdgeInsets.only(
          top: extendBodyBehindTop ? topInset : 0,
          bottom: bottomInset,
          left: padding.left,
          right: padding.right,
        );

        final body = builder(context, insets);

        return FloatingTopBarOverlayRegion(
          child: Scaffold(
            backgroundColor: AirbnbTheme.background,
            // 键盘弹出时不压缩整页，由各页面内容自行处理
            resizeToAvoidBottomInset: bottomBar == null,
            body: Stack(
              children: [
                Positioned.fill(
                  top: extendBodyBehindTop ? 0 : topInset,
                  child: body,
                ),
                if (bottomBar != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _buildBottomBar(padding),
                  ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: FloatingTopBar(
                    leading: _buildLeading(context),
                    actions: actions,
                    bottom: topBottom,
                    bottomHeight: topBottomHeight,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget? _buildLeading(BuildContext context) {
    final canPop = showBack && (ModalRoute.of(context)?.canPop ?? false);
    if (!canPop && title == null) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canPop) ...[
          FloatingPill(
            padding: EdgeInsets.zero,
            child: SizedBox(
              width: 44,
              child: FloatingPillIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        if (title != null)
          Flexible(
            child: Text(
              title!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: AirbnbTheme.textMain,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomBar(EdgeInsets padding) {
    final totalHeight = _bottomFadeExtent +
        bottomBarHeight +
        _bottomBarVerticalPadding * 2 +
        padding.bottom;
    return SizedBox(
      height: totalHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: _buildFadeGradient(
                    AirbnbTheme.background,
                    (totalHeight - _bottomFadeExtent) / totalHeight * 0.75,
                    reverse: true,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: padding.left + 20,
            right: padding.right + 20,
            bottom: padding.bottom + _bottomBarVerticalPadding,
            height: bottomBarHeight,
            child: bottomBar!,
          ),
        ],
      ),
    );
  }
}

/// 悬浮胶囊容器（ChatGPT 共享 Surface 明暗策略）
class FloatingPill extends StatelessWidget {
  const FloatingPill({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 4),
    this.height = 44,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = AirbnbTheme.isDark;
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: AirbnbTheme.surface.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(AirbnbTheme.radiusCapsule),
        border: dark
            ? Border.all(color: const Color(0x26FFFFFF), width: 0.5)
            : null,
        boxShadow: dark
            ? null
            : const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 24,
                  offset: Offset.zero,
                ),
              ],
      ),
      child: child,
    );
  }
}

/// 悬浮胶囊内的圆形图标按钮
class FloatingPillIconButton extends StatelessWidget {
  const FloatingPillIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 22, color: color ?? AirbnbTheme.textMain),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      padding: EdgeInsets.zero,
    );
  }
}

/// 无实体 AppBar 时同步状态栏 / 导航栏图标反色（导航栏背景透明，内容绘制到手势条后方）
class FloatingTopBarOverlayRegion extends StatelessWidget {
  const FloatingTopBarOverlayRegion({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = AirbnbTheme.isDark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        systemStatusBarContrastEnforced: false,
      ),
      child: child,
    );
  }
}
