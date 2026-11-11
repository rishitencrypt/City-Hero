extends Node3D
# Attach this script to the WasteManagementTask node.
# It needs an Area3D child called "GardenTrigger" (with a CollisionShape3D).

const PICKUP_DISTANCE: float = 2.5
const BIN_DISTANCE: float = 3.0
const POINTS_CORRECT: int = 5
const POINTS_WRONG: int = -5

# Freezes the player while the start popup is open (player script is not changed).
const FREEZE_PLAYER: bool = true

var player: Node3D = null
var held_item: Node3D = null
var reputation: int = 0
var total_waste: int = 0
var sorted_waste: int = 0

# Task state
var task_started: bool = false
var popup_open: bool = false
var popup_shown: bool = false
var just_started: bool = false
var saved_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE

# HUD (fixed positions: counter top-left, status top-center, hint bottom-center)
var counter_label: Label = null
var status_label: Label = null
var hint_label: Label = null
var status_tween: Tween = null

# Start popup
var popup_layer: CanvasLayer = null
var popup_root: Control = null


func _ready() -> void:
	player = get_tree().current_scene.get_node_or_null("Player") as Node3D

	_count_waste()
	_build_ui()
	_update_ui()

	var trigger: Area3D = get_node_or_null("GardenTrigger") as Area3D
	if trigger == null:
		push_warning("WasteManagementTask: add an Area3D child named GardenTrigger.")
	else:
		trigger.body_entered.connect(_on_garden_entered)


func _on_garden_entered(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return

	player = body

	# Popup only appears the first time the player walks in.
	if popup_shown or task_started:
		return

	_open_popup()


func _input(event: InputEvent) -> void:
	# E can also start the task while the popup is open.
	if popup_open and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_start_task()


func _process(_delta: float) -> void:
	# Waste cannot be picked up until the task has been started.
	if not task_started:
		return

	# Skip the frame where E was used to press START,
	# so it does not also pick up waste.
	if just_started:
		just_started = false
		return

	if player == null:
		player = get_tree().current_scene.get_node_or_null("Player") as Node3D

	if player == null:
		return

	if held_item == null:
		_handle_pickup()
	else:
		_handle_drop()

	_update_hint()


# ---------------------------------------------------------------------------
# START POPUP
# ---------------------------------------------------------------------------
func _open_popup() -> void:
	popup_open = true
	popup_shown = true

	saved_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if FREEZE_PLAYER and player != null:
		player.process_mode = Node.PROCESS_MODE_DISABLED

	popup_layer = CanvasLayer.new()
	popup_layer.layer = 10
	add_child(popup_layer)

	popup_root = CenterContainer.new()
	popup_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_layer.add_child(popup_root)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0.7)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", panel_style)
	popup_root.add_child(panel)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title: Label = Label.new()
	title.text = "WASTE MANAGEMENT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(title)

	var message: Label = Label.new()
	message.text = "Sort the waste into the correct bins."
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", 20)
	message.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(message)

	var start_button: Button = Button.new()
	start_button.text = "START"
	start_button.custom_minimum_size = Vector2(0, 40)
	start_button.add_theme_font_size_override("font_size", 20)
	start_button.add_theme_color_override("font_color", Color.WHITE)
	start_button.add_theme_color_override("font_hover_color", Color.WHITE)
	start_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	start_button.add_theme_stylebox_override("normal", _button_style(0.15))
	start_button.add_theme_stylebox_override("hover", _button_style(0.30))
	start_button.add_theme_stylebox_override("pressed", _button_style(0.40))
	start_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	start_button.pressed.connect(_start_task)
	box.add_child(start_button)

	# Quick fade in
	popup_root.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(popup_root, "modulate:a", 1.0, 0.2)


func _button_style(alpha: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, alpha)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	return style


func _start_task() -> void:
	if not popup_open:
		return

	popup_open = false
	task_started = true
	just_started = true

	if FREEZE_PLAYER and player != null:
		player.process_mode = Node.PROCESS_MODE_INHERIT

	Input.mouse_mode = saved_mouse_mode

	# Quick fade out, then remove the popup.
	var layer: CanvasLayer = popup_layer
	var tween: Tween = create_tween()
	tween.tween_property(popup_root, "modulate:a", 0.0, 0.2)
	tween.tween_callback(layer.queue_free)
	popup_layer = null
	popup_root = null

	# Show the task counter with a quick fade in.
	counter_label.visible = true
	counter_label.modulate.a = 0.0
	var counter_tween: Tween = create_tween()
	counter_tween.tween_property(counter_label, "modulate:a", 1.0, 0.3)

	_update_ui()


# ---------------------------------------------------------------------------
# EXISTING GAMEPLAY (unchanged)
# ---------------------------------------------------------------------------
func _handle_pickup() -> void:
	var nearest_waste: Node3D = _get_nearest_waste()

	if nearest_waste == null:
		return

	if Input.is_action_just_pressed("interact"):
		_pick_up(nearest_waste)


func _handle_drop() -> void:
	var nearest_bin: Node3D = _get_nearest_bin()

	if nearest_bin == null:
		return

	if Input.is_action_just_pressed("interact"):
		_try_drop(nearest_bin)


func _get_nearest_waste() -> Node3D:
	var nearest: Node3D = null
	var nearest_distance: float = PICKUP_DISTANCE

	for child in get_children():
		if not child is Node3D:
			continue

		var item := child as Node3D

		if not _is_waste(item):
			continue

		var distance := player.global_position.distance_to(item.global_position)

		if distance <= nearest_distance:
			nearest_distance = distance
			nearest = item

	return nearest


func _get_nearest_bin() -> Node3D:
	var nearest: Node3D = null
	var nearest_distance: float = BIN_DISTANCE

	for child in get_children():
		if not child is Node3D:
			continue

		var bin := child as Node3D

		if not _is_bin(bin):
			continue

		var distance := player.global_position.distance_to(bin.global_position)

		if distance <= nearest_distance:
			nearest_distance = distance
			nearest = bin

	return nearest


func _is_waste(item: Node3D) -> bool:
	var n := item.name.to_lower()

	return (
		n.begins_with("plastic") or
		n.begins_with("paper") or
		n.begins_with("metallic") or
		n.begins_with("metal") or
		n.begins_with("organic")
	)


func _is_bin(item: Node3D) -> bool:
	return item.name.to_lower().begins_with("trashcan")


func _get_category(item: Node3D) -> String:
	var n := item.name.to_lower()

	if n.begins_with("plastic"):
		return "plastic"

	if n.begins_with("paper"):
		return "paper"

	if n.begins_with("metallic") or n.begins_with("metal"):
		return "metallic"

	if n.begins_with("organic"):
		return "organic"

	return ""


func _get_bin_category(bin: Node3D) -> String:
	var n := bin.name.to_lower()

	if n.contains("plastic"):
		return "plastic"

	if n.contains("paper"):
		return "paper"

	if n.contains("organic"):
		return "organic"

	if n.contains("metallic") or n.contains("metal"):
		return "metallic"

	return ""


func _pick_up(item: Node3D) -> void:
	held_item = item

	item.reparent(player, true)

	# Position the waste in front of the player.
	item.position = Vector3(0.0, 1.2, -1.0)
	item.rotation = Vector3.ZERO

	# The counter (top-left) shows what you are carrying.
	_update_ui()

func _try_drop(bin: Node3D) -> void:
	var waste_category := _get_category(held_item)
	var bin_category := _get_bin_category(bin)

	if waste_category == bin_category:
		_correct_drop(bin)
	else:
		reputation += POINTS_WRONG
		_show_status("WRONG BIN!  -5 REP", Color(1.0, 0.3, 0.3), 1.5)
		_update_ui()


func _correct_drop(bin: Node3D) -> void:
	var item := held_item

	held_item = null

	reputation += POINTS_CORRECT
	sorted_waste += 1

	_show_status("SORTED!  +5 REP", Color(0.3, 1.0, 0.4), 1.5)

	# Put the item into the bin, then remove it.
	item.reparent(self, true)

	var target_position := bin.global_position + Vector3.UP * 0.8

	var tween := item.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(
		item,
		"global_position",
		target_position,
		0.35
	)

	tween.tween_callback(item.queue_free)

	_update_ui()

	if sorted_waste >= total_waste:
		await get_tree().create_timer(0.5).timeout
		_show_status("WASTE MANAGEMENT COMPLETE!\n+%d REP" % reputation, Color(0.3, 1.0, 0.4), 4.0)


func _count_waste() -> void:
	total_waste = 0

	for child in get_children():
		if child is Node3D and _is_waste(child as Node3D):
			total_waste += 1


# ---------------------------------------------------------------------------
# HUD
# ---------------------------------------------------------------------------
func _make_hud_label() -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	return label


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)

	# Counter: top-left
	counter_label = _make_hud_label()
	counter_label.position = Vector2(25, 25)
	counter_label.visible = false
	layer.add_child(counter_label)

	# Status messages (SORTED / WRONG / COMPLETE): top-center
	status_label = _make_hud_label()
	status_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	status_label.offset_top = 40
	status_label.offset_bottom = 110
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.modulate.a = 0.0
	layer.add_child(status_label)

	# Pickup / drop hint: bottom-center
	hint_label = _make_hud_label()
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint_label.offset_top = -90
	hint_label.offset_bottom = -50
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.visible = false
	layer.add_child(hint_label)


func _show_status(text: String, color: Color, hold_time: float) -> void:
	if status_tween != null:
		status_tween.kill()
	
	status_label.text = text
	status_label.modulate = color

	status_tween = create_tween()
	status_tween.tween_interval(hold_time)
	status_tween.tween_property(status_label, "modulate:a", 0.0, 0.5)


func _update_hint() -> void:
	if player == null:
		return

	if held_item == null:
		var waste := _get_nearest_waste()

		if waste != null:
			hint_label.text = "Press E - Pick up waste"
			hint_label.visible = true
		else:
			hint_label.visible = false
	else:
		var bin := _get_nearest_bin()

		if bin != null:
			var category := _get_bin_category(bin)
			hint_label.text = "Press E - Put in %s bin" % category.to_upper()
			hint_label.visible = true
		else:
			hint_label.text = "Carry waste to the correct bin"
			hint_label.visible = true


func _update_ui() -> void:
	if counter_label == null:
		return

	var text: String = "WASTE MANAGEMENT\nSorted: %d / %d\nReputation: %d" % [
		sorted_waste,
		total_waste,
		reputation
	]

	if held_item != null:
		text += "\nCarrying: %s" % _get_category(held_item).to_upper()

	counter_label.text = text
