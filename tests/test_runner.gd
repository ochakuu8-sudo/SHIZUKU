extends SceneTree
## 簡易ヘッドレステストランナー。
## 実行: godot --headless --script res://tests/test_runner.gd
## GUTなどの外部アドオンに依存せず、GameState.gd の重要な不変条件を検証する。

const GameStateScript := preload("res://scripts/GameState.gd")

var checks := 0
var failures := 0


func _init() -> void:
	_test_board_graph_integrity()
	_test_encounter_tiering()
	_test_train_all_respects_route_profile_bonus()
	_test_exhaustion_defeat_returns_to_start()
	_test_load_game_repairs_missing_fields()

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
	# 初期化処理を明示的に呼び出して決定的にする。
	var gs := GameStateScript.new()
	root.add_child(gs)
	gs.load_content()
	gs.new_game()
	return gs


func _test_board_graph_integrity() -> void:
	var gs := _new_game_state()
	var spaces: Array = gs.get_spaces()
	_assert(not spaces.is_empty(), "board.json should define at least one space")

	var ids := {}
	for space in spaces:
		ids[int(space.get("id", -1))] = true

	for space in spaces:
		for next_id in gs.get_next_ids(space):
			_assert(ids.has(int(next_id)), "space %s references missing next_id %s" % [space.get("id", "?"), next_id])

	var start_id := int(gs.board_data.get("start_id", 0))
	var visited := {}
	var queue := [start_id]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		if visited.has(current):
			continue
		visited[current] = true
		for next_id in gs.get_next_ids(gs.get_space_by_id(current)):
			if not visited.has(int(next_id)):
				queue.append(int(next_id))

	for space in spaces:
		_assert(visited.has(int(space.get("id", -1))), "space %s is unreachable from start_id" % space.get("id", "?"))

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
	var space: Dictionary = gs.get_space_by_id(30)
	_assert(not space.is_empty(), "test fixture expects space id 30 to exist in board.json")

	gs._apply_travel_cost(space)

	_assert(int(gs.player.get("hp", 0)) == 1, "exhaustion defeat should leave hp at 1 (got %d)" % int(gs.player.get("hp", 0)))
	_assert(int(gs.player.get("position", -1)) == int(gs.board_data.get("start_id", 0)), "exhaustion defeat should send the player back to start_id")
	gs.queue_free()


func _test_load_game_repairs_missing_fields() -> void:
	var gs := _new_game_state()
	gs.player.erase("gallery")
	gs.player.erase("position")
	gs._ensure_player_route_fields()
	_assert(gs.player.get("gallery") is Array, "missing gallery field should be repaired to an empty array")
	_assert(int(gs.player.get("position", -1)) == int(gs.board_data.get("start_id", 0)), "missing position field should be repaired to start_id")
	gs.queue_free()
