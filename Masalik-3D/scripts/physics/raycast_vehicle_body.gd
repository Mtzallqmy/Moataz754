class_name RaycastVehicleBody
extends RigidBody3D

const TIRE_STEPS := 8
const SURFACE_PROPERTIES := {
	"asphalt": Vector2(1.0, 1.0), "wet_asphalt": Vector2(0.74, 1.12),
	"gravel": Vector2(0.76, 2.5), "dirt": Vector2(0.67, 2.8),
	"mud": Vector2(0.43, 7.2), "sand": Vector2(0.52, 8.0),
	"rock": Vector2(0.88, 3.4), "grass": Vector2(0.57, 3.2),
	"water": Vector2(0.36, 6.0),
}

@export var vehicle_id := "shahiq"
@export var config: VehiclePhysicsConfig
@export var wheel_raycasts: Array[RayCast3D] = []
@export var visual_wheel_nodes: Array[Node3D] = []

var throttle_input := 0.0
var brake_input := 0.0
var steer_input := 0.0
var clutch_input := 0.0
var handbrake_active := false
var abs_enabled := true
var tcs_enabled := true
var esc_enabled := true
var hdc_enabled := false
var diff_locked := false
var wetness := 0.0
var grounded_wheels := 0
var current_speed_kmh := 0.0
var current_surface := "asphalt"
var current_steer_rad := 0.0
var powertrain: VehiclePowertrain

var wheel_omega := PackedFloat32Array([0, 0, 0, 0])
var wheel_spin := PackedFloat32Array([0, 0, 0, 0])
var compression := PackedFloat32Array([0, 0, 0, 0])
var normal_load := PackedFloat32Array([0, 0, 0, 0])
var slip_ratio := PackedFloat32Array([0, 0, 0, 0])
var slip_angle := PackedFloat32Array([0, 0, 0, 0])
var contact := [false, false, false, false]
var condition := {"engine": 100.0, "suspension": 100.0, "tires": 100.0, "body": 100.0, "cooling": 100.0}
var _impact_cooldown := 0.0

var drive_direction: int:
	get:
		return -1 if powertrain.selector == "R" else 1
	set(value):
		powertrain.set_selector("R" if value < 0 else "D", linear_velocity.length())


func _enter_tree() -> void:
	assert(wheel_raycasts.size() == 4, "Bind wheel rays FL, FR, RL and RR")
	if config == null:
		config = VehicleFleetRegistry.build_config(vehicle_id)
	powertrain = VehiclePowertrain.new(config)
	mass = config.mass_kg
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = config.center_of_mass_offset
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.02
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 0.25
	max_contacts_reported = 4
	contact_monitor = true
	can_sleep = false
	for index in 4:
		var ray := wheel_raycasts[index]
		ray.position.x = config.track_width * (0.5 if index % 2 else -0.5)
		ray.position.z = config.wheelbase * (-0.5 if index < 2 else 0.5)
		ray.target_position.y = -(config.suspension_rest_length + config.suspension_max_travel * 0.35 + config.wheel_radius)
	var shape := $CollisionShape3D as CollisionShape3D
	shape.shape = shape.shape.duplicate()
	shape.position.y = 0.47
	(shape.shape as BoxShape3D).size = Vector3(config.width, 0.75, config.length)
	inertia = Vector3(
		mass * (config.length ** 2 + config.roof_height ** 2) / 12.0,
		mass * (config.length ** 2 + config.width ** 2) / 12.0,
		mass * (config.roof_height ** 2 + config.width ** 2) / 12.0)


func set_drive_inputs(throttle: float, brake: float, steer: float, handbrake: bool) -> void:
	throttle_input = clampf(throttle, 0.0, 1.0)
	brake_input = clampf(brake, 0.0, 1.0)
	steer_input = clampf(steer, -1.0, 1.0)
	handbrake_active = handbrake


func reset_wheels() -> void:
	compression.fill(0.0)
	normal_load.fill(0.0)
	wheel_omega.fill(0.0)
	wheel_spin.fill(0.0)
	slip_ratio.fill(0.0)
	contact.fill(false)
	sleeping = false


func repair() -> void:
	for part in condition:
		condition[part] = 100.0


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	_impact_cooldown = maxf(0.0, _impact_cooldown - state.step)
	if _impact_cooldown > 0.0:
		return
	var impact := 0.0
	for index in state.get_contact_count():
		impact = maxf(impact, state.get_contact_impulse(index).length() / mass)
	if impact > 2.4:
		var damage := clampf((impact - 2.4) * 2.2, 0.0, 27.0)
		condition.body = maxf(0.0, condition.body - damage)
		condition.suspension = maxf(0.0, condition.suspension - damage * 0.35)
		condition.tires = maxf(0.0, condition.tires - damage * 0.22)
		condition.engine = maxf(0.0, condition.engine - damage * 0.25)
		condition.cooling = maxf(0.0, condition.cooling - damage * 0.37)
		_impact_cooldown = 0.4


func _physics_process(delta: float) -> void:
	var speed := linear_velocity.dot(-global_basis.z)
	current_speed_kmh = linear_velocity.length() * 3.6
	var progressive := steer_input * absf(steer_input) * 0.36 + steer_input * 0.64
	var speed_scale := lerpf(1.0, 0.28, smoothstep(5.0, 35.0, absf(speed)))
	var target := progressive * deg_to_rad(config.max_steer_angle_deg) * speed_scale
	current_steer_rad = move_toward(current_steer_rad, target, config.steer_response_speed * delta)

	var weights := _drive_weights()
	var shaft_omega := 0.0
	var worst_spin := 0.0
	for index in 4:
		shaft_omega += wheel_omega[index] * weights[index]
		if tcs_enabled and contact[index] and weights[index] > 0.0:
			worst_spin = maxf(worst_spin, absf(slip_ratio[index]))
	var throttle := throttle_input * (1.0 - 0.72 * smoothstep(0.16, 0.58, worst_spin))
	if brake_input > 0.04:
		throttle = 0.0
	var engine_health := lerpf(0.25, 1.0, condition.engine * 0.01)
	var cooling_health := lerpf(0.22, 1.0, condition.cooling * 0.01)
	var drive_torque := powertrain.step(delta, throttle, clutch_input, shaft_omega, speed, engine_health, cooling_health)
	if powertrain.temperature > 122.0:
		condition.engine = maxf(0.0, condition.engine - delta * 0.42)

	grounded_wheels = 0
	for index in 4:
		_sample_contact(index, delta)
	for index in 4:
		var torque := drive_torque * weights[index]
		if diff_locked and weights[index] > 0.0:
			torque += clampf((shaft_omega - wheel_omega[index]) * 19.0, -380.0, 380.0)
		_apply_wheel(index, torque, speed, delta)

	var velocity := linear_velocity
	apply_central_force(-velocity * velocity.length() * 0.61 * config.drag_area)
	if esc_enabled and grounded_wheels >= 3 and absf(speed) > 8.0:
		var desired := -speed * tan(current_steer_rad) / config.wheelbase
		var yaw_error := angular_velocity.dot(global_basis.y) - desired
		apply_torque(-global_basis.y * clampf(yaw_error * mass * 0.48, -1600.0, 1600.0))


func _drive_weights() -> Vector4:
	match powertrain.mode:
		"FWD":
			return Vector4(0.5, 0.5, 0.0, 0.0)
		"RWD", "2H":
			return Vector4(0.0, 0.0, 0.5, 0.5)
		_:
			return Vector4(0.25, 0.25, 0.25, 0.25)


func _wheel_steer(index: int) -> float:
	if index >= 2 or absf(current_steer_rad) < 0.001:
		return 0.0
	var radius := config.wheelbase / tan(absf(current_steer_rad))
	var inside := (index == 1) == (current_steer_rad > 0.0)
	radius += config.track_width * (-0.5 if inside else 0.5)
	return signf(current_steer_rad) * atan(config.wheelbase / maxf(0.1, radius))


func _sample_contact(index: int, delta: float) -> void:
	var ray := wheel_raycasts[index]
	ray.rotation.y = -_wheel_steer(index)
	ray.force_raycast_update()
	var was_grounded: bool = contact[index]
	contact[index] = ray.is_colliding() and ray.get_collision_normal().dot(global_basis.y) > 0.18
	normal_load[index] = 0.0
	if not contact[index]:
		compression[index] = -config.suspension_max_travel * 0.35
		return

	grounded_wheels += 1
	var gap := ray.global_position.distance_to(ray.get_collision_point()) - config.wheel_radius
	var length := maxf(0.0, gap)
	var amount := config.suspension_rest_length - length
	var damping_speed := (amount - compression[index]) / delta if was_grounded else 		-(linear_velocity + angular_velocity.cross(ray.global_position - global_position)).dot(global_basis.y)
	compression[index] = amount
	var damping := config.spring_damping * (1.0 if damping_speed > 0.0 else 1.35)
	var wear := lerpf(0.67, 1.0, condition.suspension * 0.01)
	var bump := maxf(0.0, amount - config.suspension_max_travel) * config.spring_stiffness * 2.6
	normal_load[index] = clampf(amount * config.spring_stiffness * wear + damping_speed * damping + bump, 0.0, mass * 16.0)


func _apply_wheel(index: int, drive_torque: float, speed: float, delta: float) -> void:
	var ray := wheel_raycasts[index]
	_update_visual(index, delta)
	if not contact[index]:
		wheel_omega[index] = clampf(move_toward(wheel_omega[index], 0.0, delta * 1.1) + drive_torque * delta / 2.2, -235.0, 235.0)
		slip_ratio[index] = 0.0
		slip_angle[index] = 0.0
		return

	var normal := ray.get_collision_normal()
	var point := ray.get_collision_point()
	var offset := point - global_position
	var arm := offset - global_basis * center_of_mass
	var velocity := linear_velocity + angular_velocity.cross(arm)
	var forward := (-ray.global_basis.z).slide(normal).normalized()
	var right := forward.cross(normal).normalized()
	var longitudinal := velocity.dot(forward)
	var lateral := velocity.dot(right)
	var collider := ray.get_collider()
	var surface := str(collider.get_meta("surface_type", "asphalt")) if collider != null else "asphalt"
	current_surface = surface
	var ground: Vector2 = SURFACE_PROPERTIES.get(surface, SURFACE_PROPERTIES.asphalt)
	var opposite := index ^ 1
	var bar := (compression[index] - compression[opposite]) * config.anti_roll_stiffness if contact[opposite] else 0.0
	var load := maxf(0.0, normal_load[index] + bar)
	var load_sensitivity := clampf(pow(maxf(100.0, load) / (mass * 2.4525), -0.08), 0.82, 1.13)
	var grip := config.asphalt_friction * ground.x * load_sensitivity
	grip *= lerpf(1.0, 0.72 if surface == "asphalt" else 0.85, wetness)
	grip *= lerpf(0.56, 1.0, condition.tires * 0.01)
	var grip_limit := load * grip
	var wheel_r := config.wheel_radius
	var service := brake_input
	if hdc_enabled and throttle_input < 0.1 and absf(speed) > 2.1:
		service = maxf(service, clampf((absf(speed) - 2.1) * 0.26, 0.0, 0.62))
	var brake_torque := service * config.max_brake_force * (0.29 if index < 2 else 0.21) * wheel_r
	if index >= 2 and (handbrake_active or powertrain.selector == "P"):
		brake_torque += config.handbrake_force * 0.5 * wheel_r

	var omega := wheel_omega[index]
	var step_time := delta / TIRE_STEPS
	var rotational_inertia := (2.1 + wheel_r * wheel_r * 3.8) * clampf(mass / 1920.0, 0.8, 2.6)
	var slip_scale := maxf(absf(longitudinal), 3.5)
	slip_angle[index] = atan2(lateral, maxf(absf(longitudinal), 1.45))
	var requested_lateral := -tanh(slip_angle[index] * 4.8) * grip_limit
	var rolling := -clampf(longitudinal * 4.0, -1.0, 1.0) * load * config.rolling_resistance * ground.y
	var tire_force := Vector2.ZERO

	for step in TIRE_STEPS:
		var ratio := (omega * wheel_r - longitudinal) / slip_scale
		var effective_brake := brake_torque
		if abs_enabled and service > 0.0 and absf(longitudinal) > 2.2 and not handbrake_active:
			var braking_slip := -ratio * signf(longitudinal)
			effective_brake *= 1.0 - 0.88 * smoothstep(0.12, 0.38, braking_slip)
		var traction := Vector2(tanh(ratio * 5.6) * grip_limit, requested_lateral).limit_length(grip_limit)
		var next_omega := omega + (drive_torque - traction.x * wheel_r) / rotational_inertia * step_time
		omega = move_toward(next_omega, 0.0, effective_brake / rotational_inertia * step_time)
		tire_force += traction
	tire_force = (tire_force / TIRE_STEPS + Vector2(rolling, 0.0)).limit_length(grip_limit)
	wheel_omega[index] = clampf(omega, -235.0, 235.0)
	slip_ratio[index] = (wheel_omega[index] * wheel_r - longitudinal) / slip_scale
	apply_force(normal * load + forward * tire_force.x + right * tire_force.y, offset)


func _update_visual(index: int, delta: float) -> void:
	if visual_wheel_nodes.size() <= index:
		return
	var wheel := visual_wheel_nodes[index]
	wheel.position.y = wheel_raycasts[index].position.y - config.suspension_rest_length + compression[index]
	wheel.rotation.y = -_wheel_steer(index)
	wheel_spin[index] = wrapf(wheel_spin[index] - wheel_omega[index] * delta, -PI, PI)
	wheel.get_child(0).rotation.x = wheel_spin[index]
