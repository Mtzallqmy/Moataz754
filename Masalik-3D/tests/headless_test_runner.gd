extends SceneTree

const MENU := "res://scenes/main/MainMenu.tscn"
const DRIVE := "res://scenes/main/main_game.tscn"

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	check(ProjectSettings.get_setting("physics/3d/physics_engine") == "Jolt Physics", "Jolt configured")
	var menu := (load(MENU) as PackedScene).instantiate()
	root.add_child(menu)
	current_scene = menu
	check(menu.get_node("%Start") is Button, "Arabic menu starts")
	menu.get_node("%ShowAbout").pressed.emit()
	check(menu.get_node("%Credit").text.begins_with("برمجة وتطوير معتز العلقمي"), "About displays attribution")
	menu.get_node("%Start").pressed.emit()
	await process_frame
	await process_frame
	var game := current_scene
	if not check(game != null and game.scene_file_path == DRIVE, "Menu enters native driving scene"):
		quit(1)
		return
	game.player_input_enabled = false
	var vehicle := game.get_node("SUV4x4") as RaycastVehicleBody
	var road := game.get_node("SummitRoadWorld") as MountainRoadGenerator
	await _ticks(120)
	check(vehicle.wheel_raycasts.size() == 4 and vehicle.grounded_wheels == 4, "All four wheels contact the road at idle")
	check(vehicle.linear_velocity.length() < 0.3, "Stable idle on flat ground")
	check(road.road_points.size() > 400 and road.get_node("Asphalt").get_child(0) is StaticBody3D, "Road mesh has real collision")

	var position := vehicle.global_position
	vehicle.set_drive_inputs(1.0, 0, 0, false)
	await _ticks(165)
	var speed := vehicle.current_speed_kmh
	var distance := position.distance_to(vehicle.global_position)
	print("MEASURE acceleration: %.1f km/h after 2.75 s, %.1f m" % [speed, distance])
	check(speed > 20.0 and vehicle.global_position.z < position.z - 7.0, "Accelerates forward under physics")

	position = vehicle.global_position
	vehicle.set_drive_inputs(0, 1.0, 0, false)
	await _ticks(120)
	print("MEASURE braking: %.1f m from %.1f km/h, final %.2f km/h" % [
		position.distance_to(vehicle.global_position), speed, vehicle.current_speed_kmh])
	check(vehicle.current_speed_kmh < 1.4 and vehicle.grounded_wheels >= 3, "Brakes without unintended reverse")

	vehicle.drive_direction = -1
	position = vehicle.global_position
	vehicle.set_drive_inputs(0.55, 0, 0, false)
	await _ticks(100)
	check(vehicle.global_position.z > position.z + 1.0, "Explicit reverse backs up")
	vehicle.drive_direction = 1
	vehicle.set_drive_inputs(0, 0, 0, false)
	game._recover()
	await _ticks(90)

	var heading := vehicle.global_basis.z
	vehicle.set_drive_inputs(0.40, 0, -0.45, false)
	await _ticks(135)
	check(heading.angle_to(vehicle.global_basis.z) > 0.16, "Steering changes chassis heading")
	vehicle.set_drive_inputs(0, 0, 0, false)
	game._recover()
	await _ticks(90)

	var hud: CanvasLayer = game.hud
	var wheel: Button = hud._targets["steer"]
	var pedal: Button = hud._targets["throttle"]
	var center := wheel.get_global_rect().get_center()
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.index = 3
	touch.position = center + Vector2(0, -70)
	hud._input(touch)
	touch.index = 7
	touch.position = pedal.get_global_rect().get_center()
	hud._input(touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 3
	drag.position = center + Vector2(50, -50)
	hud._input(drag)
	await process_frame
	check(hud.throttle == 1.0 and hud.steering > 0.1, "Independent steering and throttle touch indexes")
	touch.pressed = false
	hud._input(touch)
	check(hud.throttle == 0.0 and hud._held.has("steer"), "Releasing pedal does not release wheel")

	print("RESULT: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _ticks(count: int) -> void:
	for index in count:
		await physics_frame


func check(condition: bool, description: String) -> bool:
	print("%s %s" % ["PASS" if condition else "FAIL", description])
	if not condition:
		failures += 1
	return condition
