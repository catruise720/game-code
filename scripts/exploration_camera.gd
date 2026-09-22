class_name ExplorationCamera
extends Camera2D
## 挂在玩家的 Camera2D 上。地图边界使用世界坐标，不是图片本地坐标。

@export var player: GamePlayer
@export_group("地图与镜头")
@export var map_bounds: Rect2 = Rect2(0, 0, 1980, 1080)
## 使用这个参数调缩放。运行时会自动增大到能装进地图的最小值。
@export_range(0.1, 8.0, 0.05) var camera_zoom: float = 1.0
@export var follow_offset: Vector2 = Vector2(0, -40)
@export_range(0.1, 30, 0.1) var follow_response: float = 10.0

@export_group("上下观察")
@export_range(0, 600, 1) var look_up_distance: float = 180.0
@export_range(0, 600, 1) var look_down_distance: float = 180.0
@export_range(1, 1500, 1) var look_speed: float = 240.0
@export_range(1, 1500, 1) var return_speed: float = 320.0

var _look_y: float = 0.0

func _ready() -> void:
	if player == null:
		player = get_parent() as GamePlayer
	if player == null:
		push_error("ExplorationCamera：请将玩家根节点拖入 Player 属性。")
		set_physics_process(false)
		return
	if map_bounds.size.x <= 0 or map_bounds.size.y <= 0:
		push_error("Map Bounds 的宽高必须大于0。")
		set_physics_process(false)
		return
	# 脱离父节点位移继承，避免玩家移动后再叠加一次镜头位移。
	top_level = true
	ignore_rotation = true
	anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	offset = Vector2.ZERO
	drag_horizontal_enabled = false
	drag_vertical_enabled = false
	position_smoothing_enabled = false
	limit_smoothed = false
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	# 在玩家物理移动完成后更新镜头。
	process_physics_priority = player.process_physics_priority + 1
	_refresh_view()
	global_position = _clamp_center(player.global_position + follow_offset)
	enabled = true
	make_current()
	force_update_scroll()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	_refresh_view()
	var target_look := 0.0
	# 只在普通活动状态观察；攀爬、祈祷及晕倒时回到跟随位置。
	if player.state == GamePlayer.State.NORMAL:
		var direction := Input.get_axis("climb_up", "climb_down")
		if direction < 0.0:
			target_look = -look_up_distance
		elif direction > 0.0:
			target_look = look_down_distance
	var speed := return_speed if target_look == 0.0 else look_speed
	_look_y = move_toward(_look_y, target_look, speed * delta)
	var desired := _clamp_center(player.global_position + follow_offset + Vector2(0, _look_y))
	var weight := 1.0 - exp(-follow_response * delta)
	# 平滑后再限制一次，窗口尺寸或地图范围变化时也不露出边界。
	global_position = _clamp_center(global_position.lerp(desired, weight))
	force_update_scroll()

func _refresh_view() -> void:
	var viewport_size := get_viewport_rect().size
	# 镜头视野大于地图时，仅限制位置无法防止露底，需适当放大镜头。
	var fit_zoom := maxf(viewport_size.x / map_bounds.size.x, viewport_size.y / map_bounds.size.y)
	zoom = Vector2.ONE * maxf(camera_zoom, fit_zoom)
	limit_left = floori(map_bounds.position.x)
	limit_top = floori(map_bounds.position.y)
	limit_right = ceili(map_bounds.end.x)
	limit_bottom = ceili(map_bounds.end.y)

func _clamp_center(point: Vector2) -> Vector2:
	var half_view := get_viewport_rect().size / zoom / 2.0
	var minimum := map_bounds.position + half_view
	var maximum := map_bounds.end - half_view
	return Vector2(
		clampf(point.x, minf(minimum.x, maximum.x), maxf(minimum.x, maximum.x)),
		clampf(point.y, minf(minimum.y, maximum.y), maxf(minimum.y, maximum.y))
	)
