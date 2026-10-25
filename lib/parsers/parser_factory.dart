/**
 * @file: parser_factory.dart
 * @description: 多平台解析工厂与路由分发中枢
 * @author: Antigravity
 * @version: 2.0.0
 */

import '../core/security_storage.dart';
import '../models/media_item.dart';
import '../models/platform_type.dart';
import 'base_parser.dart';
import 'douyin_parser.dart';
import 'xhs_parser.dart';

class ParserFactory {
  static final List<BaseParser> _parsers = [
    DouyinParser(),
    XhsParser(),
  ];

  /// 识别目标平台类型
  static PlatformType detectPlatform(String input) {
    for (final parser in _parsers) {
      if (parser.canHandle(input)) {
        return parser.platform;
      }
    }
    return PlatformType.unknown;
  }

  /// 自动解析分发
  static Future<MediaItem> parse(String input) async {
    final cleanInput = input.trim();
    if (cleanInput.isEmpty) {
      throw Exception('请输入有效的分享链接或口令');
    }

    BaseParser? targetParser;
    for (final parser in _parsers) {
      if (parser.canHandle(cleanInput)) {
        targetParser = parser;
        break;
      }
    }

    if (targetParser == null) {
      throw Exception('当前仅支持解析抖音或小红书链接，未匹配到对应平台');
    }

    // 智能附加本地对应平台的已保存 Cookie
    String? cookie;
    if (targetParser.platform == PlatformType.douyin) {
      cookie = await SecurityStorage.getDouyinCookie();
    } else if (targetParser.platform == PlatformType.xiaohongshu) {
      cookie = await SecurityStorage.getXhsCookie();
    }

    return targetParser.parse(cleanInput, cookie: cookie);
  }
}
