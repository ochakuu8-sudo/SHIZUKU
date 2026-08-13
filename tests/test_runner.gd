extends SceneTree
## 簡易ヘッドレステストランナー。
## 実行: godot --headless --script res://tests/test_runner.gd
## GUTなどの外部アドオンに依存せず、GameState.gd の重要な不変条件を検証する。

const GameStateScript := preload("res://scripts/GameState.gd")
const BoardGeneratorScript := preload("res://scripts/BoardGenerator.gd")

var checks := 0
var failures := 0


func _init() -> void:
	_test_board_generator_produces_valid_graph()
	_test_encounter_tiering()
	_test_train_all_respects_route_profile_bonus()
	_test_exhaustion_defeat_returns_to_start()
	_test_load_game_repairs_missing_fields()
	_test_multi_step_move_lands_exactly_on_fork()
	_test_multi_step_move_skips_intermediate_effects()
	_test_multi_step_move_stops_early_at_fork_and_carries_remainder()
	_test_save_load_preserves_generated_board()

	if failures > 0:
		print("FAILED: %d/%d checks failed" % [failures, checks])
		quit(1)
	else:
		print("OK: %d checks passed" % checks)
		quit(0)


func _assert(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: %s" % message)


func _new_game_state() -> Node:
	# --script 実行では _ready() のタイミングが本来のゲーム実行と異なり保証されないため、
	# 初期化処理を明示的に呼び出して決定的にする。盤面は毎回ランダム生成される。
	var gs := GameStateScript.new()
	root.add_child(gs)
	gs.load_content()
	gs.new_game()
	return gs


func _make_test_board() -> Dictionary:
	# 分岐ロジックだけをピンポイントで検証するための、決め打ちの小さな盤面。
	# start(0) -> 1(train,all) -> 2(event,story) -> 3(fork) -> [10, 20] -> 11(boss)
	return {
		"width": 6, "height": 3, "start_id": 0,
		"spaces": [
			{"id": 0, "x": 0, "y": 1, "type": "start", "label": "START", "description": "", "next_ids": [1]},
			{"id": 1, "x": 1, "y": 1, "type": "train", "label": "鍛錬", "stat": "all", "description": "", "next_ids": [2]},
			{"id": 2, "x": 2, "y": 1, "type": "event", "label": "出来事", "category": "story", "description": "", "next_ids": [3]},
			{"id": 3, "x": 3, "y": 1, "type": "fork", "label": "分岐", "description": "", "next_ids": [10, 20]},
			{"id": 10, "x": 4, "y": 0, "type": "train", "label": "上ルート", "stat": "str", "description": "", "next_ids": [11]},
			{"id": 11, "x": 5, "y": 0, "type": "boss", "label": "試練", "description": "", "next_ids": []},
			{"id": 20, "x": 4, "y": 2, "type": "train", "label": "下ルート", "stat": "charm", "description": "", "next_ids": [11]},
		],
	}


func _new_game_state_with_board(board: Dictionary) -> Node:
	var gs := GameStateScript.new()
	root.add_child(gs)
	gs.load_content()
	gs.new_game(board)
	return gs


func _next_ids_of(spaces: Array, id: int) -> Array:
	for space in spaces:
		if int(space.get("id", -1)) == id:
			return space.get("next_ids", [])
	return []


func _test_board_generator_produces_valid_graph() -> void:
	var gs := _new_game_state()

	for trial in range(6):
		gs.rng.seed = trial * 977 + 13
		var board: Dictionary = BoardGeneratorScript.generate(gs.board_theme, gs.rng)
		var spaces: Array = board.get("spaces", [])
		_assert(spaces.size() > 10, "trial %d: generated board should be reasonably packed with tiles (got %d)" % [trial, spaces.size()])

		var ids := {}
		for space in spaces:
			ids[int(space.get("id", -1))] = true
		for space in spaces:
			for next_id in space.get("next_ids", []):
				_assert(ids.has(int(next_id)), "trial %d: space %s references missing next_id %s" % [trial, space.get("id"), next_id])

		var start_id := int(board.get("start_id", 0))
		var visited := {}
		var queue := [start_id]
		while not queue.is_empty():
			var current: int = queue.pop_front()
			if visited.has(current):
				continue
			visited[current] = true
			for next_id in _next_ids_of(spaces, current):
				if not visited.has(int(next_id)):
					queue.append(int(next_id))
		for space in spaces:
			_assert(visited.has(int(space.get("id", -1))), "trial %d: space %s is unreachable from start_id" % [trial, space.get("id", "?")])

		var dead_ends := 0
		var boss_count := 0
		var fork_count := 0
		for space in spaces:
			var next_ids: Array = space.get("next_ids", [])
			if next_ids.is_empty():
				dead_ends += 1
			if String(space.get("type", "")) == "boss":
				boss_count += 1
			if next_ids.size() > 1:
				fork_count += 1
		_assert(dead_ends == 1, "trial %d: expected exactly one dead end (the boss tile), got %d" % [trial, dead_ends])
		_assert(boss_count == 1, "trial %d: expected exactly one boss tile, got %d" % [trial, boss_count])
		_assert(fork_count > 0, "trial %d: expected at least one branching tile in a packed board" % trial)

	gs.queue_free()


func _test_encounter_tiering() -> void:
	var gs := _new_game_state()
	gs.rng.seed = 42

	for i in range(60):
		gs.start_encounter(false)
		var enemy_id := String(gs.battle.get("enemy", {}).get("id", ""))
		_assert(enemy_id != "rival", "non-strong encounter should never draw the boss-tier enemy (got %s)" % enemy_id)
		gs.battle.clear()

	for i in range(60):
		gs.start_encounter(true)
		var enemy_id2 := String(gs.battle.get("enemy", {}).get("id", ""))
		_assert(enemy_id2 != "slime", "strong encounter should never draw the weakest enemy (got %s)" % enemy_id2)
		gs.battle.clear()

	gs.queue_free()


func _test_train_all_respects_route_profile_bonus() -> void:
	var gs := _new_game_state()
	gs.player["stamina"] = 10
	gs.player["stats"] = {"str": 0, "charm": 0, "mind": 0, "resolve": 0}
	# base(2) + training route bonus(1) = 3。バグ修正前は "all" だと常に+1固定だった。
	gs._train_stat("all", 3, 2)
	var stats: Dictionary = gs.player["stats"]
	_assert(int(stats.get("str", 0)) >= 2, "route profile bonus should raise 'all' stat training (str=%d)" % int(stats.get("str", 0)))
	_assert(int(stats.get("charm", 0)) == int(stats.get("str", 0)), "'all' training should raise every stat equally")
	_assert(int(stats.get("mind", 0)) == int(stats.get("str", 0)), "'all' training should raise every stat equally")
	gs.queue_free()


func _test_exhaustion_defeat_returns_to_start() -> void:
	var gs := _new_game_state()
	gs.player["hp"] = 4
	gs.player["stamina"] = 0

	var target_space: Dictionary = {}
	for space in gs.get_spaces():
		var type_name := String(space.get("type", ""))
		if type_name != "start" and type_name != "rest":
			target_space = space
			break
	_assert(not target_space.is_empty(), "expected at least one non-start, non-rest space in the generated board")

	gs._apply_travel_cost(target_space)

	_assert(int(gs.player.get("hp", 0)) == 1, "exhaustion defeat should leave hp at 1 (got %d)" % int(gs.player.get("hp", 0)))
	_assert(int(gs.player.get("position", -1)) == int(gs.board_data.get("start_id", 0)), "exhaustion defeat should send the player back to start_id")
	gs.queue_free()


func _test_multi_step_move_lands_exactly_on_fork() -> void:
	var gs := _new_game_state_with_board(_make_test_board())
	gs.advance_route(3)
	_assert(int(gs.player.get("position", -1)) == 3, "advance_route(3) from start should land exactly on the fork (id 3)")
	_assert(gs.needs_route_choice(), "landing on a fork should require a route choice")
	_assert(gs.get_pending_steps() == 0, "no dice pips should remain when the fork is reached exactly")
	gs.queue_free()


func _test_multi_step_move_skips_intermediate_effects() -> void:
	# 出目3で 1(train, stat=all) と 2(event, category=story) を「通過」するだけなら、
	# それらのマス効果(育成/イベント)は発生しないはず。
	var gs := _new_game_state_with_board(_make_test_board())
	var before_stats: Dictionary = gs.player["stats"].duplicate(true)
	var before_gallery_size: int = gs.player["gallery"].size()

	gs.advance_route(3)

	var after_stats: Dictionary = gs.player["stats"]
	for key in before_stats.keys():
		_assert(int(after_stats.get(key, 0)) == int(before_stats.get(key, 0)),
			"passing through an intermediate train tile should not change stats (%s)" % key)
	_assert(gs.player["gallery"].size() == before_gallery_size,
		"passing through an intermediate event tile should not add a gallery entry")
	gs.queue_free()


func _test_multi_step_move_stops_early_at_fork_and_carries_remainder() -> void:
	# 出目5なら、分岐(id3)に3マス目で到達し、2マス分が保留される。
	# ルートを選ぶと、保留分(1マス)がそのまま消化されて id 10 -> id 11 まで進む。
	var gs := _new_game_state_with_board(_make_test_board())
	gs.advance_route(5)
	_assert(int(gs.player.get("position", -1)) == 3, "advance_route(5) should stop at the fork with pips remaining")
	_assert(gs.get_pending_steps() == 2, "2 pips (this fork choice + 1 more) should remain (got %d)" % gs.get_pending_steps())

	gs.choose_route(10)
	_assert(gs.get_pending_steps() == 0, "pending steps should be consumed after choosing a route")
	_assert(int(gs.player.get("position", -1)) == 11, "the remaining pip should carry the player from 10 to 11 (got %d)" % int(gs.player.get("position", -1)))
	gs.queue_free()


func _test_load_game_repairs_missing_fields() -> void:
	var gs := _new_game_state()
	gs.player.erase("gallery")
	gs.player.erase("position")
	gs._ensure_player_route_fields()
	_assert(gs.player.get("gallery") is Array, "missing gallery field should be repaired to an empty array")
	_assert(int(gs.player.get("position", -1)) == int(gs.board_data.get("start_id", 0)), "missing position field should be repaired to start_id")
	gs.queue_free()


func _test_save_load_preserves_generated_board() -> void:
	# 盤面は起動のたびにランダム生成されるため、セーブ/ロードで同じ盤面に
	# 戻れることを実際のファイル読み書きで検証する。
	var gs := _new_game_state()
	var original_start_id := int(gs.board_data.get("start_id", -1))
	var original_space_count: int = gs.get_spaces().size()

	gs.save_game()
	gs.board_data = {}
	gs.player = {}
	gs.load_game()

	_assert(int(gs.board_data.get("start_id", -1)) == original_start_id, "loaded board should match the saved board's start_id")
	_assert(gs.get_spaces().size() == original_space_count, "loaded board should have the same number of spaces as the saved one (got %d, expected %d)" % [gs.get_spaces().size(), original_space_count])
	gs.queue_free()
