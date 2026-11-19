class_name WorldStreamingManager
extends RefCounted

const CHUNK_LENGTH_M := 500.0
const REGION_LENGTH_M := 2500.0
const REGIONS := [
	{"id": "taiz_highlands", "name": "مرتفعات تعز", "ground": "#86734d", "surface": "gravel"},
	{"id": "naqil_alsahab", "name": "نقيل السحاب", "ground": "#8b786a", "surface": "rock"},
	{"id": "wadi_alrayhan", "name": "وادي الريحان", "ground": "#7b8250", "surface": "dirt"},
	{"id": "tihama_plains", "name": "سهول تهامة", "ground": "#9d966a", "surface": "grass"},
	{"id": "coastal_highway", "name": "الطريق الساحلي", "ground": "#baa67b", "surface": "sand"},
	{"id": "masalik_desert", "name": "صحراء المسالك", "ground": "#c0a477", "surface": "sand"},
]
const TOTAL_ROAD_LENGTH_M := 15000.0

var active_chunk_id := -1
var loaded_chunks: Dictionary = {}


static func region_at(distance: float) -> Dictionary:
	return REGIONS[clampi(int(distance / REGION_LENGTH_M), 0, REGIONS.size() - 1)]


func update(distance: float, chunk_count: int, host: Node3D) -> void:
	var next := clampi(int(distance / CHUNK_LENGTH_M), 0, chunk_count - 1)
	if next == active_chunk_id:
		return
	active_chunk_id = next
	for id in range(maxi(0, next - 2), mini(chunk_count, next + 3)):
		if not loaded_chunks.has(id):
			loaded_chunks[id] = host.build_sector(id)
	for id: int in loaded_chunks.keys():
		if absi(id - next) > 2:
			loaded_chunks[id].queue_free()
			loaded_chunks.erase(id)
