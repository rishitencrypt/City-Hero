extends Area3D

const CORRECT_POINTS: int = 10
const WRONG_POINTS: int = -5
const CAR_MOVE_DISTANCE: float = 12.0
const CAR_MOVE_TIME: float = 3.0

const USE_EMOJI: bool = true
const REACTION_HEIGHT: float = 2.5
const FREEZE_PLAYER: bool = true

const QUESTIONS: Array = [
	{
		"text": "A pedestrian is waiting at a crossing. What should you do?",
		"answers": ["STOP TRAFFIC", "SPEED UP", "IGNORE THEM"],
		"correct": 0
	},
	{
		"text": "An emergency vehicle is approaching. What should you do?",
		"answers": ["KEEP DRIVING", "CLEAR THE WAY", "BLOCK THE ROAD"],
		"correct": 1
	},
	{
		"text": "Traffic is building up at the junction. What should you do?",
		"answers": ["MANAGE THE SIGNAL", "IGNORE IT", "DRIVE FASTER"],
		"correct": 0
	}
]

var player_inside: bool = false
var quiz_open: bool = false
var task_complete: bool = false
var answering: bool = false
var question_index: int = 0
var reputation: int = 0

var player_ref: Node = null
var saved_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var original_car_positions: Dictionary = {}

var hint_layer: CanvasLayer = null
var hint_label: Label = null
var quiz_layer: CanvasLayer = null
var title_label: Label = null
var progress_label: Label = null
var question_label: Label = null
var rep_label: Label = null
var button_box: VBoxContainer = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_hint()
	_update_hint()


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		player_inside = true
		player_ref = body
		_update_hint()


func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		player_inside = false
		_update_hint()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if player_inside and not quiz_open:
			open_quiz()
			get_viewport().set_input_as_handled()


func _build_hint() -> void:
	hint_layer = CanvasLayer.new()
	hint_layer.layer = 5
	add_child(hint_layer)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_bottom", 60)
	hint_layer.add_child(margin)

	hint_label = Label.new()
	hint_label.text = "Press E - Traffic Control"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.size_flags_vertical = Control.SIZE_SHRINK_END
	hint_label.add_theme_font_size_override("font_size", 22)
	hint_label.add_theme_color_override("font_color", Color.WHITE)
	hint_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hint_label.add_theme_constant_override("outline_size", 6)
	margin.add_child(hint_label)


func _update_hint() -> void:
	if hint_label != null:
		hint_label.visible = player_inside and not quiz_open


func open_quiz() -> void:
	quiz_open = true
	question_index = 0
	reputation = 0
	answering = false

	save_car_positions()

	saved_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if FREEZE_PLAYER and player_ref != null:
		player_ref.process_mode = Node.PROCESS_MODE_DISABLED

	_build_quiz_ui()
	_show_question()
	_update_hint()


func close_quiz(completed: bool) -> void:
	quiz_open = false
	answering = false

	if completed:
		reset_cars()

	if quiz_layer != null:
		quiz_layer.queue_free()
		quiz_layer = null

	if FREEZE_PLAYER and player_ref != null:
		player_ref.process_mode = Node.PROCESS_MODE_INHERIT

	Input.mouse_mode = saved_mouse_mode
	_update_hint()


func _build_quiz_ui() -> void:
	quiz_layer = CanvasLayer.new()
	quiz_layer.layer = 10
	add_child(quiz_layer)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quiz_layer.add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0.7)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", panel_style)

	center.add_child(panel)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	title_label = _make_label("TRAFFIC CONTROL", 28)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_label)

	progress_label = _make_label("", 18)
	progress_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	box.add_child(progress_label)

	question_label = _make_label("", 22)
	question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(question_label)

	button_box = VBoxContainer.new()
	button_box.add_theme_constant_override("separation", 8)
	box.add_child(button_box)

	rep_label = _make_label("", 18)
	box.add_child(rep_label)

	_update_reputation_label()


func _make_label(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	return label


func _make_button(text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 40)
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.6))

	button.add_theme_stylebox_override("normal", _button_style(0.12))
	button.add_theme_stylebox_override("hover", _button_style(0.28))
	button.add_theme_stylebox_override("pressed", _button_style(0.40))
	button.add_theme_stylebox_override("disabled", _button_style(0.12))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	return button


func _button_style(alpha: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, alpha)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	return style


func _clear_buttons() -> void:
	for child in button_box.get_children():
		button_box.remove_child(child)
		child.queue_free()


func _update_reputation_label() -> void:
	if rep_label != null:
		rep_label.text = "Reputation: %d" % reputation


func _show_question() -> void:
	answering = false
	_clear_buttons()

	var q: Dictionary = QUESTIONS[question_index]
	progress_label.text = "Question %d / %d" % [question_index + 1, QUESTIONS.size()]
	question_label.text = q["text"]

	var answers: Array = q["answers"]

	for i in range(answers.size()):
		var button: Button = _make_button(answers[i])
		button.pressed.connect(_on_answer_pressed.bind(i))
		button_box.add_child(button)

	_update_reputation_label()


func _on_answer_pressed(answer_index: int) -> void:
	if answering or not quiz_open:
		return

	answering = true

	var q: Dictionary = QUESTIONS[question_index]
	var is_correct: bool = answer_index == int(q["correct"])

	if is_correct:
		reputation += CORRECT_POINTS
		move_cars()
	else:
		reputation += WRONG_POINTS

	show_reaction(is_correct)
	_update_reputation_label()

	for child in button_box.get_children():
		if child is Button:
			(child as Button).disabled = true

	await get_tree().create_timer(1.0).timeout

	if not quiz_open:
		return

	question_index += 1

	if question_index >= QUESTIONS.size():
		_show_complete()
	else:
		_show_question()


func _show_complete() -> void:
	task_complete = true
	answering = false
	_clear_buttons()

	title_label.text = "TRAFFIC TASK COMPLETE"
	progress_label.text = ""
	question_label.text = "Final reputation: %d" % reputation
	_update_reputation_label()

	var close_button: Button = _make_button("CLOSE")
	close_button.pressed.connect(close_quiz.bind(true))
	button_box.add_child(close_button)


func move_cars() -> void:
	var cars: Array[Node] = get_tree().get_nodes_in_group("traffic_cars")

	for node in cars:
		var car: Node3D = node as Node3D

		if car == null:
			continue

		var direction: Vector3 = car.global_transform.basis.z
		var target: Vector3 = car.global_position + direction * CAR_MOVE_DISTANCE

		var tween: Tween = car.create_tween()

		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_IN_OUT)

		tween.tween_property(
			car,
			"global_position",
			target,
			CAR_MOVE_TIME
		)


func save_car_positions() -> void:
	original_car_positions.clear()

	var cars: Array[Node] = get_tree().get_nodes_in_group("traffic_cars")

	for node in cars:
		var car: Node3D = node as Node3D

		if car == null:
			continue

		original_car_positions[car] = car.global_position


func reset_cars() -> void:
	for car in original_car_positions:
		if not is_instance_valid(car):
			continue

		var target_position: Vector3 = original_car_positions[car]

		var tween: Tween = car.create_tween()

		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_IN_OUT)

		tween.tween_property(
			car,
			"global_position",
			target_position,
			2.0
		)


func show_reaction(good: bool) -> void:
	var cars: Array[Node] = get_tree().get_nodes_in_group("traffic_cars")

	var color: Color = Color(0.2, 0.9, 0.3) if good else Color(0.95, 0.2, 0.2)
	var text: String

	if USE_EMOJI:
		text = "👍" if good else "👎"
	else:
		text = "GOOD" if good else "WRONG"

	for node in cars:
		var car: Node3D = node as Node3D

		if car == null:
			continue

		var label: Label3D = Label3D.new()
		label.text = text
		label.font_size = 96
		label.pixel_size = 0.01
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.modulate = color

		if USE_EMOJI:
			label.outline_size = 0
		else:
			label.outline_size = 12
			label.outline_modulate = Color(0, 0, 0)

		car.add_child(label)

		var s: Vector3 = car.global_transform.basis.get_scale()
		var sx: float = maxf(absf(s.x), 0.001)
		var sy: float = maxf(absf(s.y), 0.001)
		var sz: float = maxf(absf(s.z), 0.001)

		label.scale = Vector3(1.0 / sx, 1.0 / sy, 1.0 / sz)
		label.global_position = car.global_position + Vector3.UP * REACTION_HEIGHT

		var start_pos: Vector3 = label.position
		var end_pos: Vector3 = start_pos + Vector3(0.0, 1.0 / sy, 0.0)

		var tween: Tween = label.create_tween()
		tween.set_parallel(true)
		tween.tween_property(label, "position", end_pos, 1.0)
		tween.tween_property(label, "modulate:a", 0.0, 0.5).set_delay(0.5)
		tween.chain().tween_callback(label.queue_free)
