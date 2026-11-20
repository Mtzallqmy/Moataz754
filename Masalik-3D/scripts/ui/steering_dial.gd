extends Control


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(center.x, center.y) - 8.0
	if radius < 6.0:
		return
	draw_circle(center, radius + 5.0, Color("#0d1722b0"), true, -1.0, true)
	draw_arc(center, radius, 0, TAU, 48, Color("#c5cbd2"), 7.0, true)
	draw_arc(center, radius, -PI * 0.56, -PI * 0.44, 8, Color("#ffc66c"), 8.0, true)
	for angle in [0.0, PI, PI * 0.5]:
		var edge := center + Vector2.from_angle(angle) * (radius - 3.0)
		draw_line(center, edge, Color("#a8b2bdbb"), 6.0, true)
	draw_circle(center, radius * 0.22, Color("#26384a"), true, -1.0, true)
	draw_arc(center, radius * 0.22, 0, TAU, 24, Color("#919aa7"), 2.0, true)
