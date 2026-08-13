extends Node

signal changed
signal event_requested(event_data: Dictionary)
signal log_added(text: String)
signal damage_popup(amount: int, target: String)
signal piece_moved(space_id: int)

const BOARD_GENERATOR := preload("res://scripts/BoardGenerator.gd")
const BOARD_PATH := "res://data/board.json"
const EVENTS_PATH := "res://data/events.json"
const ENEMIES_PATH := "res://data/enemies.json"
const CHARACTERS_PATH := "res://data/characters.json"
const SAVE_PATH := "user://sugoroku_training_rpg_save.json"
const ROUTE_PROFILES := {
	"balanced": {"label": "標準路", "travel": 0, "danger": 0, "train": 0, "gold": 1.0, "battle": 1.0, "rest": 0, "score": 1},
	"safe": {"label": "安全路", "travel": -1, "danger": -1, "train": 0, "gold": 0.9, "battle": 0.9, "rest": 1, "score": 1},
	"training": {"label": "鍛錬路", "travel": 0, "danger": 0, "train": 1, "gold": 1.0, "battle": 1.0, "rest": 0, "score": 2},
	"danger": {"label": "危険路", "travel": 1, "danger": 2, "train": 0, "gold": 1.25, "battle": 1.5, "rest": 0, "score": 3},
	"reward": {"label": "報酬路", "travel": 1, "danger": 0, "train": 0, "gold": 1.5, "battle": 1.1, "rest": 0, "score": 2},
	"recovery": {"label": "休息路", "travel": -1, "danger": -2, "train": 0, "gold": 0.8, "battle": 0.8, "rest": 2, "score": 1}
}

var rng := RandomNumberGenerator.new()
var board_theme: Dictionary = {} # data/board.json: 盤面をランダム生成するための設定
var board_data: Dictionary = {} # 実際にプレイ中の盤面(new_game() のたびに生成し直す)
var events_data: Dictionary = {}
var enemies_data: Dictionary = {}
var characters_data: Dictionary = {}
var player: Dictionary = {}
var battle: Dictionary = {}
var logs: Array[String] = []
var audio_fx: Node
var pending_steps := 0 # サイコロで余ったマス数。分岐でルートを選ぶと続きを消化する。


func _ready() -> void:
	rng.randomize()
	audio_fx = get_node_or_null("/root/AudioFx")
	load_content()
	new_game()


func _play_sfx(id: String) -> void:
	# --script によるテスト実行など、AudioFx オートロードが存在しない文脈でも
	# 安全に無視できるようにする。
	if audio_fx != null:
		audio_fx.play(id)


func load_content() -> void:
	board_theme = _load_json(BOARD_PATH, {})
	events_data = _load_json(EVENTS_PATH, {"events": []})
	enemies_data = _load_json(ENEMIES_PATH, {"enemies": []})
	characters_data = _load_json(CHARACTERS_PATH, {"player": {}})


func _load_json(path: String, fallback: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Missing data file: %s" % path)
		return fallback.duplicate(true)

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Could not open data file: %s" % path)
		return fallback.duplicate(true)

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Invalid JSON dictionary: %s" % path)
		return fallback.duplicate(true)

	return parsed


func new_game(forced_board: Dictionary = {}) -> void:
	# 毎回ランダムに盤面を生成し直す(桃鉄のようなマス目が詰まったボードにするため)。
	# forced_board はテストや特殊用途で決まった盤面を差し込みたい場合に使う。
	board_data = forced_board if not forced_board.is_empty() else BOARD_GENERATOR.generate(board_theme, rng)

	var base: Dictionary = characters_data.get("player", {})
	var stats: Dictionary = base.get("stats", {"str": 5, "charm": 5, "mind": 5, "resolve": 0}).duplicate(true)
	if stats.has("bond") and not stats.has("resolve"):
		stats["resolve"] = int(stats.get("bond", 0))
		stats.erase("bond")

	player = {
		"name": base.get("name", "主人公"),
		"day": 1,
		"turn": 0,
		"position": 0,
		"previous_position": -1,
		"selected_next_id": -1,
		"finished": false,
		"hp": int(base.get("max_hp", 100)),
		"max_hp": int(base.get("max_hp", 100)),
		"stamina": int(base.get("max_stamina", 10)),
		"max_stamina": int(base.get("max_stamina", 10)),
		"gold": int(base.get("gold", 50)),
		"danger": 0,
		"route_score": 0,
		"route_profile": "balanced",
		"stats": stats,
		"adult_content_enabled": false,
		"gallery": [],
		"flags": {}
	}
	player["position"] = int(board_data.get("start_id", 0))
	battle.clear()
	logs.clear()
	pending_steps = 0
	add_log("新しいルート攻略を開始しました。")
	changed.emit()


func get_spaces() -> Array:
	return board_data.get("spaces", [])


func get_board_width() -> int:
	return int(board_data.get("width", 7))


func get_board_height() -> int:
	return int(board_data.get("height", 4))


func get_space_at_cell(x: int, y: int) -> Dictionary:
	for space in get_spaces():
		if int(space.get("x", -1)) == x and int(space.get("y", -1)) == y:
			return space
	return {}


func get_space_by_id(space_id: int) -> Dictionary:
	for space in get_spaces():
		if int(space.get("id", -1)) == space_id:
			return space
	return {}


func get_current_space() -> Dictionary:
	var spaces := get_spaces()
	if spaces.is_empty():
		return {}
	var current_space := get_space_by_id(int(player.get("position", board_data.get("start_id", 0))))
	if current_space.is_empty():
		current_space = get_space_by_id(int(board_data.get("start_id", 0)))
	if current_space.is_empty():
		return spaces[0]
	return current_space


func get_next_ids(space: Dictionary) -> Array:
	var ids: Array = []
	if space.has("next_ids"):
		for raw_id in space.get("next_ids", []):
			ids.append(int(raw_id))
	elif space.has("next_id"):
		ids.append(int(space.get("next_id", -1)))
	return ids


func get_movable_neighbors(space: Dictionary, exclude_id: int = -1) -> Array:
	# next_ids は双方向のつながり(道)を表す。exclude_id には直前にいたマスを
	# 渡すことで、「来た道をそのまま引き返すだけ」を自動歩行の判定から除外する。
	var ids: Array = []
	for raw_id in get_next_ids(space):
		var id := int(raw_id)
		if id != exclude_id:
			ids.append(id)
	return ids


func get_route_options() -> Array:
	if player.is_empty() or is_in_battle() or bool(player.get("finished", false)):
		return []

	var current := get_current_space()
	if String(current.get("type", "")) == "boss":
		return []

	var previous_id := int(player.get("previous_position", -1))
	if get_movable_neighbors(current, previous_id).size() <= 1:
		return []

	# 実際に選択肢として見せる時は、来た道を戻る選択も含めて自由に選べるようにする。
	var options: Array = []
	for next_id in get_next_ids(current):
		var space := get_space_by_id(int(next_id))
		if not space.is_empty():
			options.append(space)
	return options


func needs_route_choice() -> bool:
	if is_in_battle() or bool(player.get("finished", false)):
		return false
	var current := get_current_space()
	if String(current.get("type", "")) == "boss":
		return false
	var previous_id := int(player.get("previous_position", -1))
	return get_movable_neighbors(current, previous_id).size() > 1


func get_pending_steps() -> int:
	return pending_steps


func choose_route(next_id: int) -> void:
	if is_in_battle():
		add_log("戦闘中はルートを選べません。")
		return

	var next_ids := get_next_ids(get_current_space())
	if not next_ids.has(next_id):
		add_log("そのルートには進めません。")
		changed.emit()
		return

	player["selected_next_id"] = next_id
	var next_space := get_space_by_id(next_id)
	_set_route_profile(_get_space_route_profile(next_space))
	add_log("ルート選択: %s" % next_space.get("route_label", next_space.get("label", "次の道")))

	var remaining := maxi(1, pending_steps)
	pending_steps = 0
	var is_final_step := remaining <= 1
	_move_to_space(next_id, is_final_step)
	if not is_final_step and int(player.get("position", -1)) == next_id and not is_in_battle():
		_advance_steps(remaining - 1)


func set_adult_content_enabled(enabled: bool) -> void:
	player["adult_content_enabled"] = enabled
	add_log("敗北18+枠: %s" % ("有効" if enabled else "無効"))
	changed.emit()


func advance_route(steps: int = 1) -> void:
	if is_in_battle():
		add_log("戦闘中は移動できません。")
		return

	if bool(player.get("finished", false)):
		add_log("このルートは踏破済みです。Newで最初から始められます。")
		changed.emit()
		return

	if get_spaces().is_empty():
		add_log("盤面データが空です。")
		return

	if needs_route_choice():
		add_log("先に進むルートを選んでください。")
		changed.emit()
		return

	if String(get_current_space().get("type", "")) == "boss":
		add_log("ここが旅の終点です。")
		changed.emit()
		return

	_advance_steps(maxi(1, steps))


func _advance_steps(steps: int) -> void:
	for i in range(steps):
		if is_in_battle() or bool(player.get("finished", false)):
			return

		var current_space := get_current_space()
		if String(current_space.get("type", "")) == "boss":
			# ボスマスは足を止めて戦闘になるマスなので、ここから先へは進めない。
			return

		var previous_id := int(player.get("previous_position", -1))
		var forward_ids := get_movable_neighbors(current_space, previous_id)

		if forward_ids.is_empty():
			# 行き止まり(来た道以外につながっていない)。踏破完了ではなく、
			# 戻る以外に道が無いので出目を使って来た道を引き返す。
			forward_ids = get_next_ids(current_space)
			if forward_ids.is_empty():
				# 盤面生成上は起こらないはずだが、万一孤立したマスに来た場合の保険。
				add_log("行き止まりです。")
				changed.emit()
				return

		if forward_ids.size() > 1:
			pending_steps = steps - i
			if pending_steps > 1:
				add_log("分岐に到達。ルートを選ぶと残り%dマス分そのまま進みます。" % (pending_steps - 1))
			else:
				add_log("分岐に到達しました。次のルートを選べます。")
			changed.emit()
			return

		var next_id: int = forward_ids[0]
		var is_final_step := i == steps - 1
		_move_to_space(next_id, is_final_step)
		if int(player.get("position", -1)) != next_id:
			# 疲労などで途中送還された場合、残りの出目は消化しない。
			return


func manual_train(stat: String) -> void:
	if is_in_battle():
		add_log("戦闘中はトレーニングできません。")
		return
	_train_stat(stat, 3, 2)
	changed.emit()


func rest() -> void:
	if is_in_battle():
		add_log("戦闘中は休息できません。")
		return
	_heal(22, 5)
	_adjust_danger(-2)
	add_log("休息して回復しました。")
	changed.emit()


func _move_to_space(next_id: int, resolve_effects: bool = true) -> void:
	var next_space := get_space_by_id(next_id)
	if next_space.is_empty():
		add_log("進行先が見つかりません。")
		changed.emit()
		return

	var previous_id := int(player.get("position", -1))
	player["selected_next_id"] = -1
	player["previous_position"] = previous_id
	player["position"] = next_id
	player["turn"] = int(player.get("turn", 0)) + 1
	add_log("%s に進みました。" % next_space.get("label", "マス"))
	piece_moved.emit(next_id)
	_apply_travel_cost(next_space)
	if int(player.get("position", -1)) != next_id:
		# 疲労で倒れて拠点へ送還された場合、このマスの処理は行わない。
		changed.emit()
		return
	_apply_route_pressure(next_space)

	# サイコロの出目の途中で通過するだけのマスではイベント/戦闘/育成などの
	# マス効果までは発生させない(本来のすごろくで止まった時だけ効果が起きるのと同じ)。
	# ただし分岐点(来た道を除いて2方向以上に進める)、行き止まり、ボスマスは、
	# 出目が余っていても必ずそこで足を止めるので常に解決する。
	var type_name := String(next_space.get("type", ""))
	var forward_count := get_movable_neighbors(next_space, previous_id).size()
	var should_resolve := resolve_effects or type_name == "boss" or forward_count != 1
	if should_resolve:
		_resolve_space(next_space)
	changed.emit()


func _apply_travel_cost(space: Dictionary) -> void:
	var type_name := String(space.get("type", ""))
	if ["start", "rest"].has(type_name):
		return

	var cost := _get_travel_cost(space)
	if cost <= 0:
		add_log("%sなので移動ST消費なし。" % get_active_route_label())
		return

	if int(player.get("stamina", 0)) >= cost:
		_apply_effects({"stamina": -cost})
		add_log("探索でSTを%d消費。" % cost)
		return

	var damage := 6 + cost * 2
	_apply_effects({"hp": -damage})
	_adjust_danger(1)
	add_log("疲労でHPを%d失いました。" % damage)
	_play_sfx("damage")
	damage_popup.emit(damage, "player")
	if int(player.get("hp", 0)) <= 0:
		_handle_defeat({"id": "exhaustion", "name": "疲労困憊"})


func _apply_route_pressure(space: Dictionary) -> void:
	var type_name := String(space.get("type", ""))
	var profile := _get_active_profile()
	var danger_delta := int(profile.get("danger", 0)) + int(space.get("danger_delta", 0))
	if bool(space.get("strong", false)):
		danger_delta += 1
	if type_name == "rest":
		danger_delta -= 2
	elif type_name == "fork":
		danger_delta -= 1
	if danger_delta != 0:
		_adjust_danger(danger_delta)

	var score_gain := maxi(0, int(profile.get("score", 1)) + (1 if bool(space.get("strong", false)) else 0))
	player["route_score"] = int(player.get("route_score", 0)) + score_gain


func _resolve_space(space: Dictionary) -> void:
	match String(space.get("type", "")):
		"start":
			_heal(6, 1)
			add_log("拠点で少し回復しました。")
			_request_space_scene(space, "拠点", "拠点で短く息を整えました。次の一歩へ向けて、HPとスタミナが少し回復します。")
		"fork":
			_set_route_profile("balanced", false)
			add_log("%sに到着。次のルートを選べます。" % space.get("label", "分岐"))
			_request_space_scene(space, "分岐点", "%s。ここから先のルートを選べます。" % String(space.get("description", "道が複数に分かれています。")))
		"train":
			_train_stat(String(space.get("stat", "str")), 2 + _get_profile_int("train", 0), 2)
			_request_space_scene(space, "%sの鍛錬" % String(space.get("label", "鍛錬")), String(space.get("description", "主人公は旅の途中で能力を鍛えました。")))
		"event":
			_request_event(String(space.get("category", "daily")))
		"encounter":
			_request_space_scene(space, "%s" % String(space.get("label", "遭遇")), String(space.get("description", "道中で敵の気配が近づいてきます。")))
			start_encounter(bool(space.get("strong", false)))
		"rest":
			var rest_bonus := _get_profile_int("rest", 0)
			_heal(18 + rest_bonus * 4, 4 + rest_bonus)
			_adjust_danger(-1 - rest_bonus)
			add_log("%sで休みました。" % space.get("label", "休息"))
			_request_space_scene(space, "%sで休息" % String(space.get("label", "休息")), String(space.get("description", "主人公は体勢を立て直しました。")))
		"shop":
			var reward := ceili(float(rng.randi_range(8, 18)) * _get_profile_float("gold", 1.0))
			_apply_effects({"gold": reward})
			add_log("報酬として %d G を得ました。" % reward)
			_request_space_scene(space, "%s" % String(space.get("label", "報酬")), "%s\n%d G を得ました。" % [String(space.get("description", "旅の助けになるものを手に入れました。")), reward])
		"boss":
			_request_space_scene(space, "%s" % String(space.get("label", "試練")), String(space.get("description", "ルートの終点で大きな試練が始まります。")))
			start_boss()
		_:
			add_log("何も起きませんでした。")
			_request_space_scene(space, String(space.get("label", "イベント")), String(space.get("description", "静かな時間が流れました。")))


func _train_stat(stat: String, amount: int, stamina_cost: int) -> void:
	if int(player.get("stamina", 0)) < stamina_cost:
		add_log("スタミナ不足。休息が必要です。")
		return

	_apply_effects({"stamina": -stamina_cost})
	if stat == "all":
		var each_amount := maxi(1, amount - 1)
		_apply_effects({"str": each_amount, "charm": each_amount, "mind": each_amount})
		add_log("総合トレーニングで能力が少し伸びました。")
	else:
		_apply_effects({stat: amount})
		add_log("%s が +%d されました。" % [_stat_label(stat), amount])


func _request_event(category: String) -> void:
	var candidates: Array = []
	for event in events_data.get("events", []):
		if String(event.get("category", "")) != category:
			continue
		if bool(event.get("adult_only", false)) and not bool(player.get("adult_content_enabled", false)):
			continue
		candidates.append(event)

	if candidates.is_empty():
		add_log("イベント候補がありません。")
		return

	var picked: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)].duplicate(true)
	picked["space_type"] = "event"
	if not player["gallery"].has(picked.get("id", "")):
		player["gallery"].append(picked.get("id", ""))
	event_requested.emit(picked)
	add_log("イベント: %s" % picked.get("title", "イベント"))


func _request_space_scene(space: Dictionary, title: String, body: String) -> void:
	var raw_id = space.get("id", "unknown")
	var scene_id := str(raw_id)
	if typeof(raw_id) == TYPE_INT or typeof(raw_id) == TYPE_FLOAT:
		scene_id = str(int(raw_id))

	event_requested.emit({
		"id": "space_%s" % scene_id,
		"category": str(space.get("category", space.get("type", "space"))),
		"space_type": str(space.get("type", "space")),
		"title": title,
		"body": body,
		"image_path": str(space.get("image_path", "")),
		"adult_only": false,
		"choices": []
	})


func _request_defeat_event(enemy: Dictionary) -> void:
	var candidates: Array = []
	for event in events_data.get("events", []):
		if String(event.get("category", "")) != "defeat":
			continue
		if bool(event.get("adult_only", false)) and not bool(player.get("adult_content_enabled", false)):
			continue
		candidates.append(event)

	if candidates.is_empty():
		# defeatカテゴリに再生できるイベントが無い場合でも、敗北の演出自体は必ず表示する。
		var body := "敗北し、拠点まで運ばれました。体勢を立て直して、また前へ進みましょう。"
		if not bool(player.get("adult_content_enabled", false)):
			body += "\n(敗北18+差し替え枠は現在無効です。設定を有効にすると専用の演出が再生されます。)"
		_request_space_scene({"id": "defeat_fallback", "type": "defeat", "category": "defeat"}, "敗北", body)
		add_log("敗北イベント候補がありません。")
		return

	var picked: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)].duplicate(true)
	picked["defeated_by"] = enemy.get("id", "")
	picked["space_type"] = "defeat"
	if not player["gallery"].has(picked.get("id", "")):
		player["gallery"].append(picked.get("id", ""))
	event_requested.emit(picked)
	add_log("敗北イベント: %s" % picked.get("title", "敗北"))


func _handle_defeat(enemy: Dictionary) -> void:
	player["hp"] = 1
	player["gold"] = max(0, int(player.get("gold", 0)) - 10)
	player["position"] = int(board_data.get("start_id", 0))
	player["previous_position"] = -1
	player["danger"] = 0
	player["route_profile"] = "balanced"
	battle.clear()
	add_log("敗北。10Gを失い、拠点で目を覚ましました。")
	_play_sfx("defeat")
	piece_moved.emit(player["position"])
	_request_defeat_event(enemy)


func apply_choice(choice: Dictionary) -> void:
	_apply_effects(choice.get("effects", {}))
	add_log("選択: %s" % choice.get("label", "続ける"))
	changed.emit()


func start_encounter(strong: bool) -> void:
	var enemies: Array = enemies_data.get("enemies", [])
	if enemies.is_empty():
		add_log("敵データがありません。")
		return

	var max_index := enemies.size() - 1
	var low_index := 0
	var high_index := max_index
	if strong:
		# 強敵ルートでは最弱の敵を除いた中から選ぶ。
		low_index = mini(1, max_index)
	else:
		# 通常の遭遇では、最強格(ボス格)の敵は出さない。
		high_index = maxi(0, max_index - 1)
	var enemy: Dictionary = enemies[rng.randi_range(low_index, high_index)]
	_start_battle(enemy)


func start_boss() -> void:
	var enemies: Array = enemies_data.get("enemies", [])
	if enemies.is_empty():
		add_log("敵データがありません。")
		return
	_start_battle(enemies.back())


func _start_battle(enemy: Dictionary) -> void:
	var scaled_enemy := enemy.duplicate(true)
	var danger := int(player.get("danger", 0))
	scaled_enemy["hp"] = int(scaled_enemy.get("hp", 20)) + danger * 2
	scaled_enemy["attack"] = int(scaled_enemy.get("attack", 5)) + floori(float(danger) / 2.0)
	battle = {
		"active": true,
		"enemy": scaled_enemy,
		"enemy_hp": int(scaled_enemy.get("hp", 20)),
		"reward_multiplier": _get_profile_float("battle", 1.0) + float(danger) * 0.04,
		"guard": false
	}
	add_log("%s が現れました。危険度%d" % [scaled_enemy.get("name", "敵"), danger])
	changed.emit()


func is_in_battle() -> bool:
	return bool(battle.get("active", false))


func battle_attack() -> void:
	if not is_in_battle():
		return
	var damage := rng.randi_range(4, 8) + int(player["stats"].get("str", 0))
	_damage_enemy(damage, "攻撃")


func battle_skill() -> void:
	if not is_in_battle():
		return
	if int(player.get("stamina", 0)) < 3:
		add_log("スキルに必要なスタミナが足りません。")
		changed.emit()
		return
	_apply_effects({"stamina": -3})
	var damage := rng.randi_range(8, 13) + int(player["stats"].get("mind", 0)) * 2
	_damage_enemy(damage, "スキル")


func battle_guard() -> void:
	if not is_in_battle():
		return
	battle["guard"] = true
	add_log("身構えました。")
	_enemy_turn()
	changed.emit()


func battle_flee() -> void:
	if not is_in_battle():
		return
	if rng.randf() < 0.7:
		add_log("戦闘から離脱しました。")
		battle.clear()
	else:
		add_log("逃げられませんでした。")
		_adjust_danger(1)
		_enemy_turn()
	changed.emit()


func _damage_enemy(damage: int, action_name: String) -> void:
	battle["enemy_hp"] = max(0, int(battle.get("enemy_hp", 0)) - damage)
	add_log("%sで %d ダメージ。" % [action_name, damage])
	_play_sfx("hit")
	damage_popup.emit(damage, "enemy")
	if int(battle.get("enemy_hp", 0)) <= 0:
		_win_battle()
	else:
		_enemy_turn()
	changed.emit()


func _enemy_turn() -> void:
	if not is_in_battle():
		return

	var enemy: Dictionary = battle.get("enemy", {})
	var raw_damage := int(enemy.get("attack", 5)) + rng.randi_range(0, 4)
	var reduction: int = floori(float(int(player["stats"].get("mind", 0))) / 4.0)
	var damage: int = maxi(1, raw_damage - reduction)
	if bool(battle.get("guard", false)):
		damage = maxi(1, floori(float(damage) / 2.0))
	battle["guard"] = false
	_apply_effects({"hp": -damage})
	add_log("%s の反撃。%d ダメージ。" % [enemy.get("name", "敵"), damage])
	_play_sfx("damage")
	damage_popup.emit(damage, "player")

	if int(player.get("hp", 0)) <= 0:
		_handle_defeat(enemy.duplicate(true))


func _win_battle() -> void:
	var enemy: Dictionary = battle.get("enemy", {})
	var reward_multiplier := float(battle.get("reward_multiplier", 1.0))
	var gold := ceili(float(int(enemy.get("reward_gold", 0))) * reward_multiplier)
	var resolve := int(enemy.get("reward_resolve", 0)) + floori(float(int(player.get("danger", 0))) / 3.0)
	_apply_effects({"gold": gold, "resolve": resolve})
	_adjust_danger(-1)
	add_log("%s に勝利。%d G / 覚悟%d を獲得。" % [enemy.get("name", "敵"), gold, resolve])
	_play_sfx("victory")
	battle.clear()
	var current_space := get_current_space()
	if String(current_space.get("type", "")) == "boss":
		player["finished"] = true
		add_log("ルートを踏破しました。")
		_show_route_clear()


func _show_route_clear() -> void:
	var score := int(player.get("route_score", 0))
	var rank := "C"
	if score >= 70:
		rank = "S"
	elif score >= 50:
		rank = "A"
	elif score >= 30:
		rank = "B"
	event_requested.emit({
		"id": "route_clear",
		"category": "system",
		"space_type": "boss",
		"title": "ルート踏破",
		"body": "%s の育成成果でルートを踏破しました。\n踏破評価: %d (ランク %s)\nHP %d/%d ・ 所持金 %d G" % [
			String(player.get("name", "主人公")),
			score,
			rank,
			int(player.get("hp", 0)),
			int(player.get("max_hp", 100)),
			int(player.get("gold", 0))
		],
		"image_path": "",
		"adult_only": false,
		"choices": []
	})


func _heal(hp_amount: int, stamina_amount: int) -> void:
	_apply_effects({"hp": hp_amount, "stamina": stamina_amount})
	if hp_amount > 0:
		_play_sfx("heal")


func _apply_effects(effects: Dictionary) -> void:
	for key in effects.keys():
		var amount := int(effects[key])
		if player["stats"].has(key):
			player["stats"][key] = max(0, int(player["stats"].get(key, 0)) + amount)
		elif key == "hp":
			player["hp"] = clamp(int(player.get("hp", 0)) + amount, 0, int(player.get("max_hp", 100)))
		elif key == "stamina":
			player["stamina"] = clamp(int(player.get("stamina", 0)) + amount, 0, int(player.get("max_stamina", 10)))
		elif key == "gold":
			player["gold"] = max(0, int(player.get("gold", 0)) + amount)
			if amount > 0:
				_play_sfx("gold")
		elif key == "max_hp":
			player["max_hp"] = max(1, int(player.get("max_hp", 100)) + amount)
		elif key == "max_stamina":
			player["max_stamina"] = max(1, int(player.get("max_stamina", 10)) + amount)


func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		add_log("セーブに失敗しました。")
		return
	# 盤面は起動のたびにランダム生成し直すため、ロード後も同じ盤面に戻れるよう
	# player と一緒に board_data(生成済みの実際の盤面)も保存する。
	file.store_string(JSON.stringify({"player": player, "board": board_data}, "\t"))
	add_log("セーブしました。")
	changed.emit()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		add_log("セーブデータがありません。")
		changed.emit()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		add_log("ロードに失敗しました。")
		changed.emit()
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("player"):
		if typeof(parsed.get("board")) == TYPE_DICTIONARY and not parsed["board"].is_empty():
			board_data = parsed["board"]
		# 盤面情報の無い古いセーブの場合は、現在生成済みの盤面をそのまま使う
		# (_ensure_player_route_fields が position の不整合を start_id に補正する)。
		player = parsed["player"]
		_ensure_player_route_fields()
		battle.clear()
		pending_steps = 0
		add_log("ロードしました。")
	else:
		add_log("セーブデータを読めませんでした。")
	changed.emit()


func _ensure_player_route_fields() -> void:
	if not player.has("stats"):
		player["stats"] = {"str": 5, "charm": 5, "mind": 5, "resolve": 0}
	if player["stats"].has("bond") and not player["stats"].has("resolve"):
		player["stats"]["resolve"] = int(player["stats"].get("bond", 0))
		player["stats"].erase("bond")
	if not player.has("position") or get_space_by_id(int(player.get("position", -1))).is_empty():
		player["position"] = int(board_data.get("start_id", 0))
	if not player.has("previous_position"):
		player["previous_position"] = -1
	if not player.has("selected_next_id"):
		player["selected_next_id"] = -1
	if not player.has("finished"):
		player["finished"] = false
	if not player.has("danger"):
		player["danger"] = 0
	if not player.has("route_score"):
		player["route_score"] = 0
	if not player.has("route_profile") or not ROUTE_PROFILES.has(String(player.get("route_profile", ""))):
		player["route_profile"] = "balanced"
	if not player.has("gallery") or not (player["gallery"] is Array):
		player["gallery"] = []
	if not player.has("adult_content_enabled"):
		player["adult_content_enabled"] = false


func get_gallery_entries() -> Array:
	var seen_ids: Array = player.get("gallery", [])
	var entries: Array = []
	for event in events_data.get("events", []):
		if seen_ids.has(event.get("id", "")):
			entries.append(event)
	return entries


func add_log(text: String) -> void:
	logs.append(text)
	while logs.size() > 10:
		logs.pop_front()
	log_added.emit(text)


func _stat_label(stat: String) -> String:
	match stat:
		"str":
			return "筋力"
		"charm":
			return "魅力"
		"mind":
			return "知性"
		"resolve":
			return "覚悟"
		_:
			return stat


func get_active_route_label() -> String:
	return String(_get_active_profile().get("label", "標準路"))


func get_route_profile_label(profile_id: String) -> String:
	var profile: Dictionary = ROUTE_PROFILES.get(profile_id, ROUTE_PROFILES["balanced"])
	return String(profile.get("label", "標準路"))


func get_space_route_label(space: Dictionary) -> String:
	return get_route_profile_label(_get_space_route_profile(space))


func _get_space_route_profile(space: Dictionary) -> String:
	var profile_id := String(space.get("route_profile", "balanced"))
	if ROUTE_PROFILES.has(profile_id):
		return profile_id
	return "balanced"


func _set_route_profile(profile_id: String, announce: bool = true) -> void:
	if not ROUTE_PROFILES.has(profile_id):
		profile_id = "balanced"
	var before := String(player.get("route_profile", "balanced"))
	player["route_profile"] = profile_id
	if announce and before != profile_id:
		add_log("%sに入りました。" % get_route_profile_label(profile_id))


func _get_active_profile() -> Dictionary:
	var profile_id := String(player.get("route_profile", "balanced"))
	return ROUTE_PROFILES.get(profile_id, ROUTE_PROFILES["balanced"])


func _get_profile_int(key: String, default_value: int) -> int:
	return int(_get_active_profile().get(key, default_value))


func _get_profile_float(key: String, default_value: float) -> float:
	return float(_get_active_profile().get(key, default_value))


func _get_travel_cost(space: Dictionary) -> int:
	var base_cost := int(space.get("travel_cost", 2 if bool(space.get("strong", false)) else 1))
	return maxi(0, base_cost + _get_profile_int("travel", 0))


func _adjust_danger(amount: int) -> void:
	if amount == 0:
		return
	var before := int(player.get("danger", 0))
	var after := clampi(before + amount, 0, 10)
	player["danger"] = after
	if after > before:
		add_log("危険度 +%d  現在 %d" % [after - before, after])
		_play_sfx("danger")
	elif after < before:
		add_log("危険度 -%d  現在 %d" % [before - after, after])
