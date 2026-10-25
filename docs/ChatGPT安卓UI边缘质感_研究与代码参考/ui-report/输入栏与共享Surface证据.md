# 输入栏、顶栏与共享Surface：静态证据

## 1. 真正的输入栏调用

`xrd0.h` 有 `ModularComposerContentWrapperImpl` 标记，嵌套内容经`xrd0.b`调用`xrd0.i`（classes5.dex @0xd3c）；`xrd0.i` 为其 `Surface`，再调用`to60.c`（ElevatedContent）→`to60.d/e`。

它并非只在库里声明一个通用surface：调用者就是本APK的Composer业务包装。仍不能保证用户当前启用的所有输入栏变体都走该分支。

### 已还原参数

|参数|证据值|说明|
|圆角|24dp|xrd0.i 的q1r0.b(24f)|
|填充|主题palette.c.a，alpha=.97|原始普通light=#FFFFFFFF，dark=#FF303030；特殊palette不能按这两个概括|
|描边|1dp，原palette.c.a乘alpha1|同色实色边界；不是SweepGradient/LinearGradient；在97%内填充之外形成更实的轮廓|
|阴影颜色|黑色，alpha=.15|r0n.b=#FF000000；sit0.j按alpha重组|
|阴影blurRadius|50dp→density换算px|flx.a及dit0路径读取sit0.d；不是50dp elevation|
|额外参数h=1|特大区域fallback的RenderNode elevation=1dp|不是offsetY；常规DropShadowPainter/AGSL路径不应把它当位移|
|主题开关|强制light/dark都可画shadow和border|ly5.b默认掩码260，a()/b()均true|

边框的1dp从 `sit0.g()` → `jm01.j(width,color,shape)` → `jm01.k` → `ty9`；Brush是`xtv0`（SolidColor）。`c6n.a`将基础颜色alpha乘倍率，Composer此倍率为1，不是渐变stop。

## 2. 共享ElevatedContent的明暗策略

`to60.e`：
- `jm01.R`明确检查Android Configuration.uiMode是否night。
- 非None的shadow参数：light通常画shadow；dark只有 `sit0.b()` true才画。
- 描边：dark通常画；light只有 `sit0.a()` true才画。
- 没有自定义border color时用theme `q5n.d.a`；没有自定义width时 `sit0.g()=.5dp`。
- 普通dark palette该默认边色为 `#26FFFFFF`（38/255=14.9%白）；light palette为`#1A000000`（26/255=10.2%黑），但默认light分支不画，除非force。
- 颜色最终还乘 `sit0.e()`；不能对一个opacity为0或自定义倍率的调用者机械写“15%白边”。
- Composer正是覆盖为1dp、同背景原色、倍率1的特例，不能误用shared默认白15%边。

`to60.c`缺省shape/shadow与各业务传参独立。shadow预设`None`与小/大值均存在；不是每个Surface都画同一阴影。

## 3. 顶栏胶囊是真实消费者，但有mode差异

`sm5.A` 的ConversationTopBarPill组件路径 → `u1s.a` → `crq0.b`；另一个业务调用者 `wuq0.c` 在DEX @0x4e4直接调用`crq0.b`。`crq0.b`保留`TopBarPill`标记，@0x398调用`to60.c`。

普通模式使用传入的sit0，不应猜它一定是哪种预设。
当`crq0.b`的mode整数参数为3时明确覆盖：
- shadow alpha：night .5 / day .3；
- blurRadius：通过ly5.b掩码258取默认90dp；
- shadow/border色：来自fsq0.c得到的主题pill色，而非可统一写死白或黑；
- border width .3dp、border alpha倍率 .2；
- force shadow及border均true。

因此顶栏也有“薄边+柔阴影”的可复用机制，但**尚未从用户截图锁定其mode**，不能将此条件分支说成每个主界面按钮的参数。此轮没有充分证据为侧栏/所有悬浮按钮指定唯一边光配方。

## 4. 外阴影与毛玻璃不能混淆

Surface shadow modifier `afp → zep → lim.k`：可用时选`dit0` + `jd2` RuntimeShader，否则`flx`（Compose DropShadowPainter等fallback）。shader是圆角SDF外阴影，内部mask清零、无背景纹理采样，无折射或法线高光。详见shader-findings.md。

“1dp更实轮廓 + 97%表面 + 大半径黑影”可能在图像上形成光泽/浮起感，这是机制解释，不是已认定用户所指。真正毛玻璃需要背景内容采样与blur，已另追到Haze的具体业务场景。

## 稳定定位

- classes5.dex `xrd0.i`：q1r0.b @0x324；to60.c实际invoke见选取的DEX边文件。
- classes2.dex `to60.e`：0x1a4装shadow modifier，0x242装实色border。
- classes.dex `ly5.b`：参数/default mask；`rit0`和` sit0`各getter。
- classes3.dex `flx.a/b`：blur dp转px及特大区域fallback elevation语义。
- classes.dex `lim.h/l`：普通dark/light palette常量；R8类名不代表原始源码名。
- 工作区内 `ui-evidence/{lim,flx,crq0}-debug.java` 和前一阶段 `evidence/to60-debug.java` 供内部复核，**完整反编译类不随报告交付**。

分析仅静态，未运行APK或用户电脑；原始Kotlin名称、动态实验和主题覆盖仍受混淆/未运行限制。
