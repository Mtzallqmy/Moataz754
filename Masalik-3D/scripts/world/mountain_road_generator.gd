class_name MountainRoadGenerator
extends Node3D

@export var road_length_m := 2000.0
@export var sample_step_m := 4.0
@export var road_width_m := 9.6

var road_points := PackedVector3Array()
var across := PackedVector3Array()


func _ready() -> void:
	generate_mountain_pass()


func generate_mountain_pass() -> void:
	if not road_points.is_empty():
		return
	var count := ceili(road_length_m / sample_step_m)
	var horizontal := Vector3.ZERO
	var heading := 0.0
	for index in range(count + 1):
		var distance := minf(index * sample_step_m, road_length_m)
		var curve := smoothstep(125.0, 350.0, distance)
		var elevation := curve * (distance * 0.065 + sin(distance * 0.011) * 10.0)
		road_points.append(Vector3(horizontal.x, elevation, horizontal.z))
		across.append(Vector3(cos(heading), 0.0, sin(heading)))
		heading += curve * (0.004 * sin(distance * 0.0085) + 0.003 * sin(distance * 0.019)) * sample_step_m
		horizontal += Vector3(sin(heading), 0.0, -cos(heading)) * sample_step_m

	var asphalt := _material(Color("#30363d"))
	var stone := _material(Color("#927a59"))
	var paint := _material(Color("#e6c982"))
	_strip("Asphalt", -road_width_m * 0.5, road_width_m * 0.5, asphalt, "asphalt")
	_strip("RightShoulder", road_width_m * 0.5, 45.0, stone, "gravel", -2.5)
	_strip("LeftShoulder", -45.0, -road_width_m * 0.5, stone, "gravel", -2.5)
	_strip("CentreMarkings", -0.07, 0.07, paint, "", 0.015, true)


func lane_transform(distance: float, lateral := 0.0) -> Transform3D:
	var index := clampi(int(distance / sample_step_m), 1, road_points.size() - 2)
	var forward := (road_points[index + 1] - road_points[index - 1]).normalized()
	var point := road_points[index] + across[index] * clampf(lateral, -3.0, 3.0) + Vector3.UP * 0.9
	return Transform3D(Basis.looking_at(forward), point)


func nearest_sample(position: Vector3) -> int:
	var nearest := 0
	var best := INF
	for index in road_points.size():
		var distance := position.distance_squared_to(road_points[index])
		if distance < best:
			nearest = index
			best = distance
	return nearest


func _strip(
	label: String, left: float, right: float, material: Material, surface: String,
	decoration_height := 0.0, dashed := false
) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(material)
	var left_height := decoration_height
	var right_height := decoration_height
	if not surface.is_empty():
		left_height = decoration_height if left < -road_width_m * 0.5 else 0.0
		right_height = decoration_height if right > road_width_m * 0.5 else 0.0
	for index in range(road_points.size() - 1):
		if dashed and index % 2 == 1:
			continue
		var p0 := road_points[index]
		var p1 := road_points[index + 1]
		var a := p0 + across[index] * left + Vector3.UP * left_height
		var b := p0 + across[index] * right + Vector3.UP * right_height
		var c := p1 + across[index + 1] * left + Vector3.UP * left_height
		var d := p1 + across[index + 1] * right + Vector3.UP * right_height
		for vertex in [a, c, b, b, c, d]:
			st.add_vertex(vertex)
	st.generate_normals()
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = st.commit()
	add_child(instance)
	if not surface.is_empty():
		instance.create_trimesh_collision()
		var body := instance.get_child(0) as StaticBody3D
		body.set_meta("surface_type", surface)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	return material
