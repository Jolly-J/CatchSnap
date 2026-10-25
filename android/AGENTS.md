# android 原生层架构规范与职能分工 (AGENTS.md)

## 目录概述
`android` 目录托管 Android 原生平台能力。主要负责 Scoped Storage (MediaStore) 相册归档、系统级流体云 (Fluid Cloud) 胶囊悬浮窗渲染与权限交互。

## 核心文件清单与职责

| 文件名 | 职能定位 | 维护与设计原则 |
| :--- | :--- | :--- |
| `MainActivity.kt` | 原生生命周期与 MethodChannel 桥接 | 注册 `com.example.douyin_downloader/floating` 通道，提供 `saveFileToGallery`（基于 MediaStore 的相册写入）、前台实时活动启停与 Cookie 获取。 |
| `DownloadForegroundService.kt` | 官方标准前台实时活动服务 (Live Activity) | 基于 Android 原生 ForegroundService，在下载时常驻前台进度通知，系统自动触发 ColorOS 流体云 / HyperOS 焦点胶囊 / 状态栏灵动药丸；下载完成后自动收起。 |

## 原生交互规范
1. **MediaStore 媒体库**：在 Android 10+（API 29+）中通过 `MediaStore.Video.Media` / `MediaStore.Images.Media` 写入媒体流，必须妥善维护 `IS_PENDING` 标志位。
2. **轻量占用**：悬浮胶囊在空闲或下载完成后按设定的延迟时间自动销毁，避免无意义常驻内存。
