extends Node
## Autoload：集中负责淡出、延迟换场景、出生点定位和淡入。

@export_range(0.05, 2.0, 0.05) var fade_duration: float = 0.35
var target_spawn_id: StringName = &"default"
var changing_room: bool = false
var _fade_layer: CanvasLayer
var _fade_rect: ColorRect


func _ready() -> void:
	_create_fade_overlay()


func _create_fade_overlay() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade_rect)


func change_room(room_path: String, spawn_id: StringName = &"default") -> void:
	if changing_room or room_path.is_empty():
		return
	changing_room = true
	target_spawn_id = spawn_id
	var old_player := get_tree().current_scene.get_node_or_null("Player") as GamePlayer
	if old_player != null:
		old_player.velocity = Vector2.ZERO
		old_player.set_physics_process(false)
	_transition_to_room.call_deferred(room_path)


func _transition_to_room(room_path: String) -> void:
	await _fade_to(1.0)
	var error := get_tree().change_scene_to_file(room_path)
	if error != OK:
		push_error("无法进入房间：%s（错误码 %s）" % [room_path, error])
		await _fade_to(0.0)
		changing_room = false
		return
	await get_tree().scene_changed
	var room := get_tree().current_scene
	var placed := await place_player(room)
	if not placed:
		push_error("房间中没有找到Player或出生点：%s" % target_spawn_id)
	await get_tree().process_frame
	await _fade_to(0.0)
	changing_room = false


func place_player(room: Node) -> bool:
	await get_tree().process_frame
	if room == null:
		return false
	var player := room.get_node_or_null("Player") as GamePlayer
	var spawn := _find_spawn(room, target_spawn_id)
	if player == null or spawn == null:
		return false
	player.global_position = spawn.global_position
	player.reset_to_normal()
	player.force_update_transform()
	target_spawn_id = &"default"
	return true


func _find_spawn(room: Node, wanted_id: StringName) -> RoomSpawn:
	for node in get_tree().get_nodes_in_group(&"room_spawn"):
		var spawn := node as RoomSpawn
		if spawn != null and room.is_ancestor_of(spawn) and spawn.spawn_id == wanted_id:
			return spawn
	return null


func _fade_to(alpha: float) -> void:
	if _fade_rect == null:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_fade_rect, "color:a", alpha, fade_duration)
	await tween.finished
