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
    Map<String, dynamic>? note = noteContainer?['note'] as Map<String, dynamic>? ??
        state['noteData']?['data']?['noteData'] as Map<String, dynamic>?;

    // 兜底：兼容新版 SSR 注入的 __SETUP_SERVER_STATE__
    if (note == null) {
      final setupMatch = RegExp(
        r'window\.__SETUP_SERVER_STATE__\s*=\s*(.*?)</script>',
        dotAll: true,
      ).firstMatch(resp.body);
      if (setupMatch != null) {
        try {
          String setupJson = setupMatch.group(1)!.trim().replaceAll(':undefined', ':null');
          final setupState = json.decode(setupJson) as Map<String, dynamic>;
          note = setupState['LAUNCHER_SSR_STORE_PAGE_DATA']?['noteData'] as Map<String, dynamic>?;
        } catch (_) {}
      }
    }

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

      // 解析 mediaV2 或 capa 中的原始主视频分辨率与时长
      int origWidth = 0;
      int origHeight = 0;
      final capaDuration = (videoObj['capa'] as Map<String, dynamic>?)?['duration'] as int? ?? 0;
      if (capaDuration > 0) {
        duration = capaDuration * 1000;
      }
      final mediaV2Raw = videoObj['mediaV2'];
      if (mediaV2Raw is String && mediaV2Raw.isNotEmpty) {
        try {
          final mv2 = json.decode(mediaV2Raw) as Map<String, dynamic>;
          final mv2Video = mv2['video'] as Map<String, dynamic>?;
          if (mv2Video != null) {
            origWidth = mv2Video['width'] as int? ?? 0;
            origHeight = mv2Video['height'] as int? ?? 0;
            final mv2Dur = mv2Video['duration'] as int? ?? 0;
            if (mv2Dur > 0 && duration == 0) {
              duration = mv2Dur * 1000;
            }
          }
        } catch (_) {}
      }

      // 1. 创作者上传的原始无水印母带 (consumer.originVideoKey)
      final originKey = (videoObj['consumer'] as Map<String, dynamic>?)?['originVideoKey'] as String? ?? '';
      // Android MediaCodec H.264 硬件解码器硬性限制单边分辨率不得超过 4096 (如 2160x4320 会导致系统相册解码失败)
      final bool isUltraResolution = (origWidth > 4096 || origHeight > 4096);
      VideoStream? ultraOriginStream;

      if (originKey.isNotEmpty) {
        final originUrl = 'https://sns-video-bd.xhscdn.com/$originKey';
        final backupOriginUrl = 'https://sns-video-al.xhscdn.com/$originKey';

        if (!isUltraResolution) {
          primaryVideoUrl = originUrl;
          streams.add(
            VideoStream(
              gearName: '原画',
              url: originUrl,
              width: origWidth,
              height: origHeight,
              codec: 'H.264',
              bitrate: 10000000,
              badge: '原画推荐',
              backupUrl: backupOriginUrl,
            ),
          );
        } else {
          // 超过 4096 极客母带：保留选项但备注需第三方播放器支持，默认下载流回退为兼容移动端的高清转码流
          ultraOriginStream = VideoStream(
            gearName: '原画',
            url: originUrl,
            width: origWidth,
            height: origHeight,
            codec: 'H.264',
            bitrate: 10000000,
            badge: '8K超限',
            warningNote: '单边分辨率超4K，部分手机相册无法解码，建议使用第三方播放器',
            backupUrl: backupOriginUrl,
          );
        }
      }

      // 2. 次级流：提取 stream 中的转码流（按码率从高到低排序，完美兼容全机型相册解码）
      final h264List = (streamObj['h264'] as List?) ?? [];
      final h265List = (streamObj['h265'] as List?) ?? [];
      final av1List = (streamObj['av1'] as List?) ?? [];
      final allStreams = [...h265List, ...av1List, ...h264List]
          .whereType<Map<String, dynamic>>()
          .toList()
        ..sort((a, b) {
          final ba = (a['avgBitrate'] as int?) ?? (a['videoBitrate'] as int?) ?? 0;
          final bb = (b['avgBitrate'] as int?) ?? (b['videoBitrate'] as int?) ?? 0;
          return bb.compareTo(ba);
        });

      // 去重并规范化生成各个转码流
      final seenKeys = <String>{};
      final streamCandidates = <VideoStream>[];

      for (final sMap in allStreams) {
        String mUrl = sMap['masterUrl'] as String? ?? '';
        if (mUrl.startsWith('http://')) {
          mUrl = mUrl.replaceFirst('http://', 'https://');
        }
        if (mUrl.isEmpty) continue;

        int w = sMap['width'] as int? ?? 0;
        int h = sMap['height'] as int? ?? 0;
        if ((w == 0 || h == 0) && origWidth > 0 && origHeight > 0) {
          if (origHeight >= origWidth) {
            w = 720;
            h = (720 * origHeight / origWidth).round();
          } else {
            h = 720;
            w = (720 * origWidth / origHeight).round();
          }
        }
        // 若仍为 0，给保底竖屏分辨率
        if (w == 0 || h == 0) {
          w = 720;
          h = 960;
        }

        final codecRaw = (sMap['videoCodec'] as String? ?? sMap['video_codec'] as String? ?? '').toLowerCase();
        final codec = (codecRaw == 'hevc' || codecRaw == 'h265')
            ? 'HEVC'
            : (codecRaw == 'av1' ? 'AV1' : 'H.264');
        final bitrate = (sMap['avgBitrate'] as int?) ?? (sMap['videoBitrate'] as int?) ?? 0;
        final sizeBytes = (sMap['size'] as int?) ?? 0;
        final d = (sMap['duration'] as int?) ?? (sMap['videoDuration'] as int?) ?? 0;
        if (d > duration) duration = d;

        // 去除完全相同分辨率和编码的冗余流
        final key = '$w-$h-$codec';
        if (seenKeys.contains(key)) continue;
        seenKeys.add(key);

        // 左侧仅显示清晰简洁的画质级别（超清、高清、标清）
        final shortDim = w < h ? w : h;
        String baseName = '高清';
        if (shortDim >= 1080) {
          baseName = '超清';
        } else if (shortDim >= 720) {
          baseName = '高清';
        } else {
          baseName = '标清';
        }

        streamCandidates.add(
          VideoStream(
            gearName: baseName,
            url: mUrl,
            width: w,
            height: h,
            codec: codec,
            bitrate: bitrate,
            sizeBytes: sizeBytes,
          ),
        );
      }

      for (int i = 0; i < streamCandidates.length; i++) {
        final s = streamCandidates[i];
        final isDefault = primaryVideoUrl.isEmpty;
        if (isDefault) primaryVideoUrl = s.url;

        streams.add(
          VideoStream(
            gearName: s.gearName,
            url: s.url,
            width: s.width,
            height: s.height,
            codec: s.codec,
            bitrate: s.bitrate,
            sizeBytes: s.sizeBytes,
            badge: isDefault ? '推荐' : null,
          ),
        );
      }

      // 若存在超限母带，追加到流列表末尾供高级用户手动选择
      if (ultraOriginStream != null) {
        streams.add(ultraOriginStream);
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
      String clipUrl = '';
      if (livePhoto) {
        clipUrl = imgMap['stream']?['h264']?[0]?['masterUrl'] as String? ??
            imgMap['media']?['stream']?['h264']?[0]?['masterUrl'] as String? ??
            '';
        if (clipUrl.startsWith('http://')) {
          clipUrl = clipUrl.replaceFirst('http://', 'https://');
        }
        if (clipUrl.isNotEmpty) {
          isLive = true;
        }
      }
      // 保持与 images 索引一一对齐（非实况图存空字符串）
      if (!isVideo) {
        liveClips.add(clipUrl);
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


}
