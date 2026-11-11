

class_name WaterPuzzleUI
extends CanvasLayer
## Centered pipe-puzzle overlay. The whole UI is built in code (no .tscn needed).
## Call open(). Listen to puzzle_solved / puzzle_closed.
 
signal puzzle_solved
signal puzzle_closed
 
@export var cols: int = 6
@export var rows: int = 5
## Pauses the scene tree while open so the player cannot move. Restored on close.
@export var pause_game_while_open: bool = true
@export var success_message: String = "Leak fixed! Water flow restored."
 
const COL_TITLE: Color = Color(0.85, 0.85, 0.85)
const COL_TEXT: Color = Color(0.70, 0.70, 0.70)
const COL_GOOD: Color = Color(0.65, 0.80, 0.65)
const COL_BAD: Color = Color(0.85, 0.65, 0.65)
const COL_INFO: Color = Color(0.55, 0.55, 0.55)
 
var is_open: bool = false
var is_solved: bool = false
 
var _model: PipeModel
var _tiles: Array[PipeTile] = []
var _moves: int = 0
var _prev_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _prev_paused: bool = false
 
var _objective: Label
var _grid: GridContainer
var _status: Label
var _moves_label: Label
var _reset_btn: Button
var _test_btn: Button
var _close_btn: Button
 
 
func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()
 
 
func open() -> void:
	if is_open:
		return
	is_open = true
	_prev_mouse_mode = Input.mouse_mode
	_prev_paused = get_tree().paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if pause_game_while_open:
		get_tree().paused = true
	if _model == null:
		_model = PipeModel.new(cols, rows)
		_model.generate()
		_moves = 0
	_close_btn.text = "Continue" if is_solved else "Close"
	_rebuild_tiles()
	_refresh()
	visible = true
 
 
func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	if pause_game_while_open:
		get_tree().paused = _prev_paused
	Input.mouse_mode = _prev_mouse_mode
	puzzle_closed.emit()
 
 
func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
 
 
# ---------------------------------------------------------------- UI building
 
func _build_ui() -> void:
	var root: Control = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 
	var center: CenterContainer = CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	center.add_child(panel)
 
	var margin: MarginContainer = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(margin)
 
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
 
	vbox.add_child(_make_label("WATER CONSERVATION", 30, COL_TITLE))
 
	_objective = _make_label("A public water pipe is leaking! Connect the water source (IN) to the destination (OUT) to stop the leak.", 16, COL_TEXT)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_objective)
 
	_grid = GridContainer.new()
	_grid.columns = cols
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(_grid)
 
	vbox.add_child(_make_label("Hint: Rotate pipes to restore the water flow.", 15, COL_INFO))
 
	_status = _make_label("", 18, COL_INFO)
	vbox.add_child(_status)
 
	_moves_label = _make_label("Moves: 0", 14, COL_INFO)
	vbox.add_child(_moves_label)
 
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	vbox.add_child(buttons)
	_reset_btn = _make_button("Reset", _on_reset_pressed)
	_test_btn = _make_button("Test Flow", _on_test_pressed)
	_close_btn = _make_button("Close", close)
	buttons.add_child(_reset_btn)
	buttons.add_child(_test_btn)
	buttons.add_child(_close_btn)
 
 
func _make_label(text: String, font_size: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l
 
 
func _make_button(text: String, callback: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(130.0, 40.0)
	b.pressed.connect(callback)
	return b
 
 
func _make_panel_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.09, 0.09, 0.98)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.38, 0.38, 0.38, 1.0)
	sb.shadow_size = 10
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	return sb
 
 
# ------------------------------------------------------------------ grid/state
 
func _compute_cell_size() -> float:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var by_w: float = (vp.x * 0.85 - 100.0) / float(_model.cols)
	var by_h: float = (vp.y * 0.88 - 300.0) / float(_model.rows)
	return clampf(minf(by_w, by_h), 40.0, 100.0)
 
 
func _rebuild_tiles() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_tiles.clear()
	_grid.columns = _model.cols
	var cell: float = _compute_cell_size()
	_objective.custom_minimum_size = Vector2(cell * float(_model.cols) + 4.0 * float(_model.cols - 1), 0.0)
	for i in _model.types.size():
		var tile: PipeTile = PipeTile.new()
		_grid.add_child(tile)
		tile.setup(i, _model.types[i], cell)
		tile.set_mask(_model.get_mask(i))
		if is_solved:
			tile.interactive = false
		tile.tile_pressed.connect(_on_tile_pressed)
		_tiles.append(tile)
 
 
func _on_tile_pressed(i: int) -> void:
	if is_solved or _model == null:
		return
	if not _model.rotate_cell(i):
		return
	_moves += 1
	_tiles[i].set_mask(_model.get_mask(i))
	_tiles[i].play_pop()
	_refresh()
 
 
func _refresh(from_test: bool = false) -> void:
	var result: Dictionary = _model.evaluate()
	var connected: Dictionary = result["connected"]
	for i in _tiles.size():
		_tiles[i].set_powered(connected.has(i))
	_moves_label.text = "Moves: %d" % _moves
	if bool(result["solved"]):
		_handle_solved()
		return
	var flowing: int = connected.size() - 1
	if from_test:
		_set_status("Not connected yet - the water is blocked. Keep rotating!", COL_BAD)
	elif flowing <= 0:
		_set_status("No water is flowing. Rotate the pipe next to IN.", COL_INFO)
	else:
		_set_status("Water reaches %d pipe(s). Keep going!" % flowing, COL_INFO)
 
 
func _handle_solved() -> void:
	var first_time: bool = not is_solved
	is_solved = true
	for t in _tiles:
		t.interactive = false
	_set_status(success_message, COL_GOOD)
	_reset_btn.disabled = true
	_test_btn.disabled = true
	_close_btn.text = "Continue"
	if first_time:
		puzzle_solved.emit()
 
 
func _set_status(text: String, color: Color) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)
 
 
func _on_reset_pressed() -> void:
	if is_solved or _model == null:
		return
	_model.reset()
	_moves = 0
	for i in _tiles.size():
		_tiles[i].set_mask(_model.get_mask(i))
	_refresh()
 
 
func _on_test_pressed() -> void:
	if _model != null:
		_refresh(true)
 
