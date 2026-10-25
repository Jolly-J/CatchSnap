/**
 * @file: platform_type.dart
 * @description: 媒体平台枚举与品牌视觉映射
 * @author: Antigravity
 * @version: 2.0.0
 */

import 'package:flutter/material.dart';

enum PlatformType {
  douyin,
  xiaohongshu,
  wechat,
  unknown;

  /// 平台中文展示名称
  String get displayName {
    switch (this) {
      case PlatformType.douyin:
        return '抖音';
      case PlatformType.xiaohongshu:
        return '小红书';
      case PlatformType.wechat:
        return '微信视频号';
      case PlatformType.unknown:
        return '未知平台';
    }
  }

  /// 平台主题品牌色
  Color get brandColor {
    switch (this) {
      case PlatformType.douyin:
        return const Color(0xFF161823);
      case PlatformType.xiaohongshu:
        return const Color(0xFFFF2442);
      case PlatformType.wechat:
        return const Color(0xFF07C160);
      case PlatformType.unknown:
        return const Color(0xFF717171);
    }
  }

  /// 平台官方高清图标资源路径
  String? get iconAsset {
    switch (this) {
      case PlatformType.douyin:
        return 'assets/icons/douyin.png';
      case PlatformType.xiaohongshu:
        return 'assets/icons/xhs.png';
      default:
        return null;
    }
  }

  /// 平台默认 Web 登录入口地址
  String get loginUrl {
    switch (this) {
      case PlatformType.douyin:
        return 'https://www.douyin.com/login_page?service=https%3A%2F%2Fwww.douyin.com%2F';
      case PlatformType.xiaohongshu:
        return 'https://www.xiaohongshu.com/login';
      case PlatformType.wechat:
        return 'https://channels.weixin.qq.com/';
      case PlatformType.unknown:
        return '';
    }
  }
}
