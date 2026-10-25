# RuntimeShader / AGSL / Haze 静态核验

样本：com.openai.chatgpt 1.2026.293 用户提供的 APK。只读静态分析，未运行安装、未读取账号数据。原始类名已混淆，不把一个 `defpackage` 类归为单一库：R8 合并工具类后，同类不同方法可能来自不同组件。源码仅用于短定位，不在报告复制 shader 全文。

## 结论先行

APK 确有多种 AGSL，但**不能据此认定用户所指某处边缘光泽就是玻璃折射**。查到的 Composer/ElevatedContent shader 是圆角矩形**外阴影**；图像 mesh shader 是彩色流动占位背景；OrbitVoice shader 是语音背景；Haze 是毛玻璃/渐变模糊并确有业务使用。与父分支已确认的实色细边框叠加，足以构成“悬浮边缘/柔光”观感，但没有截图和动态证据，不把这套推断等同用户具体目标。

## 全 DEX RuntimeShader 构造清单

`ui-report/runtime-shader-constructors.tsv` 从9个DEX调用索引提取，共6个直接构造 callsite（非反射/原生动态构造完整证明）：

|DEX / 方法 / 偏移|作用|业务采用证据|
|---|---|---|
|classes.dex `x2y.a @0x8`|圆角矩形外阴影 SDF|`y2y.get → a3y.a → lim.k → zep`，父分支已追到 Composer 的 `xrd0.i → to60.c/d/e`|
|classes2 `wl.d @0xca`|OrbitVoice 动态着色背景|`wl.c` 有明确 UI 标记 OrbitVoiceBackground；`mli0.d → qki0.invoke @0x466 → wl.c`|
|classes2 `wl.f @0x18`|模糊内容 + soft-light 噪声 + tint|Haze渲染链 `a8f0.l @0x52c → wl.f`，并有下文实际业务 Haze modifier|
|classes2 `wy9.a @0x8`|6色动态 mesh gradient|`qcc0.a @0x28a → wy9.a`；`dj81.c` MessageImageFractionalMeshGradient，`zr81.b` ImagePlaceholderMeshGradient|
|classes2 `wy9.b @0x4`|通用 String shader factory|`l1u0 → c8l0`，本样本实际字符串来源 `kdn0.a(boolean)` 的Haze横/纵渐变高斯模糊|
|classes2 `wy9.e @0x8`|球体/足球图形shader|`xsv0.get` 明确错误标签 SoccerBall；属于装饰图形，不是通用组件边缘高光|

## 1. 外阴影 shader：最接近 Composer 边缘的已证实链

`x2y.a` 的 uniforms 为 `uBoxBounds`、`uCornerRadii`、`uBlurRadius`、`uShadowColor`。`jd2.a(duo0,pit0,float,long)` 分别写入上述四组参数；四角 radius 独立，并被约束在半尺寸以内。

算法梳理（解释，不是商业源码复制）：
1. rounded-box SDF 算像素到圆角边界的有符号距离。
2. 将传入 blur radius(px) 按 Skia/HWUI关系换算 `sigma = 0.57735 * radius + 0.5`（radius=0另分支）。
3. 用误差函数近似 Gaussian CDF，计算边界覆盖，同时用横纵矩形高斯区间覆盖限制。
4. 减掉实体内部 hard mask，夹至非负，得到**只在外侧的halo**；内部透明，不把内容内部压暗。
5. 乘 shadow color alpha，输出 premultiplied RGBA。

**没有**在这段shader中看到背景纹理采样、法线、光源方向、折射坐标偏移、动态扫光。白色阴影可以视觉像光晕，但“白/黑颜色与透明度”属于调用参数，不能把算法命名为玻璃高光。`a3y.a` 有 API>=33 与禁用条件，并从 ThreadLocal cache 获取shader，失败/不可用返回null交给调用者选择fallback。

父分支已追 Composer → ElevatedContent 的实际应用和 shadow/border参数；本分支只核验shader本体和uniform映射。

## 2. Haze：不只是依赖，确实用于业务

库归属证据：`rm01` Kotlin Metadata module为 `haze-root:haze`，其 create()创建 `f930`；`h7r0` 抛明确 `dev.chrisbanes.haze.RuntimeShaderRenderEffectException`。`a8f0` 部分方法 trace标签为 HazeBlur-createRenderEffect / HazeEffectNode-getOrCreateRenderEffect。

实际应用：
- `hf81.c`，UI标记 **GoogleConnectorsNuxBottomSheetContent**，约209–216行构造 `h930` source，调用 `gi81.f(...,t830.a(...),m930.c)`，不是仅声明依赖。
- `sqi.b`，UI标记 **CodeViewportBlur**，约799–830行：宽度填满、高69dp的mask区域，构造透明度渐变tint与progressive mask，并经 `gi81.f` 装载。style callback明确传入 `g(10.0f)`（dp包装类型）、`i(0.0f)`；为避免混淆字段误名，具体style属性名需结合完整setter解释，不直接把所有float叫blur。
- DEX另有 `ngu0.e`、`np81.m`、`ux90.invoke`、`w56.invoke` 调用 `gi81.f`，本分支不为尚未恢复的业务名称猜页面。

库shader细节：`kdn0.a(boolean)` 构造横/纵 separable Gaussian blur，uniform为content、blurRadius、crop、mask。radius按mask alpha在0与blurRadius间插值；上限循环常量150；sigma=max(radius/2,1)。源码内保留Haze issue 520指向，增强库归属证据。`wl.f` 对模糊结果叠soft-light噪声并合成tint；noiseAlpha clamp[0,1]。这是毛玻璃噪声/模糊质感，不是法线反射边缘。

## 3. Mesh 与 OrbitVoice：避免误判背景为边缘shader

`wy9.a`：6个color uniform、uSize/uTime/uBlend/uSaturation；6个二维中心随sin/cos运动，按到中心距离指数衰减权重混色，最后按亮度混合饱和度，输出alpha恒1。没有内容纹理采样或圆角边缘SDF。`hh2.a`写uniform，`qcc0.a`在API33+创建，失败/不可用走`br81.c` fallback。

可读业务调用：`dj81.c:235` **MessageImageFractionalMeshGradient** 与 `zr81.b:88` **ImagePlaceholderMeshGradient** 均传入2.0f、12.0f和动态float；本分支未完整追动画时间缩放，不把这两个值擅自同时标成shader blend/saturation。底层uniform名与传入顺序已见`ui-evidence/hh2-debug.java`。

`wl.c/d/e`：**OrbitVoiceBackground**，API33分支；shader输入size/tint/motion，motion为时间秒的sin，频率系数0.11、0.073、0.089、0.057。它是整个背景的低频场，不是围绕组件轮廓的gloss border。

## 可复现定位与限制

- 原始调用索引 `evidence/dex-call-index.tsv`；本分支最小构造清单 `ui-report/runtime-shader-constructors.tsv`。
- 补充反编译 `ui-evidence/qcc0-debug.java`、`wl-debug.java`、`kdn0-debug.java`、`hh2-debug.java`。部分单DEX反编译缺跨DEX类型，遇到占位应按DEX指令而非伪Java异常解读。
- 结论是静态“存在且有业务调用路径”，不保证用户设备/账号/功能开关实际执行此分支。
- 本清单覆盖直接Java RuntimeShader构造；不排除原生引擎、远程资源、Compose brush/gradient、普通stroke或系统渲染制造边缘观感。用户未指定哪一处边缘，因此不做唯一归因。
