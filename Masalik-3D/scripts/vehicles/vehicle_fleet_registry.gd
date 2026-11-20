class_name VehicleFleetRegistry
extends RefCounted

# Vehicle IDs and specifications retained from src/game/vehicleFleet.ts.
const PAINTS := [Color("#bd723b"), Color("#233352"), Color("#39564a"), Color("#a93337"), Color("#d0c7b6"), Color("#1c232a")]
const COMPOUNDS := ["all_terrain", "road", "sand", "mud"]
const COMPOUND_NAMES := ["متعدد الاستخدام", "طريق", "رمل", "وحل"]
const RIDE_STEPS := [0.0, -0.045, 0.045]

const IDS := ["shahiq", "saqr", "rahhal", "madina", "jabal", "barq", "hafilat", "munqidh", "badiya", "aseel"]
const FLEET_SPECS := {
	"shahiq": {
		"name_ar": "الشاهق", "title_ar": "الشاهق — دفع رباعي جبلي 4×4", "category_ar": "طرق وعرة ومرتفعات", "base_mass_kg": 1920,
		"max_cargo_kg": 250, "max_torque_nm": 450, "drivetrain": "4H", "gears": 6,
		"fuel_tank_l": 85, "price": 0, "center_y": -0.36, "wheelbase": 2.72,
		"track": 1.94, "radius": 0.45, "wheel_width": 0.32, "rest": 0.64,
		"travel": 0.35, "spring": 43000, "damper": 5500, "anti_roll": 9400,
		"idle": 800, "redline": 6000, "brake": 24000, "handbrake": 19000,
		"steer_speed": 3.4, "modes": ["2H", "4H", "4L"], "burn": 1.35, "drag": 0.42,
		"rolling": 220, "engine_hz": 46, "paint": "#c87236", "steer_deg": 33.0,
		"width": 1.82, "length": 4.26, "roof": 1.39,
	},
	"saqr": {
		"name_ar": "الصقر", "title_ar": "الصقر — بيك أب نقل جبلي", "category_ar": "نقل بضائع وطرق ريفية", "base_mass_kg": 1780,
		"max_cargo_kg": 750, "max_torque_nm": 420, "drivetrain": "4H", "gears": 5,
		"fuel_tank_l": 80, "price": 1100, "center_y": -0.32, "wheelbase": 3.05,
		"track": 1.88, "radius": 0.43, "wheel_width": 0.29, "rest": 0.62,
		"travel": 0.32, "spring": 46000, "damper": 5800, "anti_roll": 9000,
		"idle": 780, "redline": 5600, "brake": 23000, "handbrake": 18500,
		"steer_speed": 3.1, "modes": ["2H", "4H", "4L"], "burn": 1.28, "drag": 0.44,
		"rolling": 230, "engine_hz": 42, "paint": "#2b6cb0", "steer_deg": 31.0,
		"width": 1.82, "length": 4.91, "roof": 1.29,
	},
	"rahhal": {
		"name_ar": "الرحّال", "title_ar": "الرحّال — مركبة الكثبان والصحراء", "category_ar": "صحاري وطرق رملية", "base_mass_kg": 1640,
		"max_cargo_kg": 180, "max_torque_nm": 490, "drivetrain": "AWD", "gears": 6,
		"fuel_tank_l": 90, "price": 2200, "center_y": -0.4, "wheelbase": 2.65,
		"track": 2.08, "radius": 0.48, "wheel_width": 0.42, "rest": 0.68,
		"travel": 0.4, "spring": 39000, "damper": 5100, "anti_roll": 10500,
		"idle": 900, "redline": 6600, "brake": 22500, "handbrake": 20000,
		"steer_speed": 4.0, "modes": ["RWD", "AWD", "4L"], "burn": 1.55, "drag": 0.39,
		"rolling": 195, "engine_hz": 54, "paint": "#d4a253", "steer_deg": 35.0,
		"width": 1.98, "length": 4.16, "roof": 1.29,
	},
	"madina": {
		"name_ar": "المدينة", "title_ar": "المدينة — سيدان الطرق المعبدة", "category_ar": "طرق إسفلتية وساحلية", "base_mass_kg": 1380,
		"max_cargo_kg": 120, "max_torque_nm": 340, "drivetrain": "FWD", "gears": 6,
		"fuel_tank_l": 60, "price": 1500, "center_y": -0.45, "wheelbase": 2.68,
		"track": 1.82, "radius": 0.36, "wheel_width": 0.25, "rest": 0.46,
		"travel": 0.2, "spring": 48000, "damper": 6100, "anti_roll": 12000,
		"idle": 750, "redline": 6800, "brake": 25500, "handbrake": 17000,
		"steer_speed": 4.4, "modes": ["FWD", "AWD"], "burn": 0.85, "drag": 0.29,
		"rolling": 155, "engine_hz": 62, "paint": "#3f6a3c", "steer_deg": 34.0,
		"width": 1.74, "length": 4.56, "roof": 1.0,
	},
	"jabal": {
		"name_ar": "الجبل", "title_ar": "الجبل — شاحنة النقل الثقيل", "category_ar": "شحن ثقيل وعقبات جبلية", "base_mass_kg": 4400,
		"max_cargo_kg": 2400, "max_torque_nm": 1120, "drivetrain": "4H", "gears": 8,
		"fuel_tank_l": 160, "price": 3000, "center_y": -0.22, "wheelbase": 3.9,
		"track": 2.26, "radius": 0.54, "wheel_width": 0.36, "rest": 0.72,
		"travel": 0.34, "spring": 92000, "damper": 11800, "anti_roll": 18500,
		"idle": 650, "redline": 3800, "brake": 46000, "handbrake": 38000,
		"steer_speed": 2.3, "modes": ["RWD", "4H", "4L"], "burn": 2.35, "drag": 0.68,
		"rolling": 460, "engine_hz": 31, "paint": "#b91c1c", "steer_deg": 28.0,
		"width": 2.29, "length": 6.15, "roof": 2.18,
	},
	"barq": {
		"name_ar": "البرق", "title_ar": "البرق — سيارة سباق رالي جبلية AWD", "category_ar": "سباقات الرالي والمنعطفات", "base_mass_kg": 1320,
		"max_cargo_kg": 80, "max_torque_nm": 520, "drivetrain": "AWD", "gears": 6,
		"fuel_tank_l": 68, "price": 3600, "center_y": -0.44, "wheelbase": 2.58,
		"track": 1.92, "radius": 0.38, "wheel_width": 0.3, "rest": 0.52,
		"travel": 0.28, "spring": 52000, "damper": 6800, "anti_roll": 14500,
		"idle": 950, "redline": 7400, "brake": 28500, "handbrake": 22500,
		"steer_speed": 4.8, "modes": ["AWD", "RWD"], "burn": 1.65, "drag": 0.31,
		"rolling": 170, "engine_hz": 68, "paint": "#eab308", "steer_deg": 36.0,
		"width": 1.86, "length": 4.43, "roof": 0.86,
	},
	"hafilat": {
		"name_ar": "الحافلة الجبلية", "title_ar": "الحافلة — باص نقل الركاب بين القرى", "category_ar": "نقل الركاب والرحلات الجماعية", "base_mass_kg": 2650,
		"max_cargo_kg": 650, "max_torque_nm": 540, "drivetrain": "4H", "gears": 6,
		"fuel_tank_l": 110, "price": 2100, "center_y": -0.28, "wheelbase": 3.35,
		"track": 1.96, "radius": 0.44, "wheel_width": 0.28, "rest": 0.6,
		"travel": 0.3, "spring": 58000, "damper": 7200, "anti_roll": 11200,
		"idle": 720, "redline": 4800, "brake": 31000, "handbrake": 25000,
		"steer_speed": 2.8, "modes": ["RWD", "4H", "4L"], "burn": 1.48, "drag": 0.52,
		"rolling": 290, "engine_hz": 38, "paint": "#0284c7", "steer_deg": 30.0,
		"width": 2.18, "length": 5.72, "roof": 2.19,
	},
	"munqidh": {
		"name_ar": "المنقذ", "title_ar": "المنقذ — مركبة الإنقاذ والسحب الجبلي", "category_ar": "مهمات الإنقاذ والطوارئ الوعرة", "base_mass_kg": 2880,
		"max_cargo_kg": 1100, "max_torque_nm": 760, "drivetrain": "4H", "gears": 6,
		"fuel_tank_l": 130, "price": 2800, "center_y": -0.34, "wheelbase": 3.2,
		"track": 2.06, "radius": 0.5, "wheel_width": 0.35, "rest": 0.68,
		"travel": 0.36, "spring": 66000, "damper": 8200, "anti_roll": 13200,
		"idle": 700, "redline": 4600, "brake": 36000, "handbrake": 29000,
		"steer_speed": 2.9, "modes": ["2H", "4H", "4L"], "burn": 1.78, "drag": 0.49,
		"rolling": 320, "engine_hz": 35, "paint": "#ea580c", "steer_deg": 31.0,
		"width": 2.04, "length": 5.35, "roof": 1.89,
	},
	"badiya": {
		"name_ar": "البادية", "title_ar": "البادية — شاص صحراوي طويل القاعدة", "category_ar": "نقل صحراوي وجبلي ثقيل", "base_mass_kg": 2150,
		"max_cargo_kg": 1200, "max_torque_nm": 530, "drivetrain": "4H", "gears": 6,
		"fuel_tank_l": 140, "price": 2600, "center_y": -0.35, "wheelbase": 3.18,
		"track": 1.92, "radius": 0.46, "wheel_width": 0.31, "rest": 0.66,
		"travel": 0.35, "spring": 54000, "damper": 6600, "anti_roll": 10800,
		"idle": 760, "redline": 5500, "brake": 27000, "handbrake": 22000,
		"steer_speed": 3.2, "modes": ["2H", "4H", "4L"], "burn": 1.42, "drag": 0.45,
		"rolling": 240, "engine_hz": 40, "paint": "#d6b06a", "steer_deg": 32.0,
		"width": 1.94, "length": 4.71, "roof": 1.55,
	},
	"aseel": {
		"name_ar": "الأصيل", "title_ar": "الأصيل — أيقونة العقبات الكلاسيكية 4×4", "category_ar": "تسلق صخور ودروب تراثية", "base_mass_kg": 1580,
		"max_cargo_kg": 200, "max_torque_nm": 410, "drivetrain": "4L", "gears": 5,
		"fuel_tank_l": 75, "price": 1900, "center_y": -0.37, "wheelbase": 2.38,
		"track": 1.84, "radius": 0.45, "wheel_width": 0.32, "rest": 0.65,
		"travel": 0.38, "spring": 41000, "damper": 5300, "anti_roll": 9200,
		"idle": 750, "redline": 5400, "brake": 22000, "handbrake": 19500,
		"steer_speed": 3.6, "modes": ["2H", "4H", "4L"], "burn": 1.2, "drag": 0.46,
		"rolling": 210, "engine_hz": 44, "paint": "#4d7c0f", "steer_deg": 36.0,
		"width": 1.76, "length": 4.05, "roof": 1.52,
	},
}


static func canonical_id(id: String) -> String:
	if id == "shahiq_4x4":
		return "shahiq"
	return id if FLEET_SPECS.has(id) else "shahiq"


static func build_config(id: String, tuning: Dictionary = {}) -> VehiclePhysicsConfig:
	var spec: Dictionary = FLEET_SPECS[canonical_id(id)]
	var config := VehiclePhysicsConfig.new()
	config.mass_kg = spec.base_mass_kg
	config.center_of_mass_offset.y = spec.center_y
	config.cargo_limit = spec.max_cargo_kg
	config.wheelbase = spec.wheelbase
	config.track_width = spec.track
	config.wheel_radius = spec.radius
	config.wheel_width = spec.wheel_width
	config.width = spec.width
	config.length = spec.length
	config.roof_height = spec.roof
	var height := clampi(int(tuning.get("native_ride", 0)), 0, RIDE_STEPS.size() - 1)
	config.suspension_rest_length = float(spec.rest) + RIDE_STEPS[height]
	var tire := clampi(int(tuning.get("native_tire", 0)), 0, COMPOUNDS.size() - 1)
	config.tire_compound = COMPOUNDS[tire]
	config.suspension_max_travel = spec.travel
	config.spring_stiffness = spec.spring
	config.spring_damping = spec.damper
	config.anti_roll_stiffness = spec.anti_roll
	config.torque_nm = spec.max_torque_nm
	config.idle_rpm = spec.idle
	config.redline_rpm = spec.redline
	config.fuel_capacity = spec.fuel_tank_l
	config.fuel_liters_per_min = spec.burn
	config.default_drivetrain = spec.drivetrain
	config.supported_modes = PackedStringArray(spec.modes)
	config.drag_area = spec.drag * spec.width * (spec.roof + 0.2)
	config.rolling_resistance = spec.rolling / (spec.base_mass_kg * 9.81)
	config.max_brake_force = spec.brake
	config.handbrake_force = spec.handbrake
	config.max_steer_angle_deg = spec.steer_deg
	config.steer_response_speed = spec.steer_speed
	if spec.gears == 5:
		config.ratios = PackedFloat32Array([3.76, 2.19, 1.46, 1.0, 0.79])
	elif spec.gears == 8:
		config.ratios = PackedFloat32Array([5.34, 3.72, 2.72, 1.99, 1.5, 1.17, 0.96, 0.77])
		config.final_drive = 4.37
	return config


static func paint_for(id: String, tuning: Dictionary) -> Color:
	var index := int(tuning.get("native_paint", -1))
	return PAINTS[index] if index >= 0 and index < PAINTS.size() else Color(FLEET_SPECS[canonical_id(id)].paint)
