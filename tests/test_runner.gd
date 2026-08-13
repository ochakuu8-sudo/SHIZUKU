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
	_test_auto_continue_skips_backtrack_option()
	_test_free_choice_fork_offers_all_non_backtrack_neighbors()
	_test_boss_always_stops_even_as_a_pass_through_tile()
	_test_backtrack_into_dead_end_turns_around_instead_of_finishing()
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


func _new_game_state_with_board(board: Dictionary) -> Node:
	var gs := GameStateScript.new()
	root.add_child(gs)
	gs.load_content()
	gs.new_game(board)
	return gs


func _make_pass_through_board() -> Dictionary:
	# 0(start) -- 1(素通りするだけの中継マス。次数2だが後戻り除外で実質1方向) -- 2(boss)
	return {
		"width": 3, "height": 1, "start_id": 0,
		"spaces": [
			{"id": 0, "x": 0, "y": 0, "type": "start", "label": "START", "description": "", "next_ids": [1]},
			{"id": 1, "x": 1, "y": 0, "type": "train", "label": "中継", "stat": "str", "description": "", "next_ids": [0, 2]},
			{"id": 2, "x": 2, "y": 0, "type": "boss", "label": "試練", "description": "", "next_ids": [1]},
		],
	}


func _make_diamond_board() -> Dictionary:
	# 0(start) -- 1(分岐: 後戻りを除いても2と3の2方向) -- {2, 3} -- 4(boss)
	return {
		"width": 3, "height": 3, "start_id": 0,
		"spaces": [
			{"id": 0, "x": 0, "y": 1, "type": "start", "label": "START", "description": "", "next_ids": [1]},
			{"id": 1, "x": 1, "y": 1, "type": "fork", "label": "分岐", "description": "", "next_ids": [0, 2, 3]},
			{"id": 2, "x": 2, "y": 0, "type": "train", "label": "上ルート", "stat": "str", "description": "", "next_ids": [1, 4]},
			{"id": 3, "x": 2, "y": 2, "type": "train", "label": "下ルート", "stat": "charm", "description": "", "next_ids": [1, 4]},
			{"id": 4, "x": 3, "y": 1, "type": "boss", "label": "試練", "description": "", "next_ids": [2, 3]},
		],
	}


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

		# 双方向グラフであること: AがBにつながっているなら、BもAにつながっている。
		for space in spaces:
			var from_id := int(space.get("id", -1))
			for next_id in space.get("next_ids", []):
				var reverse_ids: Array = _next_ids_of(spaces, int(next_id))
				_assert(reverse_ids.has(from_id), "trial %d: edge %d->%d should also exist as %d->%d (undirected)" % [trial, from_id, next_id, next_id, from_id])

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
			_assert(not space.get("next_ids", []).is_empty(), "trial %d: space %s has no connections at all" % [trial, space.get("id", "?")])

		var boss_count := 0
		var branch_count := 0
		for space in spaces:
			if String(space.get("type", "")) == "boss":
				boss_count += 1
			if space.get("next_ids", []).size() > 1:
				branch_count += 1
		_assert(boss_count == 1, "trial %d: expected exactly one boss tile, got %d" % [trial, boss_count])
		_assert(branch_count > 0, "trial %d: expected at least one branching tile in a packed board" % trial)

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
	_assert(int(gs.player.get("previous_position", -99)) == -1, "exhaustion defeat should clear previous_position")
	gs.queue_free()


func _test_auto_continue_skips_backtrack_option() -> void:
	# マス1は次数2(0と2)だが、0から来た場合は後戻り除外で実質1方向しか無いので、
	# 足を止めずに素通りするはず(=マス1の育成効果は発生しない)。
	var gs := _new_game_state_with_board(_make_pass_through_board())
	var before_str := int(gs.player["stats"].get("str", 0))

	gs.advance_route(2)

	_assert(int(gs.player["stats"].get("str", 0)) == before_str, "passing through a degree-2 waypoint (excluding backtrack) should not trigger its train effect")
	_assert(int(gs.player.get("position", -1)) == 2, "should have walked all the way to the boss tile (got %d)" % int(gs.player.get("position", -1)))
	gs.queue_free()


func _test_free_choice_fork_offers_all_non_backtrack_neighbors() -> void:
	var gs := _new_game_state_with_board(_make_diamond_board())
	gs.advance_route(2)

	_assert(int(gs.player.get("position", -1)) == 1, "should stop at the branching tile (id 1), got %d" % int(gs.player.get("position", -1)))
	_assert(gs.needs_route_choice(), "a tile with 2 forward options (excluding backtrack) should require a choice")

	var option_ids: Array = []
	for option in gs.get_route_options():
		option_ids.append(int(option.get("id", -1)))
	_assert(option_ids.has(2) and option_ids.has(3), "both non-backtrack directions should be offered (got %s)" % [option_ids])

	gs.choose_route(3)
	_assert(int(gs.player.get("position", -1)) == 3, "choosing route 3 should move the player there (got %d)" % int(gs.player.get("position", -1)))
	gs.queue_free()


func _test_boss_always_stops_even_as_a_pass_through_tile() -> void:
	# マス1から見てボス(2)は唯一の前進方向なので、素通りロジック的には
	# 「1マスだから素通り」に見えてしまいかねないが、ボスは種別で必ず足を止める。
	var gs := _new_game_state_with_board(_make_pass_through_board())
	gs.advance_route(5)

	_assert(int(gs.player.get("position", -1)) == 2, "should have reached the boss tile (got %d)" % int(gs.player.get("position", -1)))
	_assert(gs.is_in_battle(), "landing on the boss tile should always start a battle, even with leftover dice pips")
	gs.queue_free()


func _test_backtrack_into_dead_end_turns_around_instead_of_finishing() -> void:
	# 分岐(1)まで出目3で到達し(1マス分保留)、あえて後戻り(0)を選ぶ。
	# start(0)は次数1(1としかつながっていない)ので、後戻り除外だと行き場が無い。
	# これを「踏破完了」と誤判定せず、来た道(1)へ引き返して残りの出目を消費するべき。
	var gs := _new_game_state_with_board(_make_diamond_board())
	gs.advance_route(3)
	_assert(int(gs.player.get("position", -1)) == 1, "should be paused at the fork with 2 pips remaining")
	_assert(gs.get_pending_steps() == 2, "expected 2 pending pips (got %d)" % gs.get_pending_steps())

	gs.choose_route(0)

	_assert(not bool(gs.player.get("finished", false)), "backtracking into a dead end must not be mistaken for finishing the route")
	_assert(int(gs.player.get("position", -1)) == 1, "should have turned around and walked back to 1 (got %d)" % int(gs.player.get("position", -1)))
	gs.queue_free()


func _test_multi_step_move_stops_early_at_fork_and_carries_remainder() -> void:
	var gs := _new_game_state_with_board(_make_diamond_board())
	# 出目1で 0->1 に到達。マス1は後戻り除外で2方向あるので、そこで足を止める。
	gs.advance_route(1)
	_assert(int(gs.player.get("position", -1)) == 1, "advance_route(1) should stop at the fork (id 1)")
	_assert(gs.get_pending_steps() == 0, "no pips should remain when the fork is reached exactly")

	gs.choose_route(2)
	_assert(int(gs.player.get("position", -1)) == 2, "choosing route 2 should move the player there")
	gs.queue_free()


func _test_load_game_repairs_missing_fields() -> void:
	var gs := _new_game_state()
	gs.player.erase("gallery")
	gs.player.erase("position")
	gs.player.erase("previous_position")
	gs._ensure_player_route_fields()
	_assert(gs.player.get("gallery") is Array, "missing gallery field should be repaired to an empty array")
	_assert(int(gs.player.get("position", -1)) == int(gs.board_data.get("start_id", 0)), "missing position field should be repaired to start_id")
	_assert(int(gs.player.get("previous_position", -99)) == -1, "missing previous_position field should be repaired to -1")
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
