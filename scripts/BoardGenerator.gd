extends RefCounted
## 桃鉄風に、盤面をグリッド状に東西南北へ広げてランダム生成する。
## data/board.json の設定を使い、GameState.new_game() から呼ばれる。
##
## 生成方式:
## - 盤面を columns x rows の格子とし、格子点(x, y)がそのままマスになる(間引きしない)。
## - 開始マスは左上(0, 0)、ボスは対角の右下(columns-1, rows-1)に置く。
## - この格子では「開始マスからの最短距離」が常に x + y と一意に定まるので、
##   隣接する格子点同士(右隣・下隣)だけをつなぎ、距離が小さい方から大きい方へ
##   一方向にのみ辺を張る。これでループの無いグラフ(DAG)を保証しつつ、
##   上下左右どの隣とも(右か下かという形で)つながるマス目状のネットワークになる。
## - 辺は確率的に間引いて分岐/合流だらけの網目にしつつ、間引きすぎて
##   到達不能・意図しない行き止まりが生まれないよう最後に救済する。


static func generate(theme: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var grid: Dictionary = theme.get("grid", {})
	var columns: int = maxi(3, int(grid.get("columns", 9)))
	var rows: int = maxi(3, int(grid.get("rows", 7)))
	var edge_keep_chance: float = clampf(float(grid.get("edge_keep_chance", 0.62)), 0.05, 1.0)

	var out_edges: Dictionary = {}
	var in_degree: Dictionary = {}
	for y in range(rows):
		for x in range(columns):
			var id := _id_at(x, y, columns)
			out_edges[id] = []
			in_degree[id] = 0

	# 右隣・下隣とだけ辺の候補を作る(距離は必ず+1で増えるので向きが一意に決まり、
	# ループが生まれない)。
	for y in range(rows):
		for x in range(columns):
			if x + 1 < columns and rng.randf() <= edge_keep_chance:
				_add_edge(out_edges, in_degree, _id_at(x, y, columns), _id_at(x + 1, y, columns))
			if y + 1 < rows and rng.randf() <= edge_keep_chance:
				_add_edge(out_edges, in_degree, _id_at(x, y, columns), _id_at(x, y + 1, columns))

	# 間引きすぎて孤立したマスを救済する: 入次数0(開始マス以外)なら、
	# 格子上で距離が1小さい隣(左 or 上)のどちらかと強制的につなぐ。
	for y in range(rows):
		for x in range(columns):
			if x == 0 and y == 0:
				continue
			var id := _id_at(x, y, columns)
			if int(in_degree.get(id, 0)) > 0:
				continue
			var lower_neighbors: Array = []
			if x > 0:
				lower_neighbors.append(_id_at(x - 1, y, columns))
			if y > 0:
				lower_neighbors.append(_id_at(x, y - 1, columns))
			var source_id: int = lower_neighbors[rng.randi_range(0, lower_neighbors.size() - 1)]
			_add_edge(out_edges, in_degree, source_id, id)

	# 出次数0(ボス以外)なら、距離が1大きい隣(右 or 下)のどちらかと強制的につなぐ。
	for y in range(rows):
		for x in range(columns):
			if x == columns - 1 and y == rows - 1:
				continue
			var id := _id_at(x, y, columns)
			if not out_edges[id].is_empty():
				continue
			var higher_neighbors: Array = []
			if x + 1 < columns:
				higher_neighbors.append(_id_at(x + 1, y, columns))
			if y + 1 < rows:
				higher_neighbors.append(_id_at(x, y + 1, columns))
			var target_id: int = higher_neighbors[rng.randi_range(0, higher_neighbors.size() - 1)]
			_add_edge(out_edges, in_degree, id, target_id)

	var spaces: Array = []
	for y in range(rows):
		for x in range(columns):
			var id := _id_at(x, y, columns)
			var is_start := x == 0 and y == 0
			var is_boss := x == columns - 1 and y == rows - 1
			var space := {
				"id": id,
				"x": x,
				"y": y,
				"next_ids": out_edges[id].duplicate(),
			}
			if is_start:
				_fill_start_tile(space, theme)
			elif is_boss:
				_fill_boss_tile(space, theme, rng)
			else:
				_fill_regular_tile(space, theme, rng)
			spaces.append(space)

	_assign_route_profiles(spaces, theme, rng)

	return {
		"width": columns,
		"height": rows,
		"start_id": _id_at(0, 0, columns),
		"spaces": spaces,
	}


static func _id_at(x: int, y: int, columns: int) -> int:
	return y * columns + x


static func _add_edge(out_edges: Dictionary, in_degree: Dictionary, from_id: int, to_id: int) -> void:
	if out_edges[from_id].has(to_id):
		return
	out_edges[from_id].append(to_id)
	in_degree[to_id] = int(in_degree.get(to_id, 0)) + 1


static func _fill_start_tile(space: Dictionary, theme: Dictionary) -> void:
	var start_theme: Dictionary = theme.get("start", {})
	space["type"] = "start"
	space["label"] = String(start_theme.get("label", "START"))
	space["description"] = String(start_theme.get("description", "旅の始まり。マス目が入り組んだルートを進みます。"))


static func _fill_boss_tile(space: Dictionary, theme: Dictionary, rng: RandomNumberGenerator) -> void:
	var boss_theme: Dictionary = theme.get("boss", {})
	var labels: Array = boss_theme.get("labels", ["試練"])
	space["type"] = "boss"
	space["label"] = String(_pick(labels, rng, "試練"))
	space["description"] = String(boss_theme.get("description", "ルートの終点で大きな試練が始まります。"))


static func _fill_regular_tile(space: Dictionary, theme: Dictionary, rng: RandomNumberGenerator) -> void:
	var type_weights: Dictionary = theme.get("type_weights", {"train": 1, "event": 1, "encounter": 1, "rest": 1, "shop": 1})
	var type_name := _weighted_pick(type_weights, rng)
	var tile_theme: Dictionary = theme.get("tiles", {}).get(type_name, {})
	var labels: Array = tile_theme.get("labels", [type_name])
	var descriptions: Array = tile_theme.get("descriptions", [])

	space["type"] = type_name
	space["label"] = String(_pick(labels, rng, type_name))
	if not descriptions.is_empty():
		space["description"] = String(_pick(descriptions, rng, ""))

	match type_name:
		"train":
			var stats: Array = tile_theme.get("stats", ["str", "charm", "mind"])
			space["stat"] = String(_pick(stats, rng, "str"))
		"event":
			var categories: Array = tile_theme.get("categories", ["daily"])
			space["category"] = String(_pick(categories, rng, "daily"))
		"encounter":
			var strong_chance: float = float(tile_theme.get("strong_chance", 0.3))
			space["strong"] = rng.randf() < strong_chance


static func _assign_route_profiles(spaces: Array, theme: Dictionary, rng: RandomNumberGenerator) -> void:
	var route_profiles: Array = theme.get("route_profiles", ["safe", "training", "danger", "reward", "recovery"])
	if route_profiles.is_empty():
		return

	var assigned: Dictionary = {}
	var pool: Array = route_profiles.duplicate()
	pool.shuffle()
	for space in spaces:
		var ids: Array = space.get("next_ids", [])
		if ids.size() <= 1:
			continue
		for target_id in ids:
			if assigned.has(target_id):
				continue
			if pool.is_empty():
				pool = route_profiles.duplicate()
				pool.shuffle()
			assigned[target_id] = pool.pop_back()

	for space in spaces:
		var id: int = int(space.get("id", -1))
		if assigned.has(id):
			space["route_profile"] = assigned[id]
			space["route_label"] = "%sへ" % String(space.get("label", "道"))


static func _weighted_pick(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	if weights.is_empty():
		return "event"
	var total := 0.0
	for key in weights.keys():
		total += float(weights[key])
	if total <= 0.0:
		return String(weights.keys()[0])
	var roll := rng.randf() * total
	var acc := 0.0
	for key in weights.keys():
		acc += float(weights[key])
		if roll <= acc:
			return String(key)
	return String(weights.keys()[-1])


static func _pick(pool: Array, rng: RandomNumberGenerator, fallback: String) -> String:
	if pool.is_empty():
		return fallback
	return String(pool[rng.randi_range(0, pool.size() - 1)])
