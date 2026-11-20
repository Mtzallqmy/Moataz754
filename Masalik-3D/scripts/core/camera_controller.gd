class_name MasalikCameraController
extends Camera3D

enum CameraView { FOLLOW, DISTANT, CABIN, HOOD, SIDE, FREE }

@export var target_vehicle: Node3D
@export var current_view: CameraView = CameraView.FOLLOW
@export var smooth_speed := 8.5

var photo_mode := false
var look_back := false
var orbit := 0.0
var zoom := 8.4
var _snap := true


func cycle_camera_view() -> void:
	current_view = ((int(current_view) + 1) % CameraView.size()) as CameraView
	_snap = true


func _physics_process(delta: float) -> void:
	if target_vehicle == null:
		return
	var car := target_vehicle as RaycastVehicleBody
	var basis := car.global_basis
	var origin := car.global_position
	var rear := Vector3(basis.z.x, 0, basis.z.z).normalized()
	if rear.is_zero_approx():
		rear = Vector3.BACK
	var roof := car.config.roof_height
	var length := car.config.length
	var desired := origin + rear * 7.2 + Vector3.UP * 2.8
	var focus := origin - rear * 4.4 + Vector3.UP * 1.07
	var interior := current_view == CameraView.CABIN or current_view == CameraView.HOOD
	var view := CameraView.FREE if photo_mode else current_view
	match view:
		CameraView.DISTANT:
			desired = origin + rear * 11.8 + Vector3.UP * 5.1
		CameraView.CABIN:
			desired = car.get_node("VehicleVisual").cockpit_mount.global_position
			focus = desired - basis.z * 30.0
		CameraView.HOOD:
			desired = origin + basis.y * (roof * 0.68) - basis.z * length * 0.47
			focus = desired - basis.z * 22.0
		CameraView.SIDE:
			desired = origin + basis.x * 7.8 + Vector3.UP * 2.5 + rear * 2.6
			focus = origin + Vector3.UP * 0.85
		CameraView.FREE:
			orbit += Input.get_axis("drive_left", "drive_right") * delta * 1.45
			zoom = clampf(zoom + Input.get_axis("drive_accelerate", "drive_brake") * delta * 4.0, 3.8, 20.0)
			desired = origin + rear.rotated(Vector3.UP, orbit) * zoom + Vector3.UP * (zoom * 0.38)
			focus = origin + Vector3.UP * roof * 0.6
	if look_back and not photo_mode and view in [CameraView.FOLLOW, CameraView.DISTANT]:
		desired = origin - rear * 6.7 + Vector3.UP * 2.5
		focus = origin + rear * 5.0 + Vector3.UP * 0.94

	if not interior or photo_mode:
		var from := origin + Vector3.UP * (roof + 0.45)
		var query := PhysicsRayQueryParameters3D.create(from, desired, 9)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			desired = hit.position + hit.normal * 0.25

	global_position = desired if _snap or interior else global_position.lerp(desired, 1.0 - exp(-smooth_speed * delta))
	_snap = false
	if global_position.distance_squared_to(focus) > 0.0001:
		look_at(focus, Vector3.UP)
