
extends Control

signal level_selected(scene_path: String)
signal back_requested

@export var game_title: String = "CITY HERO"
@export var subtitle: String = "SELECT YOUR MISSION"

@export var level_names: PackedStringArray = [
	"City Patrol",
	"Water Emergency",
	"Fire Rescue",
	"Medical Emergency",
	"Final Mission"
]

@export var level_descriptions: PackedStringArray = [
	"Keep the city safe.",
	"Repair the leaking hydrant.",
	"Respond to a city fire.",
	"Help people in need.",
	"Become a city hero."
]

@export var level_scene_paths: PackedStringArray = [
	"res://main.tscn",
	"res://main.tscn",
	"res://main.tscn",
	"res://main.tscn",
	"res://main.tscn"
]

@export var unlocked_levels: PackedInt32Array = [0]
@export var show_back_button: bool = true

var selected_level := 0

const BG := Color("#171b20")
const PANEL := Color("#242a31")
const WHITE := Color("#f1f3f5")
const MUTED := Color("#aab2bb")
const ACCENT := Color("#d5dbe0")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_screen()


func _build_screen() -> void:
	for child in get_children():
		child.queue_free()

	var background := ColorRect.new()
	background.color = BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 20)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)

	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)

	var title := Label.new()
	title.text = game_title
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", WHITE)
	heading.add_child(title)

	var sub := Label.new()
	sub.text = subtitle
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", MUTED)
	heading.add_child(sub)

	if show_back_button:
		var back := Button.new()
		back.text = "BACK"
		back.custom_minimum_size = Vector2(110, 42)
		back.pressed.connect(func(): back_requested.emit())
		header.add_child(back)

	var divider := HSeparator.new()
	layout.add_child(divider)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	scroll.add_child(grid)

	for i in range(level_names.size()):
		grid.add_child(_make_level_card(i))


func _make_level_card(index: int) -> Control:
	var unlocked := unlocked_levels.has(index)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(280, 155)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = PANEL if unlocked else Color("#1e2227")
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_color = Color("#555e68") if unlocked else Color("#343a40")
	card.add_theme_stylebox_override("panel", style)

	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 18)
	padding.add_theme_constant_override("margin_right", 18)
	padding.add_theme_constant_override("margin_top", 14)
	padding.add_theme_constant_override("margin_bottom", 14)
	card.add_child(padding)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	padding.add_child(content)

	var number := Label.new()
	number.text = "MISSION %02d" % (index + 1)
	number.add_theme_font_size_override("font_size", 12)
	number.add_theme_color_override("font_color", MUTED)
	content.add_child(number)

	var name_label := Label.new()
	name_label.text = level_names[index]
	name_label.add_theme_font_size_override("font_size", 21)
	name_label.add_theme_color_override("font_color", WHITE)
	content.add_child(name_label)

	var description := Label.new()
	if index < level_descriptions.size():
		description.text = level_descriptions[index]
	description.add_theme_color_override("font_color", MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(description)

	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 36)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if unlocked:
		button.text = "SELECT MISSION"
		button.pressed.connect(_on_level_pressed.bind(index))
	else:
		button.text = "LOCKED"
		button.disabled = true

	content.add_child(button)
	return card


func _on_level_pressed(index: int) -> void:
	if index < 0 or index >= level_scene_paths.size():
		push_warning("No scene path configured for this mission.")
		return

	selected_level = index
	level_selected.emit(level_scene_paths[index])
