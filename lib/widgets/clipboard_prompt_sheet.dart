/**
 * @file: clipboard_prompt_sheet.dart
 * @description: 剪贴板识别底部抽屉模态浮层 (爱彼迎轻量设计)
 * @author: Antigravity
 * @version: 2.0.0
 */

import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../core/constants.dart';
import '../parsers/parser_factory.dart';
import 'airbnb_button.dart';

class ClipboardPromptSheet extends StatelessWidget {
  final String text;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;

  const ClipboardPromptSheet({
    super.key,
    required this.text,
    required this.onConfirm,
    required this.onDismiss,
  });

  static Future<void> show({
    required BuildContext context,
    required String text,
    required VoidCallback onConfirm,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipboardPromptSheet(
        text: text,
        onConfirm: () {
          Navigator.of(ctx).pop();
          onConfirm();
        },
        onDismiss: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final platform = ParserFactory.detectPlatform(text);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
      decoration: BoxDecoration(
        color: AirbnbTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AirbnbTheme.radiusLg)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部拖拽指示条
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AirbnbTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 平台标签与咔捕惊喜发现吉祥物
          Row(
            children: [
              Image.asset(
                AppConstants.mascotDiscover,
                width: 44,
                height: 44,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 10),
              if (platform.iconAsset != null) ...[
                ClipOval(
                  child: Image.asset(platform.iconAsset!, width: 22, height: 22, fit: BoxFit.cover),
                ),
                const SizedBox(width: 8),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: platform.brandColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AirbnbTheme.radiusCapsule),
                ),
                child: Text(
                  platform.displayName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: platform.brandColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '咔捕发现分享链接',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AirbnbTheme.textMain,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 链接内容气泡卡片
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AirbnbTheme.background,
              borderRadius: BorderRadius.circular(AirbnbTheme.radiusSm),
              border: Border.all(color: AirbnbTheme.border),
            ),
            child: Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: AirbnbTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 操作按钮组
          Row(
            children: [
              Expanded(
                child: AirbnbButton(
                  text: '忽略',
                  isSecondary: true,
                  height: 48,
                  onPressed: onDismiss,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: AirbnbButton(
                  text: '立即解析',
                  height: 48,
                  onPressed: onConfirm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
