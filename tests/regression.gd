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
	for action in ["left", "right", "run", "jump", "pray", "climb_grab", "climb_up", "climb_down"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
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
	check(shape.size.y == 608, "检测高度跟随长度")
	var second := chain_scene.instantiate() as ClimbChain
	second.position.x = 1000
	root.add_child(second)
	check(second.length == 304, "其他实例长度独立")
	check((second.get_node("CollisionShape2D") as CollisionShape2D).shape != shape, "形状资源独立")
	var player := make_player()
	player.position = Vector2(0, 180)
	root.add_child(player)
	player.set_physics_process(false)
	await physics_frame
	await physics_frame
	check(player._try_grab_chain(), "空中检测范围可以抓链")
	check(player.state == GamePlayer.State.CLIMB, "进入攀爬状态")
	check(player.animator.frame == 0 and not player.animator.is_playing(), "抓链保持第0帧")
	Input.action_press("climb_up")
	var old_y := player.position.y
	player._update_climb(1.0 / 60.0)
	check(player.position.y < old_y and player.animator.is_playing(), "上爬移动播放动画")
	Input.action_release("climb_up")
	player._update_climb(1.0 / 60.0)
	check(player.animator.frame == 0 and not player.animator.is_playing(), "松键回第一帧")
	await process_frame
	Input.action_press("jump")
	player._update_climb(1.0 / 60.0)
	Input.action_release("jump")
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
	await physics_frame
	await physics_frame
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
	print("Regression checks completed. Failures: ", failures)
	quit(0 if failures == 0 else 1)
