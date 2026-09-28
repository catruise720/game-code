class_name ReadingPlaque
extends Area2D
## 地图中的阅读装置。Z输入由玩家统一处理，不需要手动连接进出信号。

@export var enabled: bool = true
## 相同线索的多个铭牌可共用ID；不同线索使用不同ID。留空仍可读但不记录线索。
@export var clue_id: StringName = &""
@export var inscription_title: String = "古旧铭牌"
@export_multiline var inscription_text: String = "旧渠仍通。\n转动下层水阀，待池底水纹显现，\n再于旧像前祈祷。"


func _ready() -> void:
	add_to_group(&"reading_plaque")


func can_read(body: PhysicsBody2D) -> bool:
	return enabled and monitoring and is_visible_in_tree() and overlaps_body(body)
