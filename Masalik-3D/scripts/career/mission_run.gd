class_name MissionRun
extends RefCounted

enum Outcome { IN_PROGRESS, COMPLETED, FAILED }

var spec: Dictionary
var elapsed := 0.0
var next_gate := 0
var gates := PackedFloat32Array()
var outcome := Outcome.IN_PROGRESS


func _init(mission: Dictionary) -> void:
	spec = mission
	for index in range(1, 5):
		gates.append(lerpf(mission.start, mission.finish, index / 4.0))


func update(delta: float, distance: float, lateral: float, speed: float, condition: float) -> void:
	if outcome != Outcome.IN_PROGRESS:
		return
	elapsed += delta
	if elapsed > float(spec.limit) or condition < float(spec.integrity):
		outcome = Outcome.FAILED
		return
	if absf(lateral) > 5.25 or absf(distance - gates[next_gate]) > 12.0:
		return
	if next_gate == gates.size() - 1 and spec.get("stop", false) and speed > 3.0:
		return
	next_gate += 1
	if next_gate >= gates.size():
		outcome = Outcome.COMPLETED


func target() -> float:
	return gates[mini(next_gate, gates.size() - 1)]
