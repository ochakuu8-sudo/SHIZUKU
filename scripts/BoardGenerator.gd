extends RefCounted
## 桃鉄風に、盤面をグリッド状に敷き詰めて生成する。マス同士のつながりは
## 双方向(無向グラフ)で、プレイヤーは分岐のたびに東西南北どちらへでも
## 自分で進む方向を選べる。data/board.json の設定を使い、
## GameState.new_game() から呼ばれる。
##
## 生成方式:
## - 盤面を columns x rows の格子とし、格子点(x, y)がそのままマスになる(間引きしない)。
## - 各マスは右隣・下隣の候補との間で、確率的に道(辺)を生成する。
##   道は双方向につながる(A→Bだけでなく B→A の next_ids にも入る)。
## - それだけでは盤面が分断されることがあるため、スタートから辿り着けない
##   マスが無くなるまで、救済の道を追加してつなぎ直す。
## - 開始マスは左上、ボスはスタートからグラフ上の距離が最も遠いマスに置く。


static func generate(theme: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var grid: Dictionary = theme.get("grid", {})
	var columns: int = maxi(3, int(grid.get("columns", 9)))
	var rows: int = maxi(3, int(grid.get("rows", 7)))
	var edge_keep_chance: float = clampf(float(grid.get("edge_keep_chance", 0.62)), 0.05, 1.0)

	var neighbors: Dictionary = {} # id -> Array[int] (双方向のつながり)
	for y in range(rows):
		for x in range(columns):
			neighbors[_id_at(x, y, columns)] = []

	for y in range(rows):
		for x in range(columns):
			if x + 1 < columns and rng.randf() <= edge_keep_chance:
				_link(neighbors, _id_at(x, y, columns), _id_at(x + 1, y, columns))
			if y + 1 < rows and rng.randf() <= edge_keep_chance:
				_link(neighbors, _id_at(x, y, columns), _id_at(x, y + 1, columns))

	var start_id := _id_at(0, 0, columns)
	_ensure_connected(neighbors, start_id, columns, rows, rng)

	var distances := _bfs_distances(neighbors, start_id)
	var boss_id := _pick_farthest(distances, columns, rows)

	var spaces: Array = []
	for y in range(rows):
		for x in range(columns):
			var id := _id_at(x, y, columns)
			var space := {
				"id": id,
				"x": x,
				"y": y,
				"next_ids": neighbors[id].duplicate(),
			}
			if id == start_id:
				_fill_start_tile(space, theme)
			elif id == boss_id:
				_fill_boss_tile(space, theme, rng)
			else:
				_fill_regular_tile(space, theme, rng)
			spaces.append(space)

	_assign_route_profiles(spaces, theme, rng)

	return {
		"width": columns,
		"height": rows,
		"start_id": start_id,
		"spaces": spaces,
	}


static func _id_at(x: int, y: int, columns: int) -> int:
	return y * columns + x


static func _link(neighbors: Dictionary, a: int, b: int) -> void:
	if not neighbors[a].has(b):
		neighbors[a].append(b)
	if not neighbors[b].has(a):
		neighbors[b].append(a)


static func _grid_neighbors_of(id: int, columns: int, rows: int) -> Array:
	var x := id % columns
	var y := id / columns
	var result: Array = []
	if x > 0:
		result.append(_id_at(x - 1, y, columns))
	if x + 1 < columns:
		result.append(_id_at(x + 1, y, columns))
	if y > 0:
		result.append(_id_at(x, y - 1, columns))
	if y + 1 < rows:
		result.append(_id_at(x, y + 1, columns))
	return result


static func _ensure_connected(neighbors: Dictionary, start_id: int, columns: int, rows: int, rng: RandomNumberGenerator) -> void:
	var total: int = columns * rows

	# まず、道が1本も残らなかったマス(スタート自身を含む)を直接救済する。
	# これを先にやらないと、スタートが孤立したまま偶然つながるのを運任せにしてしまう。
	for id in neighbors.keys():
		if not neighbors[id].is_empty():
			continue
		var candidates := _grid_neighbors_of(int(id), columns, rows)
		if candidates.is_empty():
			continue
		var target: int = candidates[rng.randi_range(0, candidates.size() - 1)]
		_link(neighbors, int(id), target)

	# その上で、複数の孤立した島ができていないか(スタートから辿り着けるか)を
	# BFSで確認し、辿り着けないマスがあれば繰り返しつなぎ直す。
	for attempt in range(total):
		var reached := _bfs_reachable(neighbors, start_id)
		if reached.size() >= total:
			return
		for id in neighbors.keys():
			if reached.has(id):
				continue
			var candidates := _grid_neighbors_of(id, columns, rows)
			if candidates.is_empty():
				continue
			var target: int = candidates[rng.randi_range(0, candidates.size() - 1)]
			_link(neighbors, id, target)


static func _bfs_reachable(neighbors: Dictionary, start_id: int) -> Dictionary:
	var visited: Dictionary = {}
	var queue: Array = [start_id]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		if visited.has(current):
			continue
		visited[current] = true
		for next_id in neighbors.get(current, []):
			if not visited.has(next_id):
				queue.append(next_id)
	return visited


static func _bfs_distances(neighbors: Dictionary, start_id: int) -> Dictionary:
	var distances: Dictionary = {start_id: 0}
	var queue: Array = [start_id]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		var current_dist: int = distances[current]
		for next_id in neighbors.get(current, []):
			if not distances.has(next_id):
				distances[next_id] = current_dist + 1
				queue.append(next_id)
	return distances


static func _pick_farthest(distances: Dictionary, columns: int, rows: int) -> int:
	var best_id := 0
	var best_dist := -1
	var best_tiebreak := -1
	for id in distances.keys():
		var d: int = distances[id]
		var x: int = int(id) % columns
		var y: int = int(id) / columns
		var tiebreak := x + y
		if d > best_dist or (d == best_dist and tiebreak > best_tiebreak):
			best_dist = d
			best_tiebreak = tiebreak
			best_id = int(id)
	return best_id


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
	# 分岐でどちらに進んでも見た目のルート特性が伝わるよう、拠点/ボス以外の
	# 全マスに(出現頻度が偏らないよう束をシャッフルしながら)ルート特性を割り振る。
	var route_profiles: Array = theme.get("route_profiles", ["safe", "training", "danger", "reward", "recovery"])
	if route_profiles.is_empty():
		return

	var pool: Array = []
	for space in spaces:
		var type_name := String(space.get("type", ""))
		if type_name == "start" or type_name == "boss":
			continue
		if pool.is_empty():
			pool = route_profiles.duplicate()
			pool.shuffle()
		space["route_profile"] = pool.pop_back()
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
