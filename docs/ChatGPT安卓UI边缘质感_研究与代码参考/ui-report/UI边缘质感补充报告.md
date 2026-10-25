# ChatGPT Android UI边缘质感：可学到什么，哪些已取证

样本仍为用户提供的1.2026.293。深度分析在云端完成，未安装运行APK，未继续依赖用户电脑。用户只描述“边缘的光泽感”，**尚无截图，因此下面是可证实实现和候选，不声称已找准用户指的那一处**。

## 最重要的结论

已找到真实业务使用的三类手法，不能全叫“Liquid Glass”：

1. **细实色描边 + 柔阴影 + 半透明表面**：输入栏和共享ElevatedContent的确定路径，最适合先学。
2. **白色亮边 + 半透明白填充 + elevation**：Pro引导卡片确定使用，视觉更像亮边卡片，但不应当作主聊天UI的唯一解释。
3. **背景采样 + blur + tint/noise**：Haze确实在局部业务使用，例如代码视口渐变模糊、Google连接器引导面板；成本和接入条件不同于一条border。

本次未取得足以证明“主界面通用边缘光泽是折射shader/gradient stroke/inner shadow”的调用证据。没有找到不等于全包不存在，尤其包内还有原生/Valdi渲染和动态资源。

## 优先学习：主输入栏

已闭环：`ModularComposerContentWrapperImpl → xrd0.b/i → to60.c/d/e(ElevatedContent)`。

|层|实际参数|
|---|---|
|形状|24dp圆角|
|表面|普通浅色白 / 深色#303030，alpha .97|
|轮廓|1dp，同主题原底色，alpha倍率1；**实色描边**|
|外阴影|黑色alpha .15，blurRadius50dp|
|降级参数|极大区域RenderNode fallback elevation1dp；不是阴影Y偏移|

这意味着可以先重建“近不透明内表面 + 更实的细边 + 宽柔影”，不需要背景采样，也不需要将所有东西blur。

其AGSL确为圆角SDF**外阴影**：减去实体内部mask，只留外halo；没有纹理折射、法线或镜面光照。代码里出现RuntimeShader，不能直接翻译成玻璃效果。

## 共享Surface、顶栏与主题

共享ElevatedContent通常在light画shadow、dark画细边；调用者可强制两者。
- 默认边宽0.5dp；普通dark基础边色#26FFFFFF，约14.9%白，再乘调用者alpha。
- 普通light的基础边色是#1A000000，但默认light分支不画它，除非强制。
- Composer是上表的1dp同色边特例，不能误用默认白15%边。
- ConversationTopBarPill也是实际消费者。其mode=3另有night/day不同阴影alpha、90dp blur和0.3dp描边的条件策略，详见《输入栏与共享Surface证据》。**缺少截图及实际mode，不能指定所有顶栏按钮都用这一组。**

侧栏/所有悬浮按钮在此轮尚未定位到足够具体的配方，不用Pro卡片参数冒充。

## 更明显的亮边候选：Pro引导卡片

|组件|已证实配方|
|---|---|
|ProIntelligenceArtwork|56dp高、胶囊圆角；白70%填充；1dp白55%边；12dp elevation|
|ProWorkConnectorCard|80dp方形、20dp圆角；不透明白填充；1dp白55%边；6dp elevation|

ProIntelligenceArtwork的内层另有横向紫渐变 `#FF9639ED → #FFA25BFF`。**渐变是内部背景，不是那条1dp描边。** 这类是低成本“亮边”学习例子，必须标为Pro引导场景，而非用户未提供截图的目标复现。

## 真正毛玻璃的适用范围

已追到Haze业务modifier：
- GoogleConnectorsNuxBottomSheetContent：引导面板内容采用Haze。
- CodeViewportBlur：代码视口有69dp高渐变模糊区域。

Haze会采样内容并做Gaussian blur，再结合mask、tint、噪声。主输入栏上述外阴影路径并不等于Haze路径。若做原创实现，应明确分成两个示例：
- 不采样背景的border/shadow surface，易接入；
- 确需透出背后内容的Haze/blur surface，需提供可采样背景、裁剪与性能降级。

另外，图片placeholder的六色mesh、OrbitVoice动态背景、loading shimmer均有真实业务调用，但不是静态边缘高光的同义词。

## 学习/移植建议

先将组件拆成形状、填充、轮廓、外阴影四层，分别开关对比；深色先验证细边，浅色先验证柔影。不要一开始就堆blur/渐变，以免掩盖真正起作用的轮廓对比。

参数抄到原创示例时应保留单位：blurRadius不是elevation，dp不是px，颜色alpha和总体透明度不同；不同渲染器的50dp阴影未必像素级相同。原生dropShadow重建可用于学习，但不能在未做截图对比时宣称像素级复现。

要将候选收敛为用户想学的组件，最有价值的下一份证据是一张指出边缘位置的截图（输入栏、顶栏按钮、卡片或弹层）及浅/深色状态；动态扫光再补短录屏。无需账号/敏感内容，可以遮掉聊天文本。

## 交付与证据

本目录只保留中文重述、短方法定位与小型调用清单，不交付完整商业反编译源码。配套：
- 输入栏与共享Surface证据.md
- edge-findings.md：卡片与shimmer的数值/适用范围
- shader-findings.md：6处直接RuntimeShader构造分类、Haze实际消费者
- UI关键调用边.tsv / runtime-shader-constructors.tsv

所有结论限静态可达实现；设备、远端实验、主题覆盖和用户具体屏幕尚未动态验证。
