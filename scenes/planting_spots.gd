extends Node3D

const PLANT_DISTANCE: float = 4.5
const PLANT_POINTS: int = 5

var reputation: int = 0

var player: Node3D = null
var spots: Array[Node3D] = []
var planted: Array[Node3D] = []
var message_id: int = 0
var message_showing: bool = false

var panel: PanelContainer = null
var message_label: Label = null


func _ready() -> void:
	for child in get_children():
		if child is Node3D:
			var spot := child as Node3D
			spots.append(spot)

			var tree_model := _find_tree_model(spot)
			if tree_model == null:
				push_warning("%s has no tree model child." % spot.name)
			else:
				tree_model.visible = false

	_build_ui()


func _process(_delta: float) -> void:
	if player == null:
		player = get_tree().current_scene.find_child("Player", true, false) as Node3D

	if player == null:
		return

	var spot: Node3D = _get_nearest_spot()

	if spot != null:
		if not message_showing:
			message_label.text = "PLANT A TREE?\nPress E to plant"
			panel.visible = true

		if Input.is_action_just_pressed("interact"):
			_plant(spot)

	elif not message_showing:
		panel.visible = false


func _get_nearest_spot() -> Node3D:
	var nearest: Node3D = null
	var nearest_distance: float = PLANT_DISTANCE

	for spot in spots:
		if planted.has(spot):
			continue

		var distance: float = player.global_position.distance_to(spot.global_position)

		if distance <= nearest_distance:
			nearest_distance = distance
			nearest = spot

	return nearest


func _find_tree_model(spot: Node3D) -> Node3D:
	for child in spot.get_children():
		if child is Node3D and not child is CollisionShape3D:
			return child as Node3D

	return null


func _plant(spot: Node3D) -> void:
	if planted.has(spot):
		return

	planted.append(spot)

	var tree_model := _find_tree_model(spot)

	if tree_model != null:
		tree_model.visible = true

	reputation += PLANT_POINTS

	_show_message(
		"TREE PLANTED!\n+%d Reputation" % PLANT_POINTS,
		1.5
	)

	if planted.size() >= spots.size():
		await get_tree().create_timer(1.5).timeout

		_show_message(
			"GREENERY RESTORED!\n%d/%d Trees Planted"
			% [planted.size(), spots.size()],
			3.0
		)


func _show_message(text: String, time: float) -> void:
	message_id += 1
	var id: int = message_id

	message_showing = true
	message_label.text = text
	panel.visible = true

	await get_tree().create_timer(time).timeout

	if id == message_id:
		message_showing = false


func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 6
	add_child(layer)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_bottom", 60)
	layer.add_child(margin)

	panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_END
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.set_corner_radius_all(6)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 12
	style.content_margin_bottom = 12

	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)

	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 20)
	message_label.add_theme_color_override("font_color", Color.WHITE)

	panel.add_child(message_label)
