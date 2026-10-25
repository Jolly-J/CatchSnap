# services 模块架构规范与职能分工 (AGENTS.md)

## 目录概述
`services` 模块负责系统级能力编排与业务状态调度。负责将本地持久化、原生通道（MethodChannel）、下载引擎与 UI 事件进行有机衔接。

## 核心文件清单与职责

| 文件名 | 职能定位 | 维护与设计原则 |
| :--- | :--- | :--- |
| `clipboard_service.dart` | 剪贴板单次按需检测服务 | **杜绝后台持续偷听**。仅在应用冷启动或从后台切换回前台瞬间，单次静默读取系统剪贴板并去重判断是否含有抖音/小红书链接。 |
| `cookie_service.dart` | 账号 Cookie 凭据管理服务 | 负责读取、写入、清空各平台 Cookie。对接内置 WebView 登录抓取回传的会话串。 |
| `download_service.dart` | 下载编排与相册归档服务 | 调度底层 `DownloadEngine` 多线程分片引擎，并经由 MethodChannel 将文件安全插入系统 MediaStore 相册。 |
| `download_task_manager.dart` | 全局下载任务调度管理中心 | 维护多任务队列（进行中与已完成）、后台挂起执行、取消/清空、向主页提供实时 Badge 任务数。 |
| `system_notification_service.dart` | 系统前台实时活动 (Live Activity) 服务 | 桥接 Android 官方标准前台服务，在下载运行时触发厂商系统流体云（ColorOS/HyperOS等）与通知栏进度条，下载完成自动收起。 |
| `permission_service.dart` | 极简按需权限管理服务 | 落实 **Just-In-Time 权限按需调用** 理念。移除启动强制弹窗拦截，仅在写入相册时按需申请。 |
| `fluid_cloud_service.dart` | 应用内流体云状态分发 | 仅用于 App 内部顶部灵动胶囊的平滑展开收起动画，杜绝侵入式自定义浮窗。 |
| `history_service.dart` | 历史记录归档服务 | 记录解析与下载成功的媒体素材，支持去重过滤与本地清除。 |

## 设计原则
1. **按需与节制**：权限与剪贴板读取严守用户知情原则。
2. **轻量与响应式**：服务间通过 Stream 或 ValueNotifier 进行状态分发，避免冗杂的外部依赖。
