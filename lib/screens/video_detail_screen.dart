/**
 * @file: video_detail_screen.dart
 * @description: 解析结果详情与多清晰度/图集下载页 (爱彼迎美学设计)
 * @author: Antigravity
 * @version: 2.0.0
 */

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart';
import '../models/media_item.dart';
import '../services/download_task_manager.dart';
import '../utils/format_utils.dart';
import '../widgets/airbnb_button.dart';
import '../widgets/airbnb_card.dart';
import '../widgets/floating_top_bar.dart';
import '../widgets/snap_toast.dart';
import 'history_screen.dart';


enum _DetailTagType {
  codec,       // 次要规格：淡灰低调
  resolution,  // 核心分辨率：清爽蓝灰
  recommended, // 重点推荐：品牌粉红高亮
  warning,     // 风险警示：琥珀橙高亮
}

class VideoDetailScreen extends StatefulWidget {
  final MediaItem item;

  const VideoDetailScreen({
    super.key,
    required this.item,
  });

  @override
  State<VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends State<VideoDetailScreen> {
  late VideoStream? _selectedStream;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _selectedStream = widget.item.videoStreams.isNotEmpty
        ? widget.item.videoStreams.first
        : (widget.item.videoUrl.isNotEmpty
            ? VideoStream(gearName: '默认画质', url: widget.item.videoUrl)
            : null);
  }

  /// 触发视频下载并立即返回主页
  Future<void> _startDownloadVideo() async {
    final stream = _selectedStream ??
        (widget.item.videoStreams.isNotEmpty
            ? widget.item.videoStreams.first
            : (widget.item.videoUrl.isNotEmpty
                ? VideoStream(gearName: '默认画质', url: widget.item.videoUrl)
                : null));

    if (stream == null || stream.url.isEmpty) {
      _showSnack('未找到可下载的视频链接', isError: true);
      return;
    }

    setState(() => _isDownloading = true);

    try {
      await DownloadTaskManager.instance.startVideoDownload(
        item: widget.item,
        stream: stream,
      );
      if (mounted) {
        _showSnack('已加入后台极速下载！', isSuccess: true);
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        _showSnack('创建任务失败: $e', isError: true);
      }
    }
  }

  /// 触发图集全部下载并立即返回主页
  Future<void> _startDownloadImages() async {
    final images = widget.item.images;
    if (images.isEmpty) return;

    setState(() => _isDownloading = true);

    try {
      await DownloadTaskManager.instance.startGalleryDownload(
        item: widget.item,
      );
      if (mounted) {
        _showSnack(
          widget.item.isLivePhoto ? '已加入实况照片后台保存！' : '已加入图集后台批量下载！',
          isSuccess: true,
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        _showSnack('批量下载失败: $e', isError: true);
      }
    }
  }

  void _showSnack(String msg, {bool isSuccess = false, bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      SnapToast.error(context, msg);
    } else if (isSuccess) {
      SnapToast.success(context, msg);
    } else {
      SnapToast.info(context, msg);
    }
  }


  /// 统一高度、统一圆角规范的画质标签组件（通过颜色引导用户关注焦点）
  Widget _buildTag({
    required String text,
    required _DetailTagType type,
  }) {
    Color bg;
    Color textColor;
    Color borderColor;
    FontWeight fontWeight = FontWeight.w600;

    switch (type) {
      case _DetailTagType.codec:
        // 次要编码规格：采用中性浅灰，弱化视觉噪音
        bg = const Color(0xFFF1F5F9);
        textColor = const Color(0xFF64748B);
        borderColor = const Color(0xFFE2E8F0);
        fontWeight = FontWeight.w500;
        break;
      case _DetailTagType.resolution:
        // 核心分辨率规格：采用高辨识度的精致蓝灰底与深色字
        bg = const Color(0xFFE2E8F0);
        textColor = const Color(0xFF1E293B);
        borderColor = const Color(0xFFCBD5E1);
        break;
      case _DetailTagType.recommended:
        // 重点推荐关注：爱彼迎品牌珊瑚粉，强视觉焦点
        bg = const Color(0xFFFFF0F2);
        textColor = AirbnbTheme.primary;
        borderColor = const Color(0xFFFFD1D8);
        fontWeight = FontWeight.w700;
        break;
      case _DetailTagType.warning:
        // 警告/超限风险：醒目琥珀橙，提示系统兼容性
        bg = const Color(0xFFFFFBEB);
        textColor = const Color(0xFFD97706);
        borderColor = const Color(0xFFFDE68A);
        fontWeight = FontWeight.w700;
        break;
    }

    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor, width: 0.6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: fontWeight,
          color: textColor,
          height: 1.1,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  /// 提取标准分辨率文本兜底
  String _getResolutionText(VideoStream stream) {
    if (stream.resolutionText.isNotEmpty) {
      return stream.resolutionText;
    }
    final name = stream.gearName;
    if (name.contains('1080')) return '1080×1920';
    if (name.contains('720')) return '720×1280';
    if (name.contains('4K')) return '2160×3840';
    if (name.contains('2K')) return '1440×2560';
    return '720×960';
  }

  /// 纯净归一化主标题（去除与右侧标签重复的 720p/HEVC/H.264，左侧仅保留清晰级名称：超清、高清、原画、标清）
  String _simplifyGearName(String raw) {
    if (raw.contains('原画')) return '原画';
    if (raw.contains('超清') || raw.contains('1080') || raw.contains('2K') || raw.contains('4K')) return '超清';
    if (raw.contains('高清') || raw.contains('720')) return '高清';
    if (raw.contains('标清') || raw.contains('540')) return '标清';
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final item = widget.item;

    return FloatingPageScaffold(
      title: item.platform.displayName,
      actions: [
        FloatingPill(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
          FloatingPillIconButton(
            icon: Icons.copy_rounded,
            tooltip: '复制原链接',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: item.originalUrl));
              _showSnack('已复制原分享链接');
            },
          ),
          ValueListenableBuilder<int>(
            valueListenable: DownloadTaskManager.instance.activeCountNotifier,
            builder: (context, activeCount, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  FloatingPillIconButton(
                    icon: Icons.download_rounded,
                    tooltip: '下载任务',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HistoryScreen()),
                      );
                    },
                  ),
                  if (activeCount > 0)
                    Positioned(
                      top: 2,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AirbnbTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$activeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
            ],
          ),
        ),
      ],
      bottomBarHeight: 50,
      bottomBar: item.isVideo
          ? AirbnbButton(
              text: '一键极速保存到相册',
              isLoading: _isDownloading,
              onPressed: _isDownloading ? null : _startDownloadVideo,
            )
          : AirbnbButton(
              text: item.isLivePhoto
                  ? '一键保存实况照片 (${item.images.length}张)'
                  : '一键保存全部图集 (${item.images.length}张)',
              isLoading: _isDownloading,
              onPressed: _isDownloading ? null : _startDownloadImages,
            ),
      builder: (context, insets) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20 + insets.left,
          insets.top + 4,
          20 + insets.right,
          insets.bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 封面/主图 Hero 卡片 ─────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(AirbnbTheme.radiusLg),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 10,
                    child: CachedNetworkImage(
                      imageUrl: item.coverUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: AirbnbTheme.border,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: AirbnbTheme.border,
                        child: const Icon(Icons.broken_image_rounded, size: 40),
                      ),
                    ),
                  ),
                  if (item.isVideo)
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                    ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(AirbnbTheme.radiusCapsule),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (item.platform.iconAsset != null) ...[
                            ClipOval(
                              child: Image.asset(item.platform.iconAsset!, width: 16, height: 16, fit: BoxFit.cover),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            item.platform.displayName,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (item.durationMs > 0)
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          FormatUtils.formatDuration(item.durationMs),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  if (item.isLivePhoto)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(AirbnbTheme.radiusCapsule),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.motion_photos_on_rounded, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              '实况动图',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── 标题与作者卡片 ─────────────────────────────────
            AirbnbCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title.isNotEmpty ? item.title : '无标题内容',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AirbnbTheme.textMain,
                      height: 1.4,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AirbnbTheme.border,
                        backgroundImage: item.authorAvatar.isNotEmpty
                            ? CachedNetworkImageProvider(item.authorAvatar)
                            : null,
                        child: item.authorAvatar.isEmpty
                            ? Icon(Icons.person, color: AirbnbTheme.textSecondary)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.author,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AirbnbTheme.textMain,
                              ),
                            ),
                            if (item.authorUid.isNotEmpty)
                              Text(
                                'UID: ${item.authorUid}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AirbnbTheme.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (item.likeCount > 0)
                        Row(
                          children: [
                            const Icon(Icons.favorite_rounded, size: 16, color: AirbnbTheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              '${item.likeCount}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AirbnbTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 画质选择（视频专属）────────────────────────────
            if (item.videoStreams.isNotEmpty) ...[
              Text(
                '选择下载画质',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AirbnbTheme.textMain,
                ),
              ),
              const SizedBox(height: 10),
              AirbnbCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: List.generate(item.videoStreams.length, (index) {
                    final stream = item.videoStreams[index];
                    final selected = _selectedStream == stream;
                    final isRecommended = stream == item.videoStreams.first;
                    final isLast = index == item.videoStreams.length - 1;

                    return Column(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => setState(() => _selectedStream = stream),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      selected ? Icons.radio_button_checked : Icons.radio_button_off,
                                      color: selected ? AirbnbTheme.primary : AirbnbTheme.textTertiary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    // 主标题居左：仅保留纯净级别（原画、超清、高清、标清），杜绝与右侧标签信息重复
                                    Expanded(
                                      child: Text(
                                        _simplifyGearName(stream.gearName),
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                                          color: AirbnbTheme.textMain,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // 标签全量居右：高度一致、风格统一、颜色引导重点
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildTag(
                                          text: _getResolutionText(stream),
                                          type: _DetailTagType.resolution,
                                        ),
                                        if (stream.codec.isNotEmpty) ...[
                                          const SizedBox(width: 5),
                                          _buildTag(
                                            text: stream.codec,
                                            type: _DetailTagType.codec,
                                          ),
                                        ],
                                        if (stream.badge != null && stream.badge!.isNotEmpty) ...[
                                          const SizedBox(width: 5),
                                          _buildTag(
                                            text: stream.badge!,
                                            type: stream.badge!.contains('超限')
                                                ? _DetailTagType.warning
                                                : _DetailTagType.recommended,
                                          ),
                                        ] else if (isRecommended) ...[
                                          const SizedBox(width: 5),
                                          _buildTag(
                                            text: '推荐',
                                            type: _DetailTagType.recommended,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                // 警示栏：图标居上，与主文本平齐
                                if (stream.warningNote != null && stream.warningNote!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    margin: const EdgeInsets.only(left: 30),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFFBEB),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFFDE68A), width: 0.8),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(top: 1.5),
                                          child: Icon(
                                            Icons.warning_amber_rounded,
                                            size: 15,
                                            color: Color(0xFFD97706),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            stream.warningNote!,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFFB45309),
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (!isLast)
                          Divider(height: 1, thickness: 0.6, color: AirbnbTheme.border.withValues(alpha: 0.7)),
                      ],
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── 图集缩略图网格（图集与实况动图专属）──────────────────────
            if (item.isGallery) ...[
              Text(
                item.isLivePhoto
                    ? '实况照片 (${item.images.length} 组)'
                    : '图集图片 (${item.images.length} 张)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AirbnbTheme.textMain,
                ),
              ),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: item.images.length,
                itemBuilder: (ctx, i) {
                  final isItemLive = item.isLivePhoto &&
                      i < item.livePhotoClips.length &&
                      item.livePhotoClips[i].isNotEmpty;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AirbnbTheme.radiusSm),
                        child: CachedNetworkImage(
                          imageUrl: item.images[i],
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: AirbnbTheme.border),
                          errorWidget: (_, __, ___) => Container(
                            color: AirbnbTheme.border,
                            child: const Icon(Icons.broken_image_rounded, size: 24),
                          ),
                        ),
                      ),
                      if (isItemLive)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.motion_photos_on_rounded, color: Colors.white, size: 10),
                                SizedBox(width: 3),
                                Text(
                                  'LIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}
