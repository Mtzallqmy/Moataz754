class_name TrafficAIManager
extends Node3D

const POOL_SIZE := 10
const SPAWN_RANGE := 380.0

var road: MountainRoadGenerator
var player: RaycastVehicleBody
var player_distance := 20.0
var density := 6
var enabled := true

var _agents: Array[Dictionary] = []
var _colors := [Color("#bcb6a4"), Color("#66545e"), Color("#4d6963"), Color("#465f76")]
var _step := 0.0


func _ready() -> void:
	for index in POOL_SIZE:
		var body := AnimatableBody3D.new()
		body.collision_layer = 4
		body.collision_mask = 2
		body.sync_to_physics = false
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		shape.shape.size = Vector3(1.76, 1.25, 4.25)
		shape.position.y = 0.55
		body.add_child(shape)
		var finish := StandardMaterial3D.new()
		finish.albedo_color = _colors[index % _colors.size()]
		_part(body, Vector3(1.76, 0.61, 4.25), Vector3(0, 0.5, 0), finish)
		var glass := StandardMaterial3D.new()
		glass.albedo_color = Color("#354c58")
		_part(body, Vector3(1.55, 0.48, 2.18), Vector3(0, 1.02, 0.1), glass)
		var dark := StandardMaterial3D.new()
		dark.albedo_color = Color("#161c20")
		for side in [-1.0, 1.0]:
			for axle in [-1.3, 1.3]:
				_part(body, Vector3(0.26, 0.56, 0.56), Vector3(side * 0.84, 0.28, axle), dark)
		add_child(body)
		_agents.append({"body": body, "shape": shape, "active": false, "s": 0.0, "direction": 1, "speed": 0.0})
		_set_active(_agents[-1], false)


func _physics_process(delta: float) -> void:
	if road == null or player == null:
		return
	_step += delta
	if _step >= 0.28:
		_step = 0.0
		_rebalance()
	for agent in _agents:
		if not agent.active:
			continue
		var direction: int = agent.direction
		var target := 14.0 + float(agent.get("index", 0) % 4) * 2.3
		var heading := road.lane_transform(agent.s + 18.0, 0, 0, direction < 0).basis.z
		var curve := heading.angle_to(agent.body.global_basis.z)
		target *= lerpf(1.0, 0.55, smoothstep(0.15, 0.65, curve))
		var gap := INF
		for other in _agents:
			if other.active and other.direction == direction and other != agent:
				var separation: float = (other.s - agent.s) * direction
				if separation > 0.0:
					gap = minf(gap, separation)
		var lane := 2.2 * direction
		var player_lane := (player.global_position - road.lane_transform(player_distance, 0, 0).origin).dot(road.lane_transform(player_distance, 0, 0).basis.x)
		var player_gap: float = (player_distance - agent.s) * direction
		if player_gap > 0.0 and absf(player_lane - lane) < 2.05:
			gap = minf(gap, player_gap)
		target = minf(target, maxf(0.0, (gap - 7.8) * 0.62))
		agent.speed = move_toward(agent.speed, target, delta * (6.0 if target < agent.speed else 2.0))
		agent.s += agent.speed * direction * delta
		var wanted := road.lane_transform(agent.s, lane, 0.035, direction < 0)
		agent.body.global_transform = wanted


func _rebalance() -> void:
	for index in _agents.size():
		var agent := _agents[index]
		if agent.active and (not enabled or index >= density or absf(agent.s - player_distance) > SPAWN_RANGE + 100.0 or agent.s < 12.0 or agent.s > road.road_length_m - 10.0):
			_set_active(agent, false)
		if not enabled or index >= density or agent.active:
			continue
		var direction := 1 if index % 2 else -1
		var sample := player_distance - direction * (90.0 + index * 34.0)
		if sample < 12.0:
			sample = player_distance + 125.0 + index * 33.0
		if absf(sample - player_distance) > SPAWN_RANGE or sample > road.road_length_m - 65.0:
			continue
		var clear := true
		for other in _agents:
			if other.active and other.direction == direction and absf(other.s - sample) < 24.0:
				clear = false
		if not clear:
			continue
		agent.index = index
		agent.direction = direction
		agent.s = sample
		agent.speed = 11.0
		agent.body.global_transform = road.lane_transform(sample, direction * 2.2, 0.035, direction < 0)
		_set_active(agent, true)


func _set_active(agent: Dictionary, active: bool) -> void:
	agent.active = active
	agent.body.visible = active
	agent.shape.set_deferred("disabled", not active)


func active_count() -> int:
	return _agents.filter(func(agent: Dictionary) -> bool: return agent.active).size()


func _part(body: Node3D, size: Vector3, position: Vector3, finish: Material) -> void:
	var block := BoxMesh.new()
	block.size = size
	block.material = finish
	var instance := MeshInstance3D.new()
	instance.mesh = block
	instance.position = position
	body.add_child(instance)
