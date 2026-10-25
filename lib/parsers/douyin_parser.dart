/**
 * @file: douyin_parser.dart
 * @description: 抖音本地免服高清解析器 (iPhone UA 伪装 + _ROUTER_DATA 结构解包 + Cookie 增强)
 * @author: Antigravity
 * @version: 2.0.0
 */

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../models/media_item.dart';
import '../models/platform_type.dart';
import 'base_parser.dart';

class DouyinParser extends BaseParser {
  @override
  PlatformType get platform => PlatformType.douyin;

  @override
  bool canHandle(String input) {
    return input.contains('douyin.com') ||
        input.contains('v.douyin.com') ||
        RegExp(r'^\d{16,}$').hasMatch(input.trim());
  }

  @override
  Future<MediaItem> parse(String input, {String? cookie}) async {
    final result = await _extractAwemeInfo(input, cookie);
    return _fetchVideoInfo(result.$1, result.$2, cookie, input);
  }

  // ── 内部解析子流程 ───────────────────────────────────────────

  /// 提取视频 ID 与跟随重定向产生的 Cookie (关键凭据 ttwid)
  Future<(String, String)> _extractAwemeInfo(String input, String? cookie) async {
    // 纯数字 ID
    if (RegExp(r'^\d{16,}$').hasMatch(input.trim())) {
      final ttwid = await _ensureTtwid(cookie);
      return (input.trim(), ttwid);
    }

    // 正则捕获短链
    final shortUrlMatch = RegExp(r'https?://v\.douyin\.com/[\w\-/]+').firstMatch(input);
    String targetUrl = shortUrlMatch?.group(0) ?? input;

    final (realUrl, collectedCookie) = await _followRedirectWithCookies(targetUrl, cookie);

    final id = _extractIdFromUrl(realUrl);
    if (id == null) {
      throw Exception('无法从抖音分享链接中提取有效视频 ID');
    }

    // 确保有 ttwid
    String finalCookie = collectedCookie;
    if (!finalCookie.contains('ttwid')) {
      final extraTtwid = await _ensureTtwid(cookie);
      if (extraTtwid.isNotEmpty) {
        finalCookie = finalCookie.isEmpty ? extraTtwid : '$finalCookie; $extraTtwid';
      }
    }

    return (id, finalCookie);
  }

  /// 跟随 302 重定向并收集全程 Set-Cookie (包含 ttwid)
  Future<(String, String)> _followRedirectWithCookies(String url, String? userCookie) async {
    final client = http.Client();
    final cookieMap = <String, String>{};

    if (userCookie != null && userCookie.isNotEmpty) {
      _parseCookieString(userCookie, cookieMap);
    }

    try {
      String current = url;
      for (int i = 0; i < 10; i++) {
        final req = http.Request('GET', Uri.parse(current))
          ..followRedirects = false
          ..headers.addAll({
            'User-Agent': AppConstants.uaIPhone,
            if (cookieMap.isNotEmpty)
              'Cookie': cookieMap.entries.map((e) => '${e.key}=${e.value}').join('; '),
          });

        final resp = await client.send(req);

        // 收集响应 Cookie
        final setCookie = resp.headers['set-cookie'];
        if (setCookie != null) {
          _parseSetCookieHeader(setCookie, cookieMap);
        }

        if (resp.statusCode >= 300 && resp.statusCode < 400) {
          final loc = resp.headers['location'];
          if (loc == null) break;
          current = loc.startsWith('http') ? loc : Uri.parse(current).resolve(loc).toString();
        } else {
          break;
        }
      }

      final cookieStr = cookieMap.entries.map((e) => '${e.key}=${e.value}').join('; ');
      return (current, cookieStr);
    } finally {
      client.close();
    }
  }

  /// 探查并确保存在 ttwid 凭据
  Future<String> _ensureTtwid(String? userCookie) async {
    if (userCookie != null && userCookie.contains('ttwid')) return '';
    try {
      final resp = await http.get(
        Uri.parse('https://www.douyin.com/'),
        headers: {'User-Agent': AppConstants.uaIPhone},
      ).timeout(const Duration(seconds: 8));

      final setCookie = resp.headers['set-cookie'];
      if (setCookie != null) {
        final match = RegExp(r'ttwid=[^;,\s]+').firstMatch(setCookie);
        if (match != null) return match.group(0)!;
      }
    } catch (_) {}
    return '';
  }

  void _parseCookieString(String raw, Map<String, String> out) {
    for (final part in raw.split(';')) {
      final s = part.trim();
      final idx = s.indexOf('=');
      if (idx > 0) {
        out[s.substring(0, idx).trim()] = s.substring(idx + 1).trim();
      }
    }
  }

  void _parseSetCookieHeader(String raw, Map<String, String> out) {
    // 专门提取 ttwid
    final ttwidMatch = RegExp(r'ttwid=[^;,\s]+').firstMatch(raw);
    if (ttwidMatch != null) {
      final parts = ttwidMatch.group(0)!.split('=');
      out[parts[0]] = parts[1];
    }
    // 通用提取
    final matches = RegExp(r'([a-zA-Z0-9_\-]+)=([^;,\s]+)').allMatches(raw);
    for (final m in matches) {
      final k = m.group(1)!;
      final v = m.group(2)!;
      if (!out.containsKey(k) && k != 'path' && k != 'domain' && k != 'expires' && k != 'samesite') {
        out[k] = v;
      }
    }
  }

  String? _extractIdFromUrl(String url) {
    final patterns = [
      RegExp(r'/video/(\d+)'),
      RegExp(r'/note/(\d+)'),
      RegExp(r'modal_id=(\d+)'),
      RegExp(r'[?&]vid=(\d+)'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(url);
      if (m != null) return m.group(1);
    }
    return null;
  }

  /// 请求 iesdouyin 获取官方页面 SSR 状态
  Future<MediaItem> _fetchVideoInfo(
    String awemeId,
    String redirectCookie,
    String? userCookie,
    String originalUrl,
  ) async {
    final url = 'https://www.iesdouyin.com/share/video/$awemeId/';

    final combinedCookies = <String>[];
    if (redirectCookie.isNotEmpty) combinedCookies.add(redirectCookie);
    if (userCookie != null && userCookie.isNotEmpty) combinedCookies.add(userCookie);
    if (!combinedCookies.any((c) => c.contains('ttwid='))) {
      final ttwid = await _ensureTtwid(userCookie);
      if (ttwid.isNotEmpty) combinedCookies.add(ttwid);
    }

    final headers = {
      'User-Agent': AppConstants.uaIPhone,
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9',
      if (combinedCookies.isNotEmpty) 'Cookie': combinedCookies.join('; '),
    };

    var resp = await http.get(Uri.parse(url), headers: headers)
        .timeout(const Duration(seconds: 20));

    if (resp.statusCode != 200) {
      throw Exception('请求抖音分享页失败 HTTP: ${resp.statusCode}');
    }

    List? extractItemList(String htmlBody) {
      final m = RegExp(
        r'window\._ROUTER_DATA\s*=\s*(.*?)</script>',
        dotAll: true,
      ).firstMatch(htmlBody);
      if (m == null) return null;
      try {
        final jsonStr = m.group(1)!.trim();
        final jsonData = json.decode(jsonStr) as Map<String, dynamic>;
        final loaderData = (jsonData['loaderData'] ?? jsonData) as Map<String, dynamic>;
        final Map<String, dynamic>? pageData =
            loaderData['video_(id)/page'] as Map<String, dynamic>? ??
                loaderData['note_(id)/page'] as Map<String, dynamic>? ??
                loaderData.values.whereType<Map<String, dynamic>>().firstWhere(
                      (map) => map.containsKey('videoInfoRes'),
                      orElse: () => {},
                    );
        final videoInfoRes = pageData?['videoInfoRes'] as Map<String, dynamic>?;
        return videoInfoRes?['item_list'] as List?;
      } catch (_) {
        return null;
      }
    }

    var itemList = extractItemList(resp.body);
    if (itemList == null || itemList.isEmpty) {
      // 若首次响应未下发 item_list，采集响应 Set-Cookie 重试一次
      final respCookie = resp.headers['set-cookie'];
      if (respCookie != null) {
        final cookieMap = <String, String>{};
        for (final c in combinedCookies) {
          _parseCookieString(c, cookieMap);
        }
        _parseSetCookieHeader(respCookie, cookieMap);
        final newCookieStr = cookieMap.entries.map((e) => '${e.key}=${e.value}').join('; ');
        final retryHeaders = {...headers, 'Cookie': newCookieStr};
        resp = await http.get(Uri.parse(url), headers: retryHeaders)
            .timeout(const Duration(seconds: 20));
        if (resp.statusCode == 200) {
          itemList = extractItemList(resp.body);
        }
      }
    }

    if (itemList == null || itemList.isEmpty) {
      final fallbackItem = await _fetchViaWebApi(awemeId, combinedCookies, originalUrl);
      if (fallbackItem != null) return fallbackItem;
      throw Exception('未找到对应的抖音视频条目');
    }

    return _mapToMediaItem(itemList[0] as Map<String, dynamic>, originalUrl);
  }

  MediaItem _mapToMediaItem(Map<String, dynamic> item, String originalUrl) {
    final author = (item['author'] as Map<String, dynamic>?) ?? {};
    final video = (item['video'] as Map<String, dynamic>?) ?? {};
    final music = (item['music'] as Map<String, dynamic>?) ?? {};
    final statistics = (item['statistics'] as Map<String, dynamic>?) ?? {};

    final awemeType = item['aweme_type'] as int? ?? 0;
    final isImage = awemeType == 2 || awemeType == 68;

    // 视频流提取与多清晰度档位构建
    final playAddr = (video['play_addr'] as Map<String, dynamic>?) ?? {};
    final urlList = (playAddr['url_list'] as List?) ?? [];
    final uri = playAddr['uri'] as String? ?? '';

    String rawPlayUrl = urlList.isNotEmpty ? urlList[0] as String : '';
    String video1080p = '';
    String video720p = '';

    if (rawPlayUrl.isNotEmpty) {
      video1080p = rawPlayUrl
          .replaceAll('playwm', 'play')
          .replaceAll('ratio=720p', 'ratio=1080p')
          .replaceAll('ratio=540p', 'ratio=1080p');
      video720p = rawPlayUrl.replaceAll('playwm', 'play').replaceAll('ratio=1080p', 'ratio=720p');
    } else if (uri.isNotEmpty) {
      video1080p = 'https://aweme.snssdk.com/aweme/v1/play/?video_id=$uri&ratio=1080p&line=0';
      video720p = 'https://aweme.snssdk.com/aweme/v1/play/?video_id=$uri&ratio=720p&line=0';
    }

    final streams = <VideoStream>[];
    final rawWidth = (video['width'] as int?) ?? 0;
    final rawHeight = (video['height'] as int?) ?? 0;

    int w1080 = 1080;
    int h1080 = 1920;
    int w720 = 720;
    int h720 = 1280;

    if (rawWidth > 0 && rawHeight > 0) {
      if (rawHeight >= rawWidth) {
        w1080 = 1080;
        h1080 = (1080 * rawHeight / rawWidth).round();
        w720 = 720;
        h720 = (720 * rawHeight / rawWidth).round();
      } else {
        h1080 = 1080;
        w1080 = (1080 * rawWidth / rawHeight).round();
        h720 = 720;
        w720 = (720 * rawWidth / rawHeight).round();
      }
    }

    if (video1080p.isNotEmpty) {
      streams.add(VideoStream(
        gearName: '超清',
        url: video1080p,
        width: w1080,
        height: h1080,
        codec: 'H.264',
        bitrate: 4000000,
        badge: '超清推荐',
      ));
    }
    if (video720p.isNotEmpty && video720p != video1080p) {
      streams.add(VideoStream(
        gearName: '高清',
        url: video720p,
        width: w720,
        height: h720,
        codec: 'H.264',
        bitrate: 2000000,
      ));
    }

    // 封面提取
    final originCover = (video['origin_cover'] as Map?)?.cast<String, dynamic>() ?? {};
    final standardCover = (video['cover'] as Map?)?.cast<String, dynamic>() ?? {};
    final dynamicCover = (video['dynamic_cover'] as Map?)?.cast<String, dynamic>() ?? {};

    final coverList = (originCover['url_list'] as List?) ??
        (standardCover['url_list'] as List?) ??
        (dynamicCover['url_list'] as List?) ??
        [];
    final cover = coverList.isNotEmpty ? coverList[0] as String : '';

    // 图集与 Live 实况动图判断
    final images = <String>[];
    final liveClips = <String>[];
    bool isLive = false;

    if (isImage) {
      final rawImages = item['images'] as List? ?? [];
      for (final img in rawImages) {
        final imgMap = img as Map<String, dynamic>;
        final clipVideo = (imgMap['video'] as Map?)?.cast<String, dynamic>() ?? {};
        final clipPlayAddr = (clipVideo['play_addr'] as Map?)?.cast<String, dynamic>() ?? {};
        final clipUrls = (clipPlayAddr['url_list'] as List?) ?? [];

        if (clipUrls.isNotEmpty) {
          isLive = true;
          liveClips.add(clipUrls[0] as String);
        } else {
          final imgUrls = (imgMap['url_list'] as List?) ?? [];
          if (imgUrls.isNotEmpty) images.add(imgUrls[0] as String);
        }
      }
    }

    // 作者头像与 UID
    final avatarThumb = (author['avatar_medium'] as Map?)?.cast<String, dynamic>() ??
        (author['avatar_thumb'] as Map?)?.cast<String, dynamic>() ??
        (author['avatar_168x168'] as Map?)?.cast<String, dynamic>() ??
        (author['avatar_300x300'] as Map?)?.cast<String, dynamic>() ??
        (author['avatar_larger'] as Map?)?.cast<String, dynamic>() ??
        {};
    final avatarList = (avatarThumb['url_list'] as List?) ?? [];
    final avatar = avatarList.isNotEmpty ? avatarList[0] as String : '';

    return MediaItem(
      id: item['aweme_id']?.toString() ?? '',
      platform: PlatformType.douyin,
      title: item['desc'] as String? ?? '无标题内容',
      author: author['nickname'] as String? ?? '抖音创作者',
      authorAvatar: avatar,
      authorUid: (author['unique_id'] ?? author['short_id'] ?? author['uid'] ?? '').toString(),
      coverUrl: cover,
      videoUrl: video1080p,
      videoStreams: streams,
      images: images,
      isLivePhoto: isLive,
      livePhotoClips: liveClips,
      likeCount: statistics['digg_count'] as int? ?? 0,
      durationMs: video['duration'] as int? ?? 0,
      musicTitle: music['title'] as String? ?? '',
      musicAuthor: music['author'] as String? ?? '',
      musicUrl: (music['play_url']?['url_list'] as List?)?.firstOrNull?.toString() ?? '',
      createTime: item['create_time'] as int? ?? 0,
      originalUrl: originalUrl,
    );
  }

  /// 降级调用官方公开 Web API 接口
  Future<MediaItem?> _fetchViaWebApi(
    String awemeId,
    List<String> combinedCookies,
    String originalUrl,
  ) async {
    try {
      final apiUrl = 'https://www.iesdouyin.com/web/api/v2/aweme/iteminfo/?item_ids=$awemeId';
      final headers = {
        'User-Agent': AppConstants.uaIPhone,
        'Accept': 'application/json',
        if (combinedCookies.isNotEmpty) 'Cookie': combinedCookies.join('; '),
      };
      final res = await http.get(Uri.parse(apiUrl), headers: headers).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final itemList = data['item_list'] as List?;
        if (itemList != null && itemList.isNotEmpty) {
          return _mapToMediaItem(itemList[0] as Map<String, dynamic>, originalUrl);
        }
      }
    } catch (_) {}
    return null;
  }
}
