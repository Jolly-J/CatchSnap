/**
 * @file: download_service.dart
 * @description: 多线程下载调度、流体云进度同步与相册归档服务
 * @author: Antigravity
 * @version: 2.0.0
 */

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../core/download_engine.dart';
import '../core/security_storage.dart';
import '../models/media_item.dart';
import '../utils/format_utils.dart';
import 'history_service.dart';
import 'permission_service.dart';

class DownloadService {
  static const MethodChannel _channel =
      MethodChannel('com.example.douyin_downloader/floating');

  /// 核心下载方法
  static Future<void> downloadMedia({
    required MediaItem item,
    required String downloadUrl,
    required String fileName,
    Function(double progress, String speedText)? onProgress,
  }) async {
    // 1. 按需检查存储权限
    final hasPerm = await PermissionService.requestStorageForSave();
    if (!hasPerm) {
      throw Exception('缺少存储权限，无法保存媒体到系统相册');
    }

    // 2. 构建本地临时中转路径
    final tmpDir = await getTemporaryDirectory();
    final tempFilePath = '${tmpDir.path}/$fileName';
    final tempFile = File(tempFilePath);

    try {
      // 3. 读取用户配置的并发线程数
      final threads = await SecurityStorage.getDownloadThreads();

      // 4. 执行多线程分片下载
      await DownloadEngine.instance.download(
        url: downloadUrl,
        destPath: tempFilePath,
        concurrency: threads,
        headers: {
          'Referer': item.platform.name == 'xiaohongshu'
              ? 'https://www.xiaohongshu.com/'
              : 'https://www.douyin.com/',
        },
        onProgress: (downloaded, total, speedBytes) {
          final progress = total > 0 ? (downloaded / total).clamp(0.0, 1.0) : 0.0;
          final speedStr = FormatUtils.formatSpeed(speedBytes);
          onProgress?.call(progress, speedStr);
        },
      );

      // 5. 调用原生方法将临时文件迁移至系统相册 (MediaStore)
      final albumName = await SecurityStorage.getAlbumName();
      final targetAlbum = await _resolveAlbumPath(albumName, item.author, item.authorUid);

      await _channel.invokeMethod('saveFileToGallery', {
        'filePath': tempFilePath,
        'albumName': targetAlbum,
        'fileName': fileName,
      });

      // 6. 保存到历史记录
      await HistoryService.addHistory(item);
    } catch (e) {
      rethrow;
    } finally {
      // 清理临时中转文件
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  /// 构建规范化文件名 (时间戳_清洗后的标题_作者.ext)
  static String buildFileName({
    required String prefix,
    required String extension,
    required String title,
    required String author,
  }) {
    final now = DateTime.now();
    final ts =
        '${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
    final cleanTitle = _sanitize(title.replaceAll(RegExp(r'#\S+'), '').trim());
    final shortTitle = cleanTitle.length > 20 ? cleanTitle.substring(0, 20) : cleanTitle;
    final cleanAuthor = _sanitize(author);

    final parts = [prefix, ts];
    if (shortTitle.isNotEmpty) parts.add(shortTitle);
    if (cleanAuthor.isNotEmpty) parts.add(cleanAuthor);

    return '${parts.join('_')}.$extension';
  }

  static Future<String> _resolveAlbumPath(String baseAlbum, String author, String uid) async {
    final groupByAuthor = await SecurityStorage.getGroupByAuthor();
    if (groupByAuthor && author.isNotEmpty) {
      final safeAuthor = _sanitize(author);
      final folder = uid.isNotEmpty ? '$safeAuthor($uid)' : safeAuthor;
      return '$baseAlbum/$folder';
    }
    return baseAlbum;
  }

  static String _sanitize(String name) =>
      name.replaceAll(RegExp(r'[\\/:*?"<>|\n\r]'), '_').trim();

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
