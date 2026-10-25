# parsers 模块架构规范与职能分工 (AGENTS.md)

## 目录概述
`parsers` 模块是本应用的核心数据提取引擎，专职负责**纯本地免服务器**解析各大社交平台的短视频与图集，严格杜绝将解析文本和凭据上传至未授权第三方后端。

## 核心文件清单与职责

| 文件名 | 职能定位 | 维护与设计原则 |
| :--- | :--- | :--- |
| `base_parser.dart` | 抽象解析器契约基类 | 定义 `canHandle(String url)` 和 `Future<MediaItem> parse(String input, {String? cookie})` 核心契约。 |
| `douyin_parser.dart` | 抖音本地高清免签解析器 | 支持短链跟随 302 重定向、提取 `aweme_id`、使用 iPhone 专属 UA 访问官方 `iesdouyin.com/share/video/`、从页面提取 `window._ROUTER_DATA`；结合用户 Cookie 注入解析出 1080p、4K 及实况 Live 分片。 |
| `xhs_parser.dart` | 小红书本地高清原图/视频解析器 | 支持小红书短链 `xhslink.com` 重定向、提取 `noteId`、抓取落地页 HTML、提取内嵌 `window.__INITIAL_STATE__`。结合 Cookie 提取无水印原画视频流与原图图集。 |
| `parser_factory.dart` | 智能路由与解析调度中枢 | 通过正则智能判断用户输入的分享口令属于哪个平台，自动调用对应的本地解析器，预留未来微信扩展能力。 |

## 防反爬与解析原则
1. **UA 精准拟态**：各平台针对不同的 User-Agent 下发的 HTML 结构截然不同，解析器必须使用专门验证过的 UA。
2. **Cookie 增强**：有 Cookie 时优先组装登录态 Header 获取最高清比特率；无 Cookie 时以访客免登录模式平稳兜底。
