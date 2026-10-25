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
        _showSnack('已加入图集后台批量下载！', isSuccess: true);
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
              text: '一键保存全部图集 (${item.images.length}张)',
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: item.videoStreams.map((stream) {
                    final selected = _selectedStream == stream;
                    final isRecommended = stream == item.videoStreams.first;
                    return InkWell(
                      onTap: () => setState(() => _selectedStream = stream),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Icon(
                              selected ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: selected ? AirbnbTheme.primary : AirbnbTheme.textTertiary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                stream.gearName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                  color: AirbnbTheme.textMain,
                                ),
                              ),
                            ),
                            if (isRecommended)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AirbnbTheme.primaryLight,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '推荐',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AirbnbTheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── 图集缩略图网格（图集专属）──────────────────────
            if (item.isGallery) ...[
              Text(
                '图集图片 (${item.images.length} 张)',
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
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(AirbnbTheme.radiusSm),
                    child: CachedNetworkImage(
                      imageUrl: item.images[i],
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: AirbnbTheme.border),
                    ),
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
