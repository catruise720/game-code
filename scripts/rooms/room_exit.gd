class_name RoomExit
extends Area2D
## 房间出口。玩家进入检测区后，请求RoomManager执行淡出转场。

@export_file("*.tscn") var target_room_path: String
@export var target_spawn_id: StringName = &"default"
@export_range(0.0, 2.0, 0.05) var activation_delay: float = 0.15
var _active: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if activation_delay > 0.0:
		await get_tree().create_timer(activation_delay).timeout
	_active = true


func _on_body_entered(body: Node2D) -> void:
	if not _active or not (body is GamePlayer) or target_room_path.is_empty():
		return
	_active = false
	RoomManager.change_room(target_room_path, target_spawn_id)
