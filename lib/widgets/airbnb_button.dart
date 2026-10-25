/**
 * @file: airbnb_button.dart
 * @description: 爱彼迎设计规范触控交互按钮组件 (纯文字绝对几何居中)
 * @author: Antigravity
 * @version: 2.0.0
 */

import 'package:flutter/material.dart';
import '../app_theme.dart';

class AirbnbButton extends StatefulWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isSecondary;
  final bool isLoading;
  final double height;
  final double? width;

  const AirbnbButton({
    super.key,
    required this.text,
    this.icon,
    required this.onPressed,
    this.isSecondary = false,
    this.isLoading = false,
    this.height = 50.0,
    this.width,
  });

  @override
  State<AirbnbButton> createState() => _AirbnbButtonState();
}

class _AirbnbButtonState extends State<AirbnbButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final bool disabled = widget.onPressed == null || widget.isLoading;

    return AnimatedScale(
      scale: _isPressed && !disabled ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: SizedBox(
          height: widget.height,
          width: widget.width ?? double.infinity,
          child: ElevatedButton(
            onPressed: disabled ? null : widget.onPressed,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              padding: EdgeInsets.zero, // 零内边距，完全由 Center 控制几何居中
              backgroundColor: widget.isSecondary ? AirbnbTheme.surface : AirbnbTheme.primary,
              foregroundColor: widget.isSecondary ? AirbnbTheme.textMain : Colors.white,
              disabledBackgroundColor: widget.isSecondary
                  ? AirbnbTheme.surface
                  : AirbnbTheme.primary.withValues(alpha: 0.5),
              disabledForegroundColor: AirbnbTheme.textTertiary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AirbnbTheme.radiusCapsule),
                side: widget.isSecondary
                    ? BorderSide(color: AirbnbTheme.border, width: 1.5)
                    : BorderSide.none,
              ),
            ),
            child: widget.isLoading
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  )
                : Center(
                    child: widget.icon != null
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                widget.icon,
                                size: 18,
                                color: widget.isSecondary ? AirbnbTheme.textMain : Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.text,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
                                  color: widget.isSecondary ? AirbnbTheme.textMain : Colors.white,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            widget.text,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0,
                              color: widget.isSecondary ? AirbnbTheme.textMain : Colors.white,
                            ),
                          ),
                  ),
          ),
        ),
      ),
    );
  }
}
