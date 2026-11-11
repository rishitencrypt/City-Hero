class_name LevelSelectionScreen
extends Control
## Standalone level-selection UI built entirely in code.
## Attach to a new Control scene. Does not modify your existing city scene.

signal level_selected(scene_path: String)
signal back_requested

@export var game_title: String = "CITY HERO"
@export var subtitle: String = "SELECT A MISSION"
## Add your actual level scene paths in the Inspector, e.g. res://scenes/main.tscn
@export var level_names: PackedStringArray = PackedStringArray(["First Response", "Water Conservation", "City Patrol"])
@export var level_descriptions: PackedStringArray = PackedStringArray([
	"Respond to an emergency in the city.",
	"Repair the hydrant and restore the water supply.",
	"Keep the streets safe and help citizens."
])
@export var level_scene_paths: PackedStringArray = PackedStringArray([
	"res://main.tscn",
	"res://main.tscn",
	"res://main.tscn"
])
## Indexes in this array are playable. For example [0] means only the first level is unlocked.
@export var unlocked_levels: PackedInt32Array = PackedInt32Array([0])
@export var show_back_button: bool = true

const BG := Color("#17191b")
const PANEL := Color("#222528")
const PANEL_HOVER := Color("#2b2f33")
const WHITE := Color("#f2f2f0")
const MUTED := Color("#a9adb0")
const LINE := Color("#454a4e")
const ACCENT := Color("#d5d7d8")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	for child in get_children():
		child.queue_free()

	var background := ColorRect.new()
	background.color = BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 48)
	outer.add_theme_constant_override("margin_right", 48)
	outer.add_theme_constant_override("margin_top", 32)
	outer.add_theme_constant_override("margin_bottom", 32)
	add_child(outer)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	outer.add_child(layout)

	var top := HBoxContainer.new()
	layout.add_child(top)

	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	heading.add_child(_label(game_title, 15, MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	heading.add_child(_label(subtitle, 30, WHITE, HORIZONTAL_ALIGNMENT_LEFT))

	if show_back_button:
		var back := _button("BACK")
		back.pressed.connect(func(): back_requested.emit())
		top.add_child(back)

	var rule := HSeparator.new()
	rule.add_theme_color_override("separator", LINE)
	layout.add_child(rule)

	var hint := _label("Choose your next task. Complete missions to unlock more of the city.", 15, MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	layout.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)

	var cards := GridContainer.new()
	cards.columns = 3
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("h_separation", 16)
	cards.add_theme_constant_override("v_separation", 16)
	scroll.add_child(cards)

	for i in range(level_names.size()):
		cards.add_child(_make_level_card(i))

	var footer := _label("CITY HERO  /  MISSION CONTROL", 11, MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	layout.add_child(footer)

func _make_level_card(i: int) -> PanelContainer:
	var unlocked := unlocked_levels.has(i)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(230, 235)
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL if unlocked else Color("#1d1f21")
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_color = LINE
	card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	card.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	content.add_child(_label("%02d" % (i + 1), 13, MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	var placeholder := ColorRect.new()
	placeholder.custom_minimum_size = Vector2(0, 65)
	placeholder.color = Color("#303438") if unlocked else Color("#25282a")
	content.add_child(placeholder)

	var name_text := level_names[i] if i < level_names.size() else "Mission %d" % (i + 1)
	content.add_child(_label(name_text, 19, WHITE if unlocked else MUTED, HORIZONTAL_ALIGNMENT_LEFT))

	var desc_text := level_descriptions[i] if i < level_descriptions.size() else "Explore the city and complete your objective."
	var desc := _label(desc_text, 12, MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.y = 34
	content.add_child(desc)

	var action := _button("PLAY MISSION" if unlocked else "LOCKED")
	action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action.disabled = not unlocked
	content.add_child(action)
	if unlocked:
		action.pressed.connect(func(): _choose_level(i))
	return card

func _choose_level(i: int) -> void:
	if i >= 0 and i < level_scene_paths.size() and not level_scene_paths[i].is_empty():
		level_selected.emit(level_scene_paths[i])
	else:
		push_warning("LevelSelectionScreen: set a valid scene path for level index %d." % i)

func _label(text: String, size: int, color: Color, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = alignment
	return label

func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(110, 40)
	b.focus_mode = Control.FOCUS_NONE
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#303438")
	normal.set_corner_radius_all(5)
	normal.set_border_width_all(1)
	normal.border_color = LINE
	var hover := StyleBoxFlat.new()
	hover.bg_color = PANEL_HOVER
	hover.set_corner_radius_all(5)
	hover.set_border_width_all(1)
	hover.border_color = ACCENT
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color("#41464a")
	pressed.set_corner_radius_all(5)
	pressed.set_border_width_all(1)
	pressed.border_color = WHITE
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", normal)
	b.add_theme_color_override("font_color", WHITE)
	b.add_theme_color_override("font_disabled_color", MUTED)
	b.add_theme_font_size_override("font_size", 12)
	return b
