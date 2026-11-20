class_name MissionCatalog
extends RefCounted

# Story IDs, titles and routes are migrated from src/game/missionsCatalog.ts.
const STORY := [
	{"id": "story_c1_m1", "name": "1-1: أولى الخطوات في طريق القمم", "chapter": 1, "vehicle": "shahiq", "start": 40, "finish": 1080, "weather": "clear", "time": "morning", "cargo": 0, "integrity": 0, "limit": 85, "credits": 650, "xp": 150},
	{"id": "story_c1_m2", "name": "1-2: قهوة المدرجات الصباحية", "chapter": 1, "vehicle": "saqr", "start": 420, "finish": 1940, "weather": "clear", "time": "sunrise", "cargo": 50, "integrity": 85, "limit": 115, "credits": 800, "xp": 180},
	{"id": "story_c1_m3", "name": "1-3: ضباب القمم المفاجئ", "chapter": 1, "vehicle": "shahiq", "start": 950, "finish": 2450, "weather": "mountain_fog", "time": "dawn", "cargo": 0, "integrity": 0, "limit": 120, "credits": 850, "xp": 200},
	{"id": "story_c1_m4", "name": "1-4: حافلة طلاب القرية", "chapter": 1, "vehicle": "hafilat", "start": 120, "finish": 1920, "weather": "cloudy", "time": "morning", "cargo": 0, "integrity": 0, "limit": 140, "credits": 920, "xp": 220},
	{"id": "story_c1_m5", "name": "1-5: امتحان بوابة تعز", "chapter": 1, "vehicle": "shahiq", "start": 100, "finish": 2480, "weather": "clear", "time": "afternoon", "cargo": 0, "integrity": 0, "limit": 145, "credits": 1150, "xp": 280},
	{"id": "story_c2_m1", "name": "2-1: صعود نقيل السحاب", "chapter": 2, "vehicle": "shahiq", "start": 2500, "finish": 3850, "weather": "mountain_fog", "time": "morning", "cargo": 0, "integrity": 0, "limit": 115, "credits": 980, "xp": 240},
	{"id": "story_c2_m2", "name": "2-2: الصخور الزلقة تحت المطر", "chapter": 2, "vehicle": "aseel", "start": 2850, "finish": 4450, "weather": "heavy_rain", "time": "afternoon", "cargo": 0, "integrity": 0, "limit": 135, "credits": 1100, "xp": 260},
	{"id": "story_c2_m3", "name": "2-3: إنقاذ على حافة الجسر", "chapter": 2, "vehicle": "munqidh", "start": 2550, "finish": 4850, "weather": "cloudy", "time": "sunset", "cargo": 50, "integrity": 80, "limit": 165, "credits": 1250, "xp": 290},
	{"id": "story_c2_m4", "name": "2-4: النزول الآمن بشاحنة الجبل", "chapter": 2, "vehicle": "jabal", "start": 3900, "finish": 5300, "weather": "clear", "time": "sunrise", "cargo": 100, "integrity": 85, "limit": 130, "credits": 1400, "xp": 320},
	{"id": "story_c2_m5", "name": "2-5: تحدي قمة السحاب الليلي", "chapter": 2, "vehicle": "barq", "start": 2520, "finish": 5180, "weather": "clear", "time": "night", "cargo": 0, "integrity": 0, "limit": 155, "credits": 1550, "xp": 360},
	{"id": "story_c3_m1", "name": "3-1: حمولة وادي الريحان", "chapter": 3, "vehicle": "saqr", "start": 5250, "finish": 7450, "weather": "cloudy", "time": "morning", "cargo": 100, "integrity": 80, "limit": 145, "credits": 1200, "xp": 280},
	{"id": "story_c3_m2", "name": "3-2: عبور جسر الوادي الحجري", "chapter": 3, "vehicle": "badiya", "start": 5400, "finish": 7750, "weather": "light_rain", "time": "afternoon", "cargo": 100, "integrity": 82, "limit": 155, "credits": 1320, "xp": 300},
	{"id": "story_c3_m3", "name": "3-3: سحب المركبة العالقة في الطين", "chapter": 3, "vehicle": "munqidh", "start": 5220, "finish": 6980, "weather": "heavy_rain", "time": "dawn", "cargo": 50, "integrity": 85, "limit": 130, "credits": 1380, "xp": 310},
	{"id": "story_c3_m4", "name": "3-4: رحلة أهالي الوادي إلى السوق", "chapter": 3, "vehicle": "hafilat", "start": 5600, "finish": 7850, "weather": "clear", "time": "morning", "cargo": 0, "integrity": 0, "limit": 150, "credits": 1420, "xp": 330},
	{"id": "story_c3_m5", "name": "3-5: رالي وادي الريحان المفتوح", "chapter": 3, "vehicle": "barq", "start": 5200, "finish": 7800, "weather": "clear", "time": "sunset", "cargo": 0, "integrity": 0, "limit": 140, "credits": 1650, "xp": 380},
	{"id": "story_c4_m1", "name": "4-1: خط تهامة التجاري السريع", "chapter": 4, "vehicle": "madina", "start": 7820, "finish": 10200, "weather": "clear", "time": "morning", "cargo": 0, "integrity": 0, "limit": 110, "credits": 1350, "xp": 310},
	{"id": "story_c4_m2", "name": "4-2: قافلة الميناء الثقيلة", "chapter": 4, "vehicle": "jabal", "start": 8800, "finish": 11480, "weather": "clear", "time": "afternoon", "cargo": 100, "integrity": 85, "limit": 175, "credits": 1600, "xp": 360},
	{"id": "story_c4_m3", "name": "4-3: خط الكورنيش السياحي", "chapter": 4, "vehicle": "hafilat", "start": 10220, "finish": 12550, "weather": "clear", "time": "sunset", "cargo": 0, "integrity": 0, "limit": 140, "credits": 1500, "xp": 340},
	{"id": "story_c4_m4", "name": "4-4: عاصفة الساحل الماطرة", "chapter": 4, "vehicle": "munqidh", "start": 9800, "finish": 12400, "weather": "heavy_rain", "time": "dawn", "cargo": 50, "integrity": 80, "limit": 160, "credits": 1680, "xp": 380},
	{"id": "story_c4_m5", "name": "4-5: بطولة الساحل وتهامة الكبرى", "chapter": 4, "vehicle": "madina", "start": 9500, "finish": 12580, "weather": "clear", "time": "noon", "cargo": 0, "integrity": 0, "limit": 135, "credits": 1850, "xp": 420},
	{"id": "story_c5_m1", "name": "5-1: بوابة الكثبان الذهبية", "chapter": 5, "vehicle": "rahhal", "start": 12600, "finish": 14100, "weather": "clear", "time": "morning", "cargo": 0, "integrity": 0, "limit": 95, "credits": 1550, "xp": 350},
	{"id": "story_c5_m2", "name": "5-2: قافلة الواحة بشاص البادية", "chapter": 5, "vehicle": "badiya", "start": 12550, "finish": 14850, "weather": "clear", "time": "afternoon", "cargo": 100, "integrity": 85, "limit": 145, "credits": 1750, "xp": 400},
	{"id": "story_c5_m3", "name": "5-3: في قلب العاصفة الرملية", "chapter": 5, "vehicle": "rahhal", "start": 12700, "finish": 14800, "weather": "sandstorm", "time": "sunset", "cargo": 0, "integrity": 0, "limit": 130, "credits": 1900, "xp": 440},
	{"id": "story_c5_m4", "name": "5-4: إنقاذ البعثة الصحراوية", "chapter": 5, "vehicle": "munqidh", "start": 12600, "finish": 14900, "weather": "clear", "time": "night", "cargo": 50, "integrity": 85, "limit": 150, "credits": 2100, "xp": 480},
	{"id": "story_c5_m5", "name": "5-5: التحدي النهائي — أسطورة دروب اليمن", "chapter": 5, "vehicle": "barq", "start": 10500, "finish": 14920, "weather": "clear", "time": "sunrise", "cargo": 0, "integrity": 0, "limit": 210, "credits": 3500, "xp": 800},
]

const ACTIVITIES := [
	{"id": "school_01", "name": "مدرسة القيادة • الانطلاق والتوقف", "chapter": 0, "vehicle": "shahiq", "start": 20, "finish": 104, "weather": "clear", "time": "morning", "cargo": 0, "integrity": 0, "limit": 95, "credits": 140, "xp": 25, "stop": true},
	{"id": "trial_01", "name": "سباق الزمن • طريق تعز", "chapter": 0, "vehicle": "barq", "start": 112, "finish": 990, "weather": "clear", "time": "noon", "cargo": 0, "integrity": 0, "limit": 87, "credits": 550, "xp": 90},
	{"id": "mountain_01", "name": "تحدي الجبال • منعطفات النقيل", "chapter": 0, "vehicle": "aseel", "start": 2520, "finish": 3540, "weather": "mountain_fog", "time": "dawn", "cargo": 0, "integrity": 0, "limit": 180, "credits": 680, "xp": 110},
	{"id": "cargo_01", "name": "نقل البضائع • شحنة تهامة", "chapter": 0, "vehicle": "jabal", "start": 7670, "finish": 8710, "weather": "cloudy", "time": "afternoon", "cargo": 72, "integrity": 82, "limit": 210, "credits": 720, "xp": 120},
	{"id": "rescue_01", "name": "الإنقاذ • نداء الوادي", "chapter": 0, "vehicle": "munqidh", "start": 5110, "finish": 5650, "weather": "light_rain", "time": "sunset", "cargo": 0, "integrity": 0, "limit": 160, "credits": 570, "xp": 100, "stop": true},
	{"id": "desert_01", "name": "رحلة وعرة • عبور الكثبان", "chapter": 0, "vehicle": "rahhal", "start": 12620, "finish": 14240, "weather": "dusty", "time": "afternoon", "cargo": 0, "integrity": 0, "limit": 220, "credits": 780, "xp": 140},
]


static func find(id: String) -> Dictionary:
	for mission in STORY + ACTIVITIES:
		if mission.id == id:
			return mission
	return {}


static func can_start(mission: Dictionary, records: Dictionary) -> bool:
	if mission.chapter <= 1:
		return true
	for entry in STORY:
		if entry.chapter == mission.chapter - 1 and records.get(entry.id, {}).get("completed", false):
			return true
	return false
