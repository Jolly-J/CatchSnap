# APK 边缘亮线、渐变与 shimmer：静态证据补充

## 结论先行

在已追到的真实业务调用中，**亮边不必是折射 shader 或渐变描边**：Pro onboarding 卡片明确采用「半透明白色实色描边 + 底色/内部渐变 + elevation 阴影」。通用 loading shimmer 则是独立的移动线性渐变，不能拿它解释输入框静态亮边。本报告不替代主报告对 Composer/ElevatedContent 的证据。

未发现足够证据证明本次这些组件使用 inner shadow、动态折射或 gradient stroke；这不是断言整个 APK 都不存在。

## 1. 业务样例：ProIntelligenceArtwork

稳定定位：classes6.dex `bu81.r`，其实际入口 `bu81.i`（OnboardingArtwork）在 offset 0x3c4 调用 r，而非仅预览函数。

可读证据：`ui-evidence/edge-single/bu81.java:2072–2168`，特别是2120–2139。

| 层 | APK中的参数 |
|---|---|
| 外部布局 | 宽248dp；内部条形卡高56dp |
| 形状 | `q1r0.a`，圆角百分比50%，胶囊形；不是固定50dp |
| 外层填充 | 白色 `#FFFFFFFF`，alpha0.70 |
| 边缘亮线 | 宽1dp，白色alpha0.55 |
| 阴影 | `v181.o(...,12f,shape,...,mask28)` 的 elevation12dp路径 |
| 内部填充 | 水平线性渐变 `#FF9639ED → #FFA25BFF` |
| 边框后padding | 8dp，随后绘制内部渐变与内容 |

渐变由 `ev00.b` 构造，其端点默认从 `(0,0)` 到 `(width,0)`；因此这是**内部背景渐变**，不是把同一 brush 作为 border 使用。

边框直接调用 `jm01.j` → `jm01.k` → `ty9`。`jm01.j`先创建 `xtv0`；`xtv0.toString` 明确为 `SolidColor`，绘制时会清理shader，因此这条亮线可确定为实色描边。

## 2. 业务样例：ProWorkConnectorCard

classes6.dex `bu81.t`，由 `bu81.u`（ProWorkArtwork）分别在0x498/0x4b4/0x4da调用，`bu81.i`在0x45a调用u。

可读证据：`ui-evidence/edge-single/bu81.java:2195–2233`。

- 卡片外尺寸80×80dp。
- 四角圆角20dp（`q1r0.b(20)`）。
- 边框1dp、白色alpha0.55。
- elevation6dp路径。
- 底色来自固定所选主题 `lim.h(x0n.c).c.c`；后续核对 `ui-evidence/lim-debug.java` 中普通light的 `z3n` 第三个构造值为 `#FFFFFFFF`，即不透明白，不能套用胶囊的70%填充。
- 图标40×40dp。

这同样是「浅色亮线 + 实体底色 + 外阴影」的卡片，不是采样卡片背后画面的证明。

## 3. 背景柔和渐变，不是边线

`dy81.a`（AssistantCardControlsContent）与 `xy81.a`（AssistantOverlayLayout）都有实际caller：
- `wk6.invoke`/`ls.invoke` → dy81.a；
- `fz81.a`/`no6.invoke` → xy81.a。

两者以主题色 `m2o0.c(...).l.b` 为基色，构造33个采样颜色：alpha为 cubic-bezier(0.42,0,0.58,1) 在 `i/32` 的值，i=0..32，再通过 `ev00.e` 构造纵向渐变并用 `to60.m` 作为背景。RGB不变，透明度由0平滑变1。

这是遮罩/背景渐隐层，能形成“柔和的边缘过渡”，但不是描边，也没有在此发现折射采样。

## 4. Loading shimmer 的真实实现和边界

`crq0.u` 是业务通用 shimmer modifier，全DEX调用索引中有167条直接调用（含重组/包装，不能等同167个业务场景）。真实场景如：
- `n981.a`，Sentry名 ShimmerText，传给 `crq0.u`后绘制占位文本；
- `mk20` 的 ShimmerImageResult 调用该modifier。

定量逻辑（`decompiled/sources/defpackage/crq0.java:425–510`）：
- 动画标记 `ShimmerAnimation`；float从0移动到3000；duration2000ms。
- 缓存的渐变跨度参数2000；x起点 `animatedX-2000`，终点 `animatedX-1000`，y均0。
- 三色依次为基色、基色alpha乘0.2、基色；这是一道更透明的带，不是固定白色高光。
- 默认基色来自主题token `m2o0.c(...).d.a`；默认shape来自主题shape token。
- 一个布尔分支让占位区域从10%高度起绘制、占80%高度；另一个控制是否继续drawContent。

单看 `Shimmer` 搜索会误判：
- `jjf`/`ijf` 只是 ChatgptClientMarkerType 序列化与枚举映射，`LOADING_SHIMMER_RENDERED` 是埋点名，完全不能证明绘制机制。
- `j981` 中 ShimmerProjectListItem 是加载占位业务组件，不应拿来解释静态输入框亮边。
- `i981.a` 的另一个 `card_art_shimmer` 是1200ms移动的三色渐变；仅有 `vkn.invoke` 实际caller与 `i9`重组caller，本次未补齐它的支付/业务场景归属，不把其参数移植为Composer实现。

## 5. 可以直接借鉴的设计组合（原创概括，非源码复刻）

- 静态卡片亮边：先圆角shape，添加合适elevation，绘制底色，再使用同一shape的1dp半透明白色border。
- 如需要彩色层次，将背景渐变放在卡片内部；不要误称为gradient border。
- Loading shimmer用独立状态控制，仅加载期间启用；与静态边框/阴影分离。
- 上述0.55/0.70/1dp只对应已定位的Pro onboarding卡片，不应写成ChatGPT所有输入框、按钮、sheet的统一设计token。

## 验证范围

仅云端静态APK分析，没有安装、执行、截图比对或实际主题/实验开关验证。完整反编译类仅保留在内部证据目录ui-evidence，不随本摘要作为源码交付。DEX class/method/offset是稳定定位；JADX行号仅对应本次生成文件，不是原始源码行号。
