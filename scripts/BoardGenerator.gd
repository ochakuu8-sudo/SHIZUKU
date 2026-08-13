extends RefCounted
## 桃鉄風の「マス目が詰まった」盤面を、data/board.json の設定に沿って
## そのつどランダム生成する。GameState.new_game() から呼ばれる。
##
## 生成方式:
## - 盤面を列(x=0..columns-1)に分ける。列0=拠点(1マス)、最終列=ボス(1マス)。
## - 中間の各列には複数マス(min_nodes_per_column〜max_nodes_per_column)をランダムなyに配置する。
## - 隣接する列の間だけをつなぐ(x昇順のみ)ことで、逆走やループが起きないDAGを保証する。
## - 各マスは次列のマスに1〜2本つなぎ、分岐(桃鉄でいう分かれ道)を作る。
## - 次列側で1本もつながっていないマスが出ないよう、最後に救済でつなぎ直す
##   (到達不能マスが絶対に生まれないようにするため)。


static func generate(theme: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var grid: Dictionary = theme.get("grid", {})
	var columns: int = maxi(4, int(grid.get("columns", 15)))
	var rows: int = maxi(3, int(grid.get("rows", 8)))
	var min_nodes: int = maxi(1, int(grid.get("min_nodes_per_column", 2)))
	var max_nodes: int = maxi(min_nodes, int(grid.get("max_nodes_per_column", 4)))
	var extra_edge_chance: float = float(grid.get("extra_edge_chance", 0.15))
	var fork_chance: float = float(grid.get("fork_chance", 0.45))

	var columns_rows: Array = []
	columns_rows.append(_pick_rows(rows, 1, rng))
	for x in range(1, columns - 1):
		var count: int = rng.randi_range(min_nodes, min(max_nodes, rows))
		columns_rows.append(_pick_rows(rows, count, rng))
	columns_rows.append(_pick_rows(rows, 1, rng))

	var id_grid: Array = []
	var next_id := 0
	for x in range(columns_rows.size()):
		var ids_in_column: Array = []
		for y in columns_rows[x]:
			ids_in_column.append(next_id)
			next_id += 1
		id_grid.append(ids_in_column)

	var out_edges: Dictionary = {}
	for x in range(columns_rows.size()):
		for id in id_grid[x]:
			out_edges[id] = []
	var in_degree: Dictionary = {}
	for id in out_edges.keys():
		in_degree[id] = 0

	for x in range(columns_rows.size() - 1):
		var src_ys: Array = columns_rows[x]
		var src_ids: Array = id_grid[x]
		var dst_ys: Array = columns_rows[x + 1]
		var dst_ids: Array = id_grid[x + 1]

		for i in range(src_ids.size()):
			var src_id: int = src_ids[i]
			var src_y: int = src_ys[i]
			var order := _sorted_by_distance(dst_ys, src_y)

			var link_count := 1
			if dst_ids.size() > 1 and rng.randf() < fork_chance:
				link_count = 2
			link_count = mini(link_count, dst_ids.size())

			for k in range(link_count):
				var dst_id: int = dst_ids[order[k]]
				out_edges[src_id].append(dst_id)
				in_degree[dst_id] = int(in_degree[dst_id]) + 1

			for k in range(link_count, dst_ids.size()):
				if rng.randf() < extra_edge_chance:
					var dst_id2: int = dst_ids[order[k]]
					if not out_edges[src_id].has(dst_id2):
						out_edges[src_id].append(dst_id2)
						in_degree[dst_id2] = int(in_degree[dst_id2]) + 1

		# 前の列から1本もつながっていないマスを、一番近いマスから救済してつなぐ。
		for j in range(dst_ids.size()):
			var dst_id3: int = dst_ids[j]
			if int(in_degree.get(dst_id3, 0)) > 0:
				continue
			var closest_index := _closest_index(src_ys, dst_ys[j])
			var closest_id: int = src_ids[closest_index]
			if not out_edges[closest_id].has(dst_id3):
				out_edges[closest_id].append(dst_id3)
			in_degree[dst_id3] = 1

	var spaces: Array = []
	for x in range(columns_rows.size()):
		var is_start := x == 0
		var is_boss := x == columns_rows.size() - 1
		for i in range(id_grid[x].size()):
			var id: int = id_grid[x][i]
			var y: int = columns_rows[x][i]
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
		"start_id": int(id_grid[0][0]),
		"spaces": spaces,
	}


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


static func _pick_rows(rows: int, count: int, rng: RandomNumberGenerator) -> Array:
	var pool: Array = []
	for i in range(rows):
		pool.append(i)
	for i in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var picked: Array = pool.slice(0, mini(count, pool.size()))
	picked.sort()
	return picked


static func _sorted_by_distance(ys: Array, target_y: int) -> Array:
	var order: Array = []
	for i in range(ys.size()):
		order.append(i)
	order.sort_custom(func(a, b): return absi(int(ys[a]) - target_y) < absi(int(ys[b]) - target_y))
	return order


static func _closest_index(ys: Array, target_y: int) -> int:
	var best := 0
	var best_dist := 2147483647
	for i in range(ys.size()):
		var d: int = absi(int(ys[i]) - target_y)
		if d < best_dist:
			best_dist = d
			best = i
	return best
