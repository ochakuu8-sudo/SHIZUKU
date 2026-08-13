extends Control
## 現在地を表す駒(コマ)。画像を使わず、BoardMap.gd / DiceWidget.gd と同様に
## _draw() でその場に描画する。実際の移動アニメーションは Main.gd 側で行う。

func _draw() -> void:
	var center := size * 0.5
	var radius: float = size.x * 0.5

	# 影
	draw_circle(center + Vector2(0.0, radius * 0.55), radius * 0.85, Color(0, 0, 0, 0.35))

	# 本体
	draw_circle(center, radius, Color("#f2ca69"))
	draw_arc(center, radius - 1.0, 0.0, TAU, 32, Color("#8a5a1e"), 2.0, true)

	# ハイライト
	draw_circle(center - Vector2(radius * 0.28, radius * 0.32), radius * 0.32, Color(1, 1, 1, 0.55))
