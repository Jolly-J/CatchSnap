/**
 * @file: download_task_manager.dart
 * @description: 全局下载任务调度中心，支持多任务队列、后台托管、通知栏常驻与流体云同步
 * @author: Antigravity
 * @version: 2.0.0
 */

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../core/download_engine.dart';
import '../core/security_storage.dart';
import '../models/download_task.dart';
import '../models/media_item.dart';
import '../utils/format_utils.dart';
import '../utils/motion_photo_synthesizer.dart';
import 'history_service.dart';
import 'permission_service.dart';
import 'system_notification_service.dart';

class DownloadTaskManager {
  static final DownloadTaskManager instance = DownloadTaskManager._internal();
  DownloadTaskManager._internal();

  static const MethodChannel _channel =
      MethodChannel('com.example.douyin_downloader/floating');

  final List<DownloadTask> _activeTasks = [];
  final List<DownloadTask> _completedTasks = [];
  final Map<String, bool> _cancelFlags = {};

  final ValueNotifier<int> activeCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<List<DownloadTask>> activeTasksNotifier =
      ValueNotifier<List<DownloadTask>>([]);
  final ValueNotifier<List<DownloadTask>> completedTasksNotifier =
      ValueNotifier<List<DownloadTask>>([]);

  List<DownloadTask> get activeTasks => List.unmodifiable(_activeTasks);
  List<DownloadTask> get completedTasks => List.unmodifiable(_completedTasks);

  void _notifyChange() {
    activeCountNotifier.value = _activeTasks.length;
    activeTasksNotifier.value = List.from(_activeTasks);
    completedTasksNotifier.value = List.from(_completedTasks);
  }

  /// 启动单视频下载任务
  Future<String> startVideoDownload({
    required MediaItem item,
    required VideoStream stream,
  }) async {
    final hasPerm = await PermissionService.requestStorageForSave();
    if (!hasPerm) {
      throw Exception('缺少存储权限，无法保存媒体到系统相册');
    }

    final taskId = '${DateTime.now().millisecondsSinceEpoch}_${item.id}';
    final fileName = _buildFileName(
      prefix: item.platform.name,
      extension: 'mp4',
      title: item.title,
      author: item.author,
    );

    final task = DownloadTask(
      taskId: taskId,
      mediaItem: item,
      downloadUrl: stream.url,
      fileName: fileName,
      status: TaskStatus.downloading,
      createdAt: DateTime.now(),
    );

    _activeTasks.insert(0, task);
    _cancelFlags[taskId] = false;
    _notifyChange();

    _runVideoTask(task, stream.url);
    return taskId;
  }

  /// 启动图集批量下载任务
  Future<String> startGalleryDownload({
    required MediaItem item,
  }) async {
    final hasPerm = await PermissionService.requestStorageForSave();
    if (!hasPerm) {
      throw Exception('缺少存储权限，无法保存图片到系统相册');
    }

    final images = item.images;
    if (images.isEmpty) {
      throw Exception('图集中无可用图片');
    }

    final isLive = item.isLivePhoto && item.livePhotoClips.any((c) => c.isNotEmpty);
    final taskTitleDesc = isLive ? '(${images.length}张实况照片)' : '(${images.length}张图片)';
    final taskId = '${DateTime.now().millisecondsSinceEpoch}_${item.id}_gallery';
    final task = DownloadTask(
      taskId: taskId,
      mediaItem: item,
      downloadUrl: images.first,
      fileName: '${item.title} $taskTitleDesc',
      status: TaskStatus.downloading,
      createdAt: DateTime.now(),
    );

    _activeTasks.insert(0, task);
    _cancelFlags[taskId] = false;
    _notifyChange();

    _runGalleryTask(task, images);
    return taskId;
  }

  /// 执行视频单任务
  Future<void> _runVideoTask(DownloadTask task, String url) async {
    final taskId = task.taskId;
    final item = task.mediaItem;
    final fileName = task.fileName;

    final liveEnabled = await SecurityStorage.isFluidCloudEnabled();
    if (liveEnabled) {
      await LiveActivityService.start(
        title: item.title,
        progress: 0.0,
        speed: '准备下载...',
      );
    }

    final tmpDir = await getTemporaryDirectory();
    final tempFilePath = '${tmpDir.path}/$fileName';
    final tempFile = File(tempFilePath);

    try {
      final threads = await SecurityStorage.getDownloadThreads();
      final referer = item.platform.name == 'xiaohongshu'
          ? 'https://www.xiaohongshu.com/'
          : 'https://www.douyin.com/';

      await DownloadEngine.instance.download(
        url: url,
        destPath: tempFilePath,
        concurrency: threads,
        headers: {'Referer': referer},
        onProgress: (downloaded, total, speedBytes) {
          if (_cancelFlags[taskId] == true) {
            throw Exception('TASK_CANCELED');
          }

          final progress = total > 0 ? (downloaded / total).clamp(0.0, 1.0) : 0.0;
          final speedStr = FormatUtils.formatSpeed(speedBytes);

          // 更新活跃任务状态
          final idx = _activeTasks.indexWhere((t) => t.taskId == taskId);
          if (idx != -1) {
            _activeTasks[idx] = _activeTasks[idx].copyWith(
              downloadedBytes: downloaded,
              totalBytes: total,
              speedBytesPerSecond: speedBytes,
            );
            _notifyChange();
          }

          if (liveEnabled) {
            LiveActivityService.update(
              progress: progress,
              speed: speedStr,
            );
          }
        },
      );

      // 写入系统相册
      final albumName = await SecurityStorage.getAlbumName();
      final targetAlbum = await _resolveAlbumPath(albumName, item.author, item.authorUid);

      await _channel.invokeMethod('saveFileToGallery', {
        'filePath': tempFilePath,
        'albumName': targetAlbum,
        'fileName': fileName,
      });

      // 记录历史
      await HistoryService.addHistory(item);

      // 标记完成
      if (liveEnabled) {
        LiveActivityService.stop(isSuccess: true, title: item.title);
      }

      _finishTask(taskId, isSuccess: true, savePath: tempFilePath);
    } catch (e) {
      if (_cancelFlags[taskId] == true) {
        if (liveEnabled) {
          LiveActivityService.stop(isSuccess: false, title: '已取消下载');
        }
        _finishTask(taskId, isCanceled: true);
      } else {
        if (liveEnabled) {
          LiveActivityService.stop(isSuccess: false, title: item.title);
        }
        _finishTask(taskId, isSuccess: false, error: e.toString());
      }
    } finally {
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  /// 执行图集或实况照片批量任务
  Future<void> _runGalleryTask(DownloadTask task, List<String> images) async {
    final taskId = task.taskId;
    final item = task.mediaItem;
    final isLive = item.isLivePhoto && item.livePhotoClips.any((c) => c.isNotEmpty);
    final total = images.length;

    final liveEnabled = await SecurityStorage.isFluidCloudEnabled();
    if (liveEnabled) {
      await LiveActivityService.start(
        title: isLive ? '实况照片: ${item.title}' : '图集: ${item.title}',
        progress: 0.0,
        speed: '0/$total',
      );
    }

    final tmpDir = await getTemporaryDirectory();
    final albumName = await SecurityStorage.getAlbumName();
    final targetAlbum = await _resolveAlbumPath(albumName, item.author, item.authorUid);
    final threads = await SecurityStorage.getDownloadThreads();

    try {
      for (int i = 0; i < total; i++) {
        if (_cancelFlags[taskId] == true) throw Exception('TASK_CANCELED');

        final imgUrl = images[i].startsWith('http://')
            ? images[i].replaceFirst('http://', 'https://')
            : images[i];

        final singleFileName = _buildFileName(
          prefix: '${item.platform.name}_${i + 1}',
          extension: 'jpg',
          title: item.title,
          author: item.author,
          seq: i + 1,
        );

        final hasClip = isLive &&
            i < item.livePhotoClips.length &&
            item.livePhotoClips[i].isNotEmpty;
        final clipUrl = hasClip
            ? (item.livePhotoClips[i].startsWith('http://')
                ? item.livePhotoClips[i].replaceFirst('http://', 'https://')
                : item.livePhotoClips[i])
            : '';

        final ts = DateTime.now().millisecondsSinceEpoch;
        final tempImgPath = '${tmpDir.path}/tmp_img_${ts}_${i + 1}.jpg';
        final tempClipPath = '${tmpDir.path}/tmp_clip_${ts}_${i + 1}.mp4';
        final tempMotionPath = '${tmpDir.path}/$singleFileName';

        final tempImgFile = File(tempImgPath);
        final tempClipFile = File(tempClipPath);
        final tempMotionFile = File(tempMotionPath);

        try {
          final startOverallProgress = i / total;
          final startSpeedStr = hasClip
              ? '正在保存实况照片 (${i + 1}/$total)'
              : '正在保存高清照片 (${i + 1}/$total)';
          if (liveEnabled) {
            LiveActivityService.update(progress: startOverallProgress, speed: startSpeedStr);
          }

          final referer = item.platform.name == 'xiaohongshu'
              ? 'https://www.xiaohongshu.com/'
              : 'https://www.douyin.com/';

          // 1. 下载静态高清大图
          await DownloadEngine.instance.download(
            url: imgUrl,
            destPath: tempImgPath,
            concurrency: threads,
            headers: {'Referer': referer},
            onProgress: (downloaded, totalBytes, speedBytes) {
              if (_cancelFlags[taskId] == true) throw Exception('TASK_CANCELED');
              final itemProgress = (totalBytes > 0 ? downloaded / totalBytes : 0.5) * (hasClip ? 0.6 : 1.0);
              final overallProgress = (i + itemProgress) / total;
              final speedStr = '${FormatUtils.formatSpeed(speedBytes)} (${i + 1}/$total)';

              final idx = _activeTasks.indexWhere((t) => t.taskId == taskId);
              if (idx != -1) {
                _activeTasks[idx] = _activeTasks[idx].copyWith(
                  downloadedBytes: (overallProgress * 100).toInt(),
                  totalBytes: 100,
                  speedBytesPerSecond: speedBytes,
                );
                _notifyChange();
              }

              if (liveEnabled) {
                LiveActivityService.update(progress: overallProgress, speed: speedStr);
              }
            },
          );

          // 2. 如果包含实况动视频切片，下载切片并合成单一标准的 Motion Photo (.jpg)
          if (hasClip) {
            await DownloadEngine.instance.download(
              url: clipUrl,
              destPath: tempClipPath,
              concurrency: threads,
              headers: {'Referer': referer},
              onProgress: (downloaded, totalBytes, speedBytes) {
                if (_cancelFlags[taskId] == true) throw Exception('TASK_CANCELED');
                final itemProgress = 0.6 + (totalBytes > 0 ? downloaded / totalBytes : 0.5) * 0.4;
                final overallProgress = (i + itemProgress) / total;
                final speedStr = '${FormatUtils.formatSpeed(speedBytes)} (${i + 1}/$total)';

                final idx = _activeTasks.indexWhere((t) => t.taskId == taskId);
                if (idx != -1) {
                  _activeTasks[idx] = _activeTasks[idx].copyWith(
                    downloadedBytes: (overallProgress * 100).toInt(),
                    totalBytes: 100,
                    speedBytesPerSecond: speedBytes,
                  );
                  _notifyChange();
                }

                if (liveEnabled) {
                  LiveActivityService.update(progress: overallProgress, speed: speedStr);
                }
              },
            );

            // 合成为 Google Motion Photo 1.0 规范的单张实况照片
            await MotionPhotoSynthesizer.synthesize(
              imageFile: tempImgFile,
              videoFile: tempClipFile,
              outputFile: tempMotionFile,
            );
          }

          // 3. 写入系统相册媒体库（实况照片依然是单张 .jpg 文件入库，长按即可播放动图与声音）
          final fileToSave = hasClip ? tempMotionFile : tempImgFile;
          await _channel.invokeMethod('saveFileToGallery', {
            'filePath': fileToSave.path,
            'albumName': targetAlbum,
            'fileName': singleFileName,
          });
        } finally {
          // 清理所有临时文件
          if (await tempImgFile.exists()) {
            try {
              await tempImgFile.delete();
            } catch (_) {}
          }
          if (await tempClipFile.exists()) {
            try {
              await tempClipFile.delete();
            } catch (_) {}
          }
          if (await tempMotionFile.exists()) {
            try {
              await tempMotionFile.delete();
            } catch (_) {}
          }
        }
      }

      await HistoryService.addHistory(item);
      if (liveEnabled) {
        LiveActivityService.stop(isSuccess: true, title: item.title);
      }
      _finishTask(taskId, isSuccess: true);
    } catch (e) {
      if (_cancelFlags[taskId] == true) {
        if (liveEnabled) {
          LiveActivityService.stop(isSuccess: false, title: isLive ? '已取消实况照片保存' : '已取消图集下载');
        }
        _finishTask(taskId, isCanceled: true);
      } else {
        if (liveEnabled) {
          LiveActivityService.stop(isSuccess: false, title: item.title);
        }
        _finishTask(taskId, isSuccess: false, error: e.toString());
      }
    }
  }

  void _finishTask(
    String taskId, {
    bool isSuccess = false,
    bool isCanceled = false,
    String? error,
    String? savePath,
  }) {
    final idx = _activeTasks.indexWhere((t) => t.taskId == taskId);
    if (idx != -1) {
      final task = _activeTasks.removeAt(idx);
      final finalTask = task.copyWith(
        status: isCanceled
            ? TaskStatus.canceled
            : (isSuccess ? TaskStatus.completed : TaskStatus.failed),
        errorMessage: error,
        savePath: savePath,
      );
      _completedTasks.insert(0, finalTask);
      _notifyChange();
    }
    _cancelFlags.remove(taskId);
  }

  /// 取消指定任务
  void cancelTask(String taskId) {
    _cancelFlags[taskId] = true;
    LiveActivityService.stop(isSuccess: false, title: '已取消任务');
    _finishTask(taskId, isCanceled: true);
  }

  /// 清空已完成任务
  void clearCompleted() {
    _completedTasks.clear();
    _notifyChange();
  }

  /// 移除单条已完成记录
  void removeCompleted(String taskId) {
    _completedTasks.removeWhere((t) => t.taskId == taskId);
    _notifyChange();
  }

  static String _buildFileName({
    required String prefix,
    required String extension,
    required String title,
    required String author,
    int? seq,
    String? suffix,
  }) {
    final now = DateTime.now();
    final ts =
        '${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
    final cleanTitle = _sanitize(title.replaceAll(RegExp(r'#\S+'), '').trim());
    final shortTitle = cleanTitle.length > 18 ? cleanTitle.substring(0, 18) : cleanTitle;
    final cleanAuthor = _sanitize(author);

    final parts = [prefix, ts];
    if (seq != null) parts.add('$seq');
    if (suffix != null && suffix.isNotEmpty) parts.add(suffix);
    if (shortTitle.isNotEmpty) parts.add(shortTitle);
    if (cleanAuthor.isNotEmpty) parts.add(cleanAuthor);

    return '${parts.join('_')}.$extension';
  }

  static Future<String> _resolveAlbumPath(String baseAlbum, String author, String uid) async {
    final groupByAuthor = await SecurityStorage.getGroupByAuthor();
    if (groupByAuthor && author.isNotEmpty) {
      final safeAuthor = _sanitize(author);
      return safeAuthor.isNotEmpty ? '$baseAlbum/$safeAuthor' : baseAlbum;
    }
    return baseAlbum;
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
  static String _sanitize(String s) => s.replaceAll(RegExp(r'[\\/:*?"<>|\s]'), '_');
}
