extends Node3D

enum State {
	IDLE,
	AMBULANCE_ENROUTE,
	TREATING,
	AMBULANCE_LEAVING,
	FIRE_PENDING,
	FIRE_ACTIVE,
	FIRETRUCK_ENROUTE,
	EXTINGUISHING,
	FIRETRUCK_LEAVING,
	DONE
}

const TREATMENT_TIME: float = 4.0
const FIRE_AFTER_DEPARTURE: float = 2.0
const DEBRIS_TIME: float = 40.0
const DEBRIS_READY_DELAY: float = 4.5
const CLEAR_DURATION: float = 2.0
const INTERACT_DISTANCE: float = 3.0
const PIECES_PER_PILE: int = 9
const PILE_RADIUS: float = 1.3
const FACE_BUILDING_ON_ARRIVAL: bool = true
const BUILD_SHOVEL_MODEL: bool = true

const POINTS_AMBULANCE: int = 15
const POINTS_SHOVEL: int = 5
const POINTS_DEBRIS: int = 5
const POINTS_FIRE: int = 20

const COLOR_INFO: Color = Color(0.642, 0.23, 0.167, 1.0)
const COLOR_SUCCESS: Color = Color(0.30, 0.78, 0.40)
const COLOR_WARNING: Color = Color(0.95, 0.60, 0.20)
const COLOR_ALERT: Color = Color(0.90, 0.30, 0.30)

var state: State = State.IDLE
var reputation: int = 0
var task_complete: bool = false
var awarded: Dictionary = {}

var ambulance_called: bool = false
var fire_started: bool = false
var firetruck_called: bool = false
var firetruck_dispatched: bool = false
var shovel_collected: bool = false
var debris_ready: bool = false
var road_cleared: bool = false
var hold_blocked: bool = false

var timer_left: float = 0.0
var timer_running: bool = false
var message_id: int = 0

var piles: Array[Node3D] = []
var cleared_piles: Array[Node3D] = []
var pile_progress: Dictionary = {}
var debris_mesh: BoxMesh = null
var debris_materials: Array[StandardMaterial3D] = []

var player: Node3D = null
var ambulance: Node3D = null
var firetruck: Node3D = null
var shovel: Node3D = null
var debris_root: Node3D = null
var drop_point: Node3D = null
var ambulance_route: Node3D = null
var firetruck_route: Node3D = null

var message_panel: PanelContainer = null
var message_label: Label = null
var message_style: StyleBoxFlat = null
var prompt_panel: PanelContainer = null
var prompt_label: Label = null
var clear_bar: ProgressBar = null
var hud_panel: PanelContainer = null
var hud_label: Label = null

@onready var medical: Node3D = $MedicalEmergency
@onready var person: Node3D = $MedicalEmergency/person
@onready var fire: Node3D = $BuildingFire/FireEffect
@onready var fire_blast_audio: AudioStreamPlayer = $FireBlastAudio

func _ready() -> void:
	ambulance = _find_vehicle("Ambulance")
	firetruck = _find_vehicle("Firetruck")
	shovel = get_node_or_null("Shovel") as Node3D
	debris_root = get_node_or_null("DebrisPiles") as Node3D
	drop_point = get_node_or_null("DebrisDropPoint") as Node3D
	ambulance_route = get_node_or_null("AmbulanceRoute") as Node3D
	firetruck_route = get_node_or_null("FiretruckRoute") as Node3D

	if debris_root != null:
		for child in debris_root.get_children():
			if child is Node3D:
				piles.append(child as Node3D)
		debris_root.visible = false

	_make_debris_resources()

	if shovel != null:
		if BUILD_SHOVEL_MODEL:
			_build_shovel_model()
		shovel.visible = false

	_set_fire(false)
	_build_ui()
	_connect_vehicle(ambulance, "Ambulance", _on_ambulance_arrived, _on_ambulance_departed)
	_connect_vehicle(firetruck, "Firetruck", _on_firetruck_arrived, _on_firetruck_departed)
	_warn_about_missing_nodes()


func _process(delta: float) -> void:
	if player == null:
		player = get_tree().current_scene.find_child("Player", true, false) as Node3D

	if state == State.FIRE_ACTIVE and not road_cleared and player != null:
		_update_debris(delta)
	else:
		_hide_prompt()

	_update_hud()


# ---------------------------------------------------------------------------
# PHONE CALLS
# ---------------------------------------------------------------------------
func call_number(number: String) -> String:
	match number:
		"102":
			return _call_ambulance()
		"101":
			return _call_fire_brigade()

	return ""


func _call_ambulance() -> String:
	if ambulance == null:
		return "CALL FAILED\nAmbulance node not found."

	if not ambulance.has_method("dispatch"):
		return "CALL FAILED\nAmbulance has no script attached."

	if not bool(medical.get("patient_found")):
		return "No emergency reported yet.\nFind the patient first."

	if ambulance_called:
		return "An ambulance has already been dispatched."

	var points: Array = _route_points(ambulance_route)
	if points.is_empty():
		return "CALL FAILED\nAmbulanceRoute has no Marker3D children."

	var parking: Vector3 = points[points.size() - 1]
	if parking.distance_to(person.global_position) < 2.5:
		push_warning("Last AmbulanceRoute marker is very close to the patient.")

	ambulance_called = true
	state = State.AMBULANCE_ENROUTE
	medical.call("mark_help_called")
	ambulance.call("dispatch", points)
	_show_message("AMBULANCE DISPATCHED", 3.0, COLOR_INFO)

	return "CALLING AMBULANCE...\nAmbulance dispatched!"


func _call_fire_brigade() -> String:
	if firetruck == null:
		return "CALL FAILED\nFiretruck node not found."

	if not firetruck.has_method("dispatch"):
		return "CALL FAILED\nFiretruck has no script attached."

	if not fire_started:
		return "No fire reported yet."

	if firetruck_dispatched or (firetruck_called and not road_cleared):
		return "Fire brigade has already been notified."

	firetruck_called = true

	if road_cleared:
		_dispatch_firetruck()
		return "CALLING FIRE SERVICES...\nFire brigade dispatched!"

	_show_message("FIRE BRIGADE NOTIFIED\nCLEAR THE ROAD", 4.0, COLOR_WARNING)
	return "CALLING FIRE SERVICES...\nFire brigade notified.\nClear the road so they can get through."


# ---------------------------------------------------------------------------
# AMBULANCE SEQUENCE
# ---------------------------------------------------------------------------
func _on_ambulance_arrived() -> void:
	if state != State.AMBULANCE_ENROUTE:
		return

	state = State.TREATING
	_award("ambulance", POINTS_AMBULANCE)
	_show_message("AMBULANCE ARRIVED\nPatient is receiving medical assistance.", 4.0, COLOR_SUCCESS)
	_treat_patient()


func _treat_patient() -> void:
	await get_tree().create_timer(TREATMENT_TIME).timeout

	if state != State.TREATING:
		return

	person.visible = false
	state = State.AMBULANCE_LEAVING
	_show_message("PATIENT SAFE\nThe ambulance is heading to the hospital.", 4.0, COLOR_SUCCESS)

	if ambulance.has_method("depart"):
		ambulance.call("depart")
	else:
		push_warning("Ambulance script has no depart() method.")
		_on_ambulance_departed()


func _on_ambulance_departed() -> void:
	if state != State.AMBULANCE_LEAVING:
		return

	state = State.FIRE_PENDING
	_start_fire_later()


func _start_fire_later() -> void:
	await get_tree().create_timer(FIRE_AFTER_DEPARTURE).timeout

	if state == State.FIRE_PENDING:
		start_fire()


func start_fire() -> void:
	if fire_started:
		return

	fire_started = true
	state = State.FIRE_ACTIVE
	_set_fire(true)

	if fire_blast_audio.stream != null:
		fire_blast_audio.play()

	if debris_root != null:
		debris_root.visible = true

	if shovel != null:
		shovel.visible = true
	else:
		shovel_collected = true

	if piles.is_empty():
		road_cleared = true
		debris_ready = true
	else:
		_spawn_debris()

	_show_message("BUILDING FIRE!\nDebris is falling. Find the shovel and clear the road.", 5.0, COLOR_ALERT)

# ---------------------------------------------------------------------------
# DEBRIS, SHOVEL AND ROAD CLEARING
# ---------------------------------------------------------------------------
func _spawn_debris() -> void:
	for pile in piles:
		_spawn_pile_pieces(pile)

	await get_tree().create_timer(DEBRIS_READY_DELAY).timeout

	if state == State.FIRE_ACTIVE:
		debris_ready = true


func _spawn_pile_pieces(pile: Node3D) -> void:
	for child in pile.get_children():
		if child is Node3D:
			(child as Node3D).visible = false

	pile.visible = true
	var source: Vector3 = _debris_source(pile)

	for i in range(PIECES_PER_PILE):
		var piece: MeshInstance3D = MeshInstance3D.new()
		piece.mesh = debris_mesh
		piece.material_override = debris_materials[randi() % debris_materials.size()]

		var piece_size: float = randf_range(0.73, 1.5)
		piece.scale = Vector3(
			piece_size * randf_range(0.8, 1.4),
			piece_size * randf_range(0.5, 1.0),
			piece_size * randf_range(0.8, 1.4)
		)
		piece.visible = false
		pile.add_child(piece)

		var start: Vector3 = source + Vector3(
			randf_range(-1.0, 1.0),
			randf_range(0.0, 1.5),
			randf_range(-1.0, 1.0)
		)
		var target: Vector3 = _landing_point(pile, piece_size * 0.3)

		piece.global_position = start
		piece.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)

		var duration: float = randf_range(0.7, 1.1)
		var spin: Vector3 = piece.rotation + Vector3(
			randf_range(-4.0, 4.0),
			randf_range(-4.0, 4.0),
			randf_range(-4.0, 4.0)
		)

		var tween: Tween = create_tween()
		tween.tween_interval(randf_range(0.0, 2.5))
		tween.tween_callback(piece.show)
		tween.tween_method(_move_piece.bind(piece, start, target), 0.0, 1.0, duration)
		tween.parallel().tween_property(piece, "rotation", spin, duration)


func _move_piece(t: float, piece: Node3D, start: Vector3, target: Vector3) -> void:
	if not is_instance_valid(piece):
		return

	piece.global_position = Vector3(
		lerpf(start.x, target.x, t),
		lerpf(start.y, target.y, t * t),
		lerpf(start.z, target.z, t)
	)



func _landing_point(pile: Node3D, height: float) -> Vector3:
	for attempt in range(4):
		var angle: float = randf() * TAU
		var radius: float = sqrt(randf()) * PILE_RADIUS

		var point: Vector3 = pile.global_position + Vector3(
			cos(angle) * radius,
			0.0,
			sin(angle) * radius
		)

		if player == null or _flat_distance(player.global_position, point) > 1.5:
			return point + Vector3.UP * height

	return pile.global_position + Vector3.UP * height



func _debris_source(pile: Node3D) -> Vector3:
	if drop_point != null:
		return drop_point.global_position

	return pile.global_position + Vector3(0.0, 9.0, 0.0)


func _update_debris(delta: float) -> void:
	_update_timer(delta)

	var held: bool = Input.is_action_pressed("interact")
	var pressed: bool = Input.is_action_just_pressed("interact")

	if not held:
		hold_blocked = false

	var near_shovel: bool = false
	if not shovel_collected and shovel != null:
		near_shovel = _flat_distance(player.global_position, shovel.global_position) <= INTERACT_DISTANCE

	var pile: Node3D = null
	if debris_ready:
		pile = _get_nearest_pile()

	var clearing: Node3D = null

	if near_shovel:
		_show_prompt("[E]  PICK UP SHOVEL")
		if pressed:
			_collect_shovel()
	elif pile != null and shovel_collected:
		_show_prompt("HOLD [E]  CLEAR DEBRIS")
		if held and not hold_blocked:
			clearing = pile
	elif pile != null:
		_hide_prompt()
		if pressed:
			_show_message("FIND THE SHOVEL FIRST", 2.0, COLOR_WARNING)
	else:
		_hide_prompt()

	_update_clearing(delta, clearing)


func _update_timer(delta: float) -> void:
	if not timer_running:
		if shovel_collected and debris_ready and not road_cleared:
			timer_running = true
			timer_left = DEBRIS_TIME
		return

	timer_left -= delta

	if timer_left <= 0.0:
		timer_left = DEBRIS_TIME
		_show_message("TIME UP\nThe road is still blocked. Try again!", 3.0, COLOR_WARNING)


func _collect_shovel() -> void:
	if shovel_collected:
		return

	shovel_collected = true
	hold_blocked = true
	shovel.visible = false
	_award("shovel", POINTS_SHOVEL)
	_show_message("SHOVEL COLLECTED", 2.5, COLOR_SUCCESS)


func _update_clearing(delta: float, target: Node3D) -> void:
	for pile in piles:
		if cleared_piles.has(pile):
			continue

		var progress: float = pile_progress.get(pile, 0.0)

		if pile == target:
			progress += delta / CLEAR_DURATION
		else:
			progress = maxf(progress - delta / CLEAR_DURATION * 0.5, 0.0)

		pile_progress[pile] = progress
		pile.scale = Vector3.ONE * lerpf(1.0, 0.5, minf(progress, 1.0))

		if pile == target:
			clear_bar.value = progress
			clear_bar.visible = true

			if progress >= 1.0:
				_clear_pile(pile)
				clear_bar.visible = false
				return

	if target == null:
		clear_bar.visible = false


func _clear_pile(pile: Node3D) -> void:
	if cleared_piles.has(pile):
		return

	cleared_piles.append(pile)
	pile.visible = false
	pile.scale = Vector3.ONE
	_award("debris_%d" % piles.find(pile), POINTS_DEBRIS)

	var counter: String = "ROAD CLEARED: %d/%d" % [cleared_piles.size(), piles.size()]

	if cleared_piles.size() >= piles.size():
		road_cleared = true
		timer_running = false
		_show_message(counter + "\nThe fire brigade can get through.", 3.0, COLOR_SUCCESS)
		_dispatch_firetruck()
	else:
		_show_message(counter, 2.0, COLOR_SUCCESS)


func _get_nearest_pile() -> Node3D:
	var nearest: Node3D = null
	var nearest_distance: float = INTERACT_DISTANCE

	for pile in piles:
		if cleared_piles.has(pile):
			continue

		var distance: float = _flat_distance(player.global_position, pile.global_position)

		if distance <= nearest_distance:
			nearest_distance = distance
			nearest = pile

	return nearest


# ---------------------------------------------------------------------------
# FIRETRUCK AND EXTINGUISHING
# ---------------------------------------------------------------------------
func _dispatch_firetruck() -> void:
	if firetruck_dispatched or not firetruck_called or not road_cleared:
		return

	var points: Array = _route_points(firetruck_route)

	if points.is_empty() or not firetruck.has_method("dispatch"):
		push_warning("FiretruckRoute has no Marker3D children or Firetruck has no script.")
		_show_message("FIRETRUCK ROUTE MISSING\nCheck the FiretruckRoute markers.", 4.0, COLOR_ALERT)
		return

	var facing: Variant = null
	if FACE_BUILDING_ON_ARRIVAL:
		facing = fire.global_position

	firetruck_dispatched = true
	state = State.FIRETRUCK_ENROUTE
	firetruck.call("dispatch", points, facing)
	_show_message("FIRE BRIGADE ON ITS WAY", 3.0, COLOR_INFO)


func _on_firetruck_arrived() -> void:
	if state != State.FIRETRUCK_ENROUTE:
		return

	state = State.EXTINGUISHING
	_show_message("FIRE BRIGADE ARRIVED", 2.5, COLOR_INFO)

	if firetruck.has_method("start_spray"):
		firetruck.call("start_spray", fire.global_position)

	_extinguish_fire()


func _extinguish_fire() -> void:
	await get_tree().create_timer(3.0).timeout
	_stop_effect("Flames")
	_stop_effect("Embers")
	_fade_light()

	await get_tree().create_timer(2.0).timeout
	_stop_effect("FlameSmoke")
	_stop_effect("Smoke")

	await get_tree().create_timer(1.0).timeout

	if firetruck.has_method("stop_spray"):
		firetruck.call("stop_spray")

	_finish_mission()

	await get_tree().create_timer(3.0).timeout
	_set_fire(false)


func _finish_mission() -> void:
	if task_complete:
		return

	task_complete = true
	_award("fire", POINTS_FIRE)
	_show_message("FIRE EXTINGUISHED — CITY SAFE", 5.0, COLOR_SUCCESS)

	state = State.FIRETRUCK_LEAVING

	if firetruck.has_method("depart"):
		firetruck.call("depart")
	else:
		push_warning("Firetruck script has no depart() method.")
		_on_firetruck_departed()


func _on_firetruck_departed() -> void:
	if state != State.FIRETRUCK_LEAVING:
		return

	state = State.DONE


func _stop_effect(effect_name: String) -> void:
	var node: Node = fire.find_child(effect_name, true, false)

	if node is GPUParticles3D:
		(node as GPUParticles3D).emitting = false
	elif node is CPUParticles3D:
		(node as CPUParticles3D).emitting = false


func _fade_light() -> void:
	var light: OmniLight3D = fire.find_child("OmniLight3D", true, false) as OmniLight3D

	if light == null:
		return

	var tween: Tween = create_tween()
	tween.tween_property(light, "light_energy", 0.0, 2.5)


# ---------------------------------------------------------------------------
# FIRE EFFECT SWITCH
# ---------------------------------------------------------------------------
func _set_fire(on: bool) -> void:
	fire.visible = on
	_set_effects(fire, on)
	

func _set_effects(node: Node, on: bool) -> void:
	if node is GPUParticles3D:
		var particles: GPUParticles3D = node as GPUParticles3D
		particles.emitting = on
		if on:
			particles.restart()
	elif node is CPUParticles3D:
		var particles_cpu: CPUParticles3D = node as CPUParticles3D
		particles_cpu.emitting = on
		if on:
			particles_cpu.restart()
	elif node is Light3D:
		(node as Light3D).visible = on

	for child in node.get_children():
		_set_effects(child, on)


# ---------------------------------------------------------------------------
# REPUTATION AND HELPERS
# ---------------------------------------------------------------------------
func _award(key: String, points: int) -> bool:
	if awarded.has(key):
		return false

	awarded[key] = true
	reputation += points
	return true


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _find_vehicle(node_name: String) -> Node3D:
	var node: Node = get_parent().get_node_or_null(node_name)

	if node == null:
		node = get_tree().current_scene.find_child(node_name, true, false)

	return node as Node3D


func _connect_vehicle(vehicle: Node3D, vehicle_name: String, arrived_callback: Callable, departed_callback: Callable) -> void:
	if vehicle == null:
		push_warning("%s node was not found under Main." % vehicle_name)
	elif not vehicle.has_signal("reached_destination") or not vehicle.has_signal("departed"):
		push_warning("%s needs the new vehicle script (reached_destination and departed signals)." % vehicle_name)
	else:
		vehicle.connect("reached_destination", arrived_callback)
		vehicle.connect("departed", departed_callback)


func _route_points(route: Node3D) -> Array:
	var points: Array = []

	if route == null:
		return points

	for child in route.get_children():
		if child is Node3D:
			points.append((child as Node3D).global_position)

	return points


func _warn_about_missing_nodes() -> void:
	if ambulance_route == null:
		push_warning("EmergencyResponseTask needs a child Node3D named AmbulanceRoute.")
	if firetruck_route == null:
		push_warning("EmergencyResponseTask needs a child Node3D named FiretruckRoute.")
	if shovel == null:
		push_warning("EmergencyResponseTask needs a child Node3D named Shovel.")
	if debris_root == null:
		push_warning("EmergencyResponseTask needs a child Node3D named DebrisPiles.")
	elif piles.is_empty():
		push_warning("DebrisPiles has no children.")
	if drop_point == null:
		push_warning("No DebrisDropPoint (Marker3D) found. Debris will fall from straight above each pile.")


# ---------------------------------------------------------------------------
# SHOVEL AND DEBRIS MODELS (built from simple low-poly meshes)
# ---------------------------------------------------------------------------
func _build_shovel_model() -> void:
	for child in shovel.get_children():
		if child is Node3D:
			(child as Node3D).visible = false

	var model: Node3D = Node3D.new()
	model.name = "ShovelModel"
	model.scale = Vector3(5, 5,5)
	model.rotation_degrees.z = 10.0
	shovel.add_child(model)

	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_color = Color(0.55, 0.36, 0.18)
	wood.roughness = 0.9

	var metal: StandardMaterial3D = StandardMaterial3D.new()
	metal.albedo_color = Color(0.72, 0.74, 0.78)
	metal.metallic = 0.6
	metal.roughness = 0.45

	var handle: CylinderMesh = CylinderMesh.new()
	handle.top_radius = 0.03
	handle.bottom_radius = 0.03
	handle.height = 1.1
	handle.radial_segments = 6
	handle.rings = 1
	_add_part(model, handle, wood, Vector3(0.0, 1.0, 0.0), Vector3.ZERO)

	var grip: BoxMesh = BoxMesh.new()
	grip.size = Vector3(0.26, 0.05, 0.05)
	_add_part(model, grip, wood, Vector3(0.0, 1.57, 0.0), Vector3.ZERO)

	var socket: CylinderMesh = CylinderMesh.new()
	socket.top_radius = 0.035
	socket.bottom_radius = 0.05
	socket.height = 0.14
	socket.radial_segments = 6
	socket.rings = 1
	_add_part(model, socket, metal, Vector3(0.0, 0.42, 0.0), Vector3.ZERO)

	var blade: BoxMesh = BoxMesh.new()
	blade.size = Vector3(0.30, 0.26, 0.025)
	_add_part(model, blade, metal, Vector3(0.0, 0.22, 0.0), Vector3.ZERO)

	var tip: PrismMesh = PrismMesh.new()
	tip.size = Vector3(0.30, 0.10, 0.025)
	_add_part(model, tip, metal, Vector3(0.0, 0.04, 0.0), Vector3(0.0, 0.0, 180.0))


func _add_part(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, rot_deg: Vector3) -> void:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = pos
	part.rotation_degrees = rot_deg
	parent.add_child(part)


func _make_debris_resources() -> void:
	debris_mesh = BoxMesh.new()
	debris_mesh.size = Vector3.ONE

	for color in [Color(0.30, 0.30, 0.32), Color(0.42, 0.30, 0.22), Color(0.55, 0.55, 0.52)]:
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 1.0
		debris_materials.append(material)


# ---------------------------------------------------------------------------
# UI (built once; toast = top, prompt = bottom, status HUD = top-right)
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 6
	add_child(layer)

	message_style = _make_style(COLOR_INFO)
	message_panel = _make_panel(layer, message_style, true)
	message_label = _make_label(20)
	message_panel.add_child(message_label)

	prompt_panel = _make_panel(layer, _make_style(Color(1, 1, 1, 0.6)), false)
	var prompt_box: VBoxContainer = VBoxContainer.new()
	prompt_box.add_theme_constant_override("separation", 6)
	prompt_panel.add_child(prompt_box)

	prompt_label = _make_label(20)
	prompt_box.add_child(prompt_label)

	clear_bar = ProgressBar.new()
	clear_bar.min_value = 0.0
	clear_bar.max_value = 1.0
	clear_bar.show_percentage = false
	clear_bar.custom_minimum_size = Vector2(240, 10)
	clear_bar.visible = false

	var bar_background: StyleBoxFlat = StyleBoxFlat.new()
	bar_background.bg_color = Color(1, 1, 1, 0.15)
	bar_background.set_corner_radius_all(4)
	var bar_fill: StyleBoxFlat = StyleBoxFlat.new()
	bar_fill.bg_color = COLOR_WARNING
	bar_fill.set_corner_radius_all(4)
	clear_bar.add_theme_stylebox_override("background", bar_background)
	clear_bar.add_theme_stylebox_override("fill", bar_fill)
	prompt_box.add_child(clear_bar)

	var hud_margin: MarginContainer = MarginContainer.new()
	hud_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_margin.add_theme_constant_override("margin_top", 25)
	hud_margin.add_theme_constant_override("margin_right", 25)
	layer.add_child(hud_margin)

	hud_panel = PanelContainer.new()
	hud_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	hud_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_panel.add_theme_stylebox_override("panel", _make_style(COLOR_INFO))
	hud_panel.visible = false
	hud_margin.add_child(hud_panel)

	var hud_box: VBoxContainer = VBoxContainer.new()
	hud_box.add_theme_constant_override("separation", 4)
	hud_panel.add_child(hud_box)

	var hud_title: Label = _make_label(14)
	hud_title.text = "EMERGENCY RESPONSE"
	hud_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_title.add_theme_color_override("font_color", COLOR_INFO)
	hud_box.add_child(hud_title)

	hud_label = _make_label(18)
	hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_box.add_child(hud_label)


func _make_style(accent: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.10, 0.82)
	style.set_corner_radius_all(8)
	style.border_width_left = 5
	style.border_color = accent
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _make_panel(layer: CanvasLayer, style: StyleBoxFlat, at_top: bool) -> PanelContainer:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if at_top:
		margin.add_theme_constant_override("margin_top", 110)
	else:
		margin.add_theme_constant_override("margin_bottom", 90)

	layer.add_child(margin)

	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", style)
	panel.visible = false

	if at_top:
		panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	else:
		panel.size_flags_vertical = Control.SIZE_SHRINK_END

	margin.add_child(panel)
	return panel


func _make_label(font_size: int) -> Label:
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	return label


func _show_message(text: String, time: float, accent: Color = COLOR_INFO) -> void:
	message_id += 1
	var id: int = message_id

	message_style.border_color = accent
	message_label.text = text
	message_panel.visible = true

	await get_tree().create_timer(time).timeout

	if id == message_id:
		message_panel.visible = false


func _show_prompt(text: String) -> void:
	prompt_label.text = text
	prompt_panel.visible = true


func _hide_prompt() -> void:
	prompt_panel.visible = false
	clear_bar.visible = false


func _update_hud() -> void:
	var visible_now: bool = state != State.DONE and (state != State.IDLE or bool(medical.get("patient_found")))
	hud_panel.visible = visible_now

	if not visible_now:
		return

	var lines: Array[String] = [_status_text()]

	if state == State.FIRE_ACTIVE:
		lines.append("Debris cleared: %d/%d" % [cleared_piles.size(), piles.size()])

		if shovel_collected:
			lines.append("Shovel: equipped")
			if timer_running:
				lines.append("Time left: %d s" % ceili(timer_left))
		else:
			lines.append("Find the shovel")

	hud_label.text = "\n".join(lines)


func _status_text() -> String:
	match state:
		State.IDLE:
			return "Call 102 for an ambulance"
		State.AMBULANCE_ENROUTE:
			return "Ambulance is on its way"
		State.TREATING:
			return "Paramedics are helping the patient"
		State.AMBULANCE_LEAVING:
			return "Ambulance is leaving"
		State.FIRE_PENDING:
			return "Stay alert"
		State.FIRE_ACTIVE:
			if road_cleared:
				return "Road clear. Call 101"
			if firetruck_called:
				return "Clear the road for the fire brigade"
			return "Building on fire! Call 101"
		State.FIRETRUCK_ENROUTE:
			return "Fire brigade is on its way"
		State.EXTINGUISHING:
			return "Firefighters are at work"
		State.FIRETRUCK_LEAVING:
			return "Fire out. City safe!"

	return ""
