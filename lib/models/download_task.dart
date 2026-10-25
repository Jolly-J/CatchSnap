/**
 * @file: download_task.dart
 * @description: 下载任务状态与分片进度实体
 * @author: Antigravity
 * @version: 2.0.0
 */

import 'media_item.dart';

enum TaskStatus {
  idle,
  queued,
  downloading,
  completed,
  failed,
  canceled;

  String get label {
    switch (this) {
      case TaskStatus.idle:
        return '等待中';
      case TaskStatus.queued:
        return '排队中';
      case TaskStatus.downloading:
        return '下载中';
      case TaskStatus.completed:
        return '已完成';
      case TaskStatus.failed:
        return '下载失败';
      case TaskStatus.canceled:
        return '已取消';
    }
  }
}

class DownloadTask {
  final String taskId;
  final MediaItem mediaItem;
  final String downloadUrl;
  final String fileName;
  final TaskStatus status;
  final int downloadedBytes;
  final int totalBytes;
  final double speedBytesPerSecond;
  final String savePath;
  final String? errorMessage;
  final DateTime createdAt;

  const DownloadTask({
    required this.taskId,
    required this.mediaItem,
    required this.downloadUrl,
    required this.fileName,
    this.status = TaskStatus.idle,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.speedBytesPerSecond = 0.0,
    this.savePath = '',
    this.errorMessage,
    required this.createdAt,
  });

  /// 计算总体进度百分比 (0.0 ~ 1.0)
  double get progress {
    if (totalBytes <= 0) return 0.0;
    return (downloadedBytes / totalBytes).clamp(0.0, 1.0);
  }

  DownloadTask copyWith({
    TaskStatus? status,
    int? downloadedBytes,
    int? totalBytes,
    double? speedBytesPerSecond,
    String? savePath,
    String? errorMessage,
  }) {
    return DownloadTask(
      taskId: taskId,
      mediaItem: mediaItem,
      downloadUrl: downloadUrl,
      fileName: fileName,
      status: status ?? this.status,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      speedBytesPerSecond: speedBytesPerSecond ?? this.speedBytesPerSecond,
      savePath: savePath ?? this.savePath,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt,
    );
  }
}
