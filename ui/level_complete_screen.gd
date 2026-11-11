class_name LevelCompleteScreen
extends Control
## Standalone level-complete UI built entirely in code.
## Show it after the mission objective is completed. Does not modify your city scene.

signal next_level_requested
signal replay_requested
signal level_select_requested

@export var level_title: String = "WATER CONSERVATION"
@export var completion_message: String = "The hydrant is repaired. The city is safer."
@export var reputation_earned: int = 20
@export_range(0, 3, 1) var stars_earned: int = 3
@export var next_level_available: bool = true

const BG := Color("#17191b")
const PANEL := Color("#222528")
const WHITE := Color("#f2f2f0")
const MUTED := Color("#a9adb0")
const LINE := Color("#454a4e")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	visible = false

func show_result(title: String = "", reward: int = -1, stars: int = -1) -> void:
	if not title.is_empty():
		level_title = title
	if reward >= 0:
		reputation_earned = reward
	if stars >= 0:
		stars_earned = clampi(stars, 0, 3)
	_build()
	visible = true

func hide_result() -> void:
	visible = false

func _build() -> void:
	for child in get_children():
		child.queue_free()

	var background := ColorRect.new()
	background.color = Color(0.05, 0.06, 0.07, 0.94)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 390)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = PANEL
	panel_style.set_corner_radius_all(10)
	panel_style.set_border_width_all(1)
	panel_style.border_color = LINE
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	margin.add_child(content)

	content.add_child(_label("MISSION COMPLETE", 13, MUTED))
	content.add_child(_label(level_title, 25, WHITE))
	var rule := HSeparator.new()
	rule.add_theme_color_override("separator", LINE)
	content.add_child(rule)

	var stars := _label(_star_string(), 32, WHITE)
	content.add_child(stars)

	var message := _label(completion_message, 14, MUTED)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(message)

	var reward := _label("+%d REPUTATION" % reputation_earned, 19, WHITE)
	content.add_child(reward)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(spacer)

	var next := _button("NEXT LEVEL")
	next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next.disabled = not next_level_available
	next.pressed.connect(func():
		visible = false
		next_level_requested.emit()
	)
	content.add_child(next)

	var secondary := HBoxContainer.new()
	secondary.add_theme_constant_override("separation", 10)
	content.add_child(secondary)

	var replay := _button("REPLAY")
	replay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replay.pressed.connect(func():
		visible = false
		replay_requested.emit()
	)
	secondary.add_child(replay)

	var select := _button("LEVEL SELECT")
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select.pressed.connect(func():
		visible = false
		level_select_requested.emit()
	)
	secondary.add_child(select)

func _star_string() -> String:
	var result := ""
	for i in range(3):
		result += "★" if i < stars_earned else "☆"
	return result

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(100, 40)
	b.focus_mode = Control.FOCUS_NONE
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#303438")
	normal.set_corner_radius_all(5)
	normal.set_border_width_all(1)
	normal.border_color = LINE
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color("#3b4044")
	hover.set_corner_radius_all(5)
	hover.set_border_width_all(1)
	hover.border_color = Color("#d5d7d8")
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_color_override("font_color", WHITE)
	b.add_theme_font_size_override("font_size", 12)
	return b
