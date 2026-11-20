extends Node
## مَسَالِك — دروب اليمن | MASALIK — Roads of Yemen
## Atomic Save System V2 with Backup Recovery & Phase 1 Migration
## برمجة وتطوير معتز العلقمي – تعز – اليمن – 2026م

const SAVE_PATH_PRIMARY: String = "user://masalik_save_v2.json"
const SAVE_PATH_BACKUP: String = "user://masalik_save_v2.bak.json"
const LEGACY_SAVE_PATH_V1: String = "user://masalik_save_v1.json"
const OLD_DESKTOP_DIR := "مَسَالِك — دروب اليمن - MASALIK"
const SCHEMA_VERSION: int = 2

var save_data: Dictionary = {
	"has_driven": false,
	"active_attempt": {},
	"credits": 0,
	"xp": 0,
	"owned_vehicles": ["shahiq"],
	"achievements": {},
	"touch_layout": {"left_handed": false, "scale": 1.0, "opacity": 0.84, "offsets": {}},
	"weather": "clear",
	"time_of_day": "morning",
	"audio": {"engine": 0.68, "environment": 0.42, "effects": 0.72, "music": 0.65, "interface": 0.72},
	"schema_version": SCHEMA_VERSION,
	"selected_vehicle_id": "shahiq_4x4",
	"Driving_realism": "sport",
	"transmission_type": "auto",
	"quality_preset": "Medium",
	"control_scheme": "buttons",
	"steering_sensitivity": 1.0,
	"master_volume": 0.8,
	"unlocked_regions": [
		"taiz_highlands", "naqil_alsahab", "wadi_alrayhan",
		"tihama_plains", "coastal_highway", "masalik_desert"
	],
	"best_records": {},
	"vehicle_customizations": {},
	"vehicle_states": {},
	"last_world_state": {
		"s_meters": 60.0,
		"lateral_offset": 0.0,
		"fuel_liters": 85.0,
		"damage_state": {"engine": 100.0, "suspension": 100.0, "tires": 100.0, "body": 100.0, "cooling": 100.0}
	}
}


func _ready() -> void:
	load_data()


func save_data_atomic() -> bool:
	save_data["schema_version"] = SCHEMA_VERSION
	save_data["updated_at_unix"] = Time.get_unix_time_from_system()
	if _read_v2(SAVE_PATH_PRIMARY).size() > 0:
		if not _atomic_write(SAVE_PATH_BACKUP, FileAccess.get_file_as_string(SAVE_PATH_PRIMARY)):
			return false
	return _atomic_write(SAVE_PATH_PRIMARY, JSON.stringify(save_data, "\t"))


func _atomic_write(path: String, contents: String) -> bool:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		push_warning("Unable to open save staging file.")
		return false
	var wrote := file.store_string(contents)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if not wrote or write_error != OK:
		push_warning("Unable to write save staging file.")
		return false
	var err := DirAccess.rename_absolute(temporary, path)
	if err != OK:
		push_warning("Unable to publish save: %s" % error_string(err))
	return err == OK


func load_data() -> void:
	if _load_v2(SAVE_PATH_PRIMARY):
		_prepare_loaded_state()
		return
	if _load_v2(SAVE_PATH_BACKUP):
		_prepare_loaded_state()
		save_data_atomic()
		return
	if FileAccess.file_exists(LEGACY_SAVE_PATH_V1):
		_migrate_from_v1(LEGACY_SAVE_PATH_V1)
		return

	var previous_dir := OS.get_user_data_dir().get_base_dir().path_join(OLD_DESKTOP_DIR)
	if OS.has_feature("pc"):
		if _load_v2(previous_dir.path_join(SAVE_PATH_PRIMARY.get_file())) or _load_v2(previous_dir.path_join(SAVE_PATH_BACKUP.get_file())):
			_prepare_loaded_state()
			save_data_atomic()
		elif FileAccess.file_exists(previous_dir.path_join(LEGACY_SAVE_PATH_V1.get_file())):
			_migrate_from_v1(previous_dir.path_join(LEGACY_SAVE_PATH_V1.get_file()))


func _read_v2(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var parsed: Variant = json.data
	if parsed is Dictionary and parsed.get("schema_version", 0) == SCHEMA_VERSION:
		return parsed
	return {}


var _loaded_has_ownership := false


func _load_v2(path: String) -> bool:
	var parsed := _read_v2(path)
	if parsed.is_empty():
		return false
	_apply_v2(parsed)
	return true


func _apply_v2(parsed: Dictionary) -> void:
	_loaded_has_ownership = parsed.has("owned_vehicles")
	for key in parsed:
		if not save_data.has(key):
			save_data[key] = parsed[key]
		elif typeof(parsed[key]) == typeof(save_data[key]) or (parsed[key] is float and save_data[key] is int):
			if parsed[key] is Dictionary:
				save_data[key].merge(parsed[key], true)
			else:
				save_data[key] = int(parsed[key]) if save_data[key] is int else parsed[key]


func _migrate_from_v1(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	var valid := json.parse(file.get_as_text()) == OK
	file.close()
	if not valid:
		return
	var parsed: Variant = json.data
	if typeof(parsed) == TYPE_DICTIONARY:
		if parsed.get("completed", false):
			save_data["best_records"]["m1_naqil_ascent"] = {
				"completed": true,
				"best_time_sec": float(parsed.get("best_time_sec", 0.0)),
				"best_score": int(parsed.get("best_score", 85)),
				"vehicle_id": "shahiq_4x4"
			}
		save_data_atomic()


func own_vehicle(id: String) -> bool:
	return VehicleFleetRegistry.canonical_id(id) in save_data["owned_vehicles"]


func purchase_vehicle(id: String) -> bool:
	if not VehicleFleetRegistry.FLEET_SPECS.has(id) or own_vehicle(id):
		return false
	var price: int = VehicleFleetRegistry.FLEET_SPECS[id].price
	if save_data.credits < price:
		return false
	save_data.credits -= price
	save_data.owned_vehicles.append(id)
	save_data_atomic()
	return true


func record_mission(mission: Dictionary, elapsed: float, body_condition: float) -> int:
	var old: Dictionary = save_data.best_records.get(mission.id, {})
	var first_completion: bool = not old.get("completed", false)
	var previous_time := float(old.get("best_time_sec", 0.0))
	var best_time := minf(previous_time, elapsed) if previous_time > 0.0 else elapsed
	save_data.best_records[mission.id] = {
		"completed": true, "best_time_sec": best_time, "condition": body_condition,
		"vehicle_id": mission.vehicle,
	}
	var reward := int(mission.credits) if first_completion else int(mission.credits / 5.0)
	save_data.credits += reward
	if first_completion:
		save_data.xp += mission.xp
	save_data.achievements["first_mission"] = true
	if save_data.best_records.size() >= 5:
		save_data.achievements["five_routes"] = true
	save_data_atomic()
	return reward


func _prepare_loaded_state() -> void:
	if save_data.has("updated_at_unix") and not save_data.has("has_driven_recorded"):
		save_data.has_driven = save_data.has_driven or float(save_data.last_world_state.get("s_meters", 60.0)) != 60.0
	var selected := VehicleFleetRegistry.canonical_id(str(save_data.selected_vehicle_id))
	if not _loaded_has_ownership and selected not in save_data.owned_vehicles:
		save_data.owned_vehicles.append(selected)


func export_save_text() -> String:
	return JSON.stringify(save_data, "\t")


func import_save_text(contents: String) -> bool:
	if contents.strip_edges().is_empty() or contents.length() > 1500000:
		return false
	var json := JSON.new()
	if json.parse(contents) != OK or not json.data is Dictionary:
		return false
	var data: Dictionary = json.data
	var previous := save_data.duplicate(true)
	if data.get("schema_version", 0) == SCHEMA_VERSION and data.get("last_world_state") is Dictionary:
		_apply_v2(data)
		_prepare_loaded_state()
	elif data.get("schemaVersion", 0) == 2 and data.get("selectedVehicleId") is String and data.get("unlockedVehicles") is Array:
		_merge_browser_save(data)
	else:
		return false
	if save_data_atomic():
		return true
	save_data = previous
	return false


func _merge_browser_save(web: Dictionary) -> void:
	var id := VehicleFleetRegistry.canonical_id(web.selectedVehicleId)
	save_data.selected_vehicle_id = id
	for vehicle in web.unlockedVehicles:
		if vehicle is String and VehicleFleetRegistry.FLEET_SPECS.has(vehicle) and vehicle not in save_data.owned_vehicles:
			save_data.owned_vehicles.append(vehicle)
	if id not in save_data.owned_vehicles:
		save_data.owned_vehicles.append(id)
	save_data.credits = maxi(int(save_data.credits), _nonnegative_number(web.get("masalikCoins"), 0))
	save_data.xp = maxi(int(save_data.xp), _nonnegative_number(web.get("driverXp"), 0))
	var bookmarks: Variant = web.get("missionBestTimesSec", {})
	var completions: Variant = web.get("missionCompletions", {})
	if bookmarks is Dictionary and completions is Dictionary:
		for name in completions:
			if _nonnegative_number(completions[name], 0) <= 0:
				continue
			var entry: Dictionary = save_data.best_records.get(name, {})
			var best: Variant = bookmarks.get(name, 0.0)
			var seconds := float(best) if best is float or best is int else 0.0
			if entry.is_empty() or (seconds > 0.0 and seconds < float(entry.get("best_time_sec", INF))):
				save_data.best_records[name] = {"completed": true, "best_time_sec": maxf(0.0, seconds)}
	if web.get("customizations") is Dictionary:
		for name in web.customizations:
			if VehicleFleetRegistry.FLEET_SPECS.has(name) and web.customizations[name] is Dictionary:
				var merged: Dictionary = save_data.vehicle_customizations.get(name, {})
				merged.merge(web.customizations[name], false)
				save_data.vehicle_customizations[name] = merged
	var position := _nonnegative_number(web.get("playerDistanceM"), 20)
	save_data.last_world_state.s_meters = clampf(position, 8.0, WorldStreamingManager.TOTAL_ROAD_LENGTH_M - 8.0)
	if web.get("fuelByVehicle") is Dictionary:
		var fuel: Variant = web.fuelByVehicle.get(id)
		if fuel is float or fuel is int:
			save_data.last_world_state.fuel_liters = clampf(fuel, 0.0, float(VehicleFleetRegistry.FLEET_SPECS[id].fuel_tank_l))
	if web.get("damageByVehicle") is Dictionary and web.damageByVehicle.get(id) is Dictionary:
		var condition: Dictionary = web.damageByVehicle[id]
		for pair in [["engine", "engineHealthPct"], ["tires", "tiresHealthPct"], ["suspension", "suspensionHealthPct"], ["body", "bodyHealthPct"]]:
			var health: Variant = condition.get(pair[1])
			if health is float or health is int:
				save_data.last_world_state.damage_state[pair[0]] = clampf(health, 0, 100)
	save_data.has_driven = true
	save_data.has_driven_recorded = true


func _nonnegative_number(value: Variant, fallback: int) -> int:
	return maxi(0, int(value)) if value is float or value is int else fallback


func vehicle_tuning(id: String) -> Dictionary:
	var fields: Variant = save_data.vehicle_customizations.get(id, {})
	return fields if fields is Dictionary else {}


func tuning_set(id: String, field: String, value: int) -> void:
	var custom := vehicle_tuning(id)
	custom[field] = value
	save_data.vehicle_customizations[id] = custom
	save_data_atomic()


func repair_vehicle(id: String) -> bool:
	if not own_vehicle(id):
		return false
	var state: Dictionary = save_data.vehicle_states.get(id, {})
	state["damage_state"] = {"engine": 100.0, "suspension": 100.0, "tires": 100.0, "body": 100.0, "cooling": 100.0}
	save_data.vehicle_states[id] = state
	return save_data_atomic()
