extends RefCounted

const BG: Color = Color("#191A1B")
const SURFACE: Color = Color("#242628")
const SURFACE_HOVER: Color = Color("#2D3032")
const SURFACE_PRESSED: Color = Color("#383B3D")
const BORDER: Color = Color("#414447")
const TEXT: Color = Color("#ECECE9")
const TEXT_DIM: Color = Color("#A9ACAE")
const ACCENT: Color = Color("#9BA9B4")
const BAD: Color = Color("#B96C65")

const TILE_ACTIVE: Color = Color("#777F86")
const TILE_SOLVED: Color = Color("#6F8B7A")
const TILE_REPUTATION: Color = Color("#9A8D68")
const TILE_CALLS: Color = Color("#6F8989")
const TILE_SMS: Color = Color("#72879A")
const TILE_CITY: Color = Color("#7D8790")

const FONT_TITLE: int = 20
const FONT_HEADING: int = 16
const FONT_BODY: int = 14
const FONT_CAPTION: int = 12
const ICON_SIZE: int = 64
const STROKE: float = 0.065


static func box(color: Color, radius: int = 6, margin: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style


static func frame() -> StyleBoxFlat:
	var style := box(BG, 12, 0)
	style.set_border_width_all(1)
	style.border_color = BORDER
	return style


static func label(text: String, size: int = FONT_BODY, color: Color = TEXT) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", color)
	return item


static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_BODY
	theme.set_stylebox("normal", "Button", box(SURFACE, 5, 8))
	theme.set_stylebox("hover", "Button", box(SURFACE_HOVER, 5, 8))
	theme.set_stylebox("pressed", "Button", box(SURFACE_PRESSED, 5, 8))
	theme.set_stylebox("disabled", "Button", box(Color(SURFACE, 0.5), 5, 8))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())

	for color_name in [
		"font_color",
		"font_hover_color",
		"font_pressed_color",
		"font_focus_color"
	]:
		theme.set_color(color_name, "Button", TEXT)

	theme.set_color("font_disabled_color", "Button", TEXT_DIM)
	theme.set_font_size("font_size", "Button", FONT_BODY)
	theme.set_color("font_color", "Label", TEXT)
	theme.set_stylebox("panel", "PanelContainer", box(SURFACE, 6, 8))
	theme.set_stylebox("background", "ProgressBar", box(Color("#34383B"), 2, 0))
	
	return theme


static func apply_tile(button: Button, _color: Color) -> void:
	button.add_theme_stylebox_override("normal", box(SURFACE, 6, 8))
	button.add_theme_stylebox_override("hover", box(SURFACE_HOVER, 6, 8))
	button.add_theme_stylebox_override("pressed", box(SURFACE_PRESSED, 6, 8))
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_color_override("font_pressed_color", TEXT)


static func apply_round(button: Button, size: int) -> void:
	button.custom_minimum_size = Vector2(size, size)
	button.add_theme_stylebox_override("normal", box(SURFACE, 6, 5))
	button.add_theme_stylebox_override("hover", box(SURFACE_HOVER, 6, 5))
	button.add_theme_stylebox_override("pressed", box(SURFACE_PRESSED, 6, 5))


static func icon(kind: String) -> ImageTexture:
	var segments: Array = []
	var dots: Array = []
	var rings: Array = []
	var boxes: Array = []

	match kind:
		"alert":
			boxes = [[Vector2(0.52, 0.53), Vector2(0.27, 0.34), 0.025]]
			segments = [
				[Vector2(0.40, 0.28), Vector2(0.64, 0.28)],
				[Vector2(0.39, 0.45), Vector2(0.62, 0.45)],
				[Vector2(0.39, 0.61), Vector2(0.57, 0.61)],
				[Vector2(0.39, 0.74), Vector2(0.55, 0.74)]
			]
		"solved":
			segments = [
				[Vector2(0.20, 0.52), Vector2(0.39, 0.69)],
				[Vector2(0.39, 0.69), Vector2(0.79, 0.29)]
			]
		"star":
			var points: Array = []
			for i in range(10):
				var angle: float = -PI / 2.0 + float(i) * PI / 5.0
				var radius: float = 0.36 if i % 2 == 0 else 0.17
				points.append(Vector2(0.5, 0.5) + Vector2(cos(angle), sin(angle)) * radius)
			for i in range(10):
				segments.append([points[i], points[(i + 1) % 10]])
		"calls":
			segments = [
				[Vector2(0.28, 0.23), Vector2(0.39, 0.18)],
				[Vector2(0.39, 0.18), Vector2(0.49, 0.34)],
				[Vector2(0.49, 0.34), Vector2(0.42, 0.44)],
				[Vector2(0.42, 0.44), Vector2(0.57, 0.60)],
				[Vector2(0.57, 0.60), Vector2(0.67, 0.53)],
				[Vector2(0.67, 0.53), Vector2(0.82, 0.63)],
				[Vector2(0.82, 0.63), Vector2(0.77, 0.75)],
				[Vector2(0.77, 0.75), Vector2(0.65, 0.80)],
				[Vector2(0.65, 0.80), Vector2(0.39, 0.64)],
				[Vector2(0.39, 0.64), Vector2(0.23, 0.38)],
				[Vector2(0.23, 0.38), Vector2(0.28, 0.23)]
			]
		"city":
			boxes = [
				[Vector2(0.29, 0.62), Vector2(0.12, 0.25), 0.01],
				[Vector2(0.51, 0.51), Vector2(0.12, 0.36), 0.01],
				[Vector2(0.74, 0.65), Vector2(0.11, 0.22), 0.01]
			]
		"messages":
			boxes = [[Vector2(0.50, 0.45), Vector2(0.34, 0.23), 0.025]]
			segments = [
				[Vector2(0.32, 0.65), Vector2(0.24, 0.79)],
				[Vector2(0.24, 0.79), Vector2(0.44, 0.66)],
				[Vector2(0.34, 0.40), Vector2(0.65, 0.40)],
				[Vector2(0.34, 0.51), Vector2(0.58, 0.51)]
			]
		"back":
			segments = [
				[Vector2(0.65, 0.23), Vector2(0.35, 0.50)],
				[Vector2(0.35, 0.50), Vector2(0.65, 0.77)],
				[Vector2(0.36, 0.50), Vector2(0.78, 0.50)]
			]

	return _render(segments, dots, rings, boxes)


static func signal_icon() -> ImageTexture:
	var image := Image.create_empty(18, 12, false, Image.FORMAT_RGBA8)
	for i in range(4):
		var height: int = 3 + i * 3
		var color: Color = TEXT if i < 3 else TEXT_DIM
		image.fill_rect(Rect2i(i * 5, 12 - height, 3, height), color)
	return ImageTexture.create_from_image(image)


static func battery_icon(level: float) -> ImageTexture:
	var image := Image.create_empty(24, 12, false, Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(0, 1, 21, 10), TEXT)
	image.fill_rect(Rect2i(2, 3, 17, 6), BG)
	image.fill_rect(
		Rect2i(3, 4, clampi(roundi(15.0 * clampf(level, 0.0, 1.0)), 0, 15), 4),
		TEXT
	)
	image.fill_rect(Rect2i(21, 4, 2, 4), TEXT)
	return ImageTexture.create_from_image(image)


static func _render(segments: Array, dots: Array, rings: Array, boxes: Array) -> ImageTexture:
	var image := Image.create_empty(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	for y in range(ICON_SIZE):
		for x in range(ICON_SIZE):
			var p: Vector2 = Vector2(x + 0.5, y + 0.5) / float(ICON_SIZE)
			var distance: float = 1.0
			for segment in segments:
				distance = minf(distance, _line(p, segment[0], segment[1]))
			for dot in dots:
				distance = minf(distance, p.distance_to(dot[0]) - dot[1])
			for ring in rings:
				distance = minf(distance, absf(p.distance_to(ring[0]) - ring[1]) - STROKE)
			for rectangle in boxes:
				distance = minf(distance, absf(_box(p, rectangle[0], rectangle[1], rectangle[2])) - STROKE)
			var alpha: float = 1.0 if distance <= 0.0 else 0.0
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(image)


static func _line(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var denominator: float = maxf(ab.length_squared(), 0.0001)
	var t: float = clampf((p - a).dot(ab) / denominator, 0.0, 1.0)
	return p.distance_to(a + ab * t) - STROKE


static func _box(p: Vector2, center: Vector2, half: Vector2, radius: float) -> float:
	var q: Vector2 = (p - center).abs() - half + Vector2(radius, radius)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - radius
