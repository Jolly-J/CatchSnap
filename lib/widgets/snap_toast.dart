/**
 * @file: snap_toast.dart
 * @description: 灵动极简顶部悬浮胶囊 Toast 提示 (爱彼迎极简现代风)
 * @author: Antigravity
 * @version: 2.0.0
 * 
 * 核心特性：
 * 1. 替代过时生硬的系统原生底栏 SnackBar。
 * 2. 顶部微动效滑入（弹性曲线 + 渐变透明度），如同灵动岛与流体云设计。
 * 3. 采用深邃质感暗夜药丸/纯净卡片形态，区分成功、错误、常规提示。
 */

import 'package:flutter/material.dart';
import '../core/constants.dart';

enum ToastType {
  info,
  success,
  error;

  String get mascotAsset {
    switch (this) {
      case ToastType.success:
        return AppConstants.mascotSuccess;
      case ToastType.error:
        return AppConstants.mascotSad;
      case ToastType.info:
        return AppConstants.brandLogo;
    }
  }

  Color get iconColor {
    switch (this) {
      case ToastType.success:
        return const Color(0xFF008A05);
      case ToastType.error:
        return const Color(0xFFFF385C);
      case ToastType.info:
        return const Color(0xFFFF385C);
    }
  }

  IconData get iconData {
    switch (this) {
      case ToastType.success:
        return Icons.check_circle_rounded;
      case ToastType.error:
        return Icons.error_rounded;
      case ToastType.info:
        return Icons.info_rounded;
    }
  }
}

class SnapToast {
  static OverlayEntry? _currentEntry;

  /// 展示顶部悬浮提示
  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
    Duration duration = const Duration(milliseconds: 2400),
  }) {
    // 移除已有的提示，避免重叠堆叠
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.of(context, rootOverlay: true);

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _ToastAnimationWidget(
        message: message,
        type: type,
        duration: duration,
        onDismiss: () {
          if (_currentEntry == entry) {
            entry.remove();
            _currentEntry = null;
          }
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }

  static void success(BuildContext context, String message) {
    show(context, message, type: ToastType.success);
  }

  static void error(BuildContext context, String message) {
    show(context, message, type: ToastType.error);
  }

  static void info(BuildContext context, String message) {
    show(context, message, type: ToastType.info);
  }
}

class _ToastAnimationWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final Duration duration;
  final VoidCallback onDismiss;

  const _ToastAnimationWidget({
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_ToastAnimationWidget> createState() => _ToastAnimationWidgetState();
}

class _ToastAnimationWidgetState extends State<_ToastAnimationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));

    _ctrl.forward();

    // 延迟后滑出并销毁
    Future.delayed(widget.duration, () async {
      if (mounted) {
        await _ctrl.reverse();
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 10,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: Align(
          alignment: Alignment.topCenter,
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: GestureDetector(
                onTap: () async {
                  await _ctrl.reverse();
                  widget.onDismiss();
                },
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E), // 极具质感的灵动暗夜黑胶囊
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 0.8,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x3D000000),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        widget.type.mascotAsset,
                        width: 28,
                        height: 28,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          widget.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.3,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
