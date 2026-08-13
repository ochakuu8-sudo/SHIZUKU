extends Control
## ゲーム全体の背景。単色の代わりに、縦グラデーション+中央のほのかな光+
## 星屑のようなノイズで奥行きを出す。画像素材は使わず _draw() で毎回生成する。

var dust_seed := 0


func _ready() -> void:
	dust_seed = randi()
	resized.connect(queue_redraw)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return

	var top := Color("#181f30")
	var mid := Color("#10141f")
	var bottom := Color("#090b11")
	var steps := 28
	for i in range(steps):
		var t0: float = float(i) / float(steps)
		var t1: float = float(i + 1) / float(steps)
		var tc: float = (t0 + t1) * 0.5
		var c: Color = top.lerp(mid, tc * 2.0) if tc < 0.5 else mid.lerp(bottom, (tc - 0.5) * 2.0)
		draw_rect(Rect2(0.0, rect.size.y * t0, rect.size.x, rect.size.y * (t1 - t0) + 1.0), c, true)

	# 中央にほのかな光の溜まり
	var center := rect.size * 0.5
	var max_radius: float = rect.size.length() * 0.55
	var glow_steps := 16
	for i in range(glow_steps, 0, -1):
		var t: float = float(i) / float(glow_steps)
		var radius: float = max_radius * t
		var alpha: float = 0.018 * (1.0 - t)
		draw_circle(center, radius, Color(0.36, 0.44, 0.62, alpha))

	# 星屑ノイズ
	for i in range(180):
		var x := fposmod(float(i * 137 + dust_seed), rect.size.x)
		var y := fposmod(float(i * 71 + dust_seed % 97), rect.size.y)
		var radius := 0.5 + float(i % 3) * 0.45
		var alpha := 0.02 + 0.025 * float(i % 4)
		draw_circle(Vector2(x, y), radius, Color(1, 1, 1, alpha))
