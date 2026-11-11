extends CanvasLayer
## On-screen help shared by the PYROLUX demo scenes (only used by the demos).
## Top left: scene title, one line about what it shows, and the code behind it.
## Bottom: a bar of buttons (mouse and touch) that also show their keyboard key.
## H or ?: a help card with every control. The first demo scene opened shows the card once
## as a start screen; clicking it also gives the browser canvas keyboard focus.
## Small or narrow screens (phones, a small browser window, an itch.io embed cut off by a narrow
## page): the UI is scaled up so the text stays readable, long lines wrap, the bottom buttons wrap
## onto more rows, and everything stays inside the part of the canvas the browser really shows.

const ACCENT: Color = Color(1.0, 0.62, 0.25)
const TITLE: Color = Color(1.0, 0.86, 0.66)
const TEXT: Color = Color(1.0, 0.94, 0.88)
const DIM: Color = Color(0.74, 0.78, 0.88)
const INTRO_META: StringName = &"pyrolux_demo_intro_done"
## Command line arguments of the automated tests; they skip the start screen.
const NO_INTRO_ARGS: Array[String] = ["--no-intro", "--quick", "--autotest", "--hold"]
## CSS pixels per UI unit at the 960x540 itch embed. On smaller screens the UI is scaled up to this.
const CSS_PER_UNIT: float = 0.75
## Below this width (in UI units) the help card and the bar switch to their compact layout.
const NARROW_W: float = 900.0
## Below this height (in UI units) the help card and the playground tool list get shorter.
const SHORT_H: float = 600.0
const MARGIN: float = 16.0
## The help card may shrink to this much to fit a short screen (its text stays above ~14 px).
const MIN_HELP_SCALE: float = 0.85
## Web only: watches which part of the canvas the browser shows. An itch.io embed is a fixed
## 960x540 frame, so in a narrow window its right side is cut off and the page scrolls sideways.
## Writes "left,right" (fractions of the canvas width) to window.__pxVis, checked twice a second.
const VIS_JS: String = "(function () { var c = document.getElementById('canvas'); if (!c || !window.IntersectionObserver || window.__pxVisObs) { return; } window.__pxVis = '0,1'; var t = []; for (var i = 0; i <= 50; i++) { t.push(i / 50); } var o = new IntersectionObserver(function (es) { var e = es[es.length - 1]; var b = e.boundingClientRect; var r = e.intersectionRect; if (!e.isIntersecting || b.width <= 0 || r.width <= 0) { return; } window.__pxVis = ((r.left - b.left) / b.width).toFixed(4) + ',' + ((r.right - b.left) / b.width).toFixed(4); }, { threshold: t }); o.observe(c); window.__pxVisObs = o; setInterval(function () { o.unobserve(c); o.observe(c); }, 500); })();"

var title_label: Label
var desc_label: Label
var code_label: Label
var left_column: VBoxContainer
var bar: HFlowContainer
var overlay: Control
var help_heading: String = ""
## Rows of the help card: {"keys": PackedStringArray, "text": String}. "<" and ">" draw arrow keys.
var help_rows: Array[Dictionary] = []
## The part of the canvas the UI lives in (the part on screen), in UI units, scaled by _k.
var frame: Control

var _info: PanelContainer
var _bar_panel: PanelContainer
var _hint_box: CenterContainer
var _hint_label: Label
var _help_frame: Control
var _card: PanelContainer
var _card_sb: StyleBoxFlat
var _card_box: VBoxContainer
var _prompt: Label
var _card_title: Label
var _card_wrap: Array[Label] = []
var _card_grid: GridContainer
var _card_keys: Array[Control] = []
var _card_descs: Array[Label] = []
var _tool_list: GridContainer
var _gaps: Array[Control] = []
var _bar_keys: Array[Label] = []
var _clock: float = 0.0
var _tex: Dictionary = {}
var _k: float = 1.0
var _help_s: float = 1.0
var _frame_size: Vector2 = Vector2(1280.0, 720.0)
var _vis: Vector2 = Vector2(0.0, 1.0)
var _vis_poll: float = 0.0
var _narrow: bool = false
var _short: bool = false


func _init() -> void:
	layer = 10


func _ready() -> void:
	_tex["tri_left"] = _shape_texture(true, false)
	_tex["tri_right"] = _shape_texture(false, false)
	_tex["arrow_left"] = _shape_texture(true, true)
	_tex["arrow_right"] = _shape_texture(false, true)

	frame = Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

	left_column = VBoxContainer.new()
	left_column.position = Vector2(16, 14)
	left_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_column.add_theme_constant_override("separation", 12)
	frame.add_child(left_column)
	_info = _panel(Color(0.03, 0.02, 0.025, 0.55), 10, 18, 10)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left_column.add_child(_info)
	var v: VBoxContainer = VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	_info.add_child(v)
	title_label = _label(34, TITLE)
	desc_label = _label(22, TEXT)
	code_label = _label(18, DIM)
	v.add_child(title_label)
	v.add_child(desc_label)
	v.add_child(code_label)

	_bar_panel = _panel(Color(0.0, 0.0, 0.0, 0.45), 0, 10, 8)
	_bar_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bar_panel.offset_top = -66.0
	_bar_panel.offset_bottom = 0.0
	_bar_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bar_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.add_child(_bar_panel)
	# A flow: one centred row when there is room, more rows on a narrow screen. It grows upwards.
	bar = HFlowContainer.new()
	bar.alignment = FlowContainer.ALIGNMENT_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("h_separation", 10)
	bar.add_theme_constant_override("v_separation", 8)
	_bar_panel.add_child(bar)

	_hint_box = CenterContainer.new()
	_hint_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint_box.offset_top = -124.0
	_hint_box.offset_bottom = -74.0
	_hint_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_hint_box)
	var hp: PanelContainer = _panel(Color(0.03, 0.02, 0.025, 0.6), 10, 18, 6)
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_box.add_child(hp)
	_hint_label = _label(23, TEXT)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp.add_child(_hint_label)
	_hint_box.visible = false

	_build_overlay()
	get_viewport().size_changed.connect(_layout)
	if OS.has_feature("web"):
		JavaScriptBridge.eval(VIS_JS, true)
	_layout()


func _process(delta: float) -> void:
	_clock += delta
	if overlay.visible:
		_prompt.modulate.a = 0.6 + 0.4 * (0.5 + 0.5 * sin(_clock * 4.0))
	if OS.has_feature("web"):
		_vis_poll -= delta
		if _vis_poll <= 0.0:
			_vis_poll = 0.25
			_read_vis()
	_sync()


func _input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if overlay.visible:
		hide_help()
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_H or k.keycode == KEY_QUESTION or k.unicode == 63:
		show_help(false)
		get_viewport().set_input_as_handled()


## Sets the three lines at the top left.
func set_info(title: String, description: String, code: String) -> void:
	title_label.text = title
	desc_label.text = description
	code_label.text = code
	code_label.visible = code != ""
	_layout_info()


## One line above the button bar saying what a click does here. Empty hides it.
func set_hint(text: String) -> void:
	_hint_label.text = text
	_hint_box.visible = text != ""
	_wrap_if_needed(_hint_label, _frame_size.x - 2.0 * MARGIN - 36.0)


## Adds a button to the bottom bar. `key` is shown as a key cap ("<" / ">" draw arrows).
func add_bar_button(text: String, key: String, action: Callable, icon: String = "", icon_after: bool = false) -> PanelContainer:
	var b: PanelContainer = make_button(text, key, action, icon, icon_after)
	bar.add_child(b)
	var h: HBoxContainer = b.get_child(0) as HBoxContainer
	for c in h.get_children():
		var kc: PanelContainer = c as PanelContainer
		if kc and kc.get_child_count() > 0:
			var kl: Label = kc.get_child(0) as Label
			if kl:
				_bar_keys.append(kl)
				kl.add_theme_font_size_override(&"font_size", 20 if _narrow else 17)
	return b


## Thin gap between groups of buttons in the bar (left out when the bar wraps on a narrow screen).
func add_bar_gap() -> void:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(8, 0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.visible = not _narrow
	bar.add_child(c)
	_gaps.append(c)


## A list of buttons under the info panel (the playground tools). One column; two on a short screen,
## so the list does not run into the buttons at the bottom.
func add_tool_list() -> GridContainer:
	_tool_list = GridContainer.new()
	_tool_list.columns = 2 if _short else 1
	_tool_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tool_list.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_tool_list.add_theme_constant_override("h_separation", 6)
	_tool_list.add_theme_constant_override("v_separation", 6)
	left_column.add_child(_tool_list)
	return _tool_list


## A clickable / tappable button with an optional icon and a key cap.
func make_button(text: String, key: String, action: Callable, icon: String = "", icon_after: bool = false) -> PanelContainer:
	var b: PanelContainer = PanelContainer.new()
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var h: HBoxContainer = HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 8)
	b.add_child(h)
	var ic: TextureRect = null
	if icon != "":
		ic = TextureRect.new()
		ic.texture = _tex[icon]
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(20, 20)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not icon_after:
			h.add_child(ic)
	var l: Label = _label(21, TEXT, 0)
	l.text = text
	l.visible = text != ""
	h.add_child(l)
	if ic and icon_after:
		h.add_child(ic)
	if key != "":
		h.add_child(_keycap(key, 17))
	b.set_meta(&"label", l)
	b.set_meta(&"hover", false)
	b.set_meta(&"selected", false)
	_restyle(b)
	b.mouse_entered.connect(_on_hover.bind(b, true))
	b.mouse_exited.connect(_on_hover.bind(b, false))
	b.gui_input.connect(_on_button_input.bind(b, action))
	return b


func set_button_text(b: PanelContainer, text: String) -> void:
	var l: Label = b.get_meta(&"label")
	l.text = text
	b.reset_size()


func set_button_selected(b: PanelContainer, on: bool) -> void:
	b.set_meta(&"selected", on)
	_restyle(b)


## Shows the help card. `first` = start screen wording ("click to start").
func show_help(first: bool) -> void:
	for c in _card_box.get_children():
		_card_box.remove_child(c)
		c.queue_free()
	_card_wrap.clear()
	_card_keys.clear()
	_card_descs.clear()
	_card_title = _label(60, ACCENT, 8)
	_card_title.text = "PYROLUX"
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_box.add_child(_card_title)
	var s: Label = _label(24, TEXT, 0)
	s.text = "Fire, explosion, smoke and lava VFX for Godot 4  -  live demo"
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_box.add_child(s)
	_card_wrap.append(s)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	_card_box.add_child(gap)
	if help_heading != "":
		var hh: Label = _label(25, TITLE, 0)
		hh.text = help_heading
		_card_box.add_child(hh)
		_card_wrap.append(hh)
	# Two columns, key caps | what they do. Each key stays on the line of its description; on a
	# narrow screen the descriptions wrap instead of running off the edge.
	_card_grid = GridContainer.new()
	_card_grid.columns = 2
	_card_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_grid.add_theme_constant_override("h_separation", 18)
	_card_grid.add_theme_constant_override("v_separation", 9)
	_card_box.add_child(_card_grid)
	for row in help_rows:
		var keys: PackedStringArray = row["keys"]
		var text: String = row["text"]
		var kh: HBoxContainer = HBoxContainer.new()
		kh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		kh.alignment = BoxContainer.ALIGNMENT_END
		kh.add_theme_constant_override("separation", 6)
		kh.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for key in keys:
			kh.add_child(_keycap(key, 20))
		_card_grid.add_child(kh)
		var dl: Label = _label(22, TEXT, 0)
		dl.text = text
		_card_grid.add_child(dl)
		_card_keys.append(kh)
		_card_descs.append(dl)
	var note: Label = _label(18, DIM, 0)
	note.text = "Every key also has a button at the bottom of the screen (mouse or touch)."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_box.add_child(note)
	_card_wrap.append(note)
	var gap2: Control = Control.new()
	gap2.custom_minimum_size = Vector2(0, 6)
	_card_box.add_child(gap2)
	_prompt = _label(28, ACCENT, 0)
	_prompt.text = "Click or tap anywhere to start" if first else "Click or tap anywhere to close"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_box.add_child(_prompt)
	_card_wrap.append(_prompt)
	_layout_help()
	overlay.visible = true


func hide_help() -> void:
	overlay.visible = false


## Shows the help card as a start screen the first time any demo scene opens (not again
## after switching scenes, and never in the automated test runs).
func show_intro_once() -> void:
	if Engine.has_meta(INTRO_META):
		return
	Engine.set_meta(INTRO_META, true)
	for a in OS.get_cmdline_user_args():
		if NO_INTRO_ARGS.has(a) or a.begins_with("--slot="):
			return
	show_help(true)


# ------------------------------------------------------------------ layout for the screen size

## Works out the UI scale and the visible part of the canvas, then lays every part out for it.
func _layout() -> void:
	if frame == null:
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var win: Vector2 = Vector2(get_window().size)
	if vp.x < 1.0 or vp.y < 1.0 or win.x < 1.0:
		return
	var dpr: float = 1.0
	if OS.has_feature("web"):
		dpr = clampf(DisplayServer.screen_get_scale(), 0.5, 4.0)
	var css: float = win.x / vp.x / dpr
	_k = clampf(CSS_PER_UNIT / maxf(css, 0.01), 1.0, 4.0)
	_frame_size = Vector2((_vis.y - _vis.x) * vp.x / _k, vp.y / _k)
	frame.position = Vector2(_vis.x * vp.x, 0.0)
	frame.scale = Vector2(_k, _k)
	frame.size = _frame_size
	_narrow = _frame_size.x < NARROW_W
	_short = _frame_size.y < SHORT_H
	for kl in _bar_keys:
		kl.add_theme_font_size_override(&"font_size", 20 if _narrow else 17)
	for g in _gaps:
		g.visible = not _narrow
	if _tool_list:
		_tool_list.columns = 2 if _short else 1
	code_label.visible = code_label.text != ""
	_layout_info()
	_wrap_if_needed(_hint_label, _frame_size.x - 2.0 * MARGIN - 36.0)
	_layout_help()
	_apply_help_frame()


## The info panel at the top left: lines wrap only when they would not fit.
func _layout_info() -> void:
	var w: float = _frame_size.x - 2.0 * MARGIN - 36.0
	_wrap_if_needed(title_label, w)
	_wrap_if_needed(desc_label, w)
	_wrap_if_needed(code_label, w)
	_info.reset_size()
	left_column.reset_size()


## Fits the help card into the frame width: the subtitle, heading, descriptions, note and the
## prompt wrap only when they would not fit on one line. Shorter spacing on a short screen.
func _layout_help() -> void:
	if not is_instance_valid(_card_title):
		return
	var mx: float = 20.0 if _narrow else 40.0
	var my: float = 14.0 if _short else 24.0
	_card_sb.content_margin_left = mx
	_card_sb.content_margin_right = mx
	_card_sb.content_margin_top = my
	_card_sb.content_margin_bottom = my
	var avail: float = _frame_size.x - 2.0 * MARGIN - 2.0 * mx
	_card_title.add_theme_font_size_override(&"font_size", 46 if _short else 60)
	_card_box.add_theme_constant_override("separation", 3 if _short else 6)
	_card_grid.add_theme_constant_override("v_separation", 4 if _short else 9)
	var hsep: float = 12.0 if _narrow else 18.0
	_card_grid.add_theme_constant_override("h_separation", int(hsep))
	for l in _card_wrap:
		_wrap_if_needed(l, avail)
	var kw: float = 0.0
	for kh in _card_keys:
		kw = maxf(kw, kh.get_combined_minimum_size().x)
	var dw: float = 0.0
	for d in _card_descs:
		dw = maxf(dw, _natural_w(d))
	var wrap: bool = kw + hsep + dw > avail
	for d in _card_descs:
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
		d.custom_minimum_size.x = maxf(140.0, avail - kw - hsep) if wrap else 0.0
	_card.reset_size()


## Follows sizes that change after the containers have sorted (wrapped text, wrapped buttons).
func _sync() -> void:
	var hb: float = -_bar_panel.size.y - 8.0
	if not is_equal_approx(_hint_box.offset_bottom, hb):
		_hint_box.offset_bottom = hb
		_hint_box.offset_top = hb - 50.0
	# The top-left column (info panel, playground tools) must stay above the hint and the buttons:
	# on a short screen the tool list gets more columns, then the code line steps aside.
	var low: float = _frame_size.y - _bar_panel.size.y - 8.0
	if _hint_box.visible:
		low = minf(low, _frame_size.y + _hint_box.offset_bottom - _hint_box.get_combined_minimum_size().y - 10.0)
	var col_bottom: float = left_column.position.y + left_column.get_combined_minimum_size().y
	if col_bottom > low:
		if _tool_list and _tool_list.columns < 4:
			_tool_list.columns += 1
		elif code_label.visible:
			code_label.visible = false
			_info.reset_size()
		left_column.reset_size()
	var hide_ui: bool = false
	if overlay.visible:
		var need: Vector2 = _card.get_combined_minimum_size()
		var s: float = 1.0
		var avail_h: float = _frame_size.y - 2.0 * MARGIN
		var avail_w: float = _frame_size.x - 2.0 * MARGIN
		if need.y > avail_h or need.x > avail_w:
			s = maxf(MIN_HELP_SCALE, minf(avail_h / need.y, avail_w / need.x))
		if absf(s - _help_s) > 0.002:
			_help_s = s
			_apply_help_frame()
		# On a small screen the card would sit on top of the info panel and the buttons, so they
		# step aside while it is open. On a large screen they stay, dimmed, as before.
		var card_bottom: float = (_frame_size.y + need.y * _help_s) * 0.5
		var ui_top: float = low if _hint_box.visible else _frame_size.y - _bar_panel.size.y
		hide_ui = _narrow or _short or card_bottom > ui_top
	if frame.visible == hide_ui:
		frame.visible = not hide_ui


func _apply_help_frame() -> void:
	_help_frame.position = frame.position
	_help_frame.scale = frame.scale * _help_s
	_help_frame.size = _frame_size / _help_s


## Web: reads which part of the canvas is on screen (see VIS_JS) and lays out again when it moves.
func _read_vis() -> void:
	var r: Variant = JavaScriptBridge.eval("window.__pxVis || ''", true)
	if r == null:
		return
	var parts: PackedStringArray = str(r).split(",")
	if parts.size() != 2:
		return
	var v: Vector2 = Vector2(clampf(parts[0].to_float(), 0.0, 1.0), clampf(parts[1].to_float(), 0.0, 1.0))
	if v.x < 0.01:
		v.x = 0.0
	if v.y > 0.99:
		v.y = 1.0
	if v.y - v.x < 0.15:
		return  # nearly out of view: keep the last layout
	if absf(v.x - _vis.x) > 0.004 or absf(v.y - _vis.y) > 0.004:
		_vis = v
		_layout()


func _wrap_if_needed(l: Label, w: float) -> void:
	var wrap: bool = _natural_w(l) > w
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	l.custom_minimum_size.x = maxf(100.0, w) if wrap else 0.0


## Width of a label's text on one line.
func _natural_w(l: Label) -> float:
	var mode: TextServer.AutowrapMode = l.autowrap_mode
	var cm: Vector2 = l.custom_minimum_size
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.custom_minimum_size = Vector2.ZERO
	var w: float = l.get_minimum_size().x
	l.autowrap_mode = mode
	l.custom_minimum_size = cm
	return w


# ------------------------------------------------------------------ internals

func _build_overlay() -> void:
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	add_child(overlay)
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)
	# The dimming covers the whole canvas; the card sits in the part of it that is on screen.
	_help_frame = Control.new()
	_help_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(_help_frame)
	var cc: CenterContainer = CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help_frame.add_child(cc)
	_card = _panel(Color(0.06, 0.035, 0.03, 0.86), 14, 40, 24)
	_card_sb = _card.get_theme_stylebox(&"panel") as StyleBoxFlat
	_card_sb.border_color = Color(ACCENT, 0.7)
	_card_sb.set_border_width_all(2)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(_card)
	_card_box = VBoxContainer.new()
	_card_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_box.add_theme_constant_override("separation", 6)
	_card.add_child(_card_box)
	overlay.gui_input.connect(_on_overlay_input)


func _on_overlay_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb and mb.pressed:
		hide_help()
		overlay.accept_event()


func _on_button_input(event: InputEvent, b: PanelContainer, action: Callable) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		b.accept_event()
		action.call()


func _on_hover(b: PanelContainer, on: bool) -> void:
	b.set_meta(&"hover", on)
	_restyle(b)


func _restyle(b: PanelContainer) -> void:
	var hover: bool = b.get_meta(&"hover")
	var selected: bool = b.get_meta(&"selected")
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2 if selected else 1)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	if selected:
		sb.bg_color = Color(0.5, 0.22, 0.05, 0.95)
		sb.border_color = Color(1.0, 0.82, 0.5)
	elif hover:
		sb.bg_color = Color(0.3, 0.15, 0.06, 0.95)
		sb.border_color = ACCENT
	else:
		sb.bg_color = Color(0.13, 0.075, 0.05, 0.85)
		sb.border_color = Color(1.0, 0.62, 0.3, 0.45)
	b.add_theme_stylebox_override(&"panel", sb)


func _keycap(key: String, font_size: int) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 1.0, 1.0, 0.13)
	sb.border_color = Color(1.0, 1.0, 1.0, 0.5)
	sb.set_border_width_all(1)
	sb.border_width_bottom = 3
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 7.0
	sb.content_margin_right = 7.0
	sb.content_margin_top = 0.0
	sb.content_margin_bottom = 1.0
	p.add_theme_stylebox_override(&"panel", sb)
	if key == "<" or key == ">":
		var ic: TextureRect = TextureRect.new()
		ic.texture = _tex["arrow_left" if key == "<" else "arrow_right"]
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(font_size + 2, font_size + 4)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(ic)
	else:
		var l: Label = _label(font_size, Color(1, 1, 1), 0)
		l.text = key
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(font_size * 0.8, 0)
		p.add_child(l)
	return p


func _label(font_size: int, color: Color, outline: int = 5) -> Label:
	var l: Label = Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", color)
	if outline > 0:
		l.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override(&"outline_size", outline)
	return l


func _panel(bg: Color, radius: int, margin_x: float, margin_y: float) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margin_x
	sb.content_margin_right = margin_x
	sb.content_margin_top = margin_y
	sb.content_margin_bottom = margin_y
	p.add_theme_stylebox_override(&"panel", sb)
	return p


## Small white triangle (button icon) or arrow (arrow key cap), drawn once at start.
func _shape_texture(left: bool, arrow: bool) -> ImageTexture:
	var n: int = 32
	var ss: int = 4
	var img: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var cov: int = 0
			for sy in ss:
				for sx in ss:
					var u: float = (float(x) + (float(sx) + 0.5) / ss) / n
					var v: float = absf((float(y) + (float(sy) + 0.5) / ss) / n - 0.5)
					if left:
						u = 1.0 - u
					var inside: bool
					if arrow:
						inside = (u >= 0.5 and u <= 0.9 and v <= (0.9 - u) / 0.4 * 0.36) or (u >= 0.1 and u < 0.55 and v <= 0.08)
					else:
						inside = u >= 0.2 and u <= 0.86 and v <= (0.86 - u) / 0.66 * 0.4
					if inside:
						cov += 1
			img.set_pixel(x, y, Color(1, 1, 1, float(cov) / float(ss * ss)))
	return ImageTexture.create_from_image(img)
