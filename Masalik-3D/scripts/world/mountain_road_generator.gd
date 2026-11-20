class_name MountainRoadGenerator
extends Node3D

const SECTOR_M := WorldStreamingManager.CHUNK_LENGTH_M
const BRIDGE_START := 10800.0
const BRIDGE_END := 10976.0
const TUNNEL_START := 3620.0
const TUNNEL_END := 3732.0
const TOWER := preload("res://assets/buildings/stone_tower.glb")
const TERRAIN_OFFSETS := [-135.0, -69.0, -23.0, -4.8, 4.8, 23.0, 69.0, 135.0]

@export var road_length_m := 15000.0
@export var sample_step_m := 4.0
@export var road_width_m := 9.6

var road_points := PackedVector3Array()
var across := PackedVector3Array()
var stream := WorldStreamingManager.new()
var asphalt := StandardMaterial3D.new()
var _paint: StandardMaterial3D
var _edge_paint: StandardMaterial3D
var _sea: StandardMaterial3D
var _gravel: StandardMaterial3D
var _concrete: StandardMaterial3D
var _barrier: StandardMaterial3D


func _ready() -> void:
	generate_mountain_pass()
	load_near(20.0)


func generate_mountain_pass() -> void:
	if not road_points.is_empty():
		return
	var count := ceili(road_length_m / sample_step_m)
	var horizontal := Vector3.ZERO
	for index in range(count + 1):
		var distance := minf(index * sample_step_m, road_length_m)
		road_points.append(Vector3(horizontal.x, _altitude(distance), horizontal.z))
		var heading := _heading(distance)
		across.append(Vector3(cos(heading), 0.0, sin(heading)))
		horizontal += Vector3(sin(heading), 0.0, -cos(heading)) * sample_step_m
	asphalt.albedo_color = Color("#383d41")
	asphalt.roughness = 0.96
	_paint = _material(Color("#e6c982"))
	_edge_paint = _material(Color("#e5ddd1"))
	_sea = _material(Color("#237489"))
	_gravel = _material(Color("#504d42"))
	_concrete = _material(Color("#81796c"))
	_barrier = _material(Color("#b1a489"))


func load_near(distance: float) -> void:
	stream.update(distance, ceili(road_length_m / SECTOR_M), self)


func set_wetness(wetness: float) -> void:
	asphalt.albedo_color = Color("#383d41").lerp(Color("#22292d"), wetness)
	asphalt.roughness = lerpf(0.96, 0.47, wetness)


func lane_transform(distance: float, lateral := 0.0, clearance := 0.9, reverse := false) -> Transform3D:
	var index := clampi(int(distance / sample_step_m), 0, road_points.size() - 2)
	var blend := clampf(distance / sample_step_m - index, 0.0, 1.0)
	var forward := road_points[index + 1] - road_points[index]
	var point := road_points[index].lerp(road_points[index + 1], blend)
	point += across[index].lerp(across[index + 1], blend) * lateral + Vector3.UP * clearance
	return Transform3D(Basis.looking_at(-forward if reverse else forward), point)


func nearest_sample(position: Vector3, hint := -1) -> int:
	var nearest := 0
	var best := INF
	var start := maxi(0, hint - 88) if hint >= 0 else 0
	var finish := mini(road_points.size(), hint + 89) if hint >= 0 else road_points.size()
	for index in range(start, finish):
		var distance := position.distance_squared_to(road_points[index])
		if distance < best:
			nearest = index
			best = distance
	return nearest


func build_sector(sector_id: int) -> Node3D:
	var sector := Node3D.new()
	sector.name = "Sector%02d" % sector_id
	add_child(sector)
	var start := int(sector_id * SECTOR_M / sample_step_m)
	var finish := mini(int((sector_id + 1) * SECTOR_M / sample_step_m), road_points.size() - 1)
	var region := WorldStreamingManager.region_at(sector_id * SECTOR_M)
	var land := _material(Color(region.ground))
	var surface: String = region.surface
	var desert: bool = region.id == "masalik_desert"
	var road_material := _gravel if desert else asphalt
	_strip(sector, "Road", start, finish, -4.8, 4.8, road_material, "gravel" if desert else "asphalt")
	for band in range(TERRAIN_OFFSETS.size() - 1):
		if band == 3:
			continue
		var left: float = TERRAIN_OFFSETS[band]
		var right: float = TERRAIN_OFFSETS[band + 1]
		var color := _material(Color(region.ground).darkened(0.12 * float(band % 3)))
		var collision := surface if band in [1, 2, 4, 5] else ""
		_strip(sector, "Terrain%d" % band, start, finish, left, right, color, collision, true)

	if not desert:
		_strip(sector, "Centerline", start, finish, -0.07, 0.07, _paint, "", false, 0.018, true)
		_strip(sector, "LeftEdge", start, finish, -4.64, -4.54, _edge_paint, "", false, 0.019)
		_strip(sector, "RightEdge", start, finish, 4.54, 4.64, _edge_paint, "", false, 0.019)
	if region.id == "naqil_alsahab":
		_build_tunnel(sector, start, finish)
	if region.id in ["taiz_highlands", "naqil_alsahab"]:
		_wall(sector, "Guardrail", maxi(start, ceili(410.0 / sample_step_m)), finish, 4.91, 0.18, 0.69, _barrier)
	if region.id == "coastal_highway":
		_build_bridge(sector, start, finish)
		_strip(sector, "CoastalWater", start, finish, 126, 480, _sea, "", false, -4.0)
	if region.id in ["taiz_highlands", "wadi_alrayhan", "tihama_plains"]:
		for index in range(start + 17, finish - 6, 27):
			if index < 26:
				continue
			var lateral := -16.0 - float((sector_id + index) % 4) * 3.0
			var tower := TOWER.instantiate() as Node3D
			sector.add_child(tower)
			var placement := lane_transform(index * sample_step_m, lateral, _terrain_offset(index, lateral) - 0.45)
			tower.transform = placement
			tower.rotate_y(PI * 0.5)
	_add_scenery(sector, start, finish, region.id, land)
	return sector


func _heading(distance: float) -> float:
	var scale := smoothstep(95.0, 320.0, distance)
	var mountain := smoothstep(2250.0, 2850.0, distance) * (1.0 - smoothstep(4700.0, 5300.0, distance))
	return scale * (0.38 * sin(distance * 0.0041) + 0.2 * sin(distance * 0.012) + mountain * 0.62 * sin(distance * 0.013))


func _altitude(distance: float) -> float:
	if distance < 2500.0:
		return smoothstep(125.0, 450.0, distance) * (distance * 0.047 + 8.0 * sin(distance * 0.007))
	if distance < 5000.0:
		var summit_progress := (distance - 2500.0) / 2500.0
		return lerpf(109.7, 22.0, summit_progress) + sin(summit_progress * TAU) * 84.0
	if distance < 10000.0:
		return 22.0 * (1.0 - smoothstep(5000.0, 10000.0, distance)) + sin(distance * 0.014) * 1.4 * sin(PI * (distance - 5000.0) / 5000.0)
	var bridge_profile := smoothstep(10712.0, BRIDGE_START, distance) * (1.0 - smoothstep(BRIDGE_END, 11065.0, distance))
	return bridge_profile * 3.8 + smoothstep(12400.0, 12900.0, distance) * (6.0 + sin(distance * 0.012) * 4.0)


func _terrain_offset(index: int, lateral: float) -> float:
	var distance := index * sample_step_m
	var outward := clampf((absf(lateral) - 4.8) / 118.0, 0.0, 1.0)
	var highland := (1.0 - smoothstep(4600.0, 5500.0, distance)) * smoothstep(100.0, 570.0, distance)
	var dunes := smoothstep(12300.0, 13100.0, distance)
	var asymmetry := -1.0 if lateral > 0.0 else 1.0
	var terrain := sin(distance * 0.007 + lateral * 0.032) + 0.44 * sin(distance * 0.023 - lateral * 0.091)
	return -outward * 4.0 + outward * (terrain * (6.0 + highland * 28.0 + dunes * 9.0) + asymmetry * highland * 38.0)


func _strip(
	parent: Node3D, label: String, start: int, finish: int, left: float, right: float,
	material: Material, surface: String, terrain := false, raise := 0.0, dashed := false
) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(material)
	for index in range(start, finish):
		var distance := (index + 0.5) * sample_step_m
		if terrain and distance >= BRIDGE_START and distance < BRIDGE_END:
			continue
		if dashed and index % 2 == 1:
			continue
		var a := _vertex(index, left, terrain, raise)
		var b := _vertex(index, right, terrain, raise)
		var c := _vertex(index + 1, left, terrain, raise)
		var d := _vertex(index + 1, right, terrain, raise)
		for vertex in [a, c, b, b, c, d]:
			st.add_vertex(vertex)
	st.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = st.commit()
	parent.add_child(instance)
	if not surface.is_empty():
		instance.create_trimesh_collision()
		var body := instance.get_child(0) as StaticBody3D
		body.set_meta("surface_type", surface)


func _build_bridge(sector: Node3D, start: int, finish: int) -> void:
	var first := maxi(start, ceili(BRIDGE_START / sample_step_m))
	var last := mini(finish, floori(BRIDGE_END / sample_step_m))
	if first >= last:
		return
	_strip(sector, "Estuary", first, last, -145.0, 145.0, _sea, "", false, -4.3)
	_wall(sector, "BridgeRailingLeft", first, last, -4.87, -0.56, 0.92, _concrete)
	_wall(sector, "BridgeRailingRight", first, last, 4.87, -0.56, 0.92, _concrete)
	for index in range(first + 6, last, 9):
		var p := lane_transform(index * sample_step_m, 0.0, -2.1)
		_box(sector, p, Vector3(8.3, 4.2, 1.2), _concrete)


func _build_tunnel(sector: Node3D, start: int, finish: int) -> void:
	var first := maxi(start, ceili(TUNNEL_START / sample_step_m))
	var last := mini(finish, floori(TUNNEL_END / sample_step_m))
	if first >= last:
		return
	_wall(sector, "TunnelLeft", first, last, -5.1, -0.20, 5.2, _concrete)
	_wall(sector, "TunnelRight", first, last, 5.1, -0.20, 5.2, _concrete)
	var roof := _material(Color("#45403b"))
	roof.cull_mode = BaseMaterial3D.CULL_DISABLED
	_strip(sector, "TunnelRoof", first, last, -5.12, 5.12, roof, "", false, 5.2)
	for index in range(first + 5, last, 8):
		var path := lane_transform(index * sample_step_m, 0.0, 4.98)
		var lamp := _material(Color("#c3a47e"))
		lamp.emission_enabled = true
		lamp.emission = Color("#f1ca92")
		_box(sector, path, Vector3(2.6, 0.12, 0.21), lamp)


func _wall(parent: Node3D, label: String, first: int, last: int, offset: float, bottom: float, top: float, material: StandardMaterial3D) -> void:
	if first >= last:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var finish := material.duplicate() as StandardMaterial3D
	finish.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(finish)
	for index in range(first, last):
		var a := _vertex(index, offset, false, bottom)
		var b := _vertex(index + 1, offset, false, bottom)
		var c := a + Vector3.UP * (top - bottom)
		var d := b + Vector3.UP * (top - bottom)
		for vertex in [a, c, b, b, c, d]:
			st.add_vertex(vertex)
	st.generate_normals()
	var section := MeshInstance3D.new()
	section.name = label
	section.mesh = st.commit()
	parent.add_child(section)
	var shape := section.mesh.create_trimesh_shape()
	shape.backface_collision = true
	var body := StaticBody3D.new()
	body.collision_layer = 8
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	section.add_child(body)


func _box(parent: Node3D, placement: Transform3D, dimensions: Vector3, finish: StandardMaterial3D) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh.material = finish
	instance.mesh = mesh
	instance.transform = placement
	parent.add_child(instance)


func _vertex(index: int, offset: float, terrain: bool, raise: float) -> Vector3:
	var altitude := _terrain_offset(index, offset) if terrain else raise
	return road_points[index] + across[index] * offset + Vector3.UP * altitude


func _add_scenery(parent: Node3D, start: int, finish: int, region: String, land: Material) -> void:
	var scatter := MultiMeshInstance3D.new()
	var multimesh := MultiMesh.new()
	var mesh := SphereMesh.new()
	mesh.radial_segments = 6
	mesh.rings = 4
	mesh.material = _material(Color("#68704a")) if region in ["taiz_highlands", "wadi_alrayhan", "tihama_plains"] else land
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = floori((finish - start) / 3.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8851 + start
	for index in multimesh.instance_count:
		var sample := start + index * 3
		var lateral := rng.randf_range(8.0, 38.0) * (1.0 if index % 2 else -1.0)
		var height := rng.randf_range(0.5, 2.3)
		var point := _vertex(sample, lateral, true, 0.0) + Vector3.UP * height * 0.24
		var basis := Basis.from_scale(Vector3(height * 0.8, height, height * 0.76))
		multimesh.set_instance_transform(index, Transform3D(basis, point))
	scatter.multimesh = multimesh
	scatter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(scatter)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	return material
