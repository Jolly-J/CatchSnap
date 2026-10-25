/**
 * @file: security_storage.dart
 * @description: 本地安全数据与配置管理门面
 * @author: Antigravity
 * @version: 2.0.0
 */

import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

class SecurityStorage {
  static SharedPreferences? _prefs;

  /// 初始化 SharedPreferences 实例
  static Future<SharedPreferences> get _instance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ── Cookie 管理 ──────────────────────────────────────────────
  static Future<String> getDouyinCookie() async {
    final prefs = await _instance;
    return prefs.getString(AppConstants.keyDouyinCookie) ?? '';
  }

  static Future<void> setDouyinCookie(String cookie) async {
    final prefs = await _instance;
    await prefs.setString(AppConstants.keyDouyinCookie, cookie.trim());
  }

  static Future<String> getXhsCookie() async {
    final prefs = await _instance;
    return prefs.getString(AppConstants.keyXhsCookie) ?? '';
  }

  static Future<void> setXhsCookie(String cookie) async {
    final prefs = await _instance;
    await prefs.setString(AppConstants.keyXhsCookie, cookie.trim());
  }

  // ── 下载配置 ──────────────────────────────────────────────────
  static Future<int> getDownloadThreads() async {
    final prefs = await _instance;
    return prefs.getInt(AppConstants.keyDownloadThreads) ?? AppConstants.defaultDownloadThreads;
  }

  static Future<void> setDownloadThreads(int count) async {
    final prefs = await _instance;
    await prefs.setInt(AppConstants.keyDownloadThreads, count);
  }

  static Future<String> getAlbumName() async {
    final prefs = await _instance;
    return prefs.getString(AppConstants.keyAlbumName) ?? AppConstants.defaultAlbumName;
  }

  static Future<void> setAlbumName(String name) async {
    final prefs = await _instance;
    await prefs.setString(AppConstants.keyAlbumName, name.trim().isEmpty ? AppConstants.defaultAlbumName : name.trim());
  }

  // ── 流体云开关与延迟 ──────────────────────────────────────────
  static Future<bool> isFluidCloudEnabled() async {
    final prefs = await _instance;
    return prefs.getBool(AppConstants.keyFluidCloudEnabled) ?? true;
  }

  static Future<void> setFluidCloudEnabled(bool enabled) async {
    final prefs = await _instance;
    await prefs.setBool(AppConstants.keyFluidCloudEnabled, enabled);
  }

  static Future<int> getFluidAutoCloseDelay() async {
    final prefs = await _instance;
    return prefs.getInt(AppConstants.keyAutoCloseFluidDelay) ?? 3;
  }

  static Future<void> setFluidAutoCloseDelay(int seconds) async {
    final prefs = await _instance;
    await prefs.setInt(AppConstants.keyAutoCloseFluidDelay, seconds);
  }

  static Future<bool> getGroupByAuthor() async {
    final prefs = await _instance;
    return prefs.getBool(AppConstants.keyGroupByAuthor) ?? false;
  }

  static Future<void> setGroupByAuthor(bool enabled) async {
    final prefs = await _instance;
    await prefs.setBool(AppConstants.keyGroupByAuthor, enabled);
  }

  // ── 主题外观模式 ('system' | 'light' | 'dark') ────────────────
  static Future<String> getThemeMode() async {
    final prefs = await _instance;
    return prefs.getString(AppConstants.keyThemeMode) ?? 'system';
  }

  static Future<void> setThemeMode(String mode) async {
    final prefs = await _instance;
    await prefs.setString(AppConstants.keyThemeMode, mode);
  }
}
