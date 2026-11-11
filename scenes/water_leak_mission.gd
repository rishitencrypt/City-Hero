
extends Area3D

signal mission_completed(mission_id: String)
signal reputation_awarded(amount: int)

@export var mission_id: String = "water_conservation"
@export var reputation_reward: int = 20
@export var water_effect: Node3D
@export var effect_template: Node3D
@export var effect_offset: Vector3 = Vector3(0.0, 0.8, 0.0)

@export_group("Interaction")
@export var interact_action: StringName = &"interact"
@export var handle_interact_key: bool = true
@export var player_group: String = ""
@export var interaction_radius: float = 3.0
@export var show_prompt: bool = true
@export var prompt_text: String = "Press [E] to fix the leak"

@export_group("Integration hooks (fill in after checking your scripts)")
@export var reputation_autoload: String = ""
@export var reputation_method: String = "add_reputation"
@export var tracker_autoload: String = ""
@export var tracker_method: String = "complete_mission"

@onready var leak_audio: AudioStreamPlayer = get_node_or_null("LeakAudio") as AudioStreamPlayer

var completed: bool = false
var _reward_given: bool = false
var _player_in_range: bool = false
var _puzzle: WaterPuzzleUI
var _prompt: Label3D


func _ready() -> void:
	_ensure_collision_shape()

	if leak_audio != null:
		leak_audio.stop()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	_puzzle = WaterPuzzleUI.new()
	_puzzle.success_message = "Leak fixed! Water flow restored. +%d Reputation" % reputation_reward
	add_child(_puzzle)
	_puzzle.puzzle_solved.connect(_on_puzzle_solved)
	_puzzle.puzzle_closed.connect(_on_puzzle_closed)

	_make_prompt()
	_setup_leak()

	if handle_interact_key and not InputMap.has_action(interact_action):
		push_warning("WaterLeakMission: input action '%s' does not exist." % interact_action)


func interact() -> void:
	if completed or _puzzle.is_open:
		return
	_puzzle.open()


func _unhandled_input(event: InputEvent) -> void:
	if not handle_interact_key or completed or not _player_in_range or _puzzle.is_open:
		return

	if InputMap.has_action(interact_action) and event.is_action_pressed(interact_action):
		get_viewport().set_input_as_handled()
		interact()


func _on_body_entered(body: Node3D) -> void:
	if not _is_player(body):
		return

	_player_in_range = true

	if not completed:
		_prompt.visible = show_prompt

		if water_effect != null:
			water_effect.visible = true
			_set_leak_running(water_effect, true)

		if leak_audio != null and not leak_audio.playing:
			leak_audio.play()


func _on_body_exited(body: Node3D) -> void:
	if not _is_player(body):
		return

	_player_in_range = false
	_prompt.visible = false

	if not completed:
		if water_effect != null:
			_set_leak_running(water_effect, false)
			water_effect.visible = false

		if leak_audio != null:
			leak_audio.stop()


func _is_player(body: Node) -> bool:
	if player_group != "":
		return body.is_in_group(player_group)
	return body is CharacterBody3D


func _on_puzzle_solved() -> void:
	if completed:
		return

	completed = true
	_stop_leak()
	_award_reputation()
	_notify_tracker()
	_prompt.visible = false
	set_deferred("monitoring", false)
	mission_completed.emit(mission_id)


func _on_puzzle_closed() -> void:
	_prompt.visible = show_prompt and _player_in_range and not completed


func _award_reputation() -> void:
	if _reward_given:
		return

	_reward_given = true
	reputation_awarded.emit(reputation_reward)

	if reputation_autoload == "":
		push_warning("WaterLeakMission: reputation_autoload not set.")
		return

	var target: Node = get_node_or_null("/root/" + reputation_autoload)

	if target != null and target.has_method(reputation_method):
		target.call(reputation_method, reputation_reward)
	else:
		push_warning("WaterLeakMission: could not call %s.%s()" % [reputation_autoload, reputation_method])


func _notify_tracker() -> void:
	if tracker_autoload == "":
		return

	var target: Node = get_node_or_null("/root/" + tracker_autoload)

	if target != null and target.has_method(tracker_method):
		target.call(tracker_method, mission_id)
	else:
		push_warning("WaterLeakMission: could not call %s.%s()" % [tracker_autoload, tracker_method])


func _setup_leak() -> void:
	if water_effect == null:
		water_effect = get_node_or_null("water") as Node3D

	if water_effect == null:
		push_warning("WaterLeakMission: water particle not found.")
		return

	water_effect.process_mode = Node.PROCESS_MODE_ALWAYS
	water_effect.visible = false
	_set_leak_running(water_effect, false)


func _stop_leak() -> void:
	if water_effect != null:
		_set_leak_running(water_effect, false)
		water_effect.visible = false

	if leak_audio != null:
		leak_audio.stop()


func _set_leak_running(node: Node, running: bool) -> void:
	if node is GPUParticles3D:
		(node as GPUParticles3D).emitting = running
	elif node is CPUParticles3D:
		(node as CPUParticles3D).emitting = running
	elif node is AudioStreamPlayer3D:
		var audio := node as AudioStreamPlayer3D
		if running and not audio.playing:
			audio.play()
		elif not running:
			audio.stop()

	for child in node.get_children():
		_set_leak_running(child, running)


func _ensure_collision_shape() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			return

	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = interaction_radius
	collision.shape = sphere
	add_child(collision)


func _make_prompt() -> void:
	_prompt = Label3D.new()
	_prompt.text = prompt_text
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	_prompt.pixel_size = 0.006
	_prompt.font_size = 48
	_prompt.outline_size = 12
	_prompt.position = Vector3(0.0, 1.8, 0.0)
	_prompt.visible = false
	add_child(_prompt)
