/**
 * @file: permission_service.dart
 * @description: 标准运行时权限管理服务（首次启动主动申请通知与相册媒体权限 + 下载前兜底校验）
 * @author: Antigravity
 * @version: 2.0.0
 */

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static bool _initialRequested = false;

  /// 应用启动时主动申请核心权限：
  /// 1. 实时通知 / 流体云权限 (POST_NOTIFICATIONS)
  /// 2. 相册图片与视频读写权限 (READ_MEDIA_IMAGES / READ_MEDIA_VIDEO / WRITE_EXTERNAL_STORAGE)
  static Future<void> requestInitialPermissions() async {
    if (!Platform.isAndroid || _initialRequested) return;
    _initialRequested = true;

    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      // 1. 优先请求通知权限（用于流体云与下载实时活动进度）
      final notifStatus = await Permission.notification.status;
      if (!notifStatus.isGranted) {
        await Permission.notification.request();
      }

      // 2. 请求相册与媒体存储权限
      if (sdkInt >= 33) {
        // Android 13+ 细粒度相册媒体权限（系统弹窗：“允许 咔捕 访问此设备上的照片和视频吗？”）
        final photosStatus = await Permission.photos.status;
        final videosStatus = await Permission.videos.status;
        if (!photosStatus.isGranted || !videosStatus.isGranted) {
          await [
            Permission.photos,
            Permission.videos,
          ].request();
        }
      } else {
        // Android 12 及以下传统外部存储读写权限
        final storageStatus = await Permission.storage.status;
        if (!storageStatus.isGranted) {
          await Permission.storage.request();
        }
      }
    } catch (_) {}
  }

  /// 下载前校验并按需申请相册权限与通知权限
  static Future<bool> requestStorageForSave() async {
    if (!Platform.isAndroid) return true;

    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      // 确保通知权限已触发申请（不阻塞下载主流程）
      final notifStatus = await Permission.notification.status;
      if (notifStatus.isDenied) {
        await Permission.notification.request();
      }

      if (sdkInt >= 33) {
        final photosStatus = await Permission.photos.status;
        final videosStatus = await Permission.videos.status;
        if (!photosStatus.isGranted || !videosStatus.isGranted) {
          final results = await [
            Permission.photos,
            Permission.videos,
          ].request();
          final granted = (results[Permission.photos]?.isGranted ?? false) ||
              (results[Permission.photos]?.isLimited ?? false) ||
              (results[Permission.videos]?.isGranted ?? false) ||
              (results[Permission.videos]?.isLimited ?? false);
          if (granted) return true;
        } else {
          return true;
        }
        // Android 10+ MediaStore 即使仅授予部分访问也可写入相册
        return true;
      }

      if (sdkInt >= 29) {
        final storageStatus = await Permission.storage.status;
        if (!storageStatus.isGranted) {
          await Permission.storage.request();
        }
        return true;
      }

      // Android 9 及以下机型必须拥有 storage 权限
      final status = await Permission.storage.request();
      return status.isGranted;
    } catch (_) {
      return true;
    }
  }
}
