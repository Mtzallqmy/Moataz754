class_name DriveAudio
extends Node3D

const RATE := 22050

var car: RaycastVehicleBody
var interior := false
var raining := 0.0
var _low: AudioStreamPlayer3D
var _high: AudioStreamPlayer3D
var _road: AudioStreamPlayer
var _horn: AudioStreamPlayer3D


func _ready() -> void:
	var spec: Dictionary = VehicleFleetRegistry.FLEET_SPECS[car.vehicle_id]
	_low = _spatial(_tone(float(spec.engine_hz), 0.32), "Engine")
	_high = _spatial(_tone(float(spec.engine_hz) * 2.0, 0.5), "Engine")
	_horn = _spatial(_tone(212.0, 0.66, false), "Effects")
	_road = AudioStreamPlayer.new()
	_road.stream = _noise()
	_road.bus = "Environment"
	_road.volume_db = -65.0
	add_child(_road)
	if DisplayServer.get_name() != "headless":
		_road.play()
		_low.play()
		_high.play()


func horn() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_horn.volume_db = linear_to_db(maxf(0.001, PersistenceManager.save_data.audio.effects) * 0.48)
	_horn.play()


func _process(_delta: float) -> void:
	var mix: Dictionary = PersistenceManager.save_data.audio
	var load_factor := car.throttle_input
	var rpm := car.powertrain.rpm / car.config.redline_rpm
	var inside := 0.58 if interior else 1.0
	var level: float = (0.18 + load_factor * 0.45) * float(mix.engine) * inside if car.powertrain.running else 0.0
	_low.pitch_scale = lerpf(0.82, 2.65, rpm)
	_high.pitch_scale = lerpf(0.72, 2.14, rpm)
	var blend := smoothstep(0.32, 0.72, rpm)
	_low.volume_db = linear_to_db(maxf(0.0001, level * (1.0 - blend * 0.82)))
	_high.volume_db = linear_to_db(maxf(0.0001, level * blend * 0.72))
	var road_factor := 0.36 if car.current_surface == "asphalt" else 0.88
	var road_level := minf(car.current_speed_kmh / 100.0, 1.0) * road_factor + raining * 0.28
	_road.volume_db = linear_to_db(maxf(0.0001, road_level * float(mix.environment) * inside * 0.55))
	_road.pitch_scale = lerpf(0.72, 1.55, minf(car.current_speed_kmh / 110.0, 1.0))


func _spatial(stream: AudioStream, bus: StringName) -> AudioStreamPlayer3D:
	var output := AudioStreamPlayer3D.new()
	output.stream = stream
	output.bus = bus
	output.volume_db = -65.0
	output.max_distance = 28.0
	output.unit_size = 6.8
	add_child(output)
	return output


func _tone(hz: float, overtone: float, loop := true) -> AudioStreamWAV:
	var count := RATE if loop else roundi(RATE * 0.45)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for sample in count:
		var phase := TAU * hz * sample / RATE
		var amplitude := sin(phase) + overtone * sin(phase * 2.0) + 0.19 * sin(phase * 4.0)
		var fade := 1.0 if loop else smoothstep(0.0, 1100.0, sample) * (1.0 - smoothstep(count - 4200.0, count, sample))
		bytes.encode_s16(sample * 2, roundi(amplitude * 12500.0 * fade))
	return _stream(bytes, count, loop)


func _noise() -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(RATE * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 916854
	var filtered := 0.0
	for sample in RATE:
		filtered = lerpf(filtered, rng.randf_range(-1.0, 1.0), 0.17)
		var fade := smoothstep(0.0, 110.0, sample) * (1.0 - smoothstep(RATE - 110.0, RATE, sample))
		bytes.encode_s16(sample * 2, roundi(filtered * 19000.0 * fade))
	return _stream(bytes, RATE, true)


func _stream(data: PackedByteArray, count: int, loop: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = count
	return stream
