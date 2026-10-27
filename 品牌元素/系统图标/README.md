# 咔捕系统图标

采用已确认的暖白底 `#FFF8F5`，保留当前放大镜机器人。彩色版本直接由 `../Logo/应用logo.png` 按比例导出；单色主题版本使用保留机器人、顶瓣、放大镜和胸前三角的矢量标识。

## 文件入口

| 目录 | 用途 |
| --- | --- |
| `源文件/` | 432 × 432 透明前景、实色背景、单色 PNG 和 Android 矢量图 |
| `android/res/` | 与项目 Android 图标资源一致的交付副本 |
| `商店/` | 各分发平台的上传文件 |
| `预览/图标适配总览.png` | 蒙版、主题及小尺寸预览 |
| `generate.swift` | macOS 原生导出脚本，无第三方依赖 |
| `geometry.json` | 前景位置和安全区参数 |
| `验证结果.json` | 尺寸、透明度、安全区、资源一致性与哈希检查记录 |

## Android 桌面图标

- API 26 起使用自适应图标，前景、背景独立，108 × 108 dp 图层对应 432 × 432 px 资源。
- 主要可见内容位于中心直径 64 dp 内，前景外层约束在直径 66 dp 的安全圆内。系统决定图标蒙版形状。
- API 33 起提供独立 `monochrome` 矢量图层，支持主题图标的桌面按用户配色着色。
- API 21～25 保留 48 / 72 / 96 / 144 / 192 px 传统图标，并提供圆形备用资源。
- 前景不预切系统外轮廓；背景不透明、不附加外框阴影。角色本身的 3D 材质高光保留。

依据：[Android 自适应图标规范](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive)。

## 商店素材与官方依据

核对日期：2026-10-27。商店上传图与 APK 彩色桌面图使用同一角色和暖白底。

| 平台 | 本次文件 | 核对到的要求与范围 |
| --- | --- | --- |
| Google Play | `kabu-google-play-512.png` | 512 方图、32 位 PNG、sRGB、≤ 1024KB；直角原图，平台处理外圆角及外阴影。[官方规范](https://developer.android.com/distribute/google-play/resources/icon-design-specifications) |
| 小米 | `kabu-xiaomi-oppo-512.png` | 512 方图、PNG，与桌面图标内容一致。[官方指南](https://dev.mi.com/xiaomihyperos/documentation/detail?pId=1072) |
| OPPO | `kabu-xiaomi-oppo-512.png` | 512 方图、PNG、小于 1MB、直角上传，与安装包图标一致。[官方上传指引](https://open.oppomobile.com/bbs/forum.php?mod=viewthread&tid=6304) |
| vivo | `kabu-vivo-512.png` | 256 或 512 方图、当前上限 500KB、直角且清晰，与桌面图标一致。[审核规范 2.7](https://dev.vivo.com.cn/documentCenter/doc/12)、[图标上传规范](https://dev.vivo.com.cn/documentCenter/doc/101) |
| 荣耀 | `kabu-honor-512.jpg` | API 传包表要求 512 方图、≤ 200KB，支持 PNG/JPG/JPEG；采用高质量 JPEG 满足体积限制。[官方文件类型表](https://developer.honor.com/cn/doc/guides/101359) |
| 华为 HarmonyOS 手机商店素材 | `kabu-huawei-harmonyos-216.png` 或 `kabu-master-1024.png` | 当前支持 216 或 1024 方图，PNG ≤ 3MB。[官方素材规范](https://developer.huawei.com/consumer/cn/doc/doccenter-submission/agc-help-app-visual-asset-spec-0000002277607976) |

华为一行仅指 HarmonyOS 手机商店素材规格，不能据此视为 Android APK 已完成原生 HarmonyOS 图标配置或可直接发布 HarmonyOS 应用。当前工程仍是 Android 工程。

## 验证边界

已检查导出尺寸、色彩标记、背景不透明度、前景安全区、常见蒙版预览、48～192 px 显示，以及 Android AAPT2 资源编译和链接。

1.0.0 正式 APK 已完成构建，并核对实际包内的自适应资源、版本号及专用发布签名；现有 6 项 Flutter 回归测试通过。

本次未连接手机，未完成各厂商真机桌面、主题引擎及商店后台上传验收。自定义桌面主题仍可能改变显示方式。构建和资源检查不等同于商店审核通过。

## 重新导出

在项目根目录运行：

```sh
swift -module-cache-path /tmp/kabu-swift-cache 品牌元素/系统图标/generate.swift
```

脚本更新本目录导出副本。采用新版本时，将 `android/res/` 同步到项目 `android/app/src/main/res/`，保留旧资源归档，并更新验证记录及系统图标交付包。

当前接入使用 `@mipmap/ic_launcher` 与 `@mipmap/ic_launcher_round`。原始透明 Logo 和动作素材继续保存在品牌元素目录中。
