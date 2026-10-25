/**
 * @file: system_notification_service.dart
 * @description: Android 官方标准前台实时活动 (Live Activity) 调度服务
 *               触发各厂商系统原生流体云 / 灵动胶囊 / 焦点通知
 * @author: Antigravity
 * @version: 2.0.0
 */

import 'dart:io';
import 'package:flutter/services.dart';

class LiveActivityService {
  static const MethodChannel _channel =
      MethodChannel('com.example.douyin_downloader/floating');

  /// 启动系统前台服务实时活动 (触发 ColorOS 流体云 / HyperOS 焦点胶囊)
  static Future<void> start({
    required String title,
    double progress = 0.0,
    String speed = '',
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('startLiveActivity', {
        'title': title,
        'progress': (progress * 100).toInt().clamp(0, 100),
        'speed': speed,
      });
    } catch (_) {}
  }

  /// 实时同步下载进度与网速至系统流体云
  static Future<void> update({
    required double progress,
    required String speed,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('updateLiveActivity', {
        'progress': (progress * 100).toInt().clamp(0, 100),
        'speed': speed,
      });
    } catch (_) {}
  }

  /// 停止前台服务并收起系统流体云
  static Future<void> stop({
    bool isSuccess = true,
    String title = '',
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stopLiveActivity', {
        'isSuccess': isSuccess,
        'title': title,
      });
    } catch (_) {}
  }
}
