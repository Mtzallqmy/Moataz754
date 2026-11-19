class_name TimeAndWeatherSystem
extends RefCounted

const PRESETS := {
	"clear": [0.0, 0.0011, Color("#88b5ce"), "صحو"],
	"cloudy": [0.0, 0.0027, Color("#849298"), "غائم"],
	"light_rain": [0.64, 0.007, Color("#6e8490"), "مطر خفيف"],
	"heavy_rain": [1.0, 0.012, Color("#576d7c"), "مطر غزير"],
	"mountain_fog": [0.19, 0.024, Color("#b1bbba"), "ضباب"],
	"dusty": [0.0, 0.009, Color("#b7a183"), "غبار"],
	"sandstorm": [0.0, 0.027, Color("#b28a57"), "عاصفة رملية"],
}
const HOURS := {
	"dawn": 5.35, "sunrise": 6.35, "morning": 9.0, "noon": 12.0,
	"afternoon": 15.5, "sunset": 18.2, "night": 21.0, "midnight": 0.0,
}

var weather := "clear"
var hours := 9.0
var wetness := 0.0
var _environment: Environment
var _sun: DirectionalLight3D


func _init(environment: Environment, sun: DirectionalLight3D) -> void:
	_environment = environment
	_sun = sun
	_environment.fog_enabled = true
	_environment.fog_light_energy = 0.78


func configure(next_weather: String, time_of_day: String) -> void:
	if PRESETS.has(next_weather):
		weather = next_weather
	hours = HOURS.get(time_of_day, hours)
	update(0.0)


func update(delta: float) -> void:
	hours = fposmod(hours + delta / 155.0, 24.0)
	var profile: Array = PRESETS[weather]
	wetness = profile[0]
	var elevation := sin((hours - 6.0) / 24.0 * TAU)
	var daylight := smoothstep(-0.2, 0.45, elevation)
	var color: Color = profile[2]
	_environment.background_color = Color("#0d192b").lerp(color, daylight)
	_environment.ambient_light_color = Color("#9cb6e6").lerp(Color("#d6e0e7"), daylight)
	_environment.ambient_light_energy = lerpf(0.18, 0.72, daylight)
	_environment.fog_light_color = _environment.background_color
	_environment.fog_density = profile[1]
	_sun.rotation_degrees = Vector3(-maxf(2.0, elevation * 73.0), -36.0 + (hours - 9.0) * 8.0, 0.0)
	_sun.light_energy = daylight * (0.58 if weather in ["cloudy", "heavy_rain", "mountain_fog"] else 1.12)
	_sun.light_color = Color("#f5b178").lerp(Color("#fff3dd"), smoothstep(0.1, 0.57, elevation))
	_sun.shadow_enabled = _sun.light_energy > 0.12 and QualityManager.current_quality != 0
