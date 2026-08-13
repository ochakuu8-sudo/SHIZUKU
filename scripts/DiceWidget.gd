extends Control
## サイコロの目を手描きで表示するだけの軽量ウィジェット。
## 外部画像に依存せず、BoardMap.gd と同様に _draw() でその場に描画する。

const PIP_LAYOUTS := {
	1: [Vector2(0.5, 0.5)],
	2: [Vector2(0.28, 0.28), Vector2(0.72, 0.72)],
	3: [Vector2(0.28, 0.28), Vector2(0.5, 0.5), Vector2(0.72, 0.72)],
	4: [Vector2(0.28, 0.28), Vector2(0.72, 0.28), Vector2(0.28, 0.72), Vector2(0.72, 0.72)],
	5: [Vector2(0.28, 0.28), Vector2(0.72, 0.28), Vector2(0.5, 0.5), Vector2(0.28, 0.72), Vector2(0.72, 0.72)],
	6: [Vector2(0.26, 0.24), Vector2(0.74, 0.24), Vector2(0.26, 0.5), Vector2(0.74, 0.5), Vector2(0.26, 0.76), Vector2(0.74, 0.76)],
}

var value := 1


func set_value(v: int) -> void:
	value = clampi(v, 1, 6)
	queue_redraw()


func _draw() -> void:
	var body := StyleBoxFlat.new()
	body.bg_color = Color("#f4efe6")
	body.border_color = Color("#2c3544")
	body.set_border_width_all(2)
	body.set_corner_radius_all(9)
	draw_style_box(body, Rect2(Vector2.ZERO, size))

	var pip_radius: float = size.x * 0.09
	for pos in PIP_LAYOUTS.get(value, []):
		draw_circle(Vector2(pos.x * size.x, pos.y * size.y), pip_radius, Color("#232733"))
