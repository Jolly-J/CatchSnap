/**
 * @file: airbnb_card.dart
 * @description: 爱彼迎大圆角漫反射高质感卡片容器
 * @author: Antigravity
 * @version: 2.0.0
 */

import 'package:flutter/material.dart';
import '../app_theme.dart';

class AirbnbCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double borderRadius;
  final bool hasBorder;

  const AirbnbCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20.0),
    this.onTap,
    this.backgroundColor,
    this.borderRadius = AirbnbTheme.radiusMd,
    this.hasBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? AirbnbTheme.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: hasBorder ? Border.all(color: AirbnbTheme.border, width: 1.0) : null,
        boxShadow: AirbnbTheme.shadowSm,
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        splashColor: AirbnbTheme.primary.withOpacity(0.05),
        highlightColor: AirbnbTheme.primary.withOpacity(0.02),
        child: content,
      );
    }

    return content;
  }
}
