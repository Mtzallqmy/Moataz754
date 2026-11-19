extends Node3D

var wheels: Array[Node3D] = []
var paint: StandardMaterial3D


func _ready() -> void:
	var vehicle := get_parent() as RaycastVehicleBody
	paint = _material(Color("#b7643a"), 0.34, 0.35)
	var trim := _material(Color("#202932"), 0.0, 0.74)
	var glass := _material(Color("#344e60"), 0.5, 0.2)
	var steel := _material(Color("#83929a"), 0.65, 0.3)
	var rubber := _material(Color("#171919"), 0.0, 0.94)
	var lights := _material(Color("#eddbac"), 0.1, 0.32)
	var tail := _material(Color("#9f2433"), 0.05, 0.25)
	_box(self, Vector3(1.78, 0.55, 4.15), Vector3(0, 0.47, 0), paint)
	_box(self, Vector3(1.59, 0.56, 2.2), Vector3(0, 1.01, 0.43), glass)
	_box(self, Vector3(1.68, 0.12, 2.27), Vector3(0, 1.33, 0.43), paint)
	_box(self, Vector3(1.67, 0.12, 1.18), Vector3(0, 0.77, -1.34), paint)
	for side in [-1.0, 1.0]:
		for column in [-0.54, 0.47, 1.48]:
			_box(self, Vector3(0.06, 0.55, 0.085), Vector3(side * 0.79, 1.02, column), paint)
		_box(self, Vector3(0.39, 0.15, 0.025), Vector3(side * 0.6, 0.6, -2.086), lights)
		_box(self, Vector3(0.25, 0.23, 0.026), Vector3(side * 0.72, 0.62, 2.086), tail)
		_box(self, Vector3(0.19, 0.12, 0.22), Vector3(side * 0.97, 0.97, -0.49), trim)
	_box(self, Vector3(0.74, 0.20, 0.04), Vector3(0, 0.58, -2.08), trim)
	_box(self, Vector3(1.84, 0.17, 0.17), Vector3(0, 0.26, -2.05), trim)
	_box(self, Vector3(1.84, 0.17, 0.17), Vector3(0, 0.26, 2.05), trim)
	for ray in vehicle.wheel_raycasts:
		var hub := Node3D.new()
		hub.position = ray.position
		add_child(hub)
		var tire := CylinderMesh.new()
		tire.top_radius = 0.44
		tire.bottom_radius = 0.44
		tire.height = 0.31
		tire.radial_segments = 20
		var wheel := _mesh(hub, tire, Vector3.ZERO, rubber)
		wheel.rotation.z = PI * 0.5
		var rim := CylinderMesh.new()
		rim.top_radius = 0.28
		rim.bottom_radius = 0.28
		rim.height = 0.32
		rim.radial_segments = 16
		_mesh(hub, rim, Vector3.ZERO, steel).rotation.z = PI * 0.5
		_box(hub, Vector3(0.33, 0.038, 0.48), Vector3.ZERO, trim)
		wheels.append(hub)
	vehicle.visual_wheel_nodes = wheels


func _box(parent: Node3D, size: Vector3, position: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_mesh(parent, mesh, position, material)


func _mesh(parent: Node3D, mesh: Mesh, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	parent.add_child(instance)
	return instance


func _material(color: Color, metal: float, rough: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metal
	material.roughness = rough
	return material
