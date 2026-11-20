extends Node
## GameManager Autoload — يدير حالة المهمة «رحلة القمم الأولى» ومستويات الجودة

enum QualityPreset { LOW, MEDIUM, HIGH }

var current_quality: QualityPreset = QualityPreset.HIGH
var mission_elapsed_sec: float = 0.0
var mission_active: bool = false
var resume_drive := false
var selected_region_start := 20.0
var active_mission: Dictionary = {}

func apply_quality_preset(preset: QualityPreset) -> void:
	current_quality = preset
	Engine.max_fps = 30 if preset == QualityPreset.LOW else 60
	var vp := get_viewport()
	if vp == null:
		return
	match preset:
		QualityPreset.LOW:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.scaling_3d_scale = 0.75
		QualityPreset.MEDIUM:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.scaling_3d_scale = 0.9
		QualityPreset.HIGH:
			vp.msaa_3d = Viewport.MSAA_2X
			vp.scaling_3d_scale = 1.0
