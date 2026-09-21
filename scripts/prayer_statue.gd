class_name PrayerStatue
extends Area2D
## 范围检测与祈祷事件。图像放在子 Sprite2D；谜题逻辑连接信号实现。

signal prayer_started(player: CharacterBody2D)
signal prayer_completed(player: CharacterBody2D)
signal prayer_ended(player: CharacterBody2D)

@export var enabled: bool = true
@export var statue_id: StringName = &"statue_01"

func _ready() -> void:
	add_to_group("prayer_spot")

func can_pray(player: CharacterBody2D) -> bool:
	return enabled and overlaps_body(player)

func begin_prayer(player: CharacterBody2D) -> void:
	prayer_started.emit(player)

func complete_prayer(player: CharacterBody2D) -> void:
	# 每次跪下动画完成时触发一次；保持跪姿不会每帧触发。
	prayer_completed.emit(player)

func end_prayer(player: CharacterBody2D) -> void:
	prayer_ended.emit(player)
