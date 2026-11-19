class_name VehiclePowertrain
extends RefCounted

const RAD_TO_RPM := 60.0 / TAU
const INERTIA := 0.34
const TORQUE_SPEEDS := [0.0, 0.27, 0.48, 0.72, 0.9, 1.0]
const TORQUE_FACTORS := [0.45, 0.70, 0.96, 1.0, 0.85, 0.60]

var config: VehiclePhysicsConfig
var running := true
var manual := false
var selector := "D"
var mode := "4H"
var gear := 1
var shift_time := 0.0
var rpm := 800.0
var fuel := 85.0
var temperature := 72.0


func _init(spec: VehiclePhysicsConfig) -> void:
	config = spec
	mode = spec.default_drivetrain
	rpm = spec.idle_rpm
	fuel = spec.fuel_capacity


func set_selector(next: String, speed: float) -> void:
	if next in ["P", "R", "N", "D"]:
		if absf(speed) > 0.75 and (next in ["P", "R"] or (selector == "R" and next == "D")):
			return
		if selector != next:
			gear = 1
			shift_time = 0.2
		selector = next


func shift_manual(direction: int) -> void:
	if manual and selector == "D":
		gear = clampi(gear + direction, 1, config.ratios.size())
		shift_time = 0.18


func ratio() -> float:
	var transfer := 2.55 if mode == "4L" else 1.0
	if selector == "R":
		return -config.reverse_ratio * config.final_drive * transfer
	if selector == "D":
		return config.ratios[gear - 1] * config.final_drive * transfer
	return 0.0


func gear_label() -> String:
	return "%s%d" % [selector, gear] if selector == "D" else selector


func step(delta: float, throttle: float, clutch: float, shaft_omega: float, speed: float, engine_health: float, cooling_health: float) -> float:
	shift_time = maxf(0.0, shift_time - delta)
	if running and fuel <= 0.0:
		running = false
	if running and not manual and selector == "D" and shift_time == 0.0:
		var coupled_rpm := absf(shaft_omega * ratio()) * RAD_TO_RPM
		var lower_rpm := absf(shaft_omega * config.ratios[maxi(0, gear - 2)] * config.final_drive) * RAD_TO_RPM
		if gear < config.ratios.size() and coupled_rpm > config.redline_rpm * 0.70 and maxf(coupled_rpm, rpm * 0.96) > config.redline_rpm * lerpf(0.48, 0.86, throttle):
			gear += 1
			shift_time = 0.23
		elif gear > 1 and coupled_rpm < config.redline_rpm * lerpf(0.21, 0.36, throttle) and lower_rpm < config.redline_rpm * 0.75:
			gear -= 1
			shift_time = 0.23

	var engagement := (1.0 - clutch) if shift_time == 0.0 else 0.0
	var output_ratio := ratio()
	var shaft_rpm := shaft_omega * output_ratio * RAD_TO_RPM
	var idle_floor := config.idle_rpm if not manual else config.idle_rpm * 0.5
	var drive_load := 0.0
	if running and output_ratio != 0.0:
		drive_load = clampf((rpm - shaft_rpm) * 0.105, -config.torque_nm * 0.45, config.torque_nm * 0.94) * engagement

	var torque := 0.0
	if running:
		var idle_feed := maxf(0.0, (config.idle_rpm - rpm) * 0.19)
		var limiter := 1.0 - smoothstep(config.redline_rpm * 0.94, config.redline_rpm, rpm)
		var heat_factor := 1.0 - 0.42 * smoothstep(106.0, 135.0, temperature)
		torque = throttle * _torque_curve(rpm / config.redline_rpm) * config.torque_nm * limiter * engine_health * heat_factor + idle_feed
		fuel = maxf(0.0, fuel - config.fuel_liters_per_min * (0.12 + throttle * throttle) * delta / 60.0)
	var friction := rpm * (0.009 + (1.0 - throttle) * 0.006)
	rpm = clampf(rpm + (torque - friction - drive_load) / INERTIA * RAD_TO_RPM * delta, idle_floor if running and not manual else 0.0, config.redline_rpm * 1.03)
	if manual and running and engagement > 0.72 and output_ratio != 0.0 and rpm < config.idle_rpm * 0.41:
		running = false

	var heating := (0.14 + throttle * 0.72) if running else 0.0
	var cooling := (temperature - 24.0) * (0.002 + absf(speed) * 0.00033) * cooling_health
	temperature = clampf(temperature + (heating - cooling) * delta, 24.0, 155.0)
	return drive_load * output_ratio * 0.88 if throttle > 0.025 or drive_load < 0.0 else 0.0


func _torque_curve(fraction: float) -> float:
	for index in range(1, TORQUE_SPEEDS.size()):
		if fraction <= TORQUE_SPEEDS[index]:
			var weight := inverse_lerp(TORQUE_SPEEDS[index - 1], TORQUE_SPEEDS[index], fraction)
			return lerpf(TORQUE_FACTORS[index - 1], TORQUE_FACTORS[index], weight)
	return TORQUE_FACTORS[-1]
