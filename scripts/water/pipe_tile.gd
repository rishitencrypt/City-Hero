class_name PipeTile
extends Control
## One clickable cell of the pipe grid. Draws its own pipe arms from `mask`.

signal tile_pressed(index: int)

const COL_WATER: Color = Color(0.188, 0.868, 0.824, 1.0)
const COL_DRY: Color = Color(0.68, 0.68, 0.68)
const COL_EDGE: Color = Color(0.07, 0.07, 0.07)
const COL_SOURCE: Color = Color(0.72, 0.72, 0.72)
const COL_DEST_OFF: Color = Color(0.42, 0.42, 0.42)
const COL_DEST_ON: Color = Color(0.82, 0.82, 0.82)

var index: int = 0
var tile_type: int = PipeLogic.PipeType.EMPTY
var mask: int = 0
var powered: bool = false
var interactive: bool = true:
	set(value):
		interactive = value
		_update_cursor()
		queue_redraw()

var _hover: bool = false
var _style_normal: StyleBoxFlat
var _style_hover: StyleBoxFlat


func _init() -> void:
	_style_normal = _make_style(Color(0.16, 0.16, 0.16))
	_style_hover = _make_style(Color(0.23, 0.23, 0.23))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_on_resized)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_on_resized()
	_update_cursor()


func setup(p_index: int, p_type: int, cell_size: float) -> void:
	index = p_index
	tile_type = p_type
	custom_minimum_size = Vector2(cell_size, cell_size)
	interactive = not PipeLogic.is_fixed(p_type)


func set_mask(m: int) -> void:
	if mask != m:
		mask = m
		queue_redraw()


func set_powered(v: bool) -> void:
	if powered != v:
		powered = v
		queue_redraw()


func play_pop() -> void:
	scale = Vector2(0.88, 0.88)
	var tw: Tween = create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			tile_pressed.emit(index)
			accept_event()


func _draw() -> void:
	var s: Vector2 = size
	var rect: Rect2 = Rect2(Vector2.ZERO, s)
	if _hover and interactive:
		draw_style_box(_style_hover, rect)
	else:
		draw_style_box(_style_normal, rect)

	var c: Vector2 = s / 2.0
	var pipe_col: Color = COL_WATER if powered else COL_DRY
	var half: float = s.x * 0.15
	for pass_i in 2:
		var hw: float = half + 3.0 if pass_i == 0 else half
		var col: Color = COL_EDGE if pass_i == 0 else pipe_col
		for d in PipeLogic.DIRS:
			if (mask & d) == 0:
				continue
			draw_rect(_arm_rect(d, c, hw, s), col)
		draw_rect(Rect2(c - Vector2(hw, hw), Vector2(hw * 2.0, hw * 2.0)), col)

	var font: Font = ThemeDB.fallback_font
	var fsize: int = int(s.x * 0.2)
	if tile_type == PipeLogic.PipeType.SOURCE:
		draw_circle(c, s.x * 0.24, COL_EDGE)
		draw_circle(c, s.x * 0.2, COL_SOURCE)
		draw_string(font, Vector2(0.0, c.y + fsize * 0.35), "IN", HORIZONTAL_ALIGNMENT_CENTER, s.x, fsize, Color.WHITE)
	elif tile_type == PipeLogic.PipeType.DEST:
		draw_circle(c, s.x * 0.24, COL_EDGE)
		draw_circle(c, s.x * 0.2, COL_DEST_ON if powered else COL_DEST_OFF)
		draw_string(font, Vector2(0.0, c.y + fsize * 0.35), "OUT", HORIZONTAL_ALIGNMENT_CENTER, s.x, fsize, Color.WHITE)


func _arm_rect(d: int, c: Vector2, hw: float, s: Vector2) -> Rect2:
	if d == PipeLogic.N:
		return Rect2(c.x - hw, 0.0, hw * 2.0, c.y)
	if d == PipeLogic.E:
		return Rect2(c.x, c.y - hw, s.x - c.x, hw * 2.0)
	if d == PipeLogic.S:
		return Rect2(c.x - hw, c.y, hw * 2.0, s.y - c.y)
	return Rect2(0.0, c.y - hw, c.x, hw * 2.0)


func _make_style(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(5)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.25, 0.25, 0.25, 0.45)
	return sb

func _update_cursor() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if interactive else Control.CURSOR_ARROW


func _on_resized() -> void:
	pivot_offset = size / 2.0


func _on_mouse_entered() -> void:
	_hover = true
	queue_redraw()


func _on_mouse_exited() -> void:
	_hover = false
	queue_redraw()
