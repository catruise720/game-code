@tool
class_name ClimbChain
extends Area2D
## 根节点是中段顶部中心。保持自身和父节点的缩放为 1、旋转为 0。

@export_group("锁链贴图")
@export var chain_texture: Texture2D:
	set(value):
		chain_texture = value
		_refresh()
@export var top_texture: Texture2D:
	set(value):
		top_texture = value
		_refresh()
@export var bottom_texture: Texture2D:
	set(value):
		bottom_texture = value
		_refresh()

@export_group("锁链尺寸")
@export_range(16, 4000, 1) var length: float = 304.0:
	set(value):
		length = maxf(16.0, value)
		_refresh()
@export_range(2, 240, 1) var chain_width: float = 30.0:
	set(value):
		chain_width = maxf(2.0, value)
		_refresh()
@export_range(8, 240, 1) var detection_width: float = 48.0:
	set(value):
		detection_width = maxf(8.0, value)
		_refresh()

@export_group("抓取上下余量")
@export_range(0, 160, 1) var grab_top_margin: float = 30.0:
	set(value):
		grab_top_margin = maxf(0.0, value)
		_refresh()
@export_range(0, 160, 1) var grab_bottom_margin: float = 60.0:
	set(value):
		grab_bottom_margin = maxf(0.0, value)
		_refresh()

@export_group("挂件拼接")
@export_range(0, 128, 1) var top_overlap: float = 4.0:
	set(value):
		top_overlap = value
		_refresh()
@export_range(0, 128, 1) var bottom_overlap: float = 4.0:
	set(value):
		bottom_overlap = value
		_refresh()
@export_range(-128, 128, 1) var top_offset_x: float = 0.0:
	set(value):
		top_offset_x = value
		_refresh()
@export_range(-128, 128, 1) var bottom_offset_x: float = 0.0:
	set(value):
		bottom_offset_x = value
		_refresh()

func _ready() -> void:
	_refresh()
	if not Engine.is_editor_hint():
		add_to_group("climb_chain")

func _refresh() -> void:
	if not is_node_ready():
		return
	var picture := get_node_or_null("TextureRect") as TextureRect
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if picture == null or collision == null:
		return
	picture.texture = chain_texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_TILE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.set_anchors_preset(Control.PRESET_TOP_LEFT)
	picture.pivot_offset = Vector2.ZERO
	picture.custom_minimum_size = Vector2.ZERO
	picture.rotation = 0.0
	var source_width := 30.0
	if chain_texture != null:
		source_width = maxf(1.0, float(chain_texture.get_width()))
	picture.size = Vector2(source_width, length)
	picture.scale = Vector2(chain_width / source_width, 1.0)
	picture.position = Vector2(-roundf(chain_width / 2.0), 0.0)
	picture.z_index = 0
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(detection_width, length + grab_top_margin + grab_bottom_margin)
	collision.shape = rectangle
	collision.position = Vector2(0.0, (length + grab_bottom_margin - grab_top_margin) / 2.0)
	collision.scale = Vector2.ONE
	collision.rotation = 0.0
	_update_cap("TopCap", top_texture, true)
	_update_cap("BottomWeight", bottom_texture, false)

func _update_cap(node_name: String, texture: Texture2D, is_top: bool) -> void:
	var cap := get_node_or_null(NodePath(node_name)) as Sprite2D
	if cap == null:
		return
	cap.texture = texture
	cap.visible = texture != null
	cap.centered = false
	cap.offset = Vector2.ZERO
	cap.scale = Vector2.ONE
	cap.rotation = 0.0
	cap.region_enabled = false
	cap.hframes = 1
	cap.vframes = 1
	cap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cap.z_index = 1
	if texture == null:
		return
	var image_size := texture.get_size()
	if is_top:
		cap.position = Vector2(
			-roundf(image_size.x / 2.0) + top_offset_x,
			-image_size.y + top_overlap
		)
	else:
		cap.position = Vector2(
			-roundf(image_size.x / 2.0) + bottom_offset_x,
			length - bottom_overlap
		)

func top_y() -> float:
	return global_position.y

func bottom_y() -> float:
	return global_position.y + length

func grab_top_y() -> float:
	return top_y() - grab_top_margin

func grab_bottom_y() -> float:
	return bottom_y() + grab_bottom_margin
