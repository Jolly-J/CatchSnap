/**
 * @file: xhs_parser.dart
 * @description: 小红书本地高清无水印解析器 (短链重定向 + __INITIAL_STATE__ 结构解包 + 4K/1080p原画提取)
 * @author: Antigravity
 * @version: 2.0.0
 */

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../models/media_item.dart';
import '../models/platform_type.dart';
import 'base_parser.dart';

class XhsParser extends BaseParser {
  @override
  PlatformType get platform => PlatformType.xiaohongshu;

  @override
  bool canHandle(String input) {
    return input.contains('xiaohongshu.com') ||
        input.contains('xhslink.com') ||
        input.contains('xhslink.cn');
  }

  @override
  Future<MediaItem> parse(String input, {String? cookie}) async {
    // 1. 提取短链并跟随重定向拿到真实落地页
    final rawUrl = _extractUrl(input);
    final (realUrl, collectedCookies) = await _followRedirectWithCookies(rawUrl, cookie);

    // 2. 提取 noteId
    final noteId = _extractNoteId(realUrl) ?? _extractNoteId(Uri.decodeComponent(realUrl));
    if (noteId == null) {
      throw Exception('无法从小红书链接中提取笔记 ID');
    }

    // 3. 构建适合移动端的真实请求页面 URL (确保包含 xsec_token 等防爬验证参数)
    String targetPageUrl = realUrl;
    if (realUrl.contains('/login')) {
      final queryIndex = realUrl.indexOf('?');
      final queryParams = queryIndex != -1 ? realUrl.substring(queryIndex) : '';
      targetPageUrl = 'https://www.xiaohongshu.com/discovery/item/$noteId$queryParams';
    }

    // 4. 请求页面并解析 SSR 数据
    return _fetchNoteDetail(targetPageUrl, noteId, cookie, collectedCookies, input);
  }

  // ── 内部提取逻辑 ─────────────────────────────────────────────

  String _extractUrl(String text) {
    final reg = RegExp(r'https?://[^\s，。、“”]+');
    final match = reg.firstMatch(text);
    return match?.group(0) ?? text.trim();
  }

  Future<(String, String)> _followRedirectWithCookies(String url, String? cookie) async {
    final client = http.Client();
    final cookieMap = <String, String>{};

    if (cookie != null && cookie.isNotEmpty) {
      _parseCookieString(cookie, cookieMap);
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

        // 收集响应头中的 Set-Cookie
        final rawSet = resp.headers['set-cookie'];
        if (rawSet != null) {
          final matches = RegExp(r'([a-zA-Z0-9_\-]+)=([^;,\s]+)').allMatches(rawSet);
          for (final m in matches) {
            final k = m.group(1)!;
            final v = m.group(2)!;
            if (!cookieMap.containsKey(k) &&
                k != 'path' &&
                k != 'domain' &&
                k != 'expires' &&
                k != 'samesite') {
              cookieMap[k] = v;
            }
          }
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

  void _parseCookieString(String raw, Map<String, String> out) {
    for (final part in raw.split(';')) {
      final s = part.trim();
      final idx = s.indexOf('=');
      if (idx > 0) {
        out[s.substring(0, idx).trim()] = s.substring(idx + 1).trim();
      }
    }
  }

  String? _extractNoteId(String url) {
    final patterns = [
      RegExp(r'/explore/([a-zA-Z0-9]+)'),
      RegExp(r'/discovery/item/([a-zA-Z0-9]+)'),
      RegExp(r'/item/([a-zA-Z0-9]+)'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(url);
      if (m != null) return m.group(1);
    }
    return null;
  }

  Future<MediaItem> _fetchNoteDetail(
    String pageUrl,
    String noteId,
    String? userCookie,
    String collectedCookie,
    String originalUrl,
  ) async {
    final combinedCookies = <String>[];
    if (collectedCookie.isNotEmpty) combinedCookies.add(collectedCookie);
    if (userCookie != null && userCookie.isNotEmpty) combinedCookies.add(userCookie);

    final headers = {
      'User-Agent': AppConstants.uaIPhone,
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      if (combinedCookies.isNotEmpty) 'Cookie': combinedCookies.join('; '),
    };

    final resp = await http.get(Uri.parse(pageUrl), headers: headers)
        .timeout(const Duration(seconds: 20));

    if (resp.statusCode != 200) {
      throw Exception('请求小红书页面失败 HTTP: ${resp.statusCode}');
    }

    // 提取 window.__INITIAL_STATE__
    final match = RegExp(
      r'window\.__INITIAL_STATE__\s*=\s*(.*?)</script>',
      dotAll: true,
    ).firstMatch(resp.body);

    if (match == null) {
      throw Exception('无法从小红书页面提取状态数据，建议在设置中登录小红书账号获取 Cookie');
    }

    String jsonStr = match.group(1)!.trim();
    // 处理 JavaScript undefined 占位符
    jsonStr = jsonStr.replaceAll(':undefined', ':null');
    final state = json.decode(jsonStr) as Map<String, dynamic>;

    // 兼容桌面端 noteDetailMap 与移动端 noteData
    final noteMap = (state['note']?['noteDetailMap'] as Map<String, dynamic>?) ?? {};
    final noteContainer = noteMap[noteId] as Map<String, dynamic>?;
    final note = noteContainer?['note'] as Map<String, dynamic>? ??
        state['noteData']?['data']?['noteData'] as Map<String, dynamic>?;

    if (note == null) {
      throw Exception('未找到小红书笔记数据，可能是私密笔记或需登录验证');
    }

    return _mapToMediaItem(note, noteId, originalUrl);
  }

  MediaItem _mapToMediaItem(Map<String, dynamic> note, String noteId, String originalUrl) {
    final title = (note['title'] as String? ?? '').isNotEmpty
        ? note['title'] as String
        : (note['desc'] as String? ?? '小红书笔记');
    final user = (note['user'] as Map<String, dynamic>?) ?? {};
    final interactInfo = (note['interactInfo'] as Map<String, dynamic>?) ?? {};
    final type = note['type'] as String? ?? 'normal';
    final isVideo = type == 'video';

    // 视频流提取
    final streams = <VideoStream>[];
    String primaryVideoUrl = '';
    int duration = 0;

    if (isVideo && note['video'] != null) {
      final videoObj = note['video'] as Map<String, dynamic>;
      final media = (videoObj['media'] as Map<String, dynamic>?) ?? {};
      final streamObj = (media['stream'] as Map<String, dynamic>?) ?? {};

      // 提取 h264 或 h265 流
      final h264List = (streamObj['h264'] as List?) ?? [];
      final h265List = (streamObj['h265'] as List?) ?? [];
      final allStreams = [...h264List, ...h265List];

      for (final s in allStreams) {
        final sMap = s as Map<String, dynamic>;
        String mUrl = sMap['masterUrl'] as String? ?? '';
        if (mUrl.startsWith('http://')) {
          mUrl = mUrl.replaceFirst('http://', 'https://');
        }
        final qType = sMap['qualityType'] as String? ?? '';
        final bitrate = sMap['videoBitrate'] as int? ?? 0;
        final d = sMap['videoDuration'] as int? ?? 0;
        if (d > duration) duration = d;

        if (mUrl.isNotEmpty) {
          final gear = _formatGear(qType, bitrate);
          streams.add(VideoStream(gearName: gear, url: mUrl, bitrate: bitrate));
          if (primaryVideoUrl.isEmpty) primaryVideoUrl = mUrl;
        }
      }

      // 如果 stream 中未获取到，尝试从 consumer key 兜底
      if (primaryVideoUrl.isEmpty) {
        final key = videoObj['consumer']?['originVideoKey'] as String? ?? '';
        if (key.isNotEmpty) {
          primaryVideoUrl = 'https://sns-video-bd.xhscdn.com/$key';
          streams.add(VideoStream(gearName: '原始无水印视频', url: primaryVideoUrl));
        }
      }
    }

    // 图集与 Live 实况处理
    final images = <String>[];
    final liveClips = <String>[];
    bool isLive = false;

    final imageList = (note['imageList'] as List?) ?? [];
    for (final img in imageList) {
      final imgMap = img as Map<String, dynamic>;
      String bestImgUrl = _selectBestImageUrl(imgMap);

      // 强制统一使用 https:// 协议头，避免 Cleartext 限制与连接中断
      if (bestImgUrl.startsWith('http://')) {
        bestImgUrl = bestImgUrl.replaceFirst('http://', 'https://');
      }

      if (bestImgUrl.isNotEmpty && !isVideo) {
        images.add(bestImgUrl);
      }

      // 检查 LivePhoto 实况动图 (兼容 stream 与 media.stream 两种层级)
      final livePhoto = imgMap['livePhoto'] as bool? ?? false;
      if (livePhoto) {
        isLive = true;
        String clipUrl = imgMap['stream']?['h264']?[0]?['masterUrl'] as String? ??
            imgMap['media']?['stream']?['h264']?[0]?['masterUrl'] as String? ??
            '';
        if (clipUrl.startsWith('http://')) {
          clipUrl = clipUrl.replaceFirst('http://', 'https://');
        }
        if (clipUrl.isNotEmpty) liveClips.add(clipUrl);
      }
    }

    // 封面提取（如果是视频则取首帧海报，若是图集取首图）
    String cover = '';
    if (imageList.isNotEmpty) {
      cover = _selectBestImageUrl(imageList[0] as Map<String, dynamic>);
    }
    if (cover.isEmpty && images.isNotEmpty) {
      cover = images[0];
    } else if (cover.isEmpty && note['image']?['url'] != null) {
      cover = note['image']['url'] as String;
    }
    if (cover.startsWith('http://')) {
      cover = cover.replaceFirst('http://', 'https://');
    }

    final authorName = user['nickname'] as String? ??
        user['nickName'] as String? ??
        '小红书创作者';
    String authorAvatar = user['avatar'] as String? ?? user['image'] as String? ?? '';
    if (authorAvatar.startsWith('http://')) {
      authorAvatar = authorAvatar.replaceFirst('http://', 'https://');
    }
    final likeRaw = interactInfo['likedCount'];
    final likeCount = _parseCount(likeRaw);

    return MediaItem(
      id: noteId,
      platform: PlatformType.xiaohongshu,
      title: title,
      author: authorName,
      authorAvatar: authorAvatar,
      authorUid: user['userId'] as String? ?? '',
      coverUrl: cover,
      videoUrl: primaryVideoUrl,
      videoStreams: streams,
      images: images,
      isLivePhoto: isLive,
      livePhotoClips: liveClips,
      likeCount: likeCount,
      durationMs: duration,
      originalUrl: originalUrl,
    );
  }

  /// 从小红书图片结构中构建 4K 无水印原图直链 (对齐 GitHub 开源 XHS-Downloader 核心方案)
  /// 核心原理：
  /// - 小红书默认返回的 sns-webpic-*.xhscdn.com 链接带有 !h5_1080jpg 或 !nd_dft 等后缀，由网关动态合成水印并降质为 1080p。
  /// - 提取图片底层存储的 fileId (或从 URL 中剥离出原始 token)，直接拼接到底层源站 sns-img-bd.xhscdn.com，
  ///   即可完全绕过水印合成网关，直接获取创作者上传的 4K 原始分辨率无水印母版原图。
  String _selectBestImageUrl(Map<String, dynamic> imgMap) {
    // 1. 优先直接读取原生 fileId 字段 (例如: notes_pre_post/1040g3k83...)
    String token = (imgMap['fileId'] as String? ?? '').trim();

    // 2. 若 fileId 为空，从候选 URL 中正则剥离出原始存储 token
    //    标准带水印 URL 格式: https://sns-webpic-qc.xhscdn.com/{12位时间}/{32位MD5}/{token}!{style}
    if (token.isEmpty) {
      final candidateUrls = <String>[
        imgMap['urlDefault'] as String? ?? '',
        imgMap['url'] as String? ?? '',
      ];
      final infoList = (imgMap['infoList'] as List?) ?? [];
      for (final item in infoList) {
        final u = (item as Map<String, dynamic>)['url'] as String? ?? '';
        if (u.isNotEmpty) candidateUrls.add(u);
      }

      final tokenReg = RegExp(r'xhscdn\.com/\d+/[0-9a-fA-F]+/([^!?]+)');
      for (final u in candidateUrls) {
        final m = tokenReg.firstMatch(u);
        if (m != null && m.group(1)!.isNotEmpty) {
          token = m.group(1)!;
          break;
        }
      }
    }

    // 3. 若仍为空，尝试读取旧版 traceId
    if (token.isEmpty) {
      token = (imgMap['traceId'] as String? ?? '').trim();
    }

    // 4. 拼接底层无水印源站 CDN 直链 (输出原始 4K 分辨率无水印 JPEG)
    if (token.isNotEmpty) {
      return 'https://sns-img-bd.xhscdn.com/$token?imageView2/format/jpeg';
    }

    // 5. 极端情况兜底：从 infoList 选取非 PRV 缩略图的高清链接
    final infoList = (imgMap['infoList'] as List?) ?? [];
    for (final item in infoList) {
      final m = item as Map<String, dynamic>;
      final scene = m['imageScene'] as String? ?? '';
      final u = m['url'] as String? ?? '';
      if (u.isNotEmpty && !scene.contains('PRV') && !u.contains('!style_')) {
        return u;
      }
    }

    return imgMap['urlDefault'] as String? ?? imgMap['url'] as String? ?? '';
  }

  int _parseCount(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    final s = v.toString().replaceAll(',', '').trim();
    return int.tryParse(s) ?? 0;
  }

  String _formatGear(String qualityType, int bitrate) {
    if (qualityType.contains('1080') || bitrate > 3000000) return '1080p 超清原画';
    if (qualityType.contains('720') || bitrate > 1500000) return '720p 高清';
    return qualityType.isNotEmpty ? qualityType : '默认画质';
  }
}
