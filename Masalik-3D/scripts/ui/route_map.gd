class_name RouteMap
extends Control

signal waypoint_selected(distance: float)

var road: MountainRoadGenerator
var player_distance := 0.0
var target_distance := -1.0
var player_heading := Vector3.FORWARD
var _points := PackedVector2Array()
var _min := Vector2(INF, INF)
var _max := Vector2(-INF, -INF)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	for point in road.road_points:
		var coordinate := Vector2(-point.z, point.x * 4.0)
		_points.append(coordinate)
		_min = _min.min(coordinate)
		_max = _max.max(coordinate)
	resized.connect(queue_redraw)


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		var closest := 0
		var distance := INF
		for index in range(0, _points.size(), 3):
			var separ: float = event.position.distance_squared_to(_draw_pos(index))
			if separ < distance:
				distance = separ
				closest = index
		if distance < 45.0 ** 2:
			waypoint_selected.emit(closest * road.sample_step_m)
			accept_event()


func _draw() -> void:
	if _points.is_empty():
		return
	draw_style_box(_background(), Rect2(Vector2.ZERO, size))
	for region in WorldStreamingManager.REGIONS.size():
		var first := roundi(region * 2500.0 / road.sample_step_m)
		var last := mini(roundi((region + 1) * 2500.0 / road.sample_step_m), _points.size() - 1)
		var path := PackedVector2Array()
		for index in range(first, last, 4):
			path.append(_draw_pos(index))
		path.append(_draw_pos(last))
		draw_polyline(path, Color(WorldStreamingManager.REGIONS[region].ground).lightened(0.25), 4.0, true)
		draw_circle(_draw_pos(first), 4.5, Color("#d8caaa"), true, -1.0, true)
	if target_distance >= 0.0:
		var finish := roundi(target_distance / road.sample_step_m)
		var start := roundi(player_distance / road.sample_step_m)
		var direction := 1 if start <= finish else -1
		var guided := PackedVector2Array()
		for index in range(start, finish, direction * 3):
			guided.append(_draw_pos(index))
		guided.append(_draw_pos(finish))
		if guided.size() > 1:
			draw_polyline(guided, Color("#efbb65"), 3.8, true)
		draw_circle(_draw_pos(finish), 9.0, Color("#efbb65"), false, 2.0, true)
	var player := _draw_pos(roundi(player_distance / road.sample_step_m))
	var heading := Vector2(-player_heading.z, player_heading.x * 4.0).normalized()
	var wing := heading.orthogonal() * 5.0
	draw_colored_polygon(PackedVector2Array([player + heading * 9.0, player - heading * 5.0 + wing, player - heading * 5.0 - wing]), Color("#eaf5ff"))


func _draw_pos(index: int) -> Vector2:
	var normalized := (_points[clampi(index, 0, _points.size() - 1)] - _min) / (_max - _min).max(Vector2.ONE)
	return Vector2(27, 34) + normalized * (size - Vector2(54, 68))


func _background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#182738")
	style.set_corner_radius_all(12)
	return style
