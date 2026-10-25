/**
 * @file: base_parser.dart
 * @description: 平台本地解析器抽象契约接口
 * @author: Antigravity
 * @version: 2.0.0
 */

import '../models/media_item.dart';
import '../models/platform_type.dart';

abstract class BaseParser {
  /// 当前解析器所属平台
  PlatformType get platform;

  /// 判断该链接/分享口令是否由当前解析器处理
  bool canHandle(String input);

  /// 执行本地免服解析，返回归一化的 MediaItem
  Future<MediaItem> parse(String input, {String? cookie});
}
