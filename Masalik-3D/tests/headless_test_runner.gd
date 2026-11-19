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

	await _proving_ground()
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


func _proving_ground() -> void:
	var floor := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_size := BoxShape3D.new()
	floor_size.size = Vector3(100.0, 0.5, 2900.0)
	floor_shape.shape = floor_size
	floor.add_child(floor_shape)
	floor.position = Vector3(800.0, -0.25, -1350.0)
	floor.set_meta("surface_type", "asphalt")
	root.add_child(floor)

	check(VehicleFleetRegistry.IDS.size() == 10, "Ten original vehicle IDs retained")
	var fixture := load("res://scenes/vehicles/fleet_vehicle.tscn") as PackedScene
	var acceleration: Dictionary = {}
	for id in ["shahiq", "madina", "jabal"]:
		var car := fixture.instantiate() as RaycastVehicleBody
		car.vehicle_id = id
		car.position = Vector3(800.0, 0.9, 0.0)
		root.add_child(car)
		await _ticks(120)
		check(car.grounded_wheels == 4 and car.normal_load[0] > 500.0, "%s suspension bears load" % id)
		car.set_drive_inputs(1, 0, 0, false)
		var reaches_100 := -1.0
		for tick in 2400:
			await physics_frame
			if tick == 299:
				acceleration[id] = car.current_speed_kmh
			if car.current_speed_kmh >= 100.0:
				reaches_100 = (tick + 1) / 60.0
				break
		var stopped_at := car.global_position
		var braking_from := car.current_speed_kmh
		car.set_drive_inputs(0, 1, 0, false)
		for tick in 300:
			await physics_frame
			if car.current_speed_kmh < 0.4:
				break
		print("MEASURE %s %.0f kg: 0–100 %.2f s, %.1f km/h after 5 s, stop %.1f m from %.1f km/h (%s, %.0f RPM)" % [
			id, car.mass, reaches_100, acceleration.get(id, 100.0), stopped_at.distance_to(car.global_position), braking_from, car.powertrain.gear_label(), car.powertrain.rpm])
		check(car.current_speed_kmh < 1.0, "%s brakes to rest" % id)
		if id == "shahiq":
			check(reaches_100 > 5.0 and reaches_100 < 40.0, "SUV reaches 100 km/h on the straight")
			var normal_ratio := car.powertrain.ratio()
			car.powertrain.mode = "4L"
			check(is_equal_approx(car.powertrain.ratio() / normal_ratio, 2.55), "4L changes actual gear multiplication")
			car.powertrain.mode = "2H"
			check(car._drive_weights() == Vector4(0, 0, 0.5, 0.5), "2H routes torque to rear wheels")
		car.queue_free()
		await process_frame
	check(absf(acceleration.get("madina", 100.0) - acceleration.get("jabal", 100.0)) > 4.0, "Fleet acceleration differs by specification")
	floor.queue_free()
