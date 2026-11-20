extends CanvasLayer

signal reverse_requested
signal camera_requested
signal pause_requested
signal recovery_requested
signal menu_requested
signal map_requested
signal gear_requested(selector: String)
signal shift_requested(direction: int)
signal drive_mode_requested
signal differential_requested
signal lighting_requested
signal indicators_requested
signal wipers_requested
signal horn_requested
signal ignition_requested
signal descent_requested
signal diagnostics_requested
signal photo_requested
signal photo_move(direction: float)
signal photo_capture_requested

var steering := 0.0
var throttle := 0.0
var brake := 0.0
var handbrake := false
var clutch := 0.0
var _frame: Control
var _dashboard: Label
var _mission_label: Label
var _overlay: PanelContainer
var _options: HBoxContainer
var _playing := true
var _editing := false
var _edit_pointer := -1
var _edit_target := ""
var _base_layout: Dictionary = {}
var _photo_tools: HBoxContainer
var _held: Dictionary = {}
var _start_angle := 0.0
var _wheel_angle := 0.0
var _targets: Dictionary = {}
var _readout: Label
var _pause: PanelContainer
var _wheel: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var frame := Control.new()
	frame.theme = preload("res://assets/textures/my_car_theme.tres")
	_frame = frame
	add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.layout_direction = Control.LAYOUT_DIRECTION_LTR

	_readout = Label.new()
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_readout.add_theme_font_size_override("font_size", 34)
	_readout.add_theme_color_override("font_color", Color("#f4ce8d"))
	_place(frame, _readout, Vector2(0.5, 0), Rect2(-200, 12, 400, 52))
	_dashboard = Label.new()
	_dashboard.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dashboard.add_theme_font_size_override("font_size", 18)
	_place(frame, _dashboard, Vector2(0.5, 0), Rect2(-250, 65, 500, 37))
	_mission_label = Label.new()
	_mission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mission_label.add_theme_font_size_override("font_size", 18)
	_mission_label.add_theme_color_override("font_color", Color("#f6cd8b"))
	_place(frame, _mission_label, Vector2(0.5, 0), Rect2(-270, 102, 540, 36))
	_targets["steer"] = _button(frame, "", Vector2(0, 1), Rect2(26, -210, 182, 182))
	var transparent := StyleBoxEmpty.new()
	for style in ["normal", "hover", "pressed", "focus"]:
		_targets["steer"].add_theme_stylebox_override(style, transparent)
	_wheel = preload("res://scripts/ui/steering_dial.gd").new()
	_place(frame, _wheel, Vector2(0, 1), Rect2(26, -210, 182, 182))
	_wheel.pivot_offset = Vector2(91, 91)
	_targets["throttle"] = _button(frame, "وقود", Vector2(1, 1), Rect2(-126, -157, 96, 128))
	_targets["brake"] = _button(frame, "فرامل", Vector2(1, 1), Rect2(-232, -136, 94, 106))
	_targets["handbrake"] = _button(frame, "يدوية", Vector2(1, 1), Rect2(-330, -91, 88, 61))
	_button(frame, "ناقل", Vector2(1, 1), Rect2(-126, -218, 96, 51)).pressed.connect(_show_gears)
	_targets["clutch"] = _button(frame, "قابض", Vector2(1, 1), Rect2(-330, -158, 88, 61))
	_button(frame, "خريطة", Vector2(0, 0), Rect2(26, 81, 126, 45)).pressed.connect(map_requested.emit)
	_button(frame, "مركبة", Vector2(1, 0), Rect2(-166, 81, 140, 45)).pressed.connect(_show_vehicle)
	_button(frame, "بوق", Vector2(1, 1), Rect2(-232, -199, 94, 52)).pressed.connect(horn_requested.emit)
	_button(frame, "كاميرا", Vector2(1, 0), Rect2(-310, 20, 130, 52)).pressed.connect(camera_requested.emit)
	_button(frame, "إيقاف مؤقت", Vector2(1, 0), Rect2(-168, 20, 142, 52)).pressed.connect(pause_requested.emit)
	_button(frame, "استعادة", Vector2(0, 0), Rect2(26, 20, 126, 52)).pressed.connect(recovery_requested.emit)

	_pause = PanelContainer.new()
	_place(frame, _pause, Vector2(0.5, 0.5), Rect2(-172, -142, 344, 284))
	_pause.mouse_filter = Control.MOUSE_FILTER_STOP
	var menu := VBoxContainer.new()
	_pause.add_child(menu)
	var resume := Button.new()
	resume.text = "متابعة القيادة"
	resume.custom_minimum_size.y = 66
	menu.add_child(resume)
	resume.pressed.connect(pause_requested.emit)
	var exit := Button.new()
	exit.text = "حفظ والعودة إلى القائمة"
	exit.custom_minimum_size.y = 66
	menu.add_child(exit)
	exit.pressed.connect(menu_requested.emit)
	var studio := Button.new()
	studio.text = "ضبط مواضع التحكم"
	studio.pressed.connect(_toggle_studio)
	menu.add_child(studio)
	var photo := Button.new()
	photo.text = "وضع التصوير"
	photo.pressed.connect(photo_requested.emit)
	menu.add_child(photo)
	_mini_button(menu, "الأداء", diagnostics_requested.emit)
	_pause.hide()

	_options = HBoxContainer.new()
	_options.alignment = BoxContainer.ALIGNMENT_CENTER
	_place(frame, _options, Vector2(0.5, 1), Rect2(-370, -77, 740, 55))
	_options.hide()
	_overlay = PanelContainer.new()
	_place(frame, _overlay, Vector2(0.5, 0.5), Rect2(-372, -247, 744, 494))
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.hide()
	for key in _targets:
		var button: Button = _targets[key]
		_base_layout[key] = [button.anchor_left, button.offset_left, button.offset_top, button.size]
	_apply_layout()
	_frame.resized.connect(_apply_layout)
	_photo_tools = HBoxContainer.new()
	_photo_tools.alignment = BoxContainer.ALIGNMENT_CENTER
	_place(frame, _photo_tools, Vector2(0.5, 1), Rect2(-460, -75, 920, 57))
	_mini_button(_photo_tools, "دوران يسار", photo_move.emit.bind(-1.0))
	_mini_button(_photo_tools, "دوران يمين", photo_move.emit.bind(1.0))
	_mini_button(_photo_tools, "التقاط صورة", photo_capture_requested.emit)
	_mini_button(_photo_tools, "متابعة", photo_requested.emit)
	_photo_tools.hide()


func _process(delta: float) -> void:
	if not "steer" in _held:
		_wheel_angle = move_toward(_wheel_angle, 0, delta * 8.0)
	steering = _wheel_angle / (PI * 0.75)
	_wheel.rotation = _wheel_angle
	_wheel.visible = _playing and not _overlay.visible


func _input(event: InputEvent) -> void:
	if _editing:
		_edit_control(event)
		return
	if not _playing or _pause.visible or _overlay.visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			for action: String in _targets:
				var button := _targets[action] as Button
				if button.visible and not _held.has(action) and button.get_global_rect().has_point(event.position):
					_held[action] = event.index
					if action == "steer":
						_start_angle = _touch_angle(event.position)
					_update_pedals()
					get_viewport().set_input_as_handled()
					return
		else:
			for action: String in _held.keys():
				if _held[action] == event.index:
					_held.erase(action)
					_update_pedals()
					get_viewport().set_input_as_handled()
					return
	if event is InputEventScreenDrag and _held.get("steer", -1) == event.index:
		var angle := _touch_angle(event.position)
		_wheel_angle = clampf(_wheel_angle + angle_difference(_start_angle, angle) * float(PersistenceManager.save_data.steering_sensitivity), -PI * 0.75, PI * 0.75)
		_start_angle = angle
		steering = _wheel_angle / (PI * 0.75)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		reset_input()


func reset_input() -> void:
	_held.clear()
	_wheel_angle = 0.0
	steering = 0.0
	_update_pedals()


func show_pause(paused: bool) -> void:
	reset_input()
	_options.hide()
	_pause.visible = paused


func update_readout(car: RaycastVehicleBody, route_message: String) -> void:
	var powertrain := car.powertrain
	_readout.text = "%d كم/س     %s     %s" % [roundi(car.current_speed_kmh), powertrain.gear_label(), powertrain.mode]
	_dashboard.text = "%d RPM   •   %.1f ل   •   %.0f°   •   الحالة %d%%" % [
		roundi(powertrain.rpm), powertrain.fuel, powertrain.temperature, roundi(car.condition.body)]
	_mission_label.text = route_message
	_targets["clutch"].visible = powertrain.manual


func _update_pedals() -> void:
	throttle = float(_held.has("throttle"))
	clutch = float(_held.has("clutch"))
	brake = float(_held.has("brake"))
	handbrake = _held.has("handbrake")


func _touch_angle(pointer: Vector2) -> float:
	var wheel := _targets["steer"] as Button
	var offset := pointer - wheel.get_global_rect().get_center()
	return offset.angle()


func _button(parent: Control, caption: String, anchor: Vector2, rect: Rect2) -> Button:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 23)
	_place(parent, button, anchor, rect)
	return button


func _place(parent: Control, node: Control, anchor: Vector2, rect: Rect2) -> void:
	parent.add_child(node)
	node.set_anchor(SIDE_LEFT, anchor.x)
	node.set_anchor(SIDE_RIGHT, anchor.x)
	node.set_anchor(SIDE_TOP, anchor.y)
	node.set_anchor(SIDE_BOTTOM, anchor.y)
	node.offset_left = rect.position.x
	node.offset_top = rect.position.y
	node.offset_right = rect.end.x
	node.offset_bottom = rect.end.y
	if not node is Button:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _show_gears() -> void:
	if _pause.visible:
		return
	_options_visible(["P", "R", "N", "D", "−", "+"], [
		gear_requested.emit.bind("P"), gear_requested.emit.bind("R"), gear_requested.emit.bind("N"),
		gear_requested.emit.bind("D"), shift_requested.emit.bind(-1), shift_requested.emit.bind(1)])


func _show_vehicle() -> void:
	if _pause.visible:
		return
	_options_visible(["الدفع", "الدفرنس", "المصابيح", "الإشارات", "المسّاحات", "التشغيل", "النزول"], [
		drive_mode_requested.emit, differential_requested.emit, lighting_requested.emit, indicators_requested.emit, wipers_requested.emit, ignition_requested.emit, descent_requested.emit])


func _options_visible(labels: Array, handlers: Array) -> void:
	for child in _options.get_children():
		_options.remove_child(child)
		child.queue_free()
	for index in labels.size():
		_mini_button(_options, labels[index], handlers[index])
	_mini_button(_options, "إغلاق", _options.hide)
	_options.show()


func _mini_button(parent: Container, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(65, 42)
	parent.add_child(button)
	button.pressed.connect(action)


func overlay_open() -> bool:
	return _overlay.visible


func show_overlay(contents: Control) -> VBoxContainer:
	reset_input()
	_options.hide()
	_pause.hide()
	for child in _overlay.get_children():
		_overlay.remove_child(child)
		child.queue_free()
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	_overlay.add_child(content)
	content.add_child(contents)
	_overlay.show()
	return content


func hide_overlay() -> void:
	_overlay.hide()


func set_photo_mode(visible: bool) -> void:
	reset_input()
	_playing = not visible
	for child in _frame.get_children():
		child.visible = not visible and child not in [_pause, _overlay, _options, _photo_tools]
	_photo_tools.visible = visible


func _toggle_studio() -> void:
	_editing = not _editing
	reset_input()
	_pause.visible = not _editing
	_options.hide()
	if _editing:
		_options_visible(["حفظ توزيع التحكم"], [_finish_studio])
		_options.get_child(_options.get_child_count() - 1).hide()


func _finish_studio() -> void:
	_editing = false
	_edit_pointer = -1
	_options.hide()
	PersistenceManager.save_data_atomic()
	_pause.show()


func _edit_control(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _edit_pointer < 0:
			for key in _targets:
				var button: Button = _targets[key]
				if button.visible and button.get_global_rect().has_point(event.position):
					_edit_target = key
					_edit_pointer = event.index
					get_viewport().set_input_as_handled()
					return
		if not event.pressed and event.index == _edit_pointer:
			_edit_pointer = -1
	if event is InputEventScreenDrag and event.index == _edit_pointer:
		var offsets: Dictionary = PersistenceManager.save_data.touch_layout.offsets
		var offset: Array = offsets.get(_edit_target, [0.0, 0.0])
		offsets[_edit_target] = [clampf(offset[0] + event.relative.x, -400.0, 400.0), clampf(offset[1] + event.relative.y, -300.0, 90.0)]
		_apply_layout()
		get_viewport().set_input_as_handled()


func _apply_layout() -> void:
	var layout: Dictionary = PersistenceManager.save_data.touch_layout
	var safe := Rect2(Vector2.ZERO, _frame.size).grow(-14.0)
	if OS.has_feature("android"):
		var screen_bounds := Rect2(DisplayServer.get_display_safe_area())
		var canvas_bounds := get_viewport().get_screen_transform().affine_inverse() * screen_bounds
		if canvas_bounds.has_area() and safe.intersects(canvas_bounds):
			safe = safe.intersection(canvas_bounds)
	for key in _targets:
		var button: Button = _targets[key]
		var values: Array = _base_layout[key]
		var width: float = values[3].x * float(layout.scale)
		var height: float = values[3].y * float(layout.scale)
		var anchor: float = values[0]
		var x: float = values[1]
		if layout.left_handed:
			anchor = 1.0 - anchor
			x = -x - width
		var offset: Array = layout.offsets.get(key, [0.0, 0.0])
		var rect_x := clampf(anchor * _frame.size.x + x + float(offset[0]), safe.position.x, maxf(safe.position.x, safe.end.x - width))
		var rect_y := clampf(_frame.size.y + values[2] + float(offset[1]), safe.position.y, maxf(safe.position.y, safe.end.y - height))
		button.position = Vector2(rect_x, rect_y)
		button.size = Vector2(width, height)
		button.modulate.a = float(layout.opacity)
		if key == "steer":
			_wheel.position = button.position
			_wheel.size = button.size
			_wheel.pivot_offset = button.size * 0.5
			_wheel.modulate.a = float(layout.opacity)
