extends Control
## 手描きの小アイコンウィジェット。画像素材を使わず、種類ごとにベクター線画を描画する。
## DiceWidget.gd / PieceWidget.gd と同じ技法(_draw()での直接描画)。

var kind: String = "":
	set(value):
		kind = value
		queue_redraw()

var icon_color: Color = Color("#f2ca69"):
	set(value):
		icon_color = value
		queue_redraw()

var shade_color: Color = Color("#00000000"):
	set(value):
		shade_color = value
		queue_redraw()


func setup(new_kind: String, color: Color = Color("#f2ca69")) -> void:
	kind = new_kind
	icon_color = color
	shade_color = color.darkened(0.35)
	queue_redraw()


func _p(x: float, y: float) -> Vector2:
	return Vector2(x, y) * size


func _draw() -> void:
	match kind:
		"heart":
			_draw_heart()
		"bolt":
			_draw_bolt()
		"coin":
			_draw_coin()
		"sword":
			_draw_sword()
		"spark":
			_draw_spark()
		"book":
			_draw_book()
		"flame":
			_draw_flame()
		"dumbbell":
			_draw_dumbbell()
		"flag":
			_draw_flag()
		"branch":
			_draw_branch()
		"scroll":
			_draw_scroll()
		"swords":
			_draw_crossed_swords()
		"campfire":
			_draw_campfire()
		"bag":
			_draw_bag()
		"crown":
			_draw_crown()
		"skull":
			_draw_skull()
		"shield":
			_draw_shield()
		_:
			pass


func _draw_heart() -> void:
	var points := PackedVector2Array()
	var steps := 28
	for i in range(steps + 1):
		var t: float = TAU * float(i) / float(steps)
		var hx: float = 16.0 * pow(sin(t), 3.0)
		var hy: float = -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		points.append(_p(0.5 + hx / 34.0, 0.5 + hy / 34.0 + 0.06))
	draw_colored_polygon(points, icon_color)


func _draw_bolt() -> void:
	var points := PackedVector2Array([
		_p(0.58, 0.04), _p(0.24, 0.58), _p(0.46, 0.58),
		_p(0.38, 0.96), _p(0.78, 0.4), _p(0.54, 0.4),
	])
	draw_colored_polygon(points, icon_color)


func _draw_coin() -> void:
	var r: float = size.x * 0.42
	var c := size * 0.5
	draw_circle(c, r, icon_color)
	draw_arc(c, r, 0.0, TAU, 24, shade_color, 2.0, true)
	draw_circle(c, r * 0.68, shade_color.lightened(0.1))
	draw_line(c - Vector2(r * 0.24, 0), c + Vector2(r * 0.24, 0), icon_color, 2.0, true)
	draw_line(c - Vector2(0, r * 0.24), c + Vector2(0, r * 0.24), icon_color, 2.0, true)


func _draw_sword() -> void:
	var blade := PackedVector2Array([_p(0.5, 0.04), _p(0.64, 0.52), _p(0.5, 0.62), _p(0.36, 0.52)])
	draw_colored_polygon(blade, icon_color)
	draw_rect(Rect2(_p(0.24, 0.56), size * Vector2(0.52, 0.1)), icon_color, true)
	draw_rect(Rect2(_p(0.45, 0.62), size * Vector2(0.1, 0.22)), icon_color, true)
	draw_circle(_p(0.5, 0.88), size.x * 0.08, icon_color)


func _draw_spark() -> void:
	var points := PackedVector2Array()
	var outer: float = size.x * 0.46
	var inner: float = size.x * 0.18
	var spikes := 4
	for i in range(spikes * 2):
		var t: float = float(i) / float(spikes * 2) * TAU
		var r: float = outer if i % 2 == 0 else inner
		points.append(size * 0.5 + Vector2(cos(t), sin(t)) * r)
	draw_colored_polygon(points, icon_color)
	draw_circle(_p(0.78, 0.24), size.x * 0.08, icon_color)


func _draw_book() -> void:
	var left := PackedVector2Array([_p(0.5, 0.18), _p(0.13, 0.28), _p(0.13, 0.82), _p(0.5, 0.74)])
	var right := PackedVector2Array([_p(0.5, 0.18), _p(0.87, 0.28), _p(0.87, 0.82), _p(0.5, 0.74)])
	draw_colored_polygon(left, icon_color)
	draw_colored_polygon(right, icon_color.darkened(0.15))
	draw_line(_p(0.5, 0.18), _p(0.5, 0.74), shade_color, 1.8, true)


func _draw_flame() -> void:
	var points := PackedVector2Array([
		_p(0.5, 0.03), _p(0.74, 0.36), _p(0.8, 0.62), _p(0.66, 0.88),
		_p(0.5, 0.97), _p(0.34, 0.88), _p(0.2, 0.62), _p(0.26, 0.36),
	])
	draw_colored_polygon(points, icon_color)
	var inner := PackedVector2Array([_p(0.5, 0.42), _p(0.62, 0.62), _p(0.5, 0.86), _p(0.38, 0.62)])
	draw_colored_polygon(inner, Color(1, 1, 1, 0.55))


func _draw_dumbbell() -> void:
	var width: float = maxf(2.0, size.y * 0.14)
	draw_line(_p(0.28, 0.5), _p(0.72, 0.5), icon_color, width * 0.5, true)
	draw_rect(Rect2(_p(0.08, 0.32), size * Vector2(0.16, 0.36)), icon_color, true)
	draw_rect(Rect2(_p(0.76, 0.32), size * Vector2(0.16, 0.36)), icon_color, true)


func _draw_flag() -> void:
	draw_line(_p(0.28, 0.1), _p(0.28, 0.92), icon_color, maxf(2.0, size.x * 0.08), true)
	var points := PackedVector2Array([_p(0.28, 0.14), _p(0.82, 0.28), _p(0.28, 0.46)])
	draw_colored_polygon(points, icon_color)


func _draw_branch() -> void:
	var width: float = maxf(2.0, size.x * 0.1)
	draw_line(_p(0.5, 0.9), _p(0.5, 0.5), icon_color, width, true)
	draw_line(_p(0.5, 0.5), _p(0.18, 0.1), icon_color, width, true)
	draw_line(_p(0.5, 0.5), _p(0.82, 0.1), icon_color, width, true)


func _draw_scroll() -> void:
	var rect := Rect2(_p(0.14, 0.28), size * Vector2(0.72, 0.44))
	draw_rect(rect, icon_color, true)
	draw_circle(_p(0.14, 0.28) + Vector2(0, size.y * 0.22), size.y * 0.13, icon_color)
	draw_circle(_p(0.86, 0.28) + Vector2(0, size.y * 0.22), size.y * 0.13, icon_color)
	draw_line(_p(0.28, 0.42), _p(0.72, 0.42), shade_color, 1.6, true)
	draw_line(_p(0.28, 0.54), _p(0.62, 0.54), shade_color, 1.6, true)


func _draw_crossed_swords() -> void:
	_draw_one_sword(_p(0.15, 0.85), _p(0.85, 0.15))
	_draw_one_sword(_p(0.85, 0.85), _p(0.15, 0.15))


func _draw_one_sword(from: Vector2, to: Vector2) -> void:
	var width: float = maxf(2.0, size.x * 0.08)
	draw_line(from, to, icon_color, width, true)
	var dir := (to - from).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var guard_center := from.lerp(to, 0.28)
	draw_line(guard_center - perp * size.x * 0.12, guard_center + perp * size.x * 0.12, shade_color, width * 0.7, true)


func _draw_campfire() -> void:
	var width: float = maxf(2.0, size.x * 0.08)
	draw_line(_p(0.16, 0.82), _p(0.5, 0.68), shade_color, width, true)
	draw_line(_p(0.84, 0.82), _p(0.5, 0.68), shade_color, width, true)
	var flame_outer := PackedVector2Array([
		_p(0.5, 0.12), _p(0.66, 0.4), _p(0.58, 0.68), _p(0.42, 0.68), _p(0.34, 0.4),
	])
	draw_colored_polygon(flame_outer, icon_color)
	var flame_inner := PackedVector2Array([_p(0.5, 0.32), _p(0.58, 0.5), _p(0.5, 0.66), _p(0.42, 0.5)])
	draw_colored_polygon(flame_inner, shade_color.lightened(0.3))


func _draw_bag() -> void:
	var points := PackedVector2Array([
		_p(0.26, 0.4), _p(0.74, 0.4), _p(0.84, 0.9), _p(0.16, 0.9),
	])
	draw_colored_polygon(points, icon_color)
	draw_arc(_p(0.5, 0.32), size.x * 0.16, PI, TAU, 12, icon_color, maxf(2.0, size.x * 0.07), true)


func _draw_crown() -> void:
	var points := PackedVector2Array([
		_p(0.16, 0.78), _p(0.16, 0.42), _p(0.34, 0.58),
		_p(0.5, 0.2), _p(0.66, 0.58), _p(0.84, 0.42),
		_p(0.84, 0.78),
	])
	draw_colored_polygon(points, icon_color)
	draw_circle(_p(0.5, 0.2), size.x * 0.06, shade_color.lightened(0.3))


func _draw_skull() -> void:
	draw_circle(_p(0.5, 0.4), size.x * 0.32, icon_color)
	draw_rect(Rect2(_p(0.32, 0.55), size * Vector2(0.36, 0.24)), icon_color, true)
	draw_circle(_p(0.38, 0.38), size.x * 0.07, shade_color)
	draw_circle(_p(0.62, 0.38), size.x * 0.07, shade_color)


func _draw_shield() -> void:
	var points := PackedVector2Array([
		_p(0.5, 0.06), _p(0.86, 0.2), _p(0.86, 0.5), _p(0.5, 0.94), _p(0.14, 0.5), _p(0.14, 0.2),
	])
	draw_colored_polygon(points, icon_color)
	draw_line(_p(0.5, 0.2), _p(0.5, 0.76), shade_color, 2.0, true)
