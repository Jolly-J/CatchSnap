/**
 * @file: history_service.dart
 * @description: 媒体解析与下载历史归档持久化服务
 * @author: Antigravity
 * @version: 2.0.0
 */

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../models/media_item.dart';

class HistoryService {
  static const int _maxHistoryLimit = 100;

  /// 添加记录并自动去重
  static Future<void> addHistory(MediaItem item) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(AppConstants.keyDownloadHistory);
      List<dynamic> list = historyJson != null ? json.decode(historyJson) : [];

      // 依据唯一 ID 或标题进行去重
      list.removeWhere((raw) {
        final m = raw as Map<String, dynamic>;
        return m['id'] == item.id || (m['title'] == item.title && item.title.isNotEmpty);
      });

      // 插入到首位
      list.insert(0, item.toJson());

      // 限制最大归档数量
      if (list.length > _maxHistoryLimit) {
        list = list.sublist(0, _maxHistoryLimit);
      }

      await prefs.setString(AppConstants.keyDownloadHistory, json.encode(list));
    } catch (_) {}
  }

  /// 获取历史列表
  static Future<List<MediaItem>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final historyJson = prefs.getString(AppConstants.keyDownloadHistory);
      if (historyJson == null) return [];

      final List<dynamic> list = json.decode(historyJson);
      return list.map((e) => MediaItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// 删除单条历史
  static Future<void> deleteHistory(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(AppConstants.keyDownloadHistory);
      if (historyJson == null) return;

      List<dynamic> list = json.decode(historyJson);
      list.removeWhere((e) => (e as Map<String, dynamic>)['id'] == id);

      await prefs.setString(AppConstants.keyDownloadHistory, json.encode(list));
    } catch (_) {}
  }

  /// 清空历史
  static Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.keyDownloadHistory);
    } catch (_) {}
  }
}
