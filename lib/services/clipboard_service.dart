/**
 * @file: clipboard_service.dart
 * @description: 进 App 单次安全剪贴板检测服务 (非实时偷听，尊重隐私与电量)
 * @author: Antigravity
 * @version: 2.0.0
 */

import 'package:flutter/services.dart';
import '../parsers/parser_factory.dart';
import '../models/platform_type.dart';

class ClipboardService {
  /// 缓存上一次检测处理过的剪贴板文本，防止在 App 内切换前后台时重复弹窗骚扰
  static String? _lastCheckedText;

  /// 单次检测剪贴板内容
  /// 仅在应用冷启动，或从后台切回前台（AppLifecycleState.resumed）时主动触发一次
  static Future<String?> checkOnAppResume() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text?.trim() ?? '';

      if (text.isEmpty) return null;

      // 如果与上次处理的文本相同，则跳过
      if (text == _lastCheckedText) return null;

      // 检测是否为支持的平台链接
      final platform = ParserFactory.detectPlatform(text);
      if (platform != PlatformType.unknown) {
        _lastCheckedText = text;
        return text;
      }
    } catch (_) {
      // 容错剪贴板异常（某些 Android 厂商 ROM 限制非焦点读取）
    }
    return null;
  }

  /// 手动清除已记录的文本缓存（例如用户点击清空或取消后）
  static void clearCache() {
    _lastCheckedText = null;
  }
}
