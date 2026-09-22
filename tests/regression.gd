extends SceneTree
## 运行：godot --headless --path . --script tests/regression.gd
var failures: int = 0
var severe_events: int = 0
var prayer_events: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func texture(width: int, height: int) -> ImageTexture:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)

func make_player() -> GamePlayer:
	var player := GamePlayer.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 100)
	collision.shape = shape
	player.add_child(collision)
	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.sprite_frames = SpriteFrames.new()
	for name in ["idle", "walk", "run", "jump", "climb", "kneel_down", "stand_up", "fall lower", "fall higher"]:
		sprite.sprite_frames.add_animation(name)
		sprite.sprite_frames.add_frame(name, texture(4, 4))
		sprite.sprite_frames.add_frame(name, texture(4, 4))
	player.add_child(sprite)
	player.animator = sprite
	var grip := Marker2D.new()
	grip.name = "ClimbGrip"
	grip.position = Vector2(0, -35)
	player.add_child(grip)
	return player

func _run() -> void:
	# 从没有任何游戏输入动作开始，复现直接复制脚本的场景。
	for action in ["left", "right", "run", "jump", "pray", "climb_grab", "climb_up", "climb_down", "fullscreen"]:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
	var chain_scene := load("res://scenes/chain.tscn") as PackedScene
	var chain := chain_scene.instantiate() as ClimbChain
	root.add_child(chain)
	chain.chain_texture = texture(30, 38)
	chain.top_texture = texture(20, 24)
	chain.bottom_texture = texture(26, 32)
	var top := chain.get_node("TopCap") as Sprite2D
	var bottom := chain.get_node("BottomWeight") as Sprite2D
	var top_before := top.position
	var bottom_x := bottom.position.x
	chain.length = 608
	check(top.position == top_before, "长度变化不能移动顶部")
	check(bottom.position.x == bottom_x, "长度变化不能移动配重X")
	check(bottom.position.y == 604, "配重Y跟随长度")
	var shape := (chain.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	check(shape.size.y == 698, "检测高度包含上下余量")
	var sensor := chain.get_node("CollisionShape2D") as CollisionShape2D
	check(sensor.position.y - shape.size.y / 2.0 == -30, "检测上边界包含上余量")
	check(sensor.position.y + shape.size.y / 2.0 == 668, "检测下边界包含下余量")
	var second := chain_scene.instantiate() as ClimbChain
	second.position.x = 1000
	root.add_child(second)
	check(second.length == 304, "其他实例长度独立")
	check((second.get_node("CollisionShape2D") as CollisionShape2D).shape != shape, "形状资源独立")
	var player := make_player()
	player.position = Vector2(0, 180)
	root.add_child(player)
	check(player.is_physics_processing(), "缺少旧输入动作不应停用玩家")
	player.set_physics_process(false)
	await physics_frame
	await physics_frame
	check(InputMap.has_action("fullscreen"), "自动建立全屏输入")
	check(InputMap.has_action("jump"), "自动建立共用跳跃/抓链输入")
	await process_frame
	key(KEY_RIGHT, true)
	player._physics_process(1.0 / 60.0)
	check(player.velocity.x == player.walk_speed, "真实右方向键移动")
	key(KEY_SHIFT, true)
	player._physics_process(1.0 / 60.0)
	check(player.velocity.x == player.run_speed, "Shift加速")
	key(KEY_RIGHT, false)
	key(KEY_SHIFT, false)
	key(KEY_LEFT, true)
	player._physics_process(1.0 / 60.0)
	check(player.velocity.x == -player.walk_speed, "真实左方向键移动")
	key(KEY_LEFT, false)
	player.position = Vector2(0, 180)
	await physics_frame
	await process_frame
	key(KEY_X, true)
	player._physics_process(1.0 / 60.0)
	key(KEY_X, false)
	check(player.state == GamePlayer.State.CLIMB, "进入攀爬状态")
	check(player.animator.frame == 0 and not player.animator.is_playing(), "抓链保持第0帧")
	await process_frame
	Input.action_press("climb_up")
	var old_y := player.position.y
	player._update_climb(1.0 / 60.0)
	check(player.position.y < old_y and player.animator.is_playing(), "上爬移动播放动画")
	Input.action_release("climb_up")
	player._update_climb(1.0 / 60.0)
	check(player.animator.frame == 0 and not player.animator.is_playing(), "松键回第一帧")
	Input.action_press("right")
	player.climb_horizontal_speed = 42.0
	player._update_climb(1.0 / 60.0)
	check(is_equal_approx(player.velocity.x, 42.0), "横移速度可调")
	Input.action_release("right")
	var held_x := player.global_position.x
	player._update_climb(1.0 / 60.0)
	check(is_equal_approx(player.global_position.x, held_x), "范围内松键悬停不强制回中")
	check(player.animator.frame == 0 and not player.animator.is_playing(), "范围内只横移保持首帧")
	Input.action_press("right")
	for step in range(ceili(2.0 / maxf(player.get_process_delta_time(), 0.001))):
		player._update_climb(player.get_process_delta_time())
		if player.state != GamePlayer.State.CLIMB:
			break
	check(player.climb_grip.global_position.x > 16.0 and player.state == GamePlayer.State.NORMAL, "右移越界自动松手")
	check(player.airborne and player.animator.animation == &"jump" and player.animator.frame == 1 and not player.animator.is_playing(), "横移脱离使用jump末帧")
	check(player.velocity.y == 0.0 and player.velocity.x > 0.0, "横移松手不施加起跳冲量")
	Input.action_release("right")
	player.position = Vector2(0, 180)
	player.force_update_transform()
	player._regrab_remaining = 0.0
	await physics_frame
	await physics_frame
	await process_frame
	check(player._try_grab_chain(), "复位后重新抓链")
	Input.action_press("left")
	for step in range(ceili(2.0 / maxf(player.get_process_delta_time(), 0.001))):
		player._update_climb(player.get_process_delta_time())
		if player.state != GamePlayer.State.CLIMB:
			break
	check(player.climb_grip.global_position.x < -16.0 and player.state == GamePlayer.State.NORMAL, "左移越界自动松手")
	Input.action_release("left")
	player._regrab_remaining = 0.0
	player.position = Vector2(0, 180)
	player.force_update_transform()
	check(player._try_grab_chain(), "左侧脱离后重新抓链")
	player.climb_speed = 120.0
	Input.action_press("climb_down")
	player._update_climb(1.0 / 60.0)
	check(is_equal_approx(player.velocity.y, 120.0), "上下速度可调")
	Input.action_release("climb_down")
	# 两端余量内可以抓住，且松键不会突然被拉回可见锁链端点。
	for hand_y in [-50.0, -20.0, 650.0, 680.0]:
		player.state = GamePlayer.State.NORMAL
		player.position = Vector2(0, hand_y + 35.0)
		player.force_update_transform()
		await physics_frame
		await physics_frame
		await physics_frame
		check(player._try_grab_chain(), "身体相交即可抓住，包含手部超出范围")
		var held_y := player.position.y
		player._update_climb(1.0 / 60.0)
		check(is_equal_approx(player.position.y, held_y), "余量内保持悬停")
	# 手部早已低于检测区下端，身体顶部还在区内：仍可继续向下。
	player.position = Vector2(0, 710)
	player.force_update_transform()
	check(player.climb_grip.global_position.y > chain.grab_bottom_y(), "复现手部超出下端")
	check(chain.overlaps_character(player), "身体还与检测区重叠")
	var before_down := player.position.y
	Input.action_press("climb_down")
	player._update_climb(1.0 / 60.0)
	check(player.position.y > before_down and player.state == GamePlayer.State.CLIMB, "手部越界仍可下爬")
	for step in range(100):
		player._update_climb(1.0 / 60.0)
		if player.state != GamePlayer.State.CLIMB:
			break
	check(not chain.overlaps_character(player) and player.airborne, "身体全部离开下端后松手")
	check(player.animator.animation == &"jump" and player.animator.frame == 1, "下端脱离保持jump末帧")
	Input.action_release("climb_down")
	# 手部标记可以位于任意位置，不再参与攀爬中的范围判断。
	player.position = Vector2(0, 180)
	player.force_update_transform()
	player._regrab_remaining = 0.0
	check(player._try_grab_chain(), "返回链条重新抓取")
	player.climb_grip.position = Vector2(999, -999)
	player._update_climb(1.0 / 60.0)
	check(player.state == GamePlayer.State.CLIMB, "手部标记位置不影响攀附状态")
	player.climb_grip.position = Vector2(0, -35)
	# 上端同样按身体重叠：不使用手部上界钳制。
	player.position = Vector2(0, -70)
	player.force_update_transform()
	Input.action_press("climb_up")
	var before_up := player.position.y
	player._update_climb(1.0 / 60.0)
	check(player.position.y < before_up and player.state == GamePlayer.State.CLIMB, "手部超出上端仍可上爬")
	for step in range(100):
		player._update_climb(1.0 / 60.0)
		if player.state != GamePlayer.State.CLIMB:
			break
	check(not chain.overlaps_character(player) and player.airborne, "身体全部离开上端后松手")
	Input.action_release("climb_up")
	player.position = Vector2(0, 180)
	player.force_update_transform()
	player._regrab_remaining = 0.0
	check(player._try_grab_chain(), "准备离链跳跃测试")
	await process_frame
	key(KEY_X, true)
	player._physics_process(1.0 / 60.0)
	key(KEY_X, false)
	check(player.state == GamePlayer.State.NORMAL and player.velocity.y < 0, "离链跳跃")
	check(player.animator.animation == &"jump" and player.animator.frame == 0, "离链jump首帧")
	check(player.current_chain == null and player.airborne, "离链状态清理")
	player.high_fall_finished.connect(func(): severe_events += 1)
	player.state = GamePlayer.State.LANDING_HIGHER
	player.animator.animation = &"fall higher"
	player._on_animation_finished()
	player._on_animation_finished()
	check(severe_events == 1 and player.state == GamePlayer.State.FAINTED, "高落地事件只发一次")
	check(player.animator.frame == 1, "高落地保持末帧")
	player.reset_to_normal()
	check(player.state == GamePlayer.State.NORMAL and not player.airborne, "复苏清理状态")
	var statue_scene := load("res://scenes/prayer_statue.tscn") as PackedScene
	var statue := statue_scene.instantiate() as PrayerStatue
	statue.position = Vector2(0, 260)
	root.add_child(statue)
	player.position = Vector2(0, 180)
	player.force_update_transform()
	statue.force_update_transform()
	await physics_frame
	await physics_frame
	await physics_frame
	await process_frame
	statue.prayer_completed.connect(func(_who): prayer_events += 1)
	player._try_prayer()
	check(player.state == GamePlayer.State.KNEELING_DOWN, "雕像范围允许祈祷")
	player._on_animation_finished()
	player._on_animation_finished()
	check(prayer_events == 1 and player.state == GamePlayer.State.KNEELING, "跪稳事件单次")
	player.state = GamePlayer.State.STANDING_UP
	player.animator.animation = &"stand_up"
	player._on_animation_finished()
	check(player.current_statue == null and player.state == GamePlayer.State.NORMAL, "起身恢复")
	# 真实物理落地：从地面上方连续下降，验证低/高阈值选择。
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(0, 500)
	var floor_collision := CollisionShape2D.new()
	var floor_shape := RectangleShape2D.new()
	floor_shape.size = Vector2(1000, 20)
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	root.add_child(floor_body)
	await physics_frame
	for start_y in [300.0, 100.0]:
		player.reset_to_normal()
		player.position = Vector2(0, start_y)
		player.move_and_slide() # 更新地面接触状态
		for step in range(180):
			player._update_normal(1.0 / 60.0)
			if player.state != GamePlayer.State.NORMAL:
				break
		var expected := GamePlayer.State.LANDING_LOWER if start_y == 300.0 else GamePlayer.State.LANDING_HIGHER
		check(player.state == expected, "下落高度选择正确动画")
	var incomplete := make_player()
	incomplete.get_node("ClimbGrip").free()
	incomplete.animator.sprite_frames.remove_animation("climb")
	incomplete.position = Vector2(700, 100)
	root.add_child(incomplete)
	check(incomplete.is_physics_processing(), "缺少ClimbGrip/climb不应禁用行走")
	incomplete.set_physics_process(false)
	check(not incomplete._try_grab_chain(), "配置不全安全拒绝抓链")
	await process_frame
	key(KEY_RIGHT, true)
	incomplete._physics_process(1.0 / 60.0)
	check(incomplete.velocity.x > 0.0, "配置不全仍能右移")
	key(KEY_RIGHT, false)
	key(KEY_Z, true)
	check(Input.is_action_just_pressed("pray") and not Input.is_action_pressed("jump"), "Z只触发祈祷")
	key(KEY_Z, false)
	key(KEY_V, true)
	check(Input.is_action_just_pressed("fullscreen"), "V映射全屏")
	key(KEY_V, false)
	# 实际Camera2D：上下观察、攀爬抑制、四边限制及视窗尺寸变化。
	var view := SubViewport.new()
	view.size = Vector2i(800, 450)
	root.add_child(view)
	var camera := preload("res://scripts/exploration_camera.gd").new()
	camera.player = incomplete
	camera.follow_offset = Vector2.ZERO
	incomplete.position = Vector2(990, 540)
	incomplete.state = GamePlayer.State.NORMAL
	view.add_child(camera)
	camera.set_physics_process(false)
	Input.action_press("climb_up")
	for frame in range(120):
		camera._physics_process(1.0 / 60.0)
	check(camera.global_position.y < 400, "普通状态按上键向上观察")
	incomplete.state = GamePlayer.State.CLIMB
	for frame in range(120):
		camera._physics_process(1.0 / 60.0)
	check(absf(camera.global_position.y - 540) < 1.0, "攀爬时上键不控制观察")
	Input.action_release("climb_up")
	incomplete.state = GamePlayer.State.NORMAL
	Input.action_press("climb_down")
	for frame in range(120):
		camera._physics_process(1.0 / 60.0)
	check(camera.global_position.y > 680, "普通状态下键向下观察")
	Input.action_release("climb_down")
	for frame in range(120):
		camera._physics_process(1.0 / 60.0)
	check(absf(camera.global_position.y - 540) < 1.0, "松开观察键恢复跟随")
	incomplete.position = Vector2(-10000, 10000)
	camera._physics_process(10.0)
	check(camera.global_position.is_equal_approx(Vector2(400, 855)), "镜头中心为半视野留出边界")
	check(camera.get_screen_center_position().is_equal_approx(camera.global_position), "真实镜头中心与限制位置一致")
	camera.map_bounds = Rect2(210, 50, 100, 100)
	view.size = Vector2i(1200, 900)
	camera._physics_process(1.0 / 60.0)
	var half_view := camera.get_viewport_rect().size / camera.zoom / 2.0
	var screen_start := camera.global_position - half_view
	var screen_end := camera.global_position + half_view
	check(screen_start.x >= 209.99 and screen_start.y >= 49.99 and screen_end.x <= 310.01 and screen_end.y <= 150.01, "偏移地图及大视窗仍不越界")
	print("Regression checks completed. Failures: ", failures)
	quit(0 if failures == 0 else 1)

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
