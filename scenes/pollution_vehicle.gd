extends Node3D

const REPORT_POINTS: int = 10
const SUCCESS_TIME: float = 2.0

var reputation: int = 0

var player_inside: bool = false
var reported: bool = false
var showing_success: bool = false

@onready var smoke: GPUParticles3D = $Smoke
@onready var interaction_area: Area3D = $InteractionArea
@onready var engine_audio: AudioStreamPlayer = $EngineAudio
var ui_layer: CanvasLayer = null
var panel: PanelContainer = null
var message_label: Label = null


func _ready() -> void:
	_build_ui()
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return

	player_inside = true

	if not reported:
		if engine_audio.stream != null and not engine_audio.playing:
			engine_audio.play()

		message_label.text = "EXCESSIVE SMOKE DETECTED\nCall 133 to report this vehicle"
		panel.visible = true


func _on_body_exited(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return

	player_inside = false
	engine_audio.stop()

	if not showing_success:
		panel.visible = false


func _input(event: InputEvent) -> void:
	pass


func _report_vehicle() -> void:
	if reported:
		return

	reported = true
	reputation += REPORT_POINTS

	smoke.emitting = false
	engine_audio.stop()

	interaction_area.set_deferred("monitoring", false)

	showing_success = true
	message_label.text = "VEHICLE REPORTED!\n+%d Reputation" % REPORT_POINTS
	panel.visible = true

	await get_tree().create_timer(SUCCESS_TIME).timeout

	panel.visible = false
	showing_success = false

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 6
	add_child(ui_layer)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_bottom", 60)
	ui_layer.add_child(margin)

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
func report_from_call() -> void:
	if reported:
		return

	_report_vehicle()
