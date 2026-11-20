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
	check(road.road_points.size() > 400 and road.get_node("Sector00/Road").get_child(0) is StaticBody3D, "Road mesh has real collision")

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

	game.traffic.enabled = false
	await _world_streaming(game)
	await _proving_ground()
	await _grade_and_surfaces(game)
	await _player_experience(game)
	current_scene.queue_free()
	await process_frame
	await process_frame
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


func _world_streaming(game: Node3D) -> void:
	var road: MountainRoadGenerator = game.road
	check(road.road_points.size() == 3751, "15 km route with 30 sectors has continuous sample data")
	for distance in [2550.0, 3650.0, 5100.0, 7800.0, 10870.0, 13000.0, 14980.0]:
		road.load_near(distance)
		await _ticks(3)
		var point := road.lane_transform(distance, 2.2, 0.0).origin
		var probe := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 10.0, point - Vector3.UP * 10.0, 1)
		var hit := game.get_world_3d().direct_space_state.intersect_ray(probe)
		check(not hit.is_empty() and absf(hit.position.y - point.y) < 0.45, "Loaded collision at %.0f m" % distance)
		check(road.stream.loaded_chunks.size() <= 5, "Streaming window bounded at %.0f m" % distance)
	road.load_near(20.0)
	game._recover()
	await _ticks(10)
	var traffic: TrafficAIManager = game.traffic
	traffic.enabled = true
	await _ticks(34)
	check(traffic.active_count() > 0 and traffic.active_count() <= traffic.density, "Traffic pool populates nearby lanes within density limit")
	traffic.enabled = false
	await _ticks(30)
	check(traffic.active_count() == 0, "Traffic pool despawns all agents when disabled")
	game.weather.configure("heavy_rain", "dawn")
	game._update_world(0.2)
	check(game.vehicle.wetness == 1.0 and game.road.asphalt.roughness < 0.6, "Rain updates physical traction input and surface material")
	game.weather.configure("clear", "morning")
	game._update_world(0.2)


func _player_experience(game: Node3D) -> void:
	var persistence := root.get_node("PersistenceManager")
	game._toggle_map()
	var map: RouteMap = game.hud._overlay.get_child(0).get_child(0)
	check(map.road == game.road and paused, "Offline map opens and pauses driving")
	map.waypoint_selected.emit(740.0)
	check(game._waypoint == 740.0 and map.target_distance == 740.0, "Map selects a local route destination")
	game.hud._overlay.get_child(0).get_child(-1).pressed.emit()
	check(not paused, "Closing map resumes driving")
	var camera: MasalikCameraController = game.camera
	var views: Dictionary = {}
	for index in 6:
		views[camera.current_view] = true
		camera.cycle_camera_view()
	check(views.size() == 6, "Six in-game camera views are available")

	game._save()
	check(persistence.save_data.has_driven and FileAccess.file_exists(persistence.SAVE_PATH_PRIMARY), "Free drive writes a native save")
	game._return_to_menu()
	await process_frame
	await process_frame
	var menu := current_scene
	check(not menu.get_node("%Continue").disabled, "Returning to the menu exposes continue")
	menu.call("_show_garage")
	await process_frame
	var garage: Node = menu.get("_garage")
	check(garage.get("_model").vehicle_id == "shahiq", "Garage opens with the selected 3D vehicle")
	garage.call("_select", 3)
	check(garage.get("_model").vehicle_id == "madina", "Garage previews another vehicle ID")
	garage.call("_select", 0)
	garage.call("_cycle_paint")
	check(persistence.save_data.vehicle_customizations.has("shahiq"), "Garage paint is persistent")
	menu.call("_close_detail")
	menu.call("_show_settings")
	check(menu.get("_body").get_child_count() > 10, "Settings exposes functional controls")
	menu.call("_close_detail")
	var resume := menu.get_node("%Continue") as Button
	resume.pressed.emit()
	await process_frame
	await process_frame
	game = current_scene
	check(game.road.stream.loaded_chunks.has(int(game.drive_distance / 500.0)), "Continue restores road collision before spawning")

	game._return_to_menu()
	await process_frame
	await process_frame
	menu = current_scene
	check(MissionCatalog.STORY.size() == 25 and MissionCatalog.ACTIVITIES.size() == 6, "Five chapters and six bonus activities are available")
	var school := MissionCatalog.find("school_01")
	menu.call("_start_mission", school)
	await process_frame
	await process_frame
	game = current_scene
	check(game.mission != null and game.mission.spec.id == "school_01", "Menu starts driving-school mission")
	game._save()
	check(persistence.save_data.active_attempt.get("id") == "school_01", "An unfinished mission saves its checkpoint state")
	game._return_to_menu()
	await process_frame
	await process_frame
	current_scene.get_node("%Continue").pressed.emit()
	await process_frame
	await process_frame
	game = current_scene
	check(game.mission != null and game.mission.spec.id == "school_01" and game.mission.next_gate == 0, "Continue reopens the saved mission")
	await _ticks(90)
	for index in 1800:
		if paused:
			break
		var distance: float = game.vehicle.global_position.z * -1.0
		if distance >= 101.5:
			Input.action_release("drive_accelerate")
			Input.action_press("drive_brake", 0.88)
		elif distance < 99.0 and game.vehicle.current_speed_kmh < 32.0:
			Input.action_press("drive_accelerate", 0.53)
		else:
			Input.action_release("drive_accelerate")
		await physics_frame
	Input.action_release("drive_accelerate")
	Input.action_release("drive_brake")
	check(paused and game.mission.outcome == MissionRun.Outcome.COMPLETED, "Vehicle drives all school checkpoints and stops at the finish")
	check(persistence.save_data.best_records.has("school_01") and persistence.save_data.credits >= 140, "Mission completion writes records and credits")
	check(persistence.save_data.active_attempt.is_empty(), "Completed mission clears the saved attempt")
	print("MEASURE driving school: %.2f s, gates %d/%d" % [game.mission.elapsed, game.mission.next_gate, game.mission.gates.size()])
	paused = false

	persistence.save_data_atomic()
	var saved_credits: int = persistence.save_data.credits
	var staging := FileAccess.open(persistence.SAVE_PATH_PRIMARY + ".tmp", FileAccess.WRITE)
	staging.store_string("staged runtime data interrupted mid-write")
	staging.close()
	persistence.load_data()
	check(persistence.save_data.credits == saved_credits, "Interrupted staging write leaves the primary save intact")
	var damaged := FileAccess.open(persistence.SAVE_PATH_PRIMARY, FileAccess.WRITE)
	damaged.store_string("invalid primary")
	damaged.close()
	persistence.save_data.credits = -1
	persistence.load_data()
	check(persistence.save_data.credits == saved_credits and persistence._read_v2(persistence.SAVE_PATH_PRIMARY).size() > 0, "Invalid primary recovers from the previous valid backup")
	var imported := JSON.stringify({
		"schemaVersion": 2, "selectedVehicleId": "saqr", "unlockedVehicles": ["shahiq", "saqr"],
		"masalikCoins": 5000, "driverXp": 300, "playerDistanceM": 1250,
		"missionBestTimesSec": {"story_c1_m1": 73.4}, "missionCompletions": {"story_c1_m1": 1},
	})
	check(persistence.import_save_text(imported), "Native save manager imports a web schema v2 export")
	check(persistence.save_data.credits == 5000 and persistence.own_vehicle("saqr") and persistence.save_data.best_records.has("school_01"), "Import retains native records while adding web progression")


func _grade_and_surfaces(game: Node3D) -> void:
	var floor := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(50.0, 0.5, 280.0)
	collision.shape = shape
	floor.add_child(collision)
	var slope := Basis(Vector3.RIGHT, deg_to_rad(8.0))
	floor.transform = Transform3D(slope, Vector3(900.0, 200.0, -130.0))
	floor.set_meta("surface_type", "asphalt")
	root.add_child(floor)
	var fixture := load("res://scenes/vehicles/fleet_vehicle.tscn") as PackedScene
	var car := fixture.instantiate() as RaycastVehicleBody
	car.transform = Transform3D(slope, floor.to_global(Vector3(0, 1.15, 75.0)))
	root.add_child(car)
	car.set_drive_inputs(0, 1, 0, false)
	await _ticks(100)
	var initial := car.global_position
	car.powertrain.mode = "4L"
	car.set_drive_inputs(0.8, 0, 0, false)
	await _ticks(210)
	var rise := car.global_position.y - initial.y
	var climb := -car.global_position.z + initial.z
	check(rise > 0.8 and climb > 8.0 and car.grounded_wheels >= 3, "SUV climbs the 8° test slope in low range")
	print("MEASURE uphill: %.1f m horizontal, %.1f m rise in 3.5 s" % [climb, rise])

	car.global_transform = Transform3D(slope.rotated(slope.y, PI), floor.to_global(Vector3(0, 1.15, -76.0)))
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO
	car.reset_wheels()
	car.powertrain.mode = "4H"
	car.set_drive_inputs(0, 0, 0, false)
	car.hdc_enabled = true
	await _ticks(360)
	var downhill := car.current_speed_kmh
	print("MEASURE HDC on 8° slope after 6 s: %.1f km/h" % downhill)
	check(downhill > 2.0 and downhill < 17.0, "Hill descent keeps chassis speed bounded")
	car.queue_free()
	await process_frame

	floor.transform = Transform3D(Basis.IDENTITY, Vector3(900.0, 100.0, -120.0))
	var speeds: Dictionary = {}
	for surface in ["asphalt", "sand", "mud"]:
		floor.set_meta("surface_type", surface)
		car = fixture.instantiate() as RaycastVehicleBody
		car.position = Vector3(900.0, 101.0, -10.0)
		root.add_child(car)
		await _ticks(90)
		car.set_drive_inputs(1, 0, 0, false)
		await _ticks(230)
		speeds[surface] = car.current_speed_kmh
		check(car.current_surface == surface, "Wheel rays identify %s" % surface)
		car.queue_free()
		await process_frame
	print("MEASURE surface speeds after 3.83 s: asphalt %.1f, sand %.1f, mud %.1f km/h" % [speeds.asphalt, speeds.sand, speeds.mud])
	check(speeds.asphalt - speeds.sand > 3.0 and speeds.asphalt - speeds.mud > 3.0, "Sand and mud measurably reduce traction")
	floor.queue_free()

	game.vehicle.global_basis = game.vehicle.global_basis.rotated(Vector3.BACK, PI)
	game._recover()
	await _ticks(90)
	check(game.vehicle.global_basis.y.dot(Vector3.UP) > 0.9 and game.vehicle.grounded_wheels == 4, "Recovery restores an inverted vehicle to a grounded lane")
