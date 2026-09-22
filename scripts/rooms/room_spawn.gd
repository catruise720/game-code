class_name RoomSpawn
extends Marker2D
## 房间出生点。Spawn Id 必须与出口的 Target Spawn Id 一致。

@export var spawn_id: StringName = &"default"


func _ready() -> void:
	add_to_group(&"room_spawn")
