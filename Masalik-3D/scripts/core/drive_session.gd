extends Node3D

const HUD := preload("res://scripts/ui/drive_hud.gd")
const MENU_SCENE := "res://scenes/main/MainMenu.tscn"
const PAINTS := [Color("#bd723b"), Color("#233352"), Color("#39564a"), Color("#a93337"), Color("#d0c7b6"), Color("#1c232a")]

@onready var road: MountainRoadGenerator = $SummitRoadWorld
@onready var vehicle: RaycastVehicleBody = $SUV4x4
@onready var camera: MasalikCameraController = $MainCamera3D

var hud: HUD
var player_input_enabled := true
var _autosave_time := 0.0
var _checkpoint := 20.0
var drive_distance := 20.0
var player_sample := -1
var weather: TimeAndWeatherSystem
var traffic: TrafficAIManager
var audio: DriveAudio
var mission: MissionRun
var _mission_gate: MeshInstance3D
var _world_tick := 0.0
var _waypoint := -1.0
var _photo := false
var _track_label := ""
var _resume_attempt: Dictionary = {}


func _enter_tree() -> void:
	var car := $SUV4x4 as RaycastVehicleBody
	var spec: Dictionary = QualityManager.active_mission
	car.vehicle_id = VehicleFleetRegistry.canonical_id(spec.get("vehicle", str(PersistenceManager.save_data.selected_vehicle_id)))
	if not spec.is_empty() and spec.get("cargo", 0) > 0:
		car.config = VehicleFleetRegistry.build_config(car.vehicle_id)
		car.config.mass_kg += car.config.cargo_limit * float(spec.cargo) * 0.01


func _ready() -> void:
	var data: Dictionary = PersistenceManager.save_data
	var quality := maxi(0, ["Low", "Medium", "High"].find(data.quality_preset))
	QualityManager.apply_quality_preset(quality)
	var spec: Dictionary = QualityManager.active_mission
	_checkpoint = QualityManager.selected_region_start
	if not spec.is_empty():
		mission = MissionRun.new(spec)
		_checkpoint = float(spec.start)
		if QualityManager.resume_drive:
			_resume_attempt = data.active_attempt
			mission.next_gate = clampi(int(_resume_attempt.get("next_gate", 0)), 0, mission.gates.size() - 1)
			mission.elapsed = clampf(float(_resume_attempt.get("elapsed", 0.0)), 0.0, float(spec.limit))
			var safe_start := float(spec.start) if mission.next_gate == 0 else mission.gates[mission.next_gate - 1]
			_checkpoint = clampf(float(_resume_attempt.get("distance", safe_start)), safe_start - 5.0, mission.target() - 14.0)
			_restore_vehicle(_resume_attempt)
		_create_mission_gate()
	elif QualityManager.resume_drive:
		var saved: Dictionary = data.last_world_state
		_checkpoint = clampf(float(saved.get("s_meters", 20.0)), 8.0, road.road_length_m - 8.0)
		_restore_vehicle(saved)

	var paint := int(data.vehicle_customizations.get(vehicle.vehicle_id, {}).get("native_paint", -1))
	if paint >= 0 and paint < PAINTS.size():
		vehicle.get_node("VehicleVisual").paint.albedo_color = PAINTS[paint]
	vehicle.powertrain.manual = data.transmission_type == "manual"
	vehicle.abs_enabled = data.Driving_realism != "simulation"
	vehicle.tcs_enabled = data.Driving_realism != "simulation"
	vehicle.esc_enabled = data.Driving_realism != "simulation"
	vehicle.hdc_enabled = data.Driving_realism == "arcade"
	road.load_near(_checkpoint)
	vehicle.global_transform = road.lane_transform(_checkpoint, 2.2)
	drive_distance = _checkpoint
	player_sample = int(_checkpoint / road.sample_step_m)
	weather = TimeAndWeatherSystem.new($WorldEnvironment.environment, $DirectionalLight3D)
	weather.configure(spec.get("weather", data.weather), spec.get("time", data.time_of_day))
	traffic = TrafficAIManager.new()
	traffic.road = road
	traffic.player = vehicle
	traffic.player_distance = _checkpoint
	traffic.density = [3, 6, 10][quality]
	traffic.enabled = mission == null
	add_child(traffic)
	audio = DriveAudio.new()
	audio.car = vehicle
	vehicle.add_child(audio)
	_setup_hud()


func _restore_vehicle(saved: Dictionary) -> void:
	vehicle.powertrain.fuel = clampf(float(saved.get("fuel_liters", vehicle.config.fuel_capacity)), 0.0, vehicle.config.fuel_capacity)
	if saved.get("damage_state") is Dictionary:
		for part in vehicle.condition:
			var wear: Variant = saved.damage_state.get(part, 100.0)
			if wear is float or wear is int:
				vehicle.condition[part] = clampf(float(wear), 0.0, 100.0)

func _setup_hud() -> void:
	hud = HUD.new()
	add_child(hud)
	hud.reverse_requested.connect(_toggle_reverse)
	hud.camera_requested.connect(camera.cycle_camera_view)
	hud.pause_requested.connect(_toggle_pause)
	hud.recovery_requested.connect(_recover)
	hud.menu_requested.connect(_return_to_menu)
	hud.map_requested.connect(_toggle_map)
	hud.gear_requested.connect(_select_gear)
	hud.shift_requested.connect(vehicle.powertrain.shift_manual)
	hud.drive_mode_requested.connect(_cycle_drivetrain)
	hud.differential_requested.connect(_toggle_differential)
	hud.lighting_requested.connect(_cycle_lights)
	hud.indicators_requested.connect(_cycle_indicators)
	hud.wipers_requested.connect(_toggle_wipers)
	hud.horn_requested.connect(audio.horn)
	hud.ignition_requested.connect(_toggle_ignition)
	hud.descent_requested.connect(_toggle_descent)
	hud.photo_requested.connect(_toggle_photo)
	hud.photo_move.connect(func(direction: float): camera.orbit += direction * 0.24)
	hud.photo_capture_requested.connect(_capture_photo)


func _physics_process(delta: float) -> void:
	if not player_input_enabled:
		return
	if _photo:
		return
	_keyboard_commands()
	if get_tree().paused:
		return
	var steer := clampf(hud.steering + Input.get_axis("drive_left", "drive_right"), -1.0, 1.0)
	var throttle := maxf(hud.throttle, Input.get_action_strength("drive_accelerate"))
	var brake := maxf(hud.brake, Input.get_action_strength("drive_brake"))
	vehicle.set_drive_inputs(throttle, brake, steer, hud.handbrake or Input.is_action_pressed("drive_handbrake"))
	vehicle.clutch_input = maxf(hud.clutch, Input.get_action_strength("drive_clutch"))
	var visuals := vehicle.get_node("VehicleVisual")
	visuals.set_lights(brake > 0.05, vehicle.powertrain.selector == "R")
	visuals.animate_controls(delta, steer)
	audio.interior = camera.current_view == MasalikCameraController.CameraView.CABIN
	hud.update_readout(vehicle, _track_label)
	if vehicle.global_position.y < road.road_points[maxi(0, player_sample)].y - 28.0:
		_recover()
	_world_tick += delta
	if _world_tick >= 0.20:
		_update_world(_world_tick)
		_world_tick = 0.0
	_autosave_time += delta
	if _autosave_time >= 12.0:
		_autosave_time = 0.0
		_save()


func _keyboard_commands() -> void:
	if Input.is_action_just_pressed("drive_reverse"):
		_toggle_reverse()
	if Input.is_action_just_pressed("drive_camera"):
		camera.cycle_camera_view()
	if Input.is_action_just_pressed("drive_shift_up"):
		vehicle.powertrain.shift_manual(1)
	if Input.is_action_just_pressed("drive_shift_down"):
		vehicle.powertrain.shift_manual(-1)
	if Input.is_action_just_pressed("drive_lights"):
		_cycle_lights()
	if Input.is_action_just_pressed("drive_horn"):
		audio.horn()
	if Input.is_action_just_pressed("drive_map"):
		_toggle_map()
	if Input.is_action_just_pressed("ui_cancel"):
		_toggle_pause()


func _notification(what: int) -> void:
	if (what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST) and is_node_ready() and player_input_enabled:
		_save()


func _toggle_reverse() -> void:
	vehicle.drive_direction *= -1


func _select_gear(selection: String) -> void:
	vehicle.powertrain.set_selector(selection, vehicle.linear_velocity.length())


func _cycle_drivetrain() -> void:
	if vehicle.current_speed_kmh > 11.0:
		return
	var modes := vehicle.config.supported_modes
	vehicle.powertrain.mode = modes[(modes.find(vehicle.powertrain.mode) + 1) % modes.size()]


func _toggle_differential() -> void:
	vehicle.diff_locked = not vehicle.diff_locked
	_track_label = "قفل التفاضل مفعل" if vehicle.diff_locked else "قفل التفاضل متوقف"


func _toggle_descent() -> void:
	vehicle.hdc_enabled = not vehicle.hdc_enabled
	_track_label = "مساعد النزول مفعل" if vehicle.hdc_enabled else "مساعد النزول متوقف"


func _toggle_ignition() -> void:
	vehicle.powertrain.running = not vehicle.powertrain.running and vehicle.powertrain.fuel > 0.0
	if vehicle.powertrain.running:
		vehicle.powertrain.rpm = vehicle.config.idle_rpm


func _cycle_lights() -> void:
	var display := vehicle.get_node("VehicleVisual")
	if not display.lights_on:
		display.lights_on = true
	elif not display.high_beams:
		display.high_beams = true
	else:
		display.lights_on = false
		display.high_beams = false


func _cycle_indicators() -> void:
	var visuals := vehicle.get_node("VehicleVisual")
	var modes := [0, -1, 1, 2]
	visuals.turn_signal = modes[(modes.find(visuals.turn_signal) + 1) % modes.size()]


func _toggle_wipers() -> void:
	var visuals := vehicle.get_node("VehicleVisual")
	visuals.wipers = not visuals.wipers


func _toggle_pause() -> void:
	if hud.overlay_open():
		return
	var paused := not get_tree().paused
	if paused:
		_save()
	get_tree().paused = paused
	hud.show_pause(paused)


func _save() -> void:
	var data: Dictionary = PersistenceManager.save_data
	if mission != null:
		if mission.outcome == MissionRun.Outcome.IN_PROGRESS:
			data.active_attempt = {
				"id": mission.spec.id, "next_gate": mission.next_gate, "elapsed": mission.elapsed,
				"distance": drive_distance, "fuel_liters": vehicle.powertrain.fuel, "damage_state": vehicle.condition.duplicate(),
			}
			PersistenceManager.save_data_atomic()
		return
	var current := road.nearest_sample(vehicle.global_position, player_sample) * road.sample_step_m
	_checkpoint = clampf(current, 8.0, road.road_length_m - 8.0)
	data.last_world_state.s_meters = _checkpoint
	data.last_world_state.fuel_liters = vehicle.powertrain.fuel
	data.last_world_state.damage_state = vehicle.condition.duplicate()
	data.has_driven = true
	data.has_driven_recorded = true
	PersistenceManager.save_data_atomic()


func _recover() -> void:
	if mission != null:
		_checkpoint = mission.gates[mission.next_gate - 1] - 12.0 if mission.next_gate > 0 else float(mission.spec.start)
	road.load_near(_checkpoint)
	player_sample = int(_checkpoint / road.sample_step_m)
	drive_distance = _checkpoint
	vehicle.global_transform = road.lane_transform(_checkpoint, 2.2)
	vehicle.linear_velocity = Vector3.ZERO
	vehicle.angular_velocity = Vector3.ZERO
	vehicle.reset_wheels()


func _return_to_menu() -> void:
	_save()
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


func _update_world(delta: float) -> void:
	player_sample = road.nearest_sample(vehicle.global_position, player_sample)
	drive_distance = player_sample * road.sample_step_m
	road.load_near(drive_distance)
	traffic.player_distance = drive_distance
	weather.update(delta)
	vehicle.wetness = weather.wetness
	audio.raining = weather.wetness
	road.set_wetness(weather.wetness)
	var region: Dictionary = WorldStreamingManager.region_at(drive_distance)
	_track_label = region.name
	if mission != null:
		var previous := mission.next_gate
		var lane := road.lane_transform(drive_distance, 0, 0)
		var offset := (vehicle.global_position - lane.origin).dot(lane.basis.x)
		mission.update(delta, drive_distance, offset, vehicle.current_speed_kmh, vehicle.condition.body)
		_track_label = "%s  •  %d/%d  •  %d م" % [mission.spec.name, mission.next_gate, mission.gates.size(), roundi(absf(mission.target() - drive_distance))]
		if mission.outcome != MissionRun.Outcome.IN_PROGRESS:
			_finish_mission()
		elif previous != mission.next_gate:
			_place_mission_gate()
	elif _waypoint >= 0.0:
		var difference := _waypoint - drive_distance
		if absf(difference) < 16.0:
			_track_label = "وصلت إلى نقطة المسار"
		else:
			_track_label += "  •  %d م %s" % [roundi(absf(difference)), "للأمام" if difference > 0.0 else "للخلف"]


func _create_mission_gate() -> void:
	_mission_gate = MeshInstance3D.new()
	var marker := CylinderMesh.new()
	marker.top_radius = 0.0
	marker.bottom_radius = 0.28
	marker.height = 1.0
	var highlighted := StandardMaterial3D.new()
	highlighted.albedo_color = Color("#f9b65e")
	highlighted.emission_enabled = true
	highlighted.emission = Color("#b76c25")
	marker.material = highlighted
	_mission_gate.mesh = marker
	add_child(_mission_gate)
	_place_mission_gate()


func _place_mission_gate() -> void:
	_mission_gate.position = road.lane_transform(mission.target(), 0.0, 1.5).origin


func _finish_mission() -> void:
	PersistenceManager.save_data.active_attempt = {}
	var completed := mission.outcome == MissionRun.Outcome.COMPLETED
	var result := Label.new()
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.add_theme_font_size_override("font_size", 30)
	var reward := 0
	if completed:
		reward = PersistenceManager.record_mission(mission.spec, mission.elapsed, vehicle.condition.body)
	else:
		PersistenceManager.save_data_atomic()
	result.text = "اكتملت المهمة\n%.1f ثانية  •  %d رصيد" % [mission.elapsed, reward] if completed else "انتهت المحاولة\nأعد المسار في الوقت المحدد وحافظ على المركبة"
	var buttons := hud.show_overlay(result)
	_add_overlay_button(buttons, "أعد المحاولة", func():
		get_tree().paused = false
		QualityManager.resume_drive = false
		get_tree().reload_current_scene())
	_add_overlay_button(buttons, "عودة إلى القائمة", _return_to_menu)
	get_tree().paused = true


func _toggle_map() -> void:
	if hud.overlay_open():
		return
	var map := RouteMap.new()
	map.road = road
	map.player_distance = drive_distance
	map.target_distance = mission.target() if mission != null else _waypoint
	map.player_heading = -vehicle.global_basis.z
	map.custom_minimum_size = Vector2(630.0, 377.0)
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var content := hud.show_overlay(map)
	var instruction := Label.new()
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.text = "المسار الحالي" if mission != null else "المس الطريق لاختيار وجهة"
	content.add_child(instruction)
	if mission == null:
		map.waypoint_selected.connect(func(distance: float):
			_waypoint = distance
			map.target_distance = distance
			map.queue_redraw())
	_add_overlay_button(content, "متابعة القيادة", func():
		hud.hide_overlay()
		get_tree().paused = false)
	get_tree().paused = true


func _add_overlay_button(parent: Control, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48.0
	parent.add_child(button)
	button.pressed.connect(action)


func _toggle_photo() -> void:
	_photo = not _photo
	vehicle.freeze = _photo
	vehicle.set_drive_inputs(0, 0, 0, false)
	camera.photo_mode = _photo
	get_tree().paused = false
	hud.set_photo_mode(_photo)


func _capture_photo() -> void:
	if DisplayServer.get_name() == "headless":
		return
	hud.hide()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var file := "user://my-car-photo-%d.png" % int(Time.get_unix_time_from_system())
	var error := image.save_png(file)
	if error != OK:
		push_warning("Could not save photo: %s" % error_string(error))
	hud.show()
