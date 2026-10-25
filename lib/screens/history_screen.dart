/**
 * @file: history_screen.dart
 * @description: 下载任务管理中心 (爱彼迎美学设计: 进行中任务流 + 已完成历史库)
 * @author: Antigravity
 * @version: 2.0.0
 */

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../core/constants.dart';
import '../models/download_task.dart';
import '../models/media_item.dart';
import '../services/download_task_manager.dart';
import '../services/history_service.dart';
import '../utils/format_utils.dart';
import '../widgets/airbnb_card.dart';
import '../widgets/floating_top_bar.dart';
import '../widgets/snap_toast.dart';
import 'video_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<MediaItem> _historyItems = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadHistory();
    DownloadTaskManager.instance.activeTasksNotifier.addListener(_onActiveChanged);
  }

  @override
  void dispose() {
    DownloadTaskManager.instance.activeTasksNotifier.removeListener(_onActiveChanged);
    _tabCtrl.dispose();
    super.dispose();
  }

  void _onActiveChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    final list = await HistoryService.getHistory();
    if (mounted) {
      setState(() {
        _historyItems = list;
        _isLoadingHistory = false;
      });
    }
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AirbnbTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AirbnbTheme.radiusMd)),
        title: const Text('清空历史记录', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('确定要清空全部已完成的下载记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('取消', style: TextStyle(color: AirbnbTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AirbnbTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认清空'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await HistoryService.clearHistory();
      DownloadTaskManager.instance.clearCompleted();
      _loadHistory();
      if (mounted) SnapToast.success(context, '已清空下载记录');
    }
  }

  /// 悬浮分段 Tab 胶囊高度（含与顶部栏之间的间距）
  static const double _tabPillHeight = 44.0;
  static const double _tabBarAreaHeight = _tabPillHeight + 8.0;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return FloatingPageScaffold(
      title: '下载任务中心',
      actions: [
        FloatingPill(
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: 44,
            child: FloatingPillIconButton(
              icon: Icons.delete_sweep_rounded,
              tooltip: '清空历史',
              onPressed: _clearAll,
            ),
          ),
        ),
      ],
      topBottomHeight: _tabBarAreaHeight,
      topBottom: FloatingPill(
        height: _tabPillHeight,
        padding: const EdgeInsets.all(4),
        child: TabBar(
          controller: _tabCtrl,
          dividerHeight: 0,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: AirbnbTheme.primaryLight,
            borderRadius: BorderRadius.circular(AirbnbTheme.radiusCapsule),
          ),
          splashBorderRadius: BorderRadius.circular(AirbnbTheme.radiusCapsule),
          labelColor: AirbnbTheme.primary,
          unselectedLabelColor: AirbnbTheme.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          tabs: [
            ValueListenableBuilder<List<DownloadTask>>(
              valueListenable: DownloadTaskManager.instance.activeTasksNotifier,
              builder: (ctx, active, _) {
                return Tab(
                  height: _tabPillHeight - 8,
                  text: '进行中 (${active.length})',
                );
              },
            ),
            Tab(
              height: _tabPillHeight - 8,
              text: '已完成 (${_historyItems.length})',
            ),
          ],
        ),
      ),
      builder: (context, insets) {
        final listPadding = EdgeInsets.fromLTRB(
          20 + insets.left,
          insets.top + 8,
          20 + insets.right,
          16 + insets.bottom,
        );
        return TabBarView(
          controller: _tabCtrl,
          children: [
            _buildActiveTasksTab(listPadding),
            _buildCompletedTab(listPadding),
          ],
        );
      },
    );
  }

  /// 进行中的任务列表
  Widget _buildActiveTasksTab(EdgeInsets listPadding) {
    return ValueListenableBuilder<List<DownloadTask>>(
      valueListenable: DownloadTaskManager.instance.activeTasksNotifier,
      builder: (context, activeTasks, _) {
        if (activeTasks.isEmpty) {
          return _buildEmptyState(
            mascotAsset: AppConstants.mascotSprint,
            title: '暂无正在下载的任务',
            subtitle: '在主页粘贴分享链接，咔捕即可一键极速下载并在此实时查看进度',
            listPadding: listPadding,
          );
        }

        return ListView.separated(
          padding: listPadding,
          itemCount: activeTasks.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, index) {
            final task = activeTasks[index];
            final item = task.mediaItem;
            final progress = task.progress;
            final speed = FormatUtils.formatSpeed(task.speedBytesPerSecond);

            return AirbnbCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // 封面缩略图
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CachedNetworkImage(
                              imageUrl: item.coverUrl,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                width: 64,
                                height: 64,
                                color: AirbnbTheme.border,
                                child: const Icon(Icons.broken_image, size: 24),
                              ),
                            ),
                            if (item.isVideo)
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.55),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // 标题与信息
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title.isNotEmpty ? item.title : '下载媒体',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AirbnbTheme.textMain,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (item.platform.iconAsset != null) ...[
                                  ClipOval(
                                    child: Image.asset(item.platform.iconAsset!, width: 14, height: 14, fit: BoxFit.cover),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  item.author,
                                  style: TextStyle(fontSize: 12, color: AirbnbTheme.textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // 取消按钮
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: AirbnbTheme.textTertiary, size: 20),
                        tooltip: '取消任务',
                        onPressed: () {
                          DownloadTaskManager.instance.cancelTask(task.taskId);
                          SnapToast.info(context, '已取消下载任务');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 进度条与速度
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(progress * 100).toInt()}% · 正在极速写入',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AirbnbTheme.textMain),
                      ),
                      Text(
                        speed,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AirbnbTheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress > 0 ? progress : null,
                      backgroundColor: AirbnbTheme.border,
                      valueColor: const AlwaysStoppedAnimation<Color>(AirbnbTheme.primary),
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 已完成的任务列表
  Widget _buildCompletedTab(EdgeInsets listPadding) {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator(color: AirbnbTheme.primary));
    }

    if (_historyItems.isEmpty) {
      return _buildEmptyState(
        mascotAsset: AppConstants.mascotQuestion,
        title: '暂无已完成的下载记录',
        subtitle: '完成下载的媒体将自动归档至系统相册，并在此沉淀',
        listPadding: listPadding,
      );
    }

    return ListView.separated(
      padding: listPadding,
      itemCount: _historyItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, index) {
        final item = _historyItems[index];

        return Dismissible(
          key: Key('history_${item.id}_$index'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: AirbnbTheme.error,
              borderRadius: BorderRadius.circular(AirbnbTheme.radiusMd),
            ),
            child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
          ),
          onDismissed: (_) async {
            await HistoryService.deleteHistory(item.id);
            _historyItems.removeAt(index);
            setState(() {});
            if (mounted) SnapToast.info(context, '已删除该条记录');
          },
          child: AirbnbCard(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => VideoDetailScreen(item: item)),
              );
            },
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AirbnbTheme.radiusSm),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CachedNetworkImage(
                        imageUrl: item.coverUrl,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: AirbnbTheme.border),
                        errorWidget: (_, __, ___) => Container(
                          width: 72,
                          height: 72,
                          color: AirbnbTheme.border,
                          child: const Icon(Icons.broken_image, size: 28),
                        ),
                      ),
                      if (item.isVideo)
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title.isNotEmpty ? item.title : '无标题内容',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AirbnbTheme.textMain,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (item.platform.iconAsset != null) ...[
                            ClipOval(
                              child: Image.asset(item.platform.iconAsset!, width: 14, height: 14, fit: BoxFit.cover),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            item.author,
                            style: TextStyle(fontSize: 12, color: AirbnbTheme.textSecondary),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '已存相册',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required String mascotAsset,
    required String title,
    required String subtitle,
    required EdgeInsets listPadding,
  }) {
    return Padding(
      // 空状态在悬浮顶部栏与底部导航栏之间的可视区域内居中
      padding: EdgeInsets.only(top: listPadding.top, bottom: listPadding.bottom),
      child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              mascotAsset,
              width: 120,
              height: 120,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AirbnbTheme.textMain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AirbnbTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
