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
		return
	if _load_v2(SAVE_PATH_BACKUP):
		save_data_atomic()
		return
	if FileAccess.file_exists(LEGACY_SAVE_PATH_V1):
		_migrate_from_v1(LEGACY_SAVE_PATH_V1)
		return

	var previous_dir := OS.get_user_data_dir().get_base_dir().path_join(OLD_DESKTOP_DIR)
	if OS.has_feature("pc"):
		if _load_v2(previous_dir.path_join(SAVE_PATH_PRIMARY.get_file())) or _load_v2(previous_dir.path_join(SAVE_PATH_BACKUP.get_file())):
			save_data_atomic()
		elif FileAccess.file_exists(previous_dir.path_join(LEGACY_SAVE_PATH_V1.get_file())):
			_migrate_from_v1(previous_dir.path_join(LEGACY_SAVE_PATH_V1.get_file()))


func _read_v2(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary and parsed.get("schema_version", 0) == SCHEMA_VERSION:
		return parsed
	return {}


func _load_v2(path: String) -> bool:
	var parsed := _read_v2(path)
	if parsed.is_empty():
		return false
	for key in parsed:
		if not save_data.has(key):
			save_data[key] = parsed[key]
		elif typeof(parsed[key]) == typeof(save_data[key]):
			if parsed[key] is Dictionary:
				save_data[key].merge(parsed[key], true)
			else:
				save_data[key] = parsed[key]
	return true


func _migrate_from_v1(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		if parsed.get("completed", false):
			save_data["best_records"]["m1_naqil_ascent"] = {
				"completed": true,
				"best_time_sec": float(parsed.get("best_time_sec", 0.0)),
				"best_score": int(parsed.get("best_score", 85)),
				"vehicle_id": "shahiq_4x4"
			}
		save_data_atomic()
