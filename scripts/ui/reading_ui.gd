class_name ReadingPanel
extends CanvasLayer
## 将配套场景注册为名为 ReadingUI 的Autoload。不要再放到每个房间里。
## 阅读记录只保留在本次运行中；后续由存档系统调用 export/import_read_clues。

signal clue_read(clue_id: StringName)

@export var preferred_size: Vector2 = Vector2(768, 512)
@export_range(0.5, 0.98, 0.01) var screen_fraction: float = 0.90
@export_range(12, 40, 1) var font_size: int = 22
## 可选：导入支持中文的ttf/otf字体后拖到这里。
@export var text_font: Font

@onready var panel: TextureRect = $Root/Panel
@onready var title_label: Label = $Root/Panel/Title
@onready var body_label: RichTextLabel = $Root/Panel/Body
@onready var hint_label: Label = $Root/Panel/Hint

var _reader: Node = null
var _clue_id: StringName = &""
var _read_clues: Dictionary = {}
var _all_text_seen: bool = false
var _layout_wait: int = 0


func _ready() -> void:
	visible = false
	set_process(false)
	if text_font != null:
		title_label.add_theme_font_override("font", text_font)
		body_label.add_theme_font_override("normal_font", text_font)
		hint_label.add_theme_font_override("font", text_font)
	get_viewport().size_changed.connect(_layout_panel)
	_layout_panel()


func _layout_panel() -> void:
	var view_size := get_viewport().get_visible_rect().size
	var safe_size := Vector2(maxf(preferred_size.x, 1), maxf(preferred_size.y, 1))
	var factor := minf(1.0, minf(view_size.x * screen_fraction / safe_size.x,
		view_size.y * screen_fraction / safe_size.y))
	panel.size = (safe_size * factor).floor()
	panel.position = ((view_size - panel.size) / 2.0).floor()
	var actual_font := maxi(14, roundi(font_size * factor))
	title_label.add_theme_font_size_override("font_size", actual_font + 2)
	body_label.add_theme_font_size_override("normal_font_size", actual_font)
	hint_label.add_theme_font_size_override("font_size", maxi(12, actual_font - 2))
	_layout_wait = 2


func open_plaque(plaque: ReadingPlaque, reader: Node) -> bool:
	if visible or not is_instance_valid(plaque) or not is_instance_valid(reader):
		return false
	_reader = reader
	_clue_id = plaque.clue_id
	title_label.text = plaque.inscription_title
	body_label.text = plaque.inscription_text
	body_label.scroll_to_line(0)
	_all_text_seen = false
	visible = true
	set_process(true)
	_layout_panel()
	hint_label.text = "Z 关闭"
	return true


func is_reading_for(reader: Node) -> bool:
	return visible and is_instance_valid(_reader) and _reader == reader


func _process(_delta: float) -> void:
	if not is_instance_valid(_reader):
		close_plaque(false)
		return
	if _layout_wait > 0:
		_layout_wait -= 1
		return
	var scroll := body_label.get_v_scroll_bar()
	if scroll.value + scroll.page >= scroll.max_value - 1.0:
		_all_text_seen = true
	hint_label.text = "Z 关闭" if _all_text_seen else "滚轮向下阅读 · Z 关闭"


func close_plaque(completed: bool = true) -> void:
	if not visible:
		return
	# 所有文字至少显示到结尾，再主动关闭，才记录线索；中途取消不算。
	var finished_id := _clue_id
	var should_record := completed and _all_text_seen and not finished_id.is_empty()
	visible = false
	set_process(false)
	_reader = null
	_clue_id = &""
	if should_record and not has_read(finished_id):
		_read_clues[String(finished_id)] = true
		clue_read.emit(finished_id)


func has_read(id: StringName) -> bool:
	return bool(_read_clues.get(String(id), false))


func export_read_clues() -> Array[String]:
	var ids: Array[String] = []
	for id in _read_clues:
		ids.append(String(id))
	return ids


func import_read_clues(ids: Array) -> void:
	_read_clues.clear()
	for id in ids:
		if id is String or id is StringName:
			_read_clues[String(id)] = true


func reset_progress() -> void:
	close_plaque(false)
	_read_clues.clear()
