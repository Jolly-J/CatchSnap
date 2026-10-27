# Changelog

本项目的所有重要变更均记录在此文件中。

日志格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 规范，版本号遵循 [语义化版本 (Semantic Versioning)](https://semver.org/lang/zh-CN/)。

---

## [1.0.0] - 2026-10-27

### Added (新增)
- 发布咔捕首个正式版 `v1.0.0`，保留现有抖音 / 小红书本地解析、下载任务、网页登录、相册保存和主题切换功能。
- 新增暖白底 Android 自适应图标、Android 13+ 单色主题图标，以及旧系统使用的多密度和圆形图标。
- 在 `品牌元素/系统图标/` 统一维护图标源文件、商店导出素材、预览、生成脚本与验证记录。
- 配置专用正式发布签名，提供不含密码的配置示例；密钥和密码文件仅保存在本地。

### Changed (变更)
- 源码版本、应用内版本和 APK 版本统一为 `1.0.0`，构建号递增为 `2`。此前 `2.0.0-beta1` 为开发预览编号，本次按正式版编号发布。
- Android 构建从 Flutter 版本配置读取 `versionName` 和 `versionCode`，减少多处硬编码不一致。
- README 更新正式版下载入口、图标说明与签名配置步骤。
- 停止跟踪本机生成的 Flutter 插件列表和 Android SDK 路径配置，保留已有忽略规则。

### Migration (升级说明)
- 新正式证书与测试版调试证书不同，旧测试版无法直接覆盖安装。卸载重装会清除应用本地配置、登录会话和下载记录，请先保留所需资料。

---

## [2.0.0-beta.1] - 2026-10-25

### Added (新增)
- **品牌升级与视觉体系重构（咔捕 v2.0）**：
  - 全新品牌命名「**咔捕**」及 3D 吉祥物全场景插画体系（欢迎、搜索、发现、冲刺、庆祝、空状态等）。
  - 引入爱彼迎（Airbnb）轻奢设计语言与 ChatGPT 共享 Surface 边缘质感（浅色模式 97% 微透表面 + 零偏移漫反射柔影；深色模式 97% 表面 + `0.5dp` 15% 浅白微光细边）。
- **全页面悬浮顶部栏与渐隐遮罩体系（Floating Top Bar & Fade-Through Mask）**：
  - 新增通用悬浮骨架 [`FloatingPageScaffold`](lib/widgets/floating_top_bar.dart) 与 [`FloatingTopBar`](lib/widgets/floating_top_bar.dart)，移除传统实体 `AppBar` 与底部分割栏。
  - 主页、设置页、下载任务中心、媒体详情页、网页登录页全面统一为“内容通顶穿透 + 16 段 ease-in-out 背景色渐隐遮罩 + 悬浮胶囊控件”，零 `BackdropFilter` 离屏渲染开销。
- **全链路 Edge-to-Edge 沉浸式适配**：
  - Android 原生层（[`MainActivity.kt`](android/app/src/main/kotlin/com/example/douyin_downloader/MainActivity.kt)）接入 `WindowCompat.setDecorFitsSystemWindows(window, false)`，关闭状态栏与导航栏对比度强制遮罩，适配挖孔屏与全面屏手势导航条。
  - Flutter 各页面滚动视图、底部悬浮按钮及剪贴板弹窗全面适配系统安全区边距。
- **深色模式与金标联盟「一镜到底」开屏体验**：
  - 支持「白色 / 黑暗 / 自动（设备设置）」三档外观实时切换并持久化保存。
  - 适配 Android 12+（API 31+）系统级 `SplashScreen` 与深浅色自动跟随，定制符合 `160dp` 中心安全圆规范的高清透明开屏图标 [`splash_icon.png`](android/app/src/main/res/drawable-nodpi/splash_icon.png)，解决系统圆形遮罩裁切问题。
- **仿 ChatGPT 二阶弹簧阻尼预测式返回（Predictive Back）**：
  - 自定义 [`SmoothPredictiveBackPageTransitionsBuilder`](lib/app_theme.dart)，基于 VSYNC `Ticker` 二阶临界阻尼弹簧模型与对数橡皮筋空间阻尼，彻底消除手势硬绑定感。
  - 实现“二级界面阻尼右移渐隐 → 界面默认底色中间态 → 一级界面从 0% 随手指拖拉平滑渐显”的三段式过渡。
- **Android 15/16 系统流体云（Fluid Cloud / 实时活动）原生接入**：
  - 新增 [`DownloadForegroundService.kt`](android/app/src/main/kotlin/com/example/douyin_downloader/DownloadForegroundService.kt)，声明 `POST_PROMOTED_NOTIFICATIONS` 等权限，接入 `requestPromotedOngoing` 与胶囊芯片 `setShortCriticalText`。
  - 状态栏胶囊百分比采用固定字符宽度格式化，消除数字变化时的胶囊宽度抖动。
- **内置桌面级 WebView 账号登录与 4K 无水印媒体解析**：
  - 新增 [`WebLoginScreen`](lib/screens/web_login_screen.dart)，支持抖音与小红书扫码 / 短信验证码登录并自动提取 `HttpOnly` 核心 Cookie。
  - 小红书解析器 [`XiaohongshuParser`](lib/parsers/xiaohongshu_parser.dart) 支持提取 `png/YK1` 4K 原画无水印大图与 LivePhoto 实况视频流。
  - 抖音解析器 [`DouyinParser`](lib/parsers/douyin_parser.dart) 支持纯本地直连提取 1080p 原画无水印视频与图集，彻底移除外部第三方解析服务端依赖。

### Changed (变更)
- **下载流程与交互优化**：
  - 在详情页点击开始下载后自动返回主页，由系统流体云与下载任务中心接管进度展示。
  - 移除主页顶部冗余的应用内模拟流体云黑条组件。
  - 重绘设置页「并发下载分片数」滑块组件（[`_UniformCapsuleTrackShape`](lib/screens/settings_screen.dart) 等高胶囊轨道 + [`_DualRingSliderThumbShape`](lib/screens/settings_screen.dart) 双环手柄 + 1~8 对齐可点击刻度行）。
- **权限生命周期规范化**：
  - 首次进入主页后主动引导申请通知权限（`POST_NOTIFICATIONS`）与相册写入权限，保障流体云实时通知与媒体归档正常触发。

### Fixed (修复)
- 修复多线程分片下载时高频进度回调与主线程大文件阻塞式合并导致的 UI 卡死（ANR）问题，改为 `200ms` 节流推送 + 原生后台线程池异步流式合并与相册写入。
- 修复设置页切换「白色 / 黑暗」主题时当前页背景与卡片未立即同步刷新的问题。
- 修复 Android 12+ 开屏动画因直接使用全画幅图标被系统圆形遮罩放大裁切的问题。

---

## 初始开发记录（原记为 1.0.0）- 2026-10-24

### Added (新增)
- 初始版本发布，支持基础抖音链接解析、视频下载与历史记录管理。
