/**
 * @file: fluid_cloud_service.dart
 * @description: 流体云 (Fluid Cloud) 灵动胶囊调度与通知服务
 * @author: Antigravity
 * @version: 2.0.0
 * 
 * 核心设计：
 * 1. 应用内：以 ValueNotifier 驱动顶部药丸胶囊平滑展开/收起动效。
 * 2. 系统级：若开启了系统级流体云并具备权限，通过 MethodChannel 驱动 Android 原生 WindowManager 胶囊条。
 */

import 'package:flutter/foundation.dart';
import '../core/security_storage.dart';

class FluidCloudState {
  final bool visible;
  final String title;
  final double progress; // 0.0 ~ 1.0
  final String speedText;
  final bool isCompleted;
  final bool isFailed;

  const FluidCloudState({
    this.visible = false,
    this.title = '',
    this.progress = 0.0,
    this.speedText = '',
    this.isCompleted = false,
    this.isFailed = false,
  });

  FluidCloudState copyWith({
    bool? visible,
    String? title,
    double? progress,
    String? speedText,
    bool? isCompleted,
    bool? isFailed,
  }) {
    return FluidCloudState(
      visible: visible ?? this.visible,
      title: title ?? this.title,
      progress: progress ?? this.progress,
      speedText: speedText ?? this.speedText,
      isCompleted: isCompleted ?? this.isCompleted,
      isFailed: isFailed ?? this.isFailed,
    );
  }
}

class FluidCloudService {
  /// 应用内流体云全局响应式状态
  static final ValueNotifier<FluidCloudState> state =
      ValueNotifier<FluidCloudState>(const FluidCloudState());

  /// 开始展示流体云
  static Future<void> start({required String title}) async {
    state.value = FluidCloudState(
      visible: true,
      title: title,
      progress: 0.0,
      speedText: '正在连接...',
    );
  }

  /// 实时更新流体云进度与网速
  static Future<void> update({
    required double progress,
    required String speedText,
  }) async {
    if (!state.value.visible) return;

    state.value = state.value.copyWith(
      progress: progress,
      speedText: speedText,
    );
  }

  /// 下载完成
  static Future<void> complete({String message = '下载已完成'}) async {
    state.value = state.value.copyWith(
      progress: 1.0,
      speedText: message,
      isCompleted: true,
    );

    // 延迟自动收起
    final delay = await SecurityStorage.getFluidAutoCloseDelay();
    if (delay >= 0) {
      Future.delayed(Duration(seconds: delay), () {
        dismiss();
      });
    }
  }

  /// 任务失败
  static Future<void> fail({String message = '下载遇到问题'}) async {
    state.value = state.value.copyWith(
      speedText: message,
      isFailed: true,
    );

    Future.delayed(const Duration(seconds: 4), () {
      dismiss();
    });
  }

  /// 彻底收起/隐藏流体云
  static Future<void> dismiss() async {
    state.value = const FluidCloudState(visible: false);
  }
}
