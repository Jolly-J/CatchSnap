/**
 * @file: main.dart
 * @description: 应用全局入口与主题调度 (爱彼迎轻量高效架构)
 * @author: Antigravity
 * @version: 2.0.0
 * 
 * 核心原则：
 * 1. 权限按需调用 (Just-In-Time)，移除冷启动阻断式权限弹窗。
 * 2. 挂载 Airbnb 全局设计系统规范主题。
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 沉浸式边缘到边缘系统导航栏与状态栏配置
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await AirbnbTheme.initThemeMode();

  runApp(const SnapAirApp());
}

class SnapAirApp extends StatefulWidget {
  const SnapAirApp({super.key});

  @override
  State<SnapAirApp> createState() => _SnapAirAppState();
}

class _SnapAirAppState extends State<SnapAirApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    AirbnbTheme.syncSystemUiOverlay();
    if (AirbnbTheme.themeModeNotifier.value == ThemeMode.system && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AirbnbTheme.themeModeNotifier,
      builder: (context, themeMode, _) {
        AirbnbTheme.syncSystemUiOverlay();
        return MaterialApp(
          title: '咔捕',
          debugShowCheckedModeBanner: false,
          theme: AirbnbTheme.lightTheme,
          darkTheme: AirbnbTheme.darkTheme,
          themeMode: themeMode,
          home: const HomeScreen(),
        );
      },
    );
  }
}
