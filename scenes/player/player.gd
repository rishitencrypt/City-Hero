extends CharacterBody3D


# -------------------------
# CHARACTER
# -------------------------

@onready var animation_player: AnimationPlayer = $ModelPivot/CharacterModel/AnimationPlayer


# -------------------------
# MOVEMENT
# -------------------------

@export var speed := 5.0
@export var acceleration := 12.0
@export var gravity := 15.0


# -------------------------
# CAMERA
# -------------------------

@export var mouse_sensitivity := 0.003
@export var camera_pitch_min := -0.8
@export var camera_pitch_max := 0.3

@onready var camera_pivot: SpringArm3D = $CameraPivot

var camera_yaw := 0.0
var camera_pitch := -0.2


# -------------------------
# READY
# -------------------------

func _ready() -> void:
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Start with idle animation
	animation_player.play("idle")


# -------------------------
# INPUT
# -------------------------

func _unhandled_input(event: InputEvent) -> void:

	# Mouse camera control
	if event is InputEventMouseMotion:
		camera_yaw -= event.relative.x * mouse_sensitivity
		camera_pitch -= event.relative.y * mouse_sensitivity

		camera_pitch = clamp(
			camera_pitch,
			camera_pitch_min,
			camera_pitch_max
		)

	# Escape releases mouse
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Left click captures mouse again
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# -------------------------
# PHYSICS / MOVEMENT
# -------------------------

func _physics_process(delta: float) -> void:

	# -------------------------
	# Gravity
	# -------------------------

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0


	# -------------------------
	# Camera rotation
	# -------------------------

	camera_pivot.global_rotation = Vector3(
		camera_pitch,
		camera_yaw,
		0.0
	)


	# -------------------------
	# Keyboard input
	# -------------------------

	var input_2d := Input.get_vector(
		"move_left",
		"move_right",
		"move_backward",
		"move_forward"
	)


	# -------------------------
	# Camera-relative movement
	# -------------------------

	var forward := -camera_pivot.global_transform.basis.z
	var right := camera_pivot.global_transform.basis.x

	forward.y = 0.0
	right.y = 0.0

	forward = forward.normalized()
	right = right.normalized()

	var direction := (
		right * input_2d.x +
		forward * input_2d.y
	).normalized()


	# -------------------------
	# Move player
	# -------------------------

	if direction != Vector3.ZERO:

		velocity.x = move_toward(
			velocity.x,
			direction.x * speed,
			acceleration * delta
		)

		velocity.z = move_toward(
			velocity.z,
			direction.z * speed,
			acceleration * delta
		)


		# -------------------------
		# Turn player
		# -------------------------

		var target_rotation := atan2(
			direction.x,
			direction.z
		)

		rotation.y = lerp_angle(
			rotation.y,
			target_rotation,
			8.0 * delta
		)

	else:

		velocity.x = move_toward(
			velocity.x,
			0.0,
			acceleration * delta
		)

		velocity.z = move_toward(
			velocity.z,
			0.0,
			acceleration * delta
		)


	# -------------------------
	# Apply movement
	# -------------------------

	move_and_slide()


	# -------------------------
	# Update animation
	# -------------------------

	update_animation()


# -------------------------
# CHARACTER ANIMATION
# -------------------------

func update_animation() -> void:

	var horizontal_velocity := Vector2(
		velocity.x,
		velocity.z
	)

	var movement_speed := horizontal_velocity.length()


	# -------------------------
	# IDLE
	# -------------------------

	if movement_speed < 0.1:

		if animation_player.current_animation != "idle":
			animation_player.play("idle")


	# -------------------------
	# MOVING
	# -------------------------

	else:

		# Current speed is 5,
		# so use the sprint animation.
		if movement_speed > 4.0:

			if animation_player.current_animation != "sprint":
				animation_player.play("sprint")

		else:

			if animation_player.current_animation != "walk":
				animation_player.play("walk")
