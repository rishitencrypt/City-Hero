extends Node3D

# true = hold the last frame of the "die" animation as the lying pose.
# false = skip the animation and just rotate the person onto their back.
const USE_DIE_ANIMATION: bool = true

var player_inside: bool = false
var patient_found: bool = false
var help_called: bool = false

var prompt_panel: PanelContainer = null

@onready var interaction_area: Area3D = $InteractionArea


func _ready() -> void:
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

	_build_prompt()
	play_person_animation()


func _on_body_entered(body: Node3D) -> void:
	if body.name != "Player":
		return

	player_inside = true
	patient_found = true

	if not help_called:
		prompt_panel.visible = true


func _on_body_exited(body: Node3D) -> void:
	if body.name != "Player":
		return

	player_inside = false
	prompt_panel.visible = false


func mark_help_called() -> void:
	help_called = true
	prompt_panel.visible = false


func play_person_animation() -> void:
	var animation_player: AnimationPlayer = get_node_or_null("person/AnimationPlayer") as AnimationPlayer

	if USE_DIE_ANIMATION and animation_player != null and animation_player.has_animation("die"):
		animation_player.play("die")
		animation_player.seek(animation_player.current_animation_length, true)
		animation_player.pause()
	else:
		var person: Node3D = get_node_or_null("person") as Node3D
		if person != null:
			person.rotation_degrees.x = -90.0


func _build_prompt() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 6
	add_child(layer)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_bottom", 60)
	layer.add_child(margin)

	prompt_panel = PanelContainer.new()
	prompt_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	prompt_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_panel.visible = false

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.set_corner_radius_all(6)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	prompt_panel.add_theme_stylebox_override("panel", style)
	margin.add_child(prompt_panel)

	var label: Label = Label.new()
	label.text = "SOMEONE NEEDS HELP\nPress P and call 102"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color.WHITE)
	prompt_panel.add_child(label)
