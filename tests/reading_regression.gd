extends SceneTree
## godot --headless --path . --script tests/reading_regression.gd
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	root.size = Vector2i(800, 450)
	var reading_panel := root.get_node("ReadingUI") as ReadingPanel
	var player := make_player()
	var ground := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(1000, 20)
	collider.shape = shape
	ground.position.y = 200
	ground.add_child(collider)
	root.add_child(ground)
	player.position = Vector2(0, 140)
	root.add_child(player)
	player.set_physics_process(false)
	var plaque := load("res://scenes/interactions/reading_plaque.tscn").instantiate() as ReadingPlaque
	plaque.position = Vector2(0, 190)
	plaque.clue_id = &"water_old_ritual"
	root.add_child(plaque)
	var statue := load("res://scenes/prayer_statue.tscn").instantiate() as PrayerStatue
	statue.position = plaque.position
	root.add_child(statue)
	await physics_frame
	await physics_frame
	player.velocity = Vector2(0, 10)
	player.move_and_slide()
	check(player.is_on_floor(), "玩家在地面")
	check(plaque.can_read(player), "铭牌检测到玩家")
	await process_frame
	Input.action_press("pray")
	player._physics_process(1.0 / 60)
	check(player.state == GamePlayer.State.READING, "同处铭牌和雕像范围时Z优先阅读")
	check(reading_panel.visible, "阅读框显示")
	Input.action_release("pray")
	await process_frame
	await process_frame
	await process_frame
	Input.action_press("right")
	Input.action_press("jump")
	var before := player.position
	player._physics_process(1.0 / 60)
	check(player.position.distance_to(before) < 1.0 and player.state == GamePlayer.State.READING, "阅读中不移动跳跃")
	var camera := ExplorationCamera.new()
	camera.player = player
	root.add_child(camera)
	camera.set_physics_process(false)
	Input.action_press("climb_up")
	check(not camera._can_start_look(), "阅读中不触发镜头观察")
	Input.action_release("climb_up")
	Input.action_release("right")
	Input.action_release("jump")
	Input.action_press("pray")
	player._physics_process(1.0 / 60)
	check(player.state == GamePlayer.State.NORMAL and not reading_panel.visible, "第二次Z关闭且不祈祷")
	check(reading_panel.has_read(&"water_old_ritual"), "完整短文关闭后记录线索")
	Input.action_release("pray")
	await process_frame
	plaque.enabled = false
	Input.action_press("pray")
	player._physics_process(1.0 / 60)
	Input.action_release("pray")
	check(player.state == GamePlayer.State.KNEELING_DOWN, "铭牌禁用后仍可Z祈祷")
	player.animator.animation = &"kneel_down"
	player._on_animation_finished()
	plaque.enabled = true
	await process_frame
	Input.action_press("pray")
	player._physics_process(1.0 / 60)
	Input.action_release("pray")
	check(player.state == GamePlayer.State.STANDING_UP, "跪姿中Z起身优先于阅读")
	player.reset_to_normal()
	for blocked_state in [GamePlayer.State.CLIMB, GamePlayer.State.FAINTED, GamePlayer.State.LANDING_HIGHER]:
		player.state = blocked_state
		check(not player._try_read_plaque(), "攀爬晕倒等状态不能阅读")
	player.reset_to_normal()
	# 长文必须滚到底才记已读；Z始终可以关闭。
	plaque.clue_id = &"long_text"
	plaque.inscription_text = "旧记录：水纹显现后才可祈祷。\n".repeat(100)
	check(player._try_read_plaque(), "打开长文")
	for frame in range(5):
		await process_frame
	reading_panel.close_plaque(true)
	check(not reading_panel.has_read(&"long_text"), "未读到尾的长文不解锁线索")
	player.reset_to_normal()
	player._try_read_plaque()
	for frame in range(5):
		await process_frame
	var scroll := reading_panel.body_label.get_v_scroll_bar()
	scroll.value = scroll.max_value
	await process_frame
	await process_frame
	reading_panel.close_plaque(true)
	check(reading_panel.has_read(&"long_text"), "滚到末尾后关闭记录线索")
	player.reset_to_normal()
	plaque.clue_id = &"interrupted"
	plaque.inscription_text = "一条短线索"
	player._try_read_plaque()
	await process_frame
	player.queue_free()
	plaque.queue_free()
	await process_frame
	await process_frame
	check(not reading_panel.visible and not reading_panel.has_read(&"interrupted"), "玩家随房间销毁时关闭UI且不记已读")
	check(reading_panel.has_read(&"water_old_ritual"), "铭牌销毁后此前线索仍保留")
	var ids := reading_panel.export_read_clues()
	reading_panel.reset_progress()
	reading_panel.import_read_clues(ids)
	check(reading_panel.has_read(&"water_old_ritual"), "存档接入接口可恢复已读ID")
	# 玩家动画节点重命名、嵌套或导出引用因换脚本丢失时，仍能找回有效帧资源。
	var nested_player := GamePlayer.new()
	var holder := Node2D.new()
	var empty_sprite := AnimatedSprite2D.new()
	var configured := AnimatedSprite2D.new()
	configured.name = "CharacterArt"
	configured.sprite_frames = SpriteFrames.new()
	holder.add_child(empty_sprite)
	holder.add_child(configured)
	nested_player.add_child(holder)
	check(nested_player._find_animated_sprite(nested_player) == configured, "自动查找嵌套且有SpriteFrames的动画节点")
	check(not nested_player._has_animation(&"idle"), "空Animator时动画检查不会再次访问null")
	nested_player.free()
	print("Reading regression checks completed. Failures: ", failures)
	quit(0 if failures == 0 else 1)


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
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	for animation in ["idle", "walk", "run", "jump", "climb", "kneel_down", "stand_up", "fall lower", "fall higher"]:
		sprite.sprite_frames.add_animation(animation)
		sprite.sprite_frames.add_frame(animation, texture)
		sprite.sprite_frames.add_frame(animation, texture)
	player.add_child(sprite)
	player.animator = sprite
	var grip := Marker2D.new()
	grip.name = "ClimbGrip"
	grip.position = Vector2(0, -35)
	player.add_child(grip)
	return player
