# 铭牌阅读接入教程（Godot 4）

行为：站在地面、靠近铭牌按Z打开；再按Z关闭。阅读时暂停角色移动、跳跃、攀爬输入和镜头上下观察，世界其他物体继续运行。离开铭牌范围后Z仍用于祈祷；已跪下时Z仍优先起身。X抓链/跳跃、Shift奔跑、V全屏逻辑沿用原版。

本版替代对话中的临时脚本。不要再添加旧版 `_unhandled_input()` 阅读代码，不需要玩家的 `reading_ui` 导出属性，不需要手动连接 `body_entered/body_exited`。新版玩家只在 `_physics_process` 中统一处理Z一次。

## 1. 导入文件

将这些文件按同样目录放到项目根目录（Godot中的res://）：

- scripts/player.gd：完整替换现有玩家脚本内容，保留玩家节点与Animator资源。
- scripts/interactions/reading_plaque.gd：铭牌脚本。
- scripts/ui/reading_ui.gd：文字框脚本。
- scenes/interactions/reading_plaque.tscn：已配置好的铭牌场景。
- scenes/ui/reading_ui.tscn：已配置好的文字框场景。
- assets/interactions/reading-plaque-pedestal.png：地图装置。
- assets/ui/eldritch-reading-panel.png：邪神眼睛石板阅读框。

如果你的玩家脚本存在其他目录，把新版player.gd的完整内容替换进原文件即可，不要在同一项目保留两个class_name GamePlayer。原有climb_chain.gd、prayer_statue.gd及房间和窗口脚本继续保留。不要用仓库的project.godot覆盖你的正式项目设置。

## 2. 注册一次全局阅读框

打开“项目 → 项目设置 → 全局（Global）→ 自动加载（Autoload）”。部分Godot 4版本直接显示Autoload页签。

路径选择 `res://scenes/ui/reading_ui.tscn`，名称填写 `ReadingUI`，点击添加，并保持启用。

必须添加场景tscn，不是reading_ui.gd脚本。大小写必须一致。整个游戏只注册一次，不要再往玩家或各房间拖入ReadingUI。

它默认隐藏，显示时位于CanvasLayer第50层，房间淡出黑幕第100层仍在它上方。跨场景不会被删除，因此已读ID也能跨房间保留。

## 3. 放置地图铭牌

打开D房间或测试房间，把 `scenes/interactions/reading_plaque.tscn` 从文件系统拖入房间场景。它的根节点是Area2D，脚本不能挂到Sprite2D上。

移动ReadingPlaque根节点到地面。模板原点对齐装置底部，Sprite2D已偏移y=-60；图片是128×144，实际装置高120像素。优先保持实例与父节点Scale=(1,1)。

节点结构：ReadingPlaque(Area2D)下有Sprite2D与CollisionShape2D。检测矩形默认180×160，中心在(0,-70)，用于靠近检测，不会阻挡玩家。碰撞形状已设置每个实例独立，可在具体房间“可编辑子节点”后调整。

## 4. 每块铭牌填写不同文字

选中房间中的ReadingPlaque根节点，在检查器中填写：

| 参数 | 示例 | 作用 |
|---|---|---|
| Enabled | 开启 | 是否允许阅读 |
| Clue Id | water_old_ritual | 供机关检查的唯一线索ID；英文、数字、下划线 |
| Inscription Title | 旧渠维护记录 | 阅读框标题 |
| Inscription Text | 在多行框里输入正文 | 阅读内容，可直接回车换行 |

第一块可填写正文：

> 旧渠仍通。\n转动下层水阀，待池底水纹显现，\n再于旧像前祈祷。

上面的\n代表换行。在检查器里直接按回车即可，不必输入反斜杠字符。

不同内容实例使用不同Clue Id；同一条线索放在多个房间时，可以共用ID。Clue Id留空仍能阅读，只是不记录为解谜线索。不要去UI场景的Body里为每块铭牌改文字，正文由铭牌实例传入。

## 5. 检查碰撞层

模板假定玩家Collision Layer第1层。铭牌Collision Layer全关闭，Collision Mask只勾玩家所在层，Monitoring打开，CollisionShape2D的Disabled关闭。

若玩家在第3层，就把铭牌Mask改为第3层。读取检测是Area2D.overlaps_body，只看碰撞范围，不是美术图片是否重叠。新版不要求player分组，也不要求手工连接信号。

运行游戏后可启用“调试 → 可见碰撞形状”，确认玩家身体碰撞体与铭牌检测矩形重叠。

## 6. 调整阅读框

打开 `scenes/ui/reading_ui.tscn`，修改根节点导出属性并保存。根CanvasLayer默认Visible关闭，运行时由脚本显示。编辑预览时可临时勾选。

节点关系：ReadingUI(CanvasLayer) → Root(Control) → Panel(TextureRect)；Title(Label)、Body(RichTextLabel)、Hint(Label)都是Panel的子节点。

| 根节点参数 | 默认 | 用途 |
|---|---|---|
| Preferred Size | 768×512 | 阅读框最大显示尺寸 |
| Screen Fraction | 0.90 | 不超过视窗宽高的90%，保持比例自动居中 |
| Font Size | 22 | 字号随框缩小，最低14 |
| Text Font | 空 | 可拖入项目中支持中文的ttf/otf字体 |

约800×450视窗中，框会自动缩为约607×405。摄像机Zoom不影响UI尺寸。Panel使用Nearest；非整数缩放可能出现像素粗细变化。如需严格1:1显示，可把Preferred Size设为(384,256)，正好是素材的一半。

正文使用RichTextLabel，支持换行与鼠标滚轮滚动。文字长时，鼠标放在正文区域滚到底，提示变为“Z关闭”。只有全部文字至少显示到末尾并主动按Z关闭，才登记已读；中途也能关闭，但不会解锁线索。

中文显示方块时：把有使用授权的中文字体复制到项目，例如res://fonts/，然后拖到ReadingUI根节点的Text Font。推荐短线索约40～100字，避免过长滚动。文本没有强制阅读计时。

## 7. 操作测试

1. 正常运行房间；初始应看不到阅读框。
2. 玩家在地面靠近铭牌，按一次Z，框显示标题与正文，角色站立。
3. 不松开Z，不应重复开关。
4. 阅读中按左右、X、Shift或上下，不应移动、跳跃或触发镜头观察。
5. 松开后再按一次Z，关闭；这次Z不会同时触发跪拜。
6. 走出铭牌范围，靠近神像，Z仍可跪下和起身；锁链功能照旧。
7. 完整阅读后切房再回来，ReadingUI.has_read("water_old_ritual")仍为true。

多个铭牌检测区重叠时优先最近的一块；雕像与铭牌范围重叠时普通站立Z优先阅读。正在跪下、跪姿、起身、攀爬、下落/落地或晕倒期间不会打开铭牌。建议实际摆放时适度分开雕像与铭牌检测区。

## 8. 给后续机关查询

在机关脚本中用以下条件检查，不需要查找D房间里的铭牌节点：

```gdscript
if not ReadingUI.has_read(&"water_old_ritual"):
    # 在这里显示“你还不明白机关上的刻痕”等反馈，并结束本次交互。
    return
# 在这里执行允许触发的机关逻辑。
```

这里只提供查询接口，没有替你增加水阀或圣物判定。ReadingUI.clue_read(id)信号只在第一次登记新线索时发出。

当前记录仅在本次游戏运行中跨房间保留，退出游戏后丢失。后续存档可保存ReadingUI.export_read_clues()，读档调用ReadingUI.import_read_clues(ids)；新游戏调用ReadingUI.reset_progress()。不会偷偷自动保存游戏。

## 故障排查

- 报找不到ReadingPanel/ReadingPlaque：确认两份配套脚本已导入且无解析错误；等Godot扫描完成，不只替换player.gd。
- 提示阅读框未配置：检查Autoload路径为tscn，名称ReadingUI，启用且只存在一次。
- 按Z没反应：确认站在地面且普通状态、铭牌Enabled/Monitoring开启、Mask包含玩家层、碰撞体重叠。
- 打开就关闭或同时跪拜：删掉之前额外粘贴的阅读_unhandled_input代码/旧输入监听，只使用本版完整player.gd。
- 图不显示：不要改动包内assets路径；检查贴图资源未丢失。
- 文字超框：使用提供的Body节点结构，正文支持滚动；勿开启Fit Content让其无限增高。

本模板用Godot 4验证，不含你的完整正式地图和人物美术；在正式地图中检查摆放高度、碰撞层和字体显示。
