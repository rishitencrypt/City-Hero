extends CanvasLayer

const REPUTATION_PER_STAR: int = 20
const MAX_STARS: int = 5
const FREEZE_PLAYER: bool = false
const TILE_SIZE: int = 64
const TOTAL_LEVELS: int = 6
const DAYS: Array = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
const MONTHS: Array = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
const Style = preload("res://scripts/phone_style.gd")
const SMS_SCAM: String = "Unknown Sender\n\nURGENT: Your bank account will be blocked today! Send your OTP immediately to verify your identity."

@onready var phone: Panel = $Phone
@onready var home: VBoxContainer = $Phone/Home
@onready var app_screen: VBoxContainer = $Phone/AppScreen
@onready var app_title: Label = $Phone/AppScreen/AppTitle
@onready var app_content: Label = $Phone/AppScreen/AppContent
@onready var back_button: Button = $Phone/AppScreen/BackButton
@onready var dial_display: Label = $Phone/AppScreen/DialDisplay
@onready var dial_pad: GridContainer = $Phone/AppScreen/DialPad
@onready var call_button: Button = $Phone/AppScreen/CallButton
@onready var delete_button: Button = $Phone/AppScreen/DeleteButton

var saved_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var dial_number: String = ""
var call_result_label: Label = null
var sms_box: VBoxContainer = null
var fade_tween: Tween = null
var time_label: Label = null
var greeting_label: Label = null
var date_label: Label = null
var missions_value: Label = null
var reputation_value: Label = null
var sms_badge: Panel = null


func _ready() -> void:
	phone.visible = false

	app_content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	$Phone/Home/ActiveProblems.pressed.connect(_show_active_problems)
	$Phone/Home/SolvedProblems.pressed.connect(_show_solved_problems)
	$Phone/Home/Reputation.pressed.connect(_show_reputation)
	$Phone/Home/Calls.pressed.connect(_show_calls)
	$Phone/Home/CityHero.pressed.connect(_show_city_hero)
	$Phone/Home/SMS.pressed.connect(_show_sms)

	back_button.pressed.connect(_show_home)
	_setup_dial_pad()
	_setup_sms()
	_build_phone_ui()
	_show_home()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("open_phone"):
		if phone.visible:
			_close_phone()
		else:
			_open_phone()


func _open_phone() -> void:
	phone.visible = true
	_show_home()

	saved_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if FREEZE_PLAYER:
		var player: Node = _find("Player")
		if player != null:
			player.process_mode = Node.PROCESS_MODE_DISABLED


func _close_phone() -> void:
	phone.visible = false
	Input.mouse_mode = saved_mouse_mode

	if FREEZE_PLAYER:
		var player: Node = _find("Player")
		if player != null:
			player.process_mode = Node.PROCESS_MODE_INHERIT


func _show_home() -> void:
	home.visible = true
	app_screen.visible = false

	if sms_box != null:
		sms_box.visible = false

	_refresh_home()
	_fade_in(home)


func _open_app(title: String, text: String) -> void:
	home.visible = false
	app_screen.visible = true

	app_title.text = title
	app_content.text = text
	app_content.visible = true

	dial_display.visible = false
	dial_pad.visible = false
	call_button.visible = false
	delete_button.visible = false

	if call_result_label != null:
		call_result_label.visible = false
		call_result_label.text = ""

	_fade_in(app_screen)


func _show_active_problems() -> void:
	var lines: Array[String] = []

	if not _traffic_done():
		lines.append("Traffic: manage the junction")

	if not _waste_done():
		lines.append("Waste: %d / %d sorted" % [_waste_sorted(), _waste_total()])

	if not _vehicle_reported():
		lines.append("Pollution: smoking vehicle")

	if _trees_planted() < _trees_total():
		lines.append("Pollution: %d / %d trees planted" % [_trees_planted(), _trees_total()])

	if not _emergency_done():
		lines.append("Emergency Response: ongoing")

	if not _cyber_done():
		lines.append("Cyber Safety: suspicious SMS")
	if not _water_done():
		lines.append("Water Conservation: Fix the water leak")
	if lines.is_empty():
		_open_app("ACTIVE PROBLEMS", "No active problems.")
	else:
		_open_app("ACTIVE PROBLEMS", "\n".join(lines))


func _show_solved_problems() -> void:
	var lines: Array[String] = []

	if _traffic_done():
		lines.append("Traffic: junction cleared")

	if _waste_done():
		lines.append("Waste: all waste sorted")

	if _vehicle_reported():
		lines.append("Pollution: vehicle reported")

	if _trees_total() > 0 and _trees_planted() >= _trees_total():
		lines.append("Pollution: greenery restored")

	if _emergency_done():
		lines.append("Emergency Response: fire extinguished")

	if _cyber_done():
		lines.append("Cyber Safety: scam reported")

	if _water_done():
		lines.append("Water Conservation: water leak fixed")

	if lines.is_empty():
		_open_app("SOLVED PROBLEMS", "Nothing solved yet.")
	else:
		_open_app("SOLVED PROBLEMS", "\n".join(lines))


func _show_reputation() -> void:
	var reputation: int = _get_reputation()
	var stars: int = clampi(int(reputation / REPUTATION_PER_STAR), 0, MAX_STARS)

	_open_app(
		"REPUTATION",
		"Reputation: %d\nStars: %d / %d" % [reputation, stars, MAX_STARS]
	)


func _show_calls() -> void:
	home.visible = false
	app_screen.visible = true

	app_title.text = "CALLS"
	app_content.visible = false

	dial_display.visible = true
	dial_pad.visible = true
	call_button.visible = true
	delete_button.visible = true

	dial_number = ""
	dial_display.text = ""

	if call_result_label != null:
		call_result_label.visible = false
		call_result_label.text = ""

	_fade_in(app_screen)


func _show_city_hero() -> void:
	var levels_done: int = _levels_done()

	var text: String = "Levels complete: %d / 6\n\n" % levels_done
	text += "1. Traffic Safety - %s\n" % _status(_traffic_done())
	text += "2. Waste Management - %s\n" % _status(_waste_done())
	text += "3. Pollution Control - %s\n" % _status(_pollution_done())
	text += "4. Emergency Response - %s\n" % _status(_emergency_done())
	text += "5. Cyber Safety - %s\n" % _status(_cyber_done())
	text += "6. Water Conservation - %s" % _status(_water_done())

	_open_app("CITY HERO", text)


func _status(done: bool) -> String:
	return "Done" if done else "To do"


func _build_phone_ui() -> void:
	phone.theme = Style.make_theme()
	phone.add_theme_stylebox_override("panel", Style.frame())

	_build_status_bar()
	_fit(home)
	_fit(app_screen)
	_build_home()
	_build_app_header()

	app_content.add_theme_stylebox_override("normal", Style.box(Style.SURFACE, 14, 14))
	app_content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _fit(container: Control) -> void:
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.offset_left = 16
	container.offset_top = 48
	container.offset_right = -16
	container.offset_bottom = -16


func _build_status_bar() -> void:
	var bar: HBoxContainer = HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 20
	bar.offset_top = 14
	bar.offset_right = -20
	bar.offset_bottom = 34
	bar.add_theme_constant_override("separation", 6)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phone.add_child(bar)

	time_label = Style.label("", Style.FONT_CAPTION + 1)
	bar.add_child(time_label)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(spacer)

	bar.add_child(_status_icon(Style.signal_icon()))
	bar.add_child(_status_icon(Style.battery_icon(0.8)))

	var clock: Timer = Timer.new()
	clock.wait_time = 1.0
	clock.autostart = true
	clock.timeout.connect(_update_clock)
	add_child(clock)

	_update_clock()


func _status_icon(texture: Texture2D) -> TextureRect:
	var rect: TextureRect = TextureRect.new()
	rect.texture = texture
	rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	rect.custom_minimum_size = texture.get_size()
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _build_home() -> void:
	for child in home.get_children():
		if child is Label:
			child.visible = false

	home.add_theme_constant_override("separation", 4)

	greeting_label = Style.label("", Style.FONT_TITLE + 4)
	home.add_child(greeting_label)

	date_label = Style.label("", Style.FONT_CAPTION + 1, Style.TEXT_DIM)
	home.add_child(date_label)

	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	home.add_child(gap)

	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 16)
	home.add_child(grid)

	var apps: Array = [
		["ActiveProblems", "Tasks", "alert", Style.TILE_ACTIVE],
		["SolvedProblems", "Completed Tasks", "solved", Style.TILE_SOLVED],
		["Reputation", "Reputation", "star", Style.TILE_REPUTATION],
		["Calls", "Calls", "calls", Style.TILE_CALLS],
		["SMS", "Messages", "messages", Style.TILE_SMS],
		["CityHero", "City Hero", "city", Style.TILE_CITY]
	]

	for app in apps:
		var button: Button = home.get_node_or_null(app[0]) as Button

		if button == null:
			push_warning("Phone/Home is missing the button " + app[0])
			continue

		_make_tile(grid, button, app[1], app[2], app[3])

		if app[0] == "SMS":
			sms_badge = _make_badge(button)

	var fill: Control = Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	home.add_child(fill)

	var card: PanelContainer = PanelContainer.new()
	home.add_child(card)

	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	card.add_child(rows)

	missions_value = _add_stat_row(rows, "Missions")


	reputation_value = _add_stat_row(rows, "Reputation")


func _make_tile(grid: GridContainer, button: Button, caption: String, icon_name: String, color: Color) -> void:
	var tile: VBoxContainer = VBoxContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.add_theme_constant_override("separation", 6)
	grid.add_child(tile)

	button.reparent(tile)
	button.text = ""
	button.icon = Style.icon(icon_name)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	Style.apply_tile(button, color)

	var name_label: Label = Style.label(caption, Style.FONT_CAPTION, Style.TEXT_DIM)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.add_child(name_label)


func _make_badge(button: Button) -> Panel:
	var badge: Panel = Panel.new()
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -16
	badge.offset_top = 4
	badge.offset_right = -4
	badge.offset_bottom = 16
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", Style.box(Style.BAD, 6, 0))
	button.add_child(badge)
	return badge


func _add_stat_row(parent: Control, title: String) -> Label:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)

	var name_label: Label = Style.label(title, Style.FONT_BODY, Style.TEXT_DIM)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var value: Label = Style.label("", Style.FONT_BODY)
	row.add_child(value)
	return value


func _build_app_header() -> void:
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	app_screen.add_child(header)
	app_screen.move_child(header, 0)

	back_button.reparent(header)
	back_button.text = ""
	back_button.icon = Style.icon("back")
	back_button.expand_icon = true
	back_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	Style.apply_round(back_button, 36)

	app_title.reparent(header)
	app_title.add_theme_font_size_override("font_size", Style.FONT_TITLE)
	app_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _refresh_home() -> void:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	var hour: int = now["hour"]

	if hour < 12:
		greeting_label.text = "Good morning"
	elif hour < 18:
		greeting_label.text = "Good afternoon"
	else:
		greeting_label.text = "Good evening"

	date_label.text = "%s, %d %s" % [DAYS[now["weekday"]], now["day"], MONTHS[now["month"] - 1]]

	var done: int = _levels_done()
	missions_value.text = "%d / %d" % [done, TOTAL_LEVELS]
	reputation_value.text = str(_get_reputation())
	if sms_badge != null:
		sms_badge.visible = not _cyber_done()


func _update_clock() -> void:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	time_label.text = "%02d:%02d" % [now["hour"], now["minute"]]


func _fade_in(screen: Control) -> void:
	if fade_tween != null:
		fade_tween.kill()

	screen.modulate.a = 0.0
	fade_tween = create_tween()
	fade_tween.tween_property(screen, "modulate:a", 1.0, 0.12)


func _levels_done() -> int:
	var count: int = 0

	for done in [
		_traffic_done(),
		_waste_done(),
		_pollution_done(),
		_emergency_done(),
		_cyber_done(),
		_water_done()
	]:
		if done:
			count += 1

	return count

func _setup_sms() -> void:
	sms_box = VBoxContainer.new()
	app_screen.add_child(sms_box)
	app_screen.move_child(sms_box, call_result_label.get_index())

	var choices: Dictionary = {
		"Share OTP": "share",
		"Delete Message": "delete",
		"Report Scam": "report"
	}

	for title in choices:
		var button: Button = Button.new()
		button.text = title
		button.custom_minimum_size = Vector2(0, 36)
		button.pressed.connect(_on_sms_choice.bind(choices[title]))
		sms_box.add_child(button)

	sms_box.visible = false


func _show_sms() -> void:
	if _cyber_done():
		_open_app("SMS", "No new messages.")
		return

	_open_app("SMS", SMS_SCAM)
	sms_box.visible = true


func _on_sms_choice(choice: String) -> void:
	match choice:
		"share":
			app_content.text = SMS_SCAM + "\n\nNever share your OTP. Scammers use it to take over your account, and real banks never ask for it."
		"delete":
			app_content.text = SMS_SCAM + "\n\nDeleting it is safer than replying, but reporting scams helps protect other people too."
		"report":
			var task: Node = _find("CyberSafetyTask")

			if task == null or not task.has_method("report_scam"):
				app_content.text = "Cyber Safety task not found."
				return

			task.call("report_scam")
			sms_box.visible = false
			app_content.text = "Scam reported! Never share your OTP and always report suspicious messages.\n\n+%d reputation" % int(_read(task, "reputation", 0))


func _setup_dial_pad() -> void:
	var button_names: Array[String] = [
		"Button1", "Button2", "Button3",
		"Button4", "Button5", "Button6",
		"Button7", "Button8", "Button9",
		"ButtonStar", "Button0", "ButtonHash"
	]

	for button_name in button_names:
		var button: Button = dial_pad.get_node_or_null(button_name) as Button

		if button == null:
			push_warning("Dial pad button missing: " + button_name)
			continue

		button.pressed.connect(_on_dial_button_pressed.bind(button.text))
		button.custom_minimum_size = Vector2(60, 45)

	call_button.pressed.connect(_make_call)
	delete_button.pressed.connect(_delete_digit)

	dial_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dial_display.add_theme_font_size_override("font_size", 24)

	call_result_label = Label.new()
	call_result_label.text = ""
	call_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	call_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	call_result_label.add_theme_font_size_override("font_size", 16)
	call_result_label.add_theme_color_override("font_color", Color(0.75, 0.9, 0.75))
	app_screen.add_child(call_result_label)

	dial_display.visible = false
	dial_pad.visible = false
	call_button.visible = false
	delete_button.visible = false
	call_result_label.visible = false


func _on_dial_button_pressed(value: String) -> void:
	if dial_number.length() >= 12:
		return

	dial_number += value
	dial_display.text = dial_number

	if call_result_label != null:
		call_result_label.visible = false
		call_result_label.text = ""


func _delete_digit() -> void:
	if dial_number.is_empty():
		return

	dial_number = dial_number.left(dial_number.length() - 1)
	dial_display.text = dial_number

	if call_result_label != null:
		call_result_label.visible = false
		call_result_label.text = ""


func _make_call() -> void:
	if call_result_label == null:
		return

	if dial_number.is_empty():
		call_result_label.visible = true
		call_result_label.text = "Enter a number."
		return

	match dial_number:
		"133":
			var vehicle: Node = _find("PollutionVehicle")

			if vehicle != null and vehicle.has_method("report_from_call"):
				vehicle.call("report_from_call")
				call_result_label.text = "CALL CONNECTED\nCivic Pollution Hotline notified."
			else:
				call_result_label.text = "CALL FAILED\nPollution vehicle not found."

		"101":
			_call_emergency_service("101")

		"102":
			_call_emergency_service("102")

		"100":
			call_result_label.text = "CALLING POLICE...\nPolice have been notified."

		_:
			call_result_label.text = "CALL FAILED\nUnknown number."

	call_result_label.visible = true


func _call_emergency_service(number: String) -> void:
	var emergency_task: Node = _find("EmergencyResponseTask")

	if emergency_task != null and emergency_task.has_method("call_number"):
		var result: String = str(emergency_task.call("call_number", number))

		if result.is_empty():
			call_result_label.text = "CALL FAILED\nNo response from emergency services."
		else:
			call_result_label.text = result
	else:
		call_result_label.text = "CALL FAILED\nEmergency response system not found."


func _find(node_name: String) -> Node:
	return get_tree().current_scene.find_child(node_name, true, false)


func _read(node: Node, property: String, fallback: Variant) -> Variant:
	if node == null:
		return fallback

	var value: Variant = node.get(property)
	if value == null:
		return fallback

	return value


func _get_reputation() -> int:
	var total: int = 0

	for node_name in [
		"TrafficTask",
		"WasteManagementTask",
		"PollutionVehicle",
		"PlantingSpots",
		"EmergencyResponseTask",
		"CyberSafetyTask"
	]:
		total += int(_read(_find(node_name), "reputation", 0))

	return total


func _traffic_done() -> bool:
	return bool(_read(_find("TrafficTask"), "task_complete", false))


func _waste_sorted() -> int:
	return int(_read(_find("WasteManagementTask"), "sorted_waste", 0))


func _waste_total() -> int:
	return int(_read(_find("WasteManagementTask"), "total_waste", 0))


func _waste_done() -> bool:
	return _waste_total() > 0 and _waste_sorted() >= _waste_total()


func _vehicle_reported() -> bool:
	return bool(_read(_find("PollutionVehicle"), "reported", false))


func _trees_planted() -> int:
	var planted: Array = _read(_find("PlantingSpots"), "planted", [])
	return planted.size()


func _trees_total() -> int:
	return 3


func _pollution_done() -> bool:
	return _vehicle_reported() and _trees_planted() >= _trees_total()


func _emergency_done() -> bool:
	return bool(_read(_find("EmergencyResponseTask"), "task_complete", false))


func _cyber_done() -> bool:
	return bool(_read(_find("CyberSafetyTask"), "task_complete", false))


func _water_done() -> bool:
	var task: Node = _find("WaterLeakMission")
	return bool(_read(task, "completed", false))
