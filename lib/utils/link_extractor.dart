/**
 * @file: link_extractor.dart
 * @description: 多平台分享文案正则与有效 URL 提取器
 * @author: Antigravity
 * @version: 2.0.0
 */

class LinkExtractor {
  /// 从用户粘入的任意混合文本中提取支持的有效 HTTP/HTTPS 链接
  static String? extractLink(String text) {
    if (text.isEmpty) return null;

    // 1. 优先提取抖音链接 (短链 或 视频主页)
    final douyinMatch = RegExp(
      r'https?://(?:v\.douyin\.com/[\w\-/]+|(?:www\.)?douyin\.com/(?:video|note|discover|user)/[^\s]+)',
    ).firstMatch(text);

    if (douyinMatch != null) {
      return douyinMatch.group(0);
    }

    // 2. 提取小红书链接 (短链 或 发现页，支持 xhslink.com 与 xhslink.cn)
    final xhsMatch = RegExp(
      r'https?://(?:xhslink\.(?:com|cn)/[\w\-/]+|(?:www\.)?xiaohongshu\.com/(?:explore|discovery/item)/[^\s]+)',
    ).firstMatch(text);

    if (xhsMatch != null) {
      return xhsMatch.group(0);
    }

    // 3. 通用兜底：提取第一个有效 https?:// 链接
    final genericMatch = RegExp(r'https?://[^\s，。、“”]+').firstMatch(text);
    return genericMatch?.group(0);
  }
}
