/**
 * @file: media_item.dart
 * @description: 统一归一化的多平台媒体解析实体类
 * @author: Antigravity
 * @version: 2.0.0
 */

import 'platform_type.dart';

class VideoStream {
  final String gearName; // 如 "1080p 超清", "720p 高清", "原画无水印"
  final String url;
  final int bitrate;
  final int width;
  final int height;
  final String codec; // 如 "H.264", "HEVC"
  final int sizeBytes;
  final String? badge; // 如 "推荐", "无水印原画", "8K超限"
  final String? warningNote; // 如 "单边分辨率超4K，部分手机相册无法解码"
  final String? backupUrl; // 备用 CDN 播放链接

  const VideoStream({
    required this.gearName,
    required this.url,
    this.bitrate = 0,
    this.width = 0,
    this.height = 0,
    this.codec = '',
    this.sizeBytes = 0,
    this.badge,
    this.warningNote,
    this.backupUrl,
  });

  /// 获取标准格式化分辨率标签文本，如 "1080×1920"
  String get resolutionText {
    if (width > 0 && height > 0) {
      return '$width×$height';
    }
    return '';
  }

  Map<String, dynamic> toJson() => {
        'gearName': gearName,
        'url': url,
        'bitrate': bitrate,
        'width': width,
        'height': height,
        'codec': codec,
        'sizeBytes': sizeBytes,
        'badge': badge,
        'warningNote': warningNote,
        'backupUrl': backupUrl,
      };

  factory VideoStream.fromJson(Map<String, dynamic> json) => VideoStream(
        gearName: json['gearName'] as String? ?? '默认画质',
        url: json['url'] as String? ?? '',
        bitrate: json['bitrate'] as int? ?? 0,
        width: json['width'] as int? ?? 0,
        height: json['height'] as int? ?? 0,
        codec: json['codec'] as String? ?? '',
        sizeBytes: json['sizeBytes'] as int? ?? 0,
        badge: json['badge'] as String?,
        warningNote: json['warningNote'] as String?,
        backupUrl: json['backupUrl'] as String?,
      );
}

class MediaItem {
  final String id;
  final PlatformType platform;
  final String title;
  final String author;
  final String authorAvatar;
  final String authorUid;
  final String coverUrl;
  final String videoUrl;
  final List<VideoStream> videoStreams;
  final List<String> images;
  final bool isLivePhoto;
  final List<String> livePhotoClips; // 实况照片的视频分片或配对媒体
  final int likeCount;
  final int durationMs;
  final String musicTitle;
  final String musicAuthor;
  final String musicUrl;
  final int createTime;
  final String originalUrl;

  const MediaItem({
    required this.id,
    required this.platform,
    required this.title,
    required this.author,
    this.authorAvatar = '',
    this.authorUid = '',
    required this.coverUrl,
    this.videoUrl = '',
    this.videoStreams = const [],
    this.images = const [],
    this.isLivePhoto = false,
    this.livePhotoClips = const [],
    this.likeCount = 0,
    this.durationMs = 0,
    this.musicTitle = '',
    this.musicAuthor = '',
    this.musicUrl = '',
    this.createTime = 0,
    required this.originalUrl,
  });

  /// 是否为纯视频类型（具有视频流或视频链接即优先判定为视频）
  bool get isVideo => (videoUrl.isNotEmpty || videoStreams.isNotEmpty) && !isLivePhoto;

  /// 是否为图集或实况图集类型（非纯视频且具有图片集合）
  bool get isGallery => !isVideo && images.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'platform': platform.name,
        'title': title,
        'author': author,
        'authorAvatar': authorAvatar,
        'authorUid': authorUid,
        'coverUrl': coverUrl,
        'videoUrl': videoUrl,
        'videoStreams': videoStreams.map((e) => e.toJson()).toList(),
        'images': images,
        'isLivePhoto': isLivePhoto,
        'livePhotoClips': livePhotoClips,
        'likeCount': likeCount,
        'durationMs': durationMs,
        'musicTitle': musicTitle,
        'musicAuthor': musicAuthor,
        'musicUrl': musicUrl,
        'createTime': createTime,
        'originalUrl': originalUrl,
      };

  factory MediaItem.fromJson(Map<String, dynamic> json) => MediaItem(
        id: json['id'] as String? ?? '',
        platform: PlatformType.values.firstWhere(
          (p) => p.name == json['platform'],
          orElse: () => PlatformType.unknown,
        ),
        title: json['title'] as String? ?? '',
        author: json['author'] as String? ?? '',
        authorAvatar: json['authorAvatar'] as String? ?? '',
        authorUid: json['authorUid'] as String? ?? '',
        coverUrl: json['coverUrl'] as String? ?? '',
        videoUrl: json['videoUrl'] as String? ?? '',
        videoStreams: (json['videoStreams'] as List?)
                ?.map((e) => VideoStream.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        images: (json['images'] as List?)?.map((e) => e.toString()).toList() ?? [],
        isLivePhoto: json['isLivePhoto'] as bool? ?? false,
        livePhotoClips:
            (json['livePhotoClips'] as List?)?.map((e) => e.toString()).toList() ?? [],
        likeCount: json['likeCount'] as int? ?? 0,
        durationMs: json['durationMs'] as int? ?? 0,
        musicTitle: json['musicTitle'] as String? ?? '',
        musicAuthor: json['musicAuthor'] as String? ?? '',
        musicUrl: json['musicUrl'] as String? ?? '',
        createTime: json['createTime'] as int? ?? 0,
        originalUrl: json['originalUrl'] as String? ?? '',
      );
}
