extends Node3D

signal reached_destination
signal departed

enum Mode { IDLE, DRIVING, ALIGNING }

@export var speed: float = 8.0
@export var turn_speed: float = 3.5
@export var flip_direction: bool = true

const WAYPOINT_RADIUS: float = 1.5
const FINAL_RADIUS: float = 1.0
const SLOW_DISTANCE: float = 4.0
const WAYPOINT_TIMEOUT: float = 25.0
const ALIGN_TIMEOUT: float = 4.0

var mode: Mode = Mode.IDLE
var route: Array = []
var waypoints: Array = []
var waypoint_index: int = 0
var waypoint_time: float = 0.0
var heading: float = 0.0
var home_position: Vector3 = Vector3.ZERO
var face_point: Variant = null
var dispatched: bool = false
var arrived: bool = false
var leaving: bool = false
var has_departed: bool = false


func _ready() -> void:
	home_position = global_position
	heading = rotation.y - _model_offset()


func dispatch(target: Variant, facing: Variant = null) -> void:
	if dispatched or mode != Mode.IDLE:
		push_warning("Ambulance is already dispatched.")
		return

	var points: Array = []

	if target is Vector3:
		points.append(target)
	elif target is Array:
		points = (target as Array).duplicate()

	if points.is_empty():
		push_warning("Ambulance was dispatched without a destination.")
		return

	route = points
	face_point = facing
	dispatched = true
	arrived = false
	has_departed = false
	_start_path(route.duplicate(), false)


func depart() -> void:
	if mode != Mode.IDLE or not arrived:
		return

	var path: Array = route.duplicate()
	path.reverse()
	path.remove_at(0)
	path.append(home_position)

	arrived = false
	_start_path(path, true)


func _process(delta: float) -> void:
	if mode == Mode.DRIVING:
		_drive(delta)
	elif mode == Mode.ALIGNING:
		_align(delta)


func _start_path(path: Array, is_leaving: bool) -> void:
	waypoints = path
	waypoint_index = 0
	waypoint_time = 0.0
	leaving = is_leaving
	heading = rotation.y - _model_offset()
	mode = Mode.DRIVING


func _drive(delta: float) -> void:
	var target: Vector3 = waypoints[waypoint_index]
	var offset: Vector3 = target - global_position
	offset.y = 0.0

	var distance: float = offset.length()
	var is_last: bool = waypoint_index == waypoints.size() - 1
	var radius: float = FINAL_RADIUS if is_last else WAYPOINT_RADIUS

	waypoint_time += delta

	if distance <= radius or waypoint_time > WAYPOINT_TIMEOUT:
		_next_waypoint()
		return

	var desired: float = atan2(-offset.x, -offset.z)
	_steer(desired, delta)

	var error: float = absf(angle_difference(heading, desired))
	var factor: float = clampf(cos(error), 0.0, 1.0)

	if is_last:
		factor *= clampf(distance / SLOW_DISTANCE, 0.3, 1.0)

	var forward: Vector3 = Vector3(-sin(heading), 0.0, -cos(heading))
	global_position += forward * speed * factor * delta
	_apply_rotation()


func _next_waypoint() -> void:
	waypoint_time = 0.0

	if waypoint_index < waypoints.size() - 1:
		waypoint_index += 1
		return

	if not leaving and face_point is Vector3:
		mode = Mode.ALIGNING
	else:
		_complete()


func _align(delta: float) -> void:
	waypoint_time += delta

	var target: Vector3 = face_point
	var offset: Vector3 = target - global_position
	offset.y = 0.0

	var desired: float = atan2(-offset.x, -offset.z)
	_steer(desired, delta)
	_apply_rotation()

	if absf(angle_difference(heading, desired)) < 0.05 or waypoint_time > ALIGN_TIMEOUT:
		_complete()


func _complete() -> void:
	mode = Mode.IDLE

	if leaving:
		leaving = false
		dispatched = false
		has_departed = true
		departed.emit()
	else:
		arrived = true
		reached_destination.emit()


func _steer(desired: float, delta: float) -> void:
	var max_turn: float = turn_speed * delta
	heading += clampf(angle_difference(heading, desired), -max_turn, max_turn)


func _apply_rotation() -> void:
	rotation.y = heading + _model_offset()


func _model_offset() -> float:
	if flip_direction:
		return PI

	return 0.0
