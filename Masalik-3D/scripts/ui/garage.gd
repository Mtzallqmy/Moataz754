extends VBoxContainer

const FLEET_SCENE := "res://scenes/vehicles/fleet_vehicle.tscn"
const PAINTS := [Color("#bd723b"), Color("#233352"), Color("#39564a"), Color("#a93337"), Color("#d0c7b6"), Color("#1c232a")]

var _selected := "shahiq"
var _model: RaycastVehicleBody
var _preview: SubViewport
var _camera: Camera3D
var _info: Label
var _purchase: Button
var _paint: Button
var _orbit := 0.8
var _zoom := 7.5


func _ready() -> void:
	_selected = VehicleFleetRegistry.canonical_id(PersistenceManager.save_data.selected_vehicle_id)
	var vehicles := OptionButton.new()
	for id in VehicleFleetRegistry.IDS:
		vehicles.add_item(VehicleFleetRegistry.FLEET_SPECS[id].name_ar)
	vehicles.select(VehicleFleetRegistry.IDS.find(_selected))
	vehicles.item_selected.connect(_select)
	add_child(vehicles)

	var holder := SubViewportContainer.new()
	holder.custom_minimum_size.y = 315.0
	holder.stretch = true
	holder.gui_input.connect(_orbit_input)
	add_child(holder)
	_preview = SubViewport.new()
	_preview.own_world_3d = true
	_preview.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(_preview)

	var ambience := WorldEnvironment.new()
	ambience.environment = Environment.new()
	ambience.environment.background_mode = Environment.BG_COLOR
	ambience.environment.background_color = Color("#182232")
	ambience.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambience.environment.ambient_light_color = Color("#e1ebf6")
	ambience.environment.ambient_light_energy = 0.75
	_preview.add_child(ambience)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46, -38, 0)
	sun.light_color = Color("#ffedcc")
	sun.light_energy = 1.4
	_preview.add_child(sun)
	var stage := MeshInstance3D.new()
	var platform := CylinderMesh.new()
	platform.top_radius = 5.1
	platform.bottom_radius = 5.1
	platform.height = 0.15
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#344251")
	platform.material = material
	stage.mesh = platform
	stage.position.y = -0.43
	_preview.add_child(stage)
	_camera = Camera3D.new()
	_camera.current = true
	_preview.add_child(_camera)

	_info = Label.new()
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_info)
	var actions := HBoxContainer.new()
	add_child(actions)
	_purchase = Button.new()
	_purchase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_purchase.custom_minimum_size.y = 48
	_purchase.pressed.connect(_purchase_or_select)
	actions.add_child(_purchase)
	_paint = Button.new()
	_paint.text = "تغيير الطلاء"
	_paint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paint.pressed.connect(_cycle_paint)
	actions.add_child(_paint)
	_select(vehicles.selected)


func _select(index: int) -> void:
	_selected = VehicleFleetRegistry.IDS[index]
	if is_instance_valid(_model):
		_model.queue_free()
	_model = (load(FLEET_SCENE) as PackedScene).instantiate()
	_model.vehicle_id = _selected
	_model.freeze = true
	_model.process_mode = Node.PROCESS_MODE_DISABLED
	_preview.add_child(_model)
	_apply_paint()
	_refresh()
	_update_camera()


func _refresh() -> void:
	var spec: Dictionary = VehicleFleetRegistry.FLEET_SPECS[_selected]
	var owned := PersistenceManager.own_vehicle(_selected)
	_info.text = "%s  •  %d كغ  •  %d ن·م  •  الرصيد %d" % [spec.category_ar, spec.base_mass_kg, spec.max_torque_nm, PersistenceManager.save_data.credits]
	_purchase.text = "اختيار المركبة" if owned else "شراء بـ %d" % spec.price
	_purchase.disabled = not owned and PersistenceManager.save_data.credits < spec.price
	if owned and VehicleFleetRegistry.canonical_id(PersistenceManager.save_data.selected_vehicle_id) == _selected:
		_purchase.text = "المركبة المختارة"
		_purchase.disabled = true
	_paint.disabled = not owned


func _purchase_or_select() -> void:
	if PersistenceManager.own_vehicle(_selected) or PersistenceManager.purchase_vehicle(_selected):
		PersistenceManager.save_data.selected_vehicle_id = _selected
		PersistenceManager.save_data_atomic()
	_refresh()


func _cycle_paint() -> void:
	var custom: Dictionary = PersistenceManager.save_data.vehicle_customizations
	var fields: Dictionary = custom.get(_selected, {})
	var next := (int(fields.get("native_paint", -1)) + 1) % PAINTS.size()
	fields["native_paint"] = next
	custom[_selected] = fields
	PersistenceManager.save_data_atomic()
	_apply_paint()


func _apply_paint() -> void:
	var fields: Dictionary = PersistenceManager.save_data.vehicle_customizations.get(_selected, {})
	var selected := int(fields.get("native_paint", -1))
	if selected >= 0 and selected < PAINTS.size():
		_model.get_node("VehicleVisual").paint.albedo_color = PAINTS[selected]


func _orbit_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag or (event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_orbit += event.relative.x * 0.012
		_zoom = clampf(_zoom + event.relative.y * 0.014, 4.5, 13.0)
		_update_camera()


func _update_camera() -> void:
	_camera.position = Vector3(sin(_orbit) * _zoom, 2.55, cos(_orbit) * _zoom)
	_camera.look_at(Vector3(0, _model.config.roof_height * 0.52, 0))
