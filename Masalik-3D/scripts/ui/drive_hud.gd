extends CanvasLayer

signal reverse_requested
signal camera_requested
signal pause_requested
signal recovery_requested
signal menu_requested

var steering := 0.0
var throttle := 0.0
var brake := 0.0
var handbrake := false
var _held: Dictionary = {}
var _start_angle := 0.0
var _wheel_angle := 0.0
var _targets: Dictionary = {}
var _readout: Label
var _pause: PanelContainer
var _wheel: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var frame := Control.new()
	add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.layout_direction = Control.LAYOUT_DIRECTION_LTR

	_readout = Label.new()
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_readout.add_theme_font_size_override("font_size", 34)
	_readout.add_theme_color_override("font_color", Color("#f4ce8d"))
	_place(frame, _readout, Vector2(0.5, 0), Rect2(-200, 12, 400, 52))
	_targets["steer"] = _button(frame, "◉", Vector2(0, 1), Rect2(26, -210, 182, 182))
	_wheel = Label.new()
	_wheel.text = "┃"
	_wheel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wheel.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_wheel.add_theme_color_override("font_color", Color("#ffc768"))
	_wheel.add_theme_font_size_override("font_size", 42)
	_place(frame, _wheel, Vector2(0, 1), Rect2(26, -210, 182, 182))
	_wheel.pivot_offset = Vector2(91, 91)
	_targets["throttle"] = _button(frame, "وقود", Vector2(1, 1), Rect2(-126, -157, 96, 128))
	_targets["brake"] = _button(frame, "فرامل", Vector2(1, 1), Rect2(-232, -136, 94, 106))
	_targets["handbrake"] = _button(frame, "يدوية", Vector2(1, 1), Rect2(-330, -91, 88, 61))
	_button(frame, "ناقل", Vector2(1, 1), Rect2(-126, -218, 96, 51)).pressed.connect(reverse_requested.emit)
	_button(frame, "كاميرا", Vector2(1, 0), Rect2(-310, 20, 130, 52)).pressed.connect(camera_requested.emit)
	_button(frame, "إيقاف مؤقت", Vector2(1, 0), Rect2(-168, 20, 142, 52)).pressed.connect(pause_requested.emit)
	_button(frame, "استعادة", Vector2(0, 0), Rect2(26, 20, 126, 52)).pressed.connect(recovery_requested.emit)

	_pause = PanelContainer.new()
	_place(frame, _pause, Vector2(0.5, 0.5), Rect2(-172, -88, 344, 176))
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
	_pause.hide()


func _process(delta: float) -> void:
	if not "steer" in _held:
		_wheel_angle = move_toward(_wheel_angle, 0, delta * 8.0)
	steering = _wheel_angle / (PI * 0.75)
	_wheel.rotation = _wheel_angle


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not _pause.visible:
		if event.pressed:
			for action: String in _targets:
				var button := _targets[action] as Button
				if not _held.has(action) and button.get_global_rect().has_point(event.position):
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
	if event is InputEventScreenDrag and not _pause.visible and _held.get("steer", -1) == event.index:
		var angle := _touch_angle(event.position)
		_wheel_angle = clampf(_wheel_angle + angle_difference(_start_angle, angle), -PI * 0.75, PI * 0.75)
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
	_pause.visible = paused


func update_readout(speed: float, reverse: bool) -> void:
	var direction := "R" if reverse else "D"
	_readout.text = "%d   كم/س   •   %s" % [roundi(speed), direction]


func _update_pedals() -> void:
	throttle = float(_held.has("throttle"))
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
