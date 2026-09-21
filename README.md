# 破败教堂探索解谜：代码整理版

整理日期：2026-09-21。Godot 4 / GDScript。

这是根据当前对话整理的代码基线，不是从本地项目完整导出的版本。玩家美术、地图、SpriteFrames 等仍使用自己的项目资源。没有凭空加入尚未完成的存档、耐力、圣物或结局系统。

## 文件

- `scripts/player.gd`：玩家完整控制脚本。
- `scripts/prayer_statue.gd`：祈祷范围、启用开关、祈祷事件。
- `scripts/climb_chain.gd`：可调长度/宽度、上下挂件、攀爬范围。
- `scenes/chain.tscn`：锁链空素材模板，导入图片后使用。
- `scenes/prayer_statue.tscn`：雕像空素材模板，原点在雕像脚下。
- `tests/regression.gd`：不依赖正式美术的自动回归检查。

把 `scripts`、`scenes` 放到现有项目的 `res://` 下，保留这些路径。先备份旧玩家脚本；若已存在同名类，替换旧脚本，不要让项目内同时存在两个 `class_name ClimbChain`。

## 已实现行为

- 左右行走、跑步、仅地面普通起跳、空中水平控制。
- `jump` 播放一次后保持末帧；直接走出边缘时显示末帧。
- 从本次空中最高点到落地的实际下降距离区分落地动画。
- `fall lower` 播完恢复活动；`fall higher` 播完保持末帧并发出事件。
- 地面且处于雕像范围内按祈祷键跪下，保持末帧，再按相同键起身。
- 地面/跳跃中在链条范围按 Z 抓取；无上下输入保持 `climb` 第0帧。
- ↑↓持续输入且实际移动才循环攀爬；到端点或受阻时暂停第0帧。
- 攀爬中按跳跃离链，`jump` 从第0帧重新播放，可配合左右键。
- 下爬接触地面自动放手。抓链会清除之前的坠落累计，离链后重新计量。

## 玩家节点和美术

玩家根节点必须是 CharacterBody2D，挂 `player.gd`，直接子节点包括：

| 名称 | 类型 | 设置 |
|---|---|---|
| AnimatedSprite2D | AnimatedSprite2D | 赋值 SpriteFrames，也可拖给根节点 Animator 属性 |
| CollisionShape2D | CollisionShape2D | 按站立角色建立有效碰撞体 |
| ClimbGrip | Marker2D | 放在 climb 未翻转的第一帧双手握持位置 |

`ClimbGrip` 必须在玩家根节点下面，不是锁链下。攀爬时固定使用未翻转的原始帧以保证握点一致；不自动改变玩家碰撞体。角色根节点保持 scale=(1,1)。

动画名称必须逐字一致（含空格）：

| 动画 | 循环 |
|---|---|
| idle / walk / run / climb | 是 |
| jump / kneel_down / stand_up / fall lower / fall higher | 否 |

脚本自动设置循环；动画帧和速度仍在 SpriteFrames 编辑器设置。climb 使用你的两帧，建议先4 FPS。所有动画至少一帧。

## 输入映射

项目 → 项目设置 → 输入映射，添加以下动作。已有动作保留原绑定，下面只是建议：

| 动作名 | 建议按键 |
|---|---|
| left | A 或 ← |
| right | D 或 → |
| run | Shift |
| jump | 空格 |
| pray | E |
| climb_grab | Z |
| climb_up | ↑ |
| climb_down | ↓ |

不要让 `pray` 和 `climb_grab` 共用按键。Z 是按下一次抓住，不是按住持续抓取；跳离后需重新按下Z，并等待默认0.15秒再次抓取间隔。

## 锁链场景

`Chain` 根节点为 Area2D，挂 `climb_chain.gd`，直接子节点名称大小写必须一致：

- TextureRect
- CollisionShape2D
- TopCap（Sprite2D）
- BottomWeight（Sprite2D）

在根节点设置 Chain Texture（中段）、Top Texture（顶部）、Bottom Texture（配重）。不要只给子节点 Texture 赋值，刷新时会被根节点参数覆盖。上下挂件可留空。

| 参数 | 初始值 | 含义 |
|---|---:|---|
| Length | 304 | 可攀爬中段长度，不含两端挂件 |
| Chain Width | 30 | PNG显示宽度，包含透明留白 |
| Detection Width | 48 | 抓取检测宽度，独立于视觉宽度 |
| Top / Bottom Overlap | 4 | 配件遮住中段连接处的距离 |
| Top / Bottom Offset X | 0 | 配件水平微调 |

用上下可以无缝重复的短段 PNG。30×38素材可用38的整数倍长度；非整段长度会截断末尾。修改长度通过Tile重复，不拉长链环。宽度通过横向缩放，保持原宽或整数倍才可避免像素列宽度不均。脚本使用Nearest，无平滑混色。

裁掉挂件PNG多余透明留白。配件保持原尺寸，不随中段宽度缩放。不要手动拖子节点修正位置，刷新会覆盖，应使用Overlap和Offset参数。

场景根节点和地图父节点 scale=(1,1)、rotation=0；把锁链场景原点放在中段顶部挂点。顶部留侧向跳离空间，平台不要封死竖井。当前没有自动攀上/翻越平台功能。

## 雕像场景

根节点为 Area2D，挂 `prayer_statue.gd`。Sprite2D放雕像图片，CollisionShape2D设置互动范围。模板以地面为原点，图像中心在y=-90；按实际素材调整。

脚本自动加入 `prayer_spot` 分组；锁链自动加入 `climb_chain` 分组。已有纯Area2D雕像若手动加入 `prayer_spot` 也兼容，但不会发出新雕像脚本的事件。

雕像事件：

- `prayer_started(player)`：开始跪下。
- `prayer_completed(player)`：跪下动画结束，每次祈祷一次；保持跪姿不重复触发。
- `prayer_ended(player)`：起身完成，或外部重置中止祈祷。

在Godot信号面板连接 `prayer_completed` 到门/谜题控制器即可。脚本不预设真神/邪神奖励，不会自动生成圣物或存档。

## 碰撞设置

示例约定玩家 Collision Layer 第1层；地形第2层，玩家Mask包含地形第2层。雕像和锁链 Collision Layer=0，Mask勾选玩家第1层，Monitoring开启。若项目已有其他分层，按实际玩家层修改Mask。Area2D只检测，不挡玩家。

## 落地阈值和后续传送

玩家导出 `lower_fall_height=80`、`higher_fall_height=260`，单位像素。确保 higher 大于 lower。小于 lower 直接恢复普通活动。默认跳跃理论升高约66.7像素，因此同高度正常起跳落地不会播放低落地动画。

高落地完成发出 `high_fall_finished`，人物留在FAINTED状态。需要外部房间控制器连接该信号，决定是否传送。目的地与惩罚规则尚未实现。外部移动角色到安全复活点之后调用 `player.reset_to_normal()` 清除锁定和坠落累计。跨场景传送应由场景管理器处理，新玩家节点会重新初始化。

保持重力在落地/祈祷锁定中生效。静态平台为当前基线；移动锁链、移动平台上的特殊祈祷和改变碰撞体大小不包含在本版。

## 接入检查

1. 玩家能站立、走跑、起跳；空中不会被walk/run覆盖。
2. 走出边缘显示jump末帧；低/高坠落按检查器阈值播放。
3. 雕像内按E跪下，动画中重复按键无效；跪稳后按E起身。
4. 地面和空中均能按Z抓链，松开↑↓显示第0帧。
5. 左右+跳跃可离链，jump从第0帧开始。
6. 抓链后再跳离落地不会沿用抓链前的坠落距离。
7. 长度变化配重只沿Y移动；顶部X/Y固定；第二个锁链实例不受影响。
8. 灯光、素材导入和人物碰撞体在你的实际项目里再做一次目视检查。

## 待实现

耐力消耗与恢复、存档、七件圣物与记忆、单向门条件、谜题选择、惩罚房间传送、结局判定、NPC和机关逻辑。这里只预留了祈祷与高落地事件。

## 验证结果与运行方式

此仓库的 `project.godot` 仅用于导入脚本、验证模板，不含正式游戏主场景。不要用它覆盖你原有项目的 project.godot。

已在 Godot 4.4.1 headless 下通过编辑器导入和自动回归检查（0失败）：锁链实例尺寸独立、挂件定位、空中抓链、上爬/松键、离链jump、祈祷完成单次事件、晕倒单次事件/末帧、复苏状态清理，以及实际物理下落的两档落地动画选择。未替代你的实际角色帧、关卡碰撞和相机下的人工验证。

先用Godot打开此目录导入，或执行：

```bash
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/regression.gd
```

自己的游戏通常只需复制 `scripts/` 和需要的 `scenes/`，按上面的说明绑定角色资源与输入。
