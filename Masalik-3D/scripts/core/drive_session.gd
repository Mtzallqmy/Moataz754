extends Node3D

const HUD := preload("res://scripts/ui/drive_hud.gd")

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
var _world_tick := 0.0


func _ready() -> void:
	if QualityManager.resume_drive:
		var saved: Dictionary = PersistenceManager.save_data["last_world_state"]
		_checkpoint = clampf(float(saved.get("s_meters", 20.0)), 4.0, road.road_length_m - 8.0)
	road.load_near(_checkpoint)
	vehicle.global_transform = road.lane_transform(_checkpoint, 2.2)
	drive_distance = _checkpoint
	player_sample = int(_checkpoint / road.sample_step_m)
	weather = TimeAndWeatherSystem.new($WorldEnvironment.environment, $DirectionalLight3D)
	weather.configure("clear", "morning")
	traffic = TrafficAIManager.new()
	traffic.road = road
	traffic.player = vehicle
	traffic.player_distance = _checkpoint
	traffic.density = [3, 6, 10][QualityManager.current_quality]
	add_child(traffic)
	hud = HUD.new()
	add_child(hud)
	hud.reverse_requested.connect(_toggle_reverse)
	hud.camera_requested.connect(camera.cycle_camera_view)
	hud.pause_requested.connect(_toggle_pause)
	hud.recovery_requested.connect(_recover)
	hud.menu_requested.connect(_return_to_menu)


func _physics_process(delta: float) -> void:
	if not player_input_enabled:
		return
	if Input.is_action_just_pressed("drive_reverse"):
		_toggle_reverse()
	if Input.is_action_just_pressed("drive_camera"):
		camera.cycle_camera_view()
	if Input.is_action_just_pressed("ui_cancel"):
		_toggle_pause()
		return

	var steer := clampf(hud.steering + Input.get_axis("drive_left", "drive_right"), -1.0, 1.0)
	var throttle := maxf(hud.throttle, Input.get_action_strength("drive_accelerate"))
	var brake := maxf(hud.brake, Input.get_action_strength("drive_brake"))
	vehicle.set_drive_inputs(throttle, brake, steer, hud.handbrake or Input.is_action_pressed("drive_handbrake"))
	hud.update_readout(vehicle.current_speed_kmh, vehicle.drive_direction == -1)
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and is_node_ready() and player_input_enabled:
		_save()


func _toggle_reverse() -> void:
	if vehicle.linear_velocity.length() <= 0.75:
		vehicle.drive_direction *= -1


func _toggle_pause() -> void:
	var paused := not get_tree().paused
	if paused:
		_save()
	get_tree().paused = paused
	hud.show_pause(paused)


func _save() -> void:
	_checkpoint = clampf(drive_distance, 8.0, road.road_length_m - 8.0)
	PersistenceManager.save_data["last_world_state"]["s_meters"] = _checkpoint
	PersistenceManager.save_data["has_driven"] = true
	PersistenceManager.save_data_atomic()


func _recover() -> void:
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
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")


func _update_world(delta: float) -> void:
	player_sample = road.nearest_sample(vehicle.global_position, player_sample)
	drive_distance = player_sample * road.sample_step_m
	road.load_near(drive_distance)
	traffic.player_distance = drive_distance
	weather.update(delta)
	vehicle.wetness = weather.wetness
	road.set_wetness(weather.wetness)
