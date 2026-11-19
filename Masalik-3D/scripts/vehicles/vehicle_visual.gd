extends Node3D

var wheels: Array[Node3D] = []
var paint: StandardMaterial3D
var headlights: StandardMaterial3D
var brake_lamps: StandardMaterial3D
var reverse_lamps: StandardMaterial3D
var high_beams := false
var lights_on := false
var _headlight_spot: SpotLight3D


func _ready() -> void:
	var vehicle := get_parent() as RaycastVehicleBody
	var config := vehicle.config
	var id := vehicle.vehicle_id
	var spec: Dictionary = VehicleFleetRegistry.FLEET_SPECS[id]
	paint = _material(Color(spec.paint), 0.34, 0.35)
	var trim := _material(Color("#202932"), 0.0, 0.74)
	var glass := _material(Color("#344e60"), 0.5, 0.2)
	var steel := _material(Color("#83929a"), 0.65, 0.3)
	var rubber := _material(Color("#171919"), 0.0, 0.94)
	headlights = _material(Color("#eddbac"), 0.1, 0.32)
	brake_lamps = _material(Color("#9f2433"), 0.05, 0.25)
	reverse_lamps = _material(Color("#c3cbc7"), 0.05, 0.25)
	var width := config.width
	var length := config.length
	var roof := config.roof_height
	var waist := minf(0.83, roof * 0.68)
	var tall := id in ["jabal", "hafilat", "munqidh"]
	var pickup := id in ["saqr", "badiya"]
	var cabin_length := length * (0.32 if pickup or id == "jabal" else 0.56)
	var cabin_center := -length * 0.09 if pickup else length * 0.08
	if id == "jabal":
		cabin_center = -length * 0.32
	if id == "hafilat":
		cabin_length = length * 0.88
		cabin_center = 0.0
	if id == "munqidh":
		cabin_center = -length * 0.18
		cabin_length = length * 0.44
	_box(self, Vector3(width, waist - 0.13, length), Vector3(0, (0.13 + waist) * 0.5, 0), paint)
	_box(self, Vector3(width * 0.9, roof - waist, cabin_length), Vector3(0, (waist + roof) * 0.5, cabin_center), glass)
	_box(self, Vector3(width * 0.94, 0.105, cabin_length * 1.035), Vector3(0, roof, cabin_center), paint)
	_box(self, Vector3(width * 0.96, 0.08, length * 0.87), Vector3(0, waist - 0.018, 0), paint)
	var column_count := 5 if id == "hafilat" else 3
	for side in [-1.0, 1.0]:
		for index in column_count:
			var column := cabin_center + (float(index) / (column_count - 1) - 0.5) * cabin_length
			_box(self, Vector3(0.07, roof - waist, 0.085), Vector3(side * width * 0.45, (roof + waist) * 0.5, column), paint)
		_box(self, Vector3(width * 0.21, 0.13 if not tall else 0.19, 0.025), Vector3(side * width * 0.34, waist * 0.81, -length * 0.5 - 0.018), headlights)
		_box(self, Vector3(width * 0.10, 0.18, 0.026), Vector3(side * width * 0.41, waist * 0.83, length * 0.5 + 0.018), brake_lamps)
		_box(self, Vector3(width * 0.047, 0.085, 0.026), Vector3(side * width * 0.31, waist * 0.76, length * 0.5 + 0.018), reverse_lamps)
		_box(self, Vector3(width * 0.11, 0.12, 0.22), Vector3(side * width * 0.54, waist + 0.15, cabin_center - cabin_length * 0.34), trim)
		if pickup:
			_box(self, Vector3(0.10, 0.18, length * 0.36), Vector3(side * width * 0.46, waist + 0.08, length * 0.28), paint)
	if id in ["jabal", "munqidh"]:
		var cargo := steel if id == "jabal" else _material(Color("#e6ddc2"), 0.12, 0.6)
		_box(self, Vector3(width * 0.96, roof * 0.60, length * 0.49), Vector3(0, waist + roof * 0.28, length * 0.25), cargo)
	if id in ["rahhal", "munqidh", "badiya"]:
		_box(self, Vector3(width * 0.73, 0.09, 0.18), Vector3(0, roof + 0.13, cabin_center), headlights)
	if id == "barq":
		_box(self, Vector3(width * 0.85, 0.08, 0.31), Vector3(0, waist + 0.20, length * 0.45), trim)
		_box(self, Vector3(width * 0.4, 0.25, 0.08), Vector3(0, waist + 0.09, length * 0.45), trim)
	_box(self, Vector3(width * 0.42, waist * 0.28, 0.04), Vector3(0, waist * 0.74, -length * 0.5 - 0.02), trim)
	for side in [-1.0, 1.0]:
		_box(self, Vector3(width * 1.03, 0.15, 0.17), Vector3(0, 0.25, side * length * 0.5), trim)
	_headlight_spot = SpotLight3D.new()
	_headlight_spot.position = Vector3(0, waist * 0.8, -length * 0.5)
	_headlight_spot.rotation_degrees.x = -6.0
	_headlight_spot.spot_range = 45.0
	_headlight_spot.spot_angle = 34.0
	_headlight_spot.light_color = Color("#fff1d3")
	add_child(_headlight_spot)
	_headlight_spot.hide()
	for ray in vehicle.wheel_raycasts:
		var hub := Node3D.new()
		hub.position = ray.position
		add_child(hub)
		var axle := Node3D.new()
		hub.add_child(axle)
		var tire := CylinderMesh.new()
		tire.top_radius = vehicle.config.wheel_radius
		tire.bottom_radius = vehicle.config.wheel_radius
		tire.height = vehicle.config.wheel_width
		tire.radial_segments = 20
		var wheel := _mesh(axle, tire, Vector3.ZERO, rubber)
		wheel.rotation.z = PI * 0.5
		var rim := CylinderMesh.new()
		rim.top_radius = config.wheel_radius * 0.63
		rim.bottom_radius = config.wheel_radius * 0.63
		rim.height = vehicle.config.wheel_width + 0.013
		rim.radial_segments = 16
		_mesh(axle, rim, Vector3.ZERO, steel).rotation.z = PI * 0.5
		_box(axle, Vector3(0.33, 0.038, 0.48), Vector3.ZERO, trim)
		wheels.append(hub)
	vehicle.visual_wheel_nodes = wheels


func set_lights(braking: bool, reversing: bool) -> void:
	_emission(headlights, Color("#fff3d9"), lights_on)
	_emission(brake_lamps, Color("#f73333"), braking)
	_emission(reverse_lamps, Color("#fff5db"), reversing)
	_headlight_spot.visible = lights_on
	_headlight_spot.spot_range = 72.0 if high_beams else 44.0


func _emission(material: StandardMaterial3D, color: Color, enabled: bool) -> void:
	if material.emission_enabled != enabled:
		material.emission_enabled = enabled
		material.emission = color


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
