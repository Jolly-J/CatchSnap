# SnapAir - 轻量多平台高清素材下载器

> 极简高效 · 爱彼迎设计哲学 · 纯本地免服解析 · 多线程分片加速 · 流体云进度胶囊

一款采用 Flutter + Kotlin 打造的现代化移动端短视频与图集下载工具。支持**抖音 (Douyin)** 与 **小红书 (Xiaohongshu)** 高清无水印解析下载，内置 Web 登录自动捕获 Cookie 凭据，全面适配 Android 10+ Scoped Storage 媒体库存储。

---

## ✨ 核心特性

### 1. 纯本地免服解析 (Privacy First)
* **零外部后端依赖**：彻底剔除自建服务器依赖，解析逻辑全部在手机本地运行，用户隐私与凭据绝不上云。
* **智能双平台支持**：
  * **抖音**：支持分享口令、短网址（`v.douyin.com`）、视频/笔记落地页；提取无水印 1080p 超清原画、音频原声与 LivePhoto 实况片段。
  * **小红书**：支持 `xhslink.com` 短链解析、多清晰度视频流提取（1080p/720p）、全套原图无损图集及实况动图下载。

### 2. 呼出 Web 官方登录，捕获高清 Cookie
* **内置 WebView 登录**：在设置或首页一键呼出平台官方移动端登录页（验证码/扫码安全鉴权）。
* **自动提取凭据**：登录成功后自动通过 `CookieManager` 抓取并加密保存在本地沙盒，直接解锁平台针对登录用户的最高码率原画流。

### 3. 多线程分片下载引擎 (Range Concurrency)
* **跑满带宽**：通过 HTTP `Range` 请求将媒体分割为 1~8 个并行分片并发拉取，大文件下载速度提升 3~5 倍。
* **智能平滑降级**：当服务端不支持分片 Range 时，自动无缝降级为标准流式下载，确保 100% 成功率。

### 4. 新技术体验：流体云 (Fluid Cloud)
* **应用内顶部灵动胶囊**：下载中在界面顶端平滑展开深色药丸胶囊，实时显示瞬时网速（MB/s）、总体百分比与下载状态。
* **系统级悬浮灵动胶囊**：开启系统悬浮胶囊后，即使切出应用刷视频，也能在屏幕上方悬浮胶囊静默显示下载进度，支持点击立即收起。

### 5. 极简轻量与合规友好
* **拒绝实时监听剪贴板**：不常驻后台监听剪贴板，仅在用户进入应用或切回前台瞬间进行单次按需探查，并以底部模态抽屉优雅询问。
* **权限按需调用 (Just-In-Time)**：取消冷启动强制阻断式授权，仅在写入相册或开启悬浮窗时按需申请。

### 6. 爱彼迎 (Airbnb) 设计美学
* 经典的珊瑚红品牌色（`#FF385C`）、大圆角容器（16~24dp）、微边框（`#EBEBEB`）与漫反射柔和阴影，带来温润而高质感的视觉交互体验。

---

## 🏗️ 项目架构

```
lib/
├── AGENTS.md                                # 项目根目录架构规范
├── main.dart                                # 应用全局入口与沉浸式状态栏调度
├── app_theme.dart                           # 爱彼迎设计规范与色彩/阴影资产令牌
│
├── core/                                    # 基础底层引擎模块
│   ├── AGENTS.md
│   ├── constants.dart                       # 全局常量、UA 与键名规范
│   ├── download_engine.dart                 # 高性能多线程 Range 分片并发下载核心
│   └── security_storage.dart                # 本地安全与配置持久化门面
│
├── models/                                  # 核心数据模型 (Entities)
│   ├── AGENTS.md
│   ├── platform_type.dart                   # 平台枚举与品牌色映射
│   ├── media_item.dart                      # 归一化媒体实体 (视频流/多画质/图集/LivePhoto)
│   └── download_task.dart                   # 下载任务与分片状态实体
│
├── parsers/                                 # 纯本地解析器引擎层
│   ├── AGENTS.md
│   ├── base_parser.dart                     # 抽象解析基类接口
│   ├── parser_factory.dart                  # 智能平台路由与解析调度中枢
│   ├── douyin_parser.dart                   # 抖音本地高清免签解析器
│   └── xhs_parser.dart                      # 小红书本地高清解析器
│
├── services/                                # 业务协调与系统能力服务
│   ├── AGENTS.md
│   ├── clipboard_service.dart               # 进 App 单次剪贴板感知服务
│   ├── cookie_service.dart                  # 账号 Cookie 凭据管理服务
│   ├── download_service.dart                # 下载调度与 MediaStore 相册归档
│   ├── permission_service.dart              # Just-In-Time 按需权限服务
│   ├── fluid_cloud_service.dart             # 流体云胶囊调度服务
│   └── history_service.dart                 # 素材归档与历史管理
│
├── utils/                                   # 纯函数工具库
│   ├── AGENTS.md
│   ├── link_extractor.dart                  # 正则提取有效 URL
│   └── format_utils.dart                    # 尺寸、速率、时长格式化
│
├── widgets/                                 # 爱彼迎原子组件库
│   ├── AGENTS.md
│   ├── airbnb_button.dart                   # 经典胶囊按钮与微触感动效
│   ├── airbnb_card.dart                     # 漫反射微阴影圆角卡片
│   ├── fluid_cloud_capsule.dart             # 顶部灵动药丸胶囊组件
│   └── clipboard_prompt_sheet.dart          # 底部优雅剪贴板唤起抽屉
│
└── screens/                                 # 表现层交互页面
    ├── AGENTS.md
    ├── home_screen.dart                     # 首页 (大胶囊输入、平台凭据状态、流体云)
    ├── video_detail_screen.dart             # 详情页 (画质档位选择、图集网格、极速下载)
    ├── web_login_screen.dart                # 内置 WebView 登录获取 Cookie 页面
    ├── history_screen.dart                  # 历史素材库管理
    └── settings_screen.dart                 # 设置页 (多线程调节、流体云控制、相册管理)
```

---

## 📱 运行与构建

```bash
# 1. 安装项目依赖
flutter pub get

# 2. 运行到连接的 Android 设备
flutter run

# 3. 构建发布版 APK
flutter build apk --release
```
