class_name GamePlayer
extends CharacterBody2D
## Godot 4：普通移动、祈祷、分高度落地、锁链攀爬。

signal high_fall_finished

@export_group("Movement")
@export var walk_speed: float = 150.0
@export var run_speed: float = 400.0
@export var gravity: float = 1200.0
@export var jump_force: float = -400.0
@export var animator: AnimatedSprite2D

@export_group("Climbing")
## 上下攀爬速度（像素/秒），保留原参数名兼容已有场景。
@export_range(0, 500, 1) var climb_speed: float = 90.0
## 左右横移速度（像素/秒）。
@export_range(0, 300, 1) var climb_horizontal_speed: float = 35.0
@export var regrab_delay: float = 0.15

@export_group("Landing")
@export var lower_fall_height: float = 80.0
@export var higher_fall_height: float = 260.0

@onready var climb_grip: Marker2D = get_node_or_null("ClimbGrip") as Marker2D

enum State {
	NORMAL, CLIMB, KNEELING_DOWN, KNEELING, STANDING_UP,
	LANDING_LOWER, LANDING_HIGHER, FAINTED
}
var state: State = State.NORMAL
var current_chain: ClimbChain
var current_statue: Area2D
var airborne: bool = false
var highest_y: float = 0.0
var _regrab_remaining: float = 0.0

func _ready() -> void:
	_ensure_default_input_map()

	if animator == null:
		animator = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animator == null or animator.sprite_frames == null:
		push_error("请在玩家检查器的 Animator 中指定带 SpriteFrames 的 AnimatedSprite2D。")
		set_physics_process(false)
		return
	if climb_grip == null:
		push_warning("缺少 ClimbGrip：暂不可抓链，普通移动和跳跃仍然可用。")
	for animation_name in ["idle", "walk", "run", "jump", "climb", "kneel_down", "stand_up", "fall lower", "fall higher"]:
		if not _has_animation(animation_name):
			push_warning("人物动画缺失或无帧：" + animation_name + "；请补全，普通移动不会被停用。")
	for animation_name in ["jump", "kneel_down", "stand_up", "fall lower", "fall higher"]:
		if _has_animation(animation_name):
			animator.sprite_frames.set_animation_loop(animation_name, false)
	for animation_name in ["idle", "walk", "run", "climb"]:
		if _has_animation(animation_name):
			animator.sprite_frames.set_animation_loop(animation_name, true)
	if not animator.animation_finished.is_connected(_on_animation_finished):
		animator.animation_finished.connect(_on_animation_finished)
	highest_y = global_position.y
	_play_ground_animation()

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("fullscreen"):
		_toggle_fullscreen()

	_regrab_remaining = maxf(0.0, _regrab_remaining - delta)
	if state == State.NORMAL:
		if Input.is_action_just_pressed("pray") and is_on_floor():
			_try_prayer()
		# X 共用：附近有锁链时优先抓链；抓不到才由普通移动处理为跳跃。
		if state == State.NORMAL and Input.is_action_just_pressed("jump"):
			if _try_grab_chain():
				return # 抓住当帧先显示 climb 第一帧
	elif state == State.KNEELING and Input.is_action_just_pressed("pray"):
		state = State.STANDING_UP
		animator.play("stand_up")
	match state:
		State.NORMAL:
			_update_normal(delta)
		State.CLIMB:
			_update_climb(delta)
		_:
			velocity.x = 0.0
			if not is_on_floor():
				velocity.y += gravity * delta
			move_and_slide()

func _update_normal(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		_begin_jump()
	var direction := Input.get_axis("left", "right")
	velocity.x = direction * _horizontal_speed()
	if direction != 0.0:
		animator.flip_h = direction < 0.0
	var previous_y := global_position.y
	move_and_slide()
	if not is_on_floor():
		if not airborne:
			airborne = true
			highest_y = previous_y
			_hold_last(&"jump") # 走出边缘：直接显示跳跃末帧
		highest_y = minf(highest_y, global_position.y)
		return
	if airborne:
		var distance := maxf(0.0, global_position.y - highest_y)
		airborne = false
		if distance >= maxf(lower_fall_height, higher_fall_height):
			velocity.x = 0.0
			if _has_animation(&"fall higher"):
				state = State.LANDING_HIGHER
				animator.play("fall higher")
			else:
				state = State.FAINTED
				high_fall_finished.emit()
			return
		if distance >= lower_fall_height and _has_animation(&"fall lower"):
			state = State.LANDING_LOWER
			velocity.x = 0.0
			animator.play("fall lower")
			return
	_play_ground_animation()

func _horizontal_speed() -> float:
	return run_speed if Input.is_action_pressed("run") else walk_speed


func _ensure_default_input_map() -> void:
	# 在运行时统一这八个动作的键盘绑定，防止旧Z抓链与Z祈祷冲突。
	# 保留手柄等非键盘绑定；不改写磁盘上的项目设置。
	_ensure_key_action(&"left", KEY_LEFT)
	_ensure_key_action(&"right", KEY_RIGHT)
	_ensure_key_action(&"jump", KEY_X)
	_ensure_key_action(&"pray", KEY_Z)
	_ensure_key_action(&"run", KEY_SHIFT)
	_ensure_key_action(&"climb_up", KEY_UP)
	_ensure_key_action(&"climb_down", KEY_DOWN)
	_ensure_key_action(&"fullscreen", KEY_V)


func _ensure_key_action(action_name: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for existing_event in InputMap.action_get_events(action_name):
		if existing_event is InputEventKey:
			InputMap.action_erase_event(action_name, existing_event)

	var key_event := InputEventKey.new()
	key_event.physical_keycode = keycode
	InputMap.action_add_event(action_name, key_event)


func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _begin_jump() -> void:
	state = State.NORMAL
	current_chain = null
	velocity.y = jump_force
	airborne = true
	highest_y = global_position.y
	if _has_animation(&"jump"):
		animator.play("jump")
		animator.set_frame_and_progress(0, 0.0)

func _try_grab_chain() -> bool:
	if _regrab_remaining > 0.0 or climb_grip == null or not _has_animation(&"climb"):
		return false
	var candidate: ClimbChain = null
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group("climb_chain"):
		var chain := node as ClimbChain
		if chain == null or not chain.overlaps_character(self):
			continue
		# 以身体碰撞体与Area2D相交为准，不再额外用手部高度拒绝抓取。
		var offset_x := chain.global_position.x - climb_grip.global_position.x
		if test_move(global_transform, Vector2(offset_x, 0.0)):
			continue
		if absf(offset_x) < nearest_distance:
			nearest_distance = absf(offset_x)
			candidate = chain
	if candidate == null:
		return false
	move_and_collide(Vector2(candidate.global_position.x - climb_grip.global_position.x, 0.0))
	current_chain = candidate
	state = State.CLIMB
	velocity = Vector2.ZERO
	airborne = false
	highest_y = global_position.y
	# 固定攀爬图的原始朝向，保证 ClimbGrip 与手的位置一致。
	animator.flip_h = false
	_hold_frame(&"climb", 0)
	return true

func _update_climb(_delta: float) -> void:
	if not is_instance_valid(current_chain):
		_release_to_fall()
		return
	if not current_chain.overlaps_character(self):
		_release_to_fall(true)
		return
	if Input.is_action_just_pressed("jump"):
		var direction := Input.get_axis("left", "right")
		_regrab_remaining = regrab_delay
		_begin_jump()
		velocity.x = direction * _horizontal_speed()
		if direction != 0.0:
			animator.flip_h = direction < 0.0
		move_and_slide()
		return
	var direction_y := Input.get_axis("climb_up", "climb_down")
	var direction_x := Input.get_axis("left", "right")
	# 四个方向均不使用手部坐标或人为距离限制；实体墙/地面仍由物理碰撞阻挡。
	velocity = Vector2(
		direction_x * climb_horizontal_speed,
		direction_y * climb_speed
	)
	var previous_y := global_position.y
	move_and_slide() # 此分支不施加重力
	# 身体任意启用碰撞形状仍有重叠便保持攀爬，全部离开才松手。
	if not current_chain.overlaps_character(self):
		_release_to_fall(true)
		return
	if direction_y != 0.0 and absf(global_position.y - previous_y) > 0.01:
		animator.play("climb")
	else:
		_hold_frame(&"climb", 0)
	if direction_y > 0.0 and is_on_floor():
		current_chain = null
		state = State.NORMAL
		velocity = Vector2.ZERO
		airborne = false
		_play_ground_animation()

func _release_to_fall(keep_horizontal_velocity: bool = false) -> void:
	current_chain = null
	state = State.NORMAL
	velocity = Vector2(velocity.x if keep_horizontal_velocity else 0.0, 0.0)
	_regrab_remaining = regrab_delay
	airborne = true
	highest_y = global_position.y
	_hold_last(&"jump")

func _try_prayer() -> void:
	if not _has_animation(&"kneel_down") or not _has_animation(&"stand_up"):
		return
	var nearest_distance := INF
	var candidate: Area2D = null
	for node in get_tree().get_nodes_in_group("prayer_spot"):
		var area := node as Area2D
		if area == null or not area.overlaps_body(self):
			continue
		if area is PrayerStatue and not (area as PrayerStatue).can_pray(self):
			continue
		var distance := global_position.distance_squared_to(area.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			candidate = area
	if candidate == null:
		return
	current_statue = candidate
	state = State.KNEELING_DOWN
	velocity = Vector2.ZERO
	animator.play("kneel_down")
	if current_statue is PrayerStatue:
		(current_statue as PrayerStatue).begin_prayer(self)

func _end_prayer() -> void:
	var previous_statue := current_statue
	current_statue = null
	if is_instance_valid(previous_statue) and previous_statue is PrayerStatue:
		(previous_statue as PrayerStatue).end_prayer(self)

func _hold_frame(animation_name: StringName, frame_index: int) -> void:
	if not _has_animation(animation_name):
		return
	animator.animation = animation_name
	animator.pause()
	animator.set_frame_and_progress(frame_index, 0.0)

func _hold_last(animation_name: StringName) -> void:
	if not _has_animation(animation_name):
		return
	_hold_frame(animation_name, animator.sprite_frames.get_frame_count(animation_name) - 1)

func _play_ground_animation() -> void:
	var desired: StringName = &"idle"
	if Input.get_axis("left", "right") == 0.0:
		desired = &"idle"
	elif Input.is_action_pressed("run"):
		desired = &"run"
	else:
		desired = &"walk"
	if _has_animation(desired):
		animator.play(desired)
	elif _has_animation(&"idle"):
		animator.play("idle")

func _has_animation(animation_name: StringName) -> bool:
	return animator.sprite_frames.has_animation(animation_name) and animator.sprite_frames.get_frame_count(animation_name) > 0

func _on_animation_finished() -> void:
	match state:
		State.KNEELING_DOWN:
			if animator.animation == &"kneel_down":
				state = State.KNEELING
				_hold_last(&"kneel_down")
				if is_instance_valid(current_statue) and current_statue is PrayerStatue:
					(current_statue as PrayerStatue).complete_prayer(self)
		State.STANDING_UP:
			if animator.animation == &"stand_up":
				state = State.NORMAL
				_play_ground_animation()
				_end_prayer()
		State.LANDING_LOWER:
			if animator.animation == &"fall lower":
				state = State.NORMAL
				_play_ground_animation()
		State.LANDING_HIGHER:
			if animator.animation == &"fall higher":
				state = State.FAINTED
				_hold_last(&"fall higher")
				high_fall_finished.emit()

func reset_to_normal() -> void:
	## 外部传送或复苏后调用。这里不实现传送目的地或结局。
	state = State.NORMAL
	current_chain = null
	velocity = Vector2.ZERO
	airborne = false
	highest_y = global_position.y
	_regrab_remaining = regrab_delay
	_play_ground_animation()
	_end_prayer()
