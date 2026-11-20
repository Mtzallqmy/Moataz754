extends Control

const DRIVE_SCENE := "res://scenes/main/main_game.tscn"
const CREDIT := "برمجة وتطوير معتز العلقمي – تعز – اليمن – 2026م"
const GARAGE := preload("res://scripts/ui/garage.gd")

@onready var panel: VBoxContainer = %Menu
@onready var about: VBoxContainer = %About
@onready var resume_button: Button = %Continue
var _detail: ScrollContainer
var _body: VBoxContainer
var _garage: GARAGE


func _ready() -> void:
	resume_button.disabled = not PersistenceManager.save_data.has_driven and PersistenceManager.save_data.active_attempt.is_empty()
	resume_button.pressed.connect(_start.bind(true))
	%Start.pressed.connect(_start.bind(false))
	%ShowAbout.pressed.connect(_show_about.bind(true))
	%Back.pressed.connect(_show_about.bind(false))
	%Credit.text = CREDIT
	var navigation := HFlowContainer.new()
	navigation.alignment = FlowContainer.ALIGNMENT_CENTER
	navigation.add_theme_constant_override("h_separation", 8)
	navigation.add_theme_constant_override("v_separation", 7)
	panel.add_child(navigation)
	panel.move_child(navigation, panel.get_child_count() - 2)
	_button(navigation, "المرآب", _show_garage)
	_button(navigation, "المهمات", _show_missions)
	_button(navigation, "العالم المفتوح", _show_regions)
	_button(navigation, "الإعدادات", _show_settings)
	%Start.grab_focus()


func _start(resume: bool) -> void:
	QualityManager.active_mission = MissionCatalog.find(str(PersistenceManager.save_data.active_attempt.get("id", ""))) if resume else {}
	QualityManager.selected_region_start = 20.0
	QualityManager.resume_drive = resume
	get_tree().change_scene_to_file(DRIVE_SCENE)


func _start_region(index: int) -> void:
	QualityManager.active_mission = {}
	QualityManager.resume_drive = false
	QualityManager.selected_region_start = index * WorldStreamingManager.REGION_LENGTH_M + 20.0
	get_tree().change_scene_to_file(DRIVE_SCENE)


func _start_mission(mission: Dictionary) -> void:
	QualityManager.active_mission = mission
	QualityManager.resume_drive = false
	get_tree().change_scene_to_file(DRIVE_SCENE)


func _show_about(show_about: bool) -> void:
	panel.visible = not show_about
	about.visible = show_about
	if show_about:
		%Back.grab_focus()
	else:
		%ShowAbout.grab_focus()


func _show_garage() -> void:
	_open_detail("المرآب", false)
	_garage = GARAGE.new()
	_body.add_child(_garage)


func _show_regions() -> void:
	_open_detail("العالم المفتوح")
	for index in WorldStreamingManager.REGIONS.size():
		var region: Dictionary = WorldStreamingManager.REGIONS[index]
		_button(_body, region.name, _start_region.bind(index))


func _show_missions() -> void:
	_open_detail("المهمات")
	_heading("أنماط القيادة")
	for mission in MissionCatalog.ACTIVITIES:
		_add_mission(mission)
	for chapter in range(1, 6):
		_heading("الفصل %d" % chapter)
		for mission in MissionCatalog.STORY:
			if mission.chapter == chapter:
				_add_mission(mission)


func _add_mission(mission: Dictionary) -> void:
	var records: Dictionary = PersistenceManager.save_data.best_records
	var best: Dictionary = records.get(mission.id, {})
	var caption: String = mission.name
	if best.get("completed", false):
		caption += "  •  %.1f ث" % float(best.best_time_sec)
	var button := _button(_body, caption, _start_mission.bind(mission))
	button.disabled = not MissionCatalog.can_start(mission, records)


func _show_settings() -> void:
	_open_detail("الإعدادات")
	var data: Dictionary = PersistenceManager.save_data
	_option("جودة الرسوم", ["اقتصادي", "متوازن", "عالٍ"], ["Low", "Medium", "High"], data.quality_preset, func(value):
		_store_setting("quality_preset", value)
		QualityManager.apply_quality_preset(["Low", "Medium", "High"].find(value)))
	_option("ناقل الحركة", ["تلقائي", "يدوي"], ["auto", "manual"], data.transmission_type, func(value): _store_setting("transmission_type", value))
	_option("مساعدات القيادة", ["مبتدئ", "متوازن", "محاكاة"], ["arcade", "sport", "simulation"], data.Driving_realism, func(value): _store_setting("Driving_realism", value))

	var labels := PackedStringArray()
	for key in TimeAndWeatherSystem.PRESETS:
		labels.append(TimeAndWeatherSystem.PRESETS[key][3])
	_option("الطقس", Array(labels), TimeAndWeatherSystem.PRESETS.keys(), data.weather, func(value): _store_setting("weather", value))
	_option("وقت الانطلاق", ["فجر", "شروق", "صباح", "ظهر", "عصر", "غروب", "ليل", "منتصف الليل"],
		TimeAndWeatherSystem.HOURS.keys(), data.time_of_day, func(value): _store_setting("time_of_day", value))
	_slider("حساسية المقود", 0.45, 1.7, float(data.steering_sensitivity), func(value): _store_setting("steering_sensitivity", value))
	_slider("مستوى صوت المحرك", 0.0, 1.0, float(data.audio.engine), func(value): data.audio.engine = value)
	_slider("مستوى صوت البيئة", 0.0, 1.0, float(data.audio.environment), func(value): data.audio.environment = value)
	_slider("مستوى صوت المؤثرات", 0.0, 1.0, float(data.audio.effects), func(value): data.audio.effects = value)
	_toggle("تبديل مواضع المقود والدواسات", data.touch_layout.left_handed, func(value): data.touch_layout.left_handed = value)
	_slider("حجم أزرار القيادة", 0.7, 1.17, float(data.touch_layout.scale), func(value): data.touch_layout.scale = value)
	_slider("عتامة أزرار القيادة", 0.32, 1.0, float(data.touch_layout.opacity), func(value): data.touch_layout.opacity = value)
	_button(_body, "إعادة مواضع اللمس الافتراضية", func():
		data.touch_layout = {"left_handed": false, "scale": 1.0, "opacity": 0.84, "offsets": {}}
		_close_detail()
		_show_settings())
	_button(_body, "حفظ الإعدادات", func():
		var saved := PersistenceManager.save_data_atomic()
		_heading("تم حفظ الإعدادات" if saved else "تعذّر الحفظ"))
	_button(_body, "الإنجازات", _show_achievements)
	_button(_body, "إدارة الحفظ", _show_saves)


func _show_achievements() -> void:
	_close_detail()
	_open_detail("الإنجازات")
	var data: Dictionary = PersistenceManager.save_data
	_heading("الرصيد %d   •   الخبرة %d" % [int(data.credits), int(data.xp)])
	_heading("أول طريق" if data.achievements.get("first_mission", false) else "أكمل مهمتك الأولى")
	_heading("خمسة مسارات مكتملة" if data.achievements.get("five_routes", false) else "أكمل خمسة مسارات")


func _show_saves() -> void:
	_close_detail()
	_open_detail("إدارة الحفظ")
	var editor := TextEdit.new()
	editor.custom_minimum_size = Vector2(0, 270)
	editor.placeholder_text = "ألصق نسخة الحفظ بصيغة JSON هنا"
	_body.add_child(editor)
	_button(_body, "نسخ حفظ اللعبة", func():
		editor.text = PersistenceManager.export_save_text()
		DisplayServer.clipboard_set(editor.text)
		_heading("نُسخت بيانات الحفظ"))
	_button(_body, "استيراد الحفظ الملصق", func():
		if PersistenceManager.import_save_text(editor.text):
			resume_button.disabled = not PersistenceManager.save_data.has_driven and PersistenceManager.save_data.active_attempt.is_empty()
			_heading("استُورد الحفظ")
		else:
			_heading("تعذّر الاستيراد. استخدم نسخة حفظ JSON صالحة."))


func _store_setting(key: String, value: Variant) -> void:
	PersistenceManager.save_data[key] = value


func _open_detail(title: String, scroll := true) -> void:
	panel.hide()
	_detail = ScrollContainer.new()
	_detail.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_detail.custom_minimum_size = Vector2(684 if scroll else 900, 590)
	_detail.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	$Center.add_child(_detail)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 7)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_child(_body)
	_button(_body, "عودة", _close_detail)
	_heading(title)


func _close_detail() -> void:
	PersistenceManager.save_data_atomic()
	_detail.hide()
	_detail.queue_free()
	panel.show()


func _heading(title: String) -> void:
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color("#f4ce8d"))
	_body.add_child(label)


func _option(title: String, captions: Array, values: Array, selected: Variant, handler: Callable) -> void:
	var list := OptionButton.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for caption in captions:
		list.add_item(caption)
	list.select(maxi(0, values.find(selected)))
	list.item_selected.connect(func(index: int): handler.call(values[index]))
	_setting_row(title, list)


func _slider(title: String, minimum: float, maximum: float, value: float, handler: Callable) -> void:
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.01
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(handler)
	_setting_row(title, slider)


func _toggle(title: String, value: bool, handler: Callable) -> void:
	var toggle := CheckButton.new()
	toggle.button_pressed = value
	toggle.toggled.connect(handler)
	_setting_row(title, toggle)


func _setting_row(title: String, input: Control) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 47
	var name := Label.new()
	name.custom_minimum_size.x = 250.0
	name.text = title
	name.add_theme_font_size_override("font_size", 20)
	_body.add_child(row)
	row.add_child(name)
	row.add_child(input)


func _button(parent: Control, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 46.0
	button.add_theme_font_size_override("font_size", 21)
	parent.add_child(button)
	button.pressed.connect(action)
	return button
