# 圆角表面的边缘光泽：轻量 Compose 设计参考

**尚无用户截图，不能认定用户说的边缘光泽就是 Pro 页面、输入栏或某个固定控件。** 这里将 APK 中找到的具体候选与可调整的原创设计实验分开。`LightweightGlossSurface.kt` 使用公开 Compose API 独立编写，不是提取的 ChatGPT 源码，不复现全部 UI，也未编译/实机验证。

## 先理解视觉组成

窄而明亮的边缘、略透明的面、宽而淡的阴影，加上有对比度的背景，就可能产生光泽/玻璃感；**不需要据此推断有背景模糊**。白色 alpha=.70 表示 70% 不透明，不能写成“70%透明”。同一组参数在白底可能很克制，在彩色或深色底会更明显。

示例将三个东西分开命名：

- `fillColor`：面色及自身 alpha，不降低文字/图标 alpha。
- `edgeWidth`、`edgeTopColor`、`edgeBottomColor`：边缘；上下颜色相同就使用 SolidColor。上下不同仅是额外设计实验，不作为已找到的 APK 渐变描边证据。
- `elevation` **或** `softShadowRadius`：二选一的阴影。elevation 是高度，不是模糊半径；50dp blur 不能等同 50dp elevation。

## 优先学习：共享 Surface 的主题策略

`SharedSurfaceReference` 展示比 Pro 卡片更通用的候选：普通 dark 默认 **0.5dp、#26FFFFFF（约14.9%白）实色边**；普通 light 默认不画边，转而使用阴影。light 基础边色为 #1A000000，只有强制边框时才画。示例 `forceBorderInLight` 可对照这两种状态。

此函数的24dp圆角、传入面色、light 6dp elevation 是**原创演示选择**，不是已解码的共享Surface默认配方。elevation 只是公开 API 的视觉重建，不宣称复现自有外阴影算法。Composer有自己的1dp同色边与50dp柔影，不应套用共享Surface默认白15%边。

## 已核准的主输入栏候选

| 属性 | 静态证据 |
| --- | --- |
| 圆角 | 24dp |
| 面色 | 主题 palette.c.a，alpha=.97 |
| 常规浅色/深色主题基色 | #FFFFFFFF / #FF303030 |
| 描边 | 1dp，原主题基色 alpha=1，SolidColor，不是白色渐变 |
| 自有软阴影参数 | 黑色 #FF000000 × alpha=.15，blurRadius=50dp |

`ComposerSurfaceReference` 用公开 `dropShadow(Shadow(radius=50.dp, color=black@.15))` 近似重建这组设计参数，**不是复刻 APK 的自有 shader/RenderNode 算法**，相同数值不保证相同像素。示例选择零 offset/零 spread；它们属于此设计实现，不额外声称 APK 全部实现与此相同。取证中字段值 `1` 对应超大区域 fallback 的 RenderNode elevation，不是 shadow offsetY=1dp。

该函数只有外观容器，不是可编辑输入框，没有键盘、光标、焦点、发送按钮、语音状态或无障碍输入语义。

## Pro 候选

已核准的真实业务候选见 [edge-findings.md](../ui-report/edge-findings.md)：

- `ProIntelligenceArtwork`：胶囊 shape 为 50% 圆角；白色 alpha=.70 填充、1dp 白色 alpha=.55 **实色**亮边、12dp elevation、边框后 8dp padding。内部是水平紫色背景渐变 #FF9639ED → #FFA25BFF，**不是 gradient stroke**。布局外部宽 248dp、条形区域高 56dp。
- `ProWorkConnectorCard`：80×80dp、20dp 圆角、1dp 白色 alpha=.55 边、6dp elevation。固定浅色主题底色 token 后续核准为 #FFFFFFFF（不透明白），不是白70%；补核定位为 `ui-evidence/lim-debug.java:1448`。

`ProArtworkCapsuleReference` 用原创文字呈现前者的层次；`ProConnectorCardReference` 默认用核准的不透明白，也保留可调整的 `cardSurfaceColor`。胶囊的通用容器通过大半径钳制实现，内部背景使用50%圆角；这些是设计重建，不宣称业务布局逐像素一致。

这两处均有真实业务调用，但依然不能认定用户所说的边缘光泽就是它们。未找到动态折射/渐变描边证据不等于整个 APK 不存在这些技术。

## 如何运行与调整

在已配置 Kotlin/Compose 插件的 Android 工程添加固定稳定版本（与自己的 BOM/version catalog 统一，避免强制降级）：

```kotlin
implementation("androidx.compose.ui:ui:1.9.4")
implementation("androidx.compose.foundation:foundation:1.9.4")
```

已有 `ComponentActivity.setContent` 中调用 `GlossSurfaceStudyDemo()`。新 `dropShadow`/`Shadow` 框架属于 Compose UI 1.9 系列；这里不依赖 alpha 渐进模糊 API。Demo 展示浅灰、浅蓝、深色三种背景，并有一个明确标为 design experiment 的渐变边缘。

建议调参顺序：
1. 先选与目标相同的背景、主题、控件尺寸和密度。
2. 保持实色 1dp 边，调 fill alpha；不要同时把所有层改透明。
3. 再调边缘 alpha；白底上的白边本来就可能不明显。
4. 最后增加淡阴影。若目标有清楚方向性高光，再试上下渐变，别先加模糊。
5. 用截图/录屏对照；未经定位，不要把 Pro/Composer/TopBar 的值混成一套通用参数。

## 性能与工程边界

- **没有 backdrop capture、RenderEffect 背景模糊或运行时 shader。** `dropShadow` 本身会生成柔阴影，也有成本；“不做背景模糊”不等于 GPU 零成本。
- shape、edge Brush、Shadow 通过 `remember` 缓存；没有逐帧 draw 回调中重建画笔。若改成依赖尺寸的自绘 Brush，使用 `drawWithCache`，尺寸/输入变动再建。
- 不要给长列表每一行都叠多个 50dp 阴影；先测滚动帧时间、GPU overdraw、低端设备内存。动画优先改轻量层属性，避免每帧重建大阴影蒙版。
- 阴影在外层绘制，内容在内层 clip；外部父容器若先 clip，仍会截断阴影。留足外部间距，注意 Lazy 列表/滚动 viewport 裁剪。
- 平台 elevation 阴影随 Android/设备渲染可能不同；`dropShadow` 参数式阴影也不保证等于 APK 自有实现。
- 文字对比度、触摸目标、TalkBack、动态字体、深色模式均需单独验证。装饰边缘不能代替控件语义。

## 验证状态

只进行了 API/源码核对与静态文本检查；**没有 Kotlin 编译、布局渲染截图或设备性能测试**。执行环境未发现 kotlinc/Gradle/常见 Android SDK。`validate_ui_reference.py` 的10项静态文本检查通过，见 `validation.txt`；这不代替编译、渲染或性能测量。交付不是已验证的生产控件。

## 官方参考

- [Compose shadows：elevation 与 radius/spread/offset 的区别](https://developer.android.com/develop/ui/compose/graphics/draw/shadows)
- [Compose Brush：渐变与 SolidColor](https://developer.android.com/develop/ui/compose/graphics/draw/brush)
- [Graphics modifiers：drawWithCache](https://developer.android.com/develop/ui/compose/graphics/draw/modifiers)
- [Compose blur：模糊 API 与平台限制](https://developer.android.com/develop/ui/compose/graphics/blur/overview)
- [Compose UI 1.9 版本记录](https://developer.android.com/jetpack/androidx/releases/compose-ui)
- [Shadow 参数类源码](https://raw.githubusercontent.com/androidx/androidx/androidx-main/compose/ui/ui-graphics/src/commonMain/kotlin/androidx/compose/ui/graphics/shadow/Shadow.kt)

这些文档用于解释公开 API，不用于证明 ChatGPT 用了某种特效。APK 候选证据见 [UI边缘质感补充报告](../ui-report/UI边缘质感补充报告.md)；不要把静态可达实现等同于用户当前屏幕实际启用效果。
