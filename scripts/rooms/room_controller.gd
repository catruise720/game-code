class_name RoomController
extends Node2D
## 每个房间的根节点脚本；直接运行单个房间时也会把玩家放到default出生点。


func _ready() -> void:
	if RoomManager.changing_room:
		return
	await RoomManager.place_player(self)
