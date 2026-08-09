extends Node

signal changed
signal event_requested(event_data: Dictionary)
signal log_added(text: String)

const BOARD_PATH := "res://data/board.json"
const EVENTS_PATH := "res://data/events.json"
const ENEMIES_PATH := "res://data/enemies.json"
const CHARACTERS_PATH := "res://data/characters.json"
const SAVE_PATH := "user://sugoroku_training_rpg_save.json"

var rng := RandomNumberGenerator.new()
var board_data: Dictionary = {}
var events_data: Dictionary = {}
var enemies_data: Dictionary = {}
var characters_data: Dictionary = {}
var player: Dictionary = {}
var battle: Dictionary = {}
var last_roll := 0
var logs: Array[String] = []


func _ready() -> void:
	rng.randomize()
	load_content()
	new_game()


func load_content() -> void:
	board_data = _load_json(BOARD_PATH, {"spaces": []})
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


func new_game() -> void:
	var base: Dictionary = characters_data.get("player", {})
	var stats: Dictionary = base.get("stats", {"str": 5, "charm": 5, "mind": 5, "bond": 0}).duplicate(true)

	player = {
		"name": base.get("name", "主人公"),
		"day": 1,
		"turn": 0,
		"position": 0,
		"hp": int(base.get("max_hp", 100)),
		"max_hp": int(base.get("max_hp", 100)),
		"stamina": int(base.get("max_stamina", 10)),
		"max_stamina": int(base.get("max_stamina", 10)),
		"gold": int(base.get("gold", 50)),
		"stats": stats,
		"adult_content_enabled": false,
		"gallery": [],
		"flags": {}
	}
	battle.clear()
	last_roll = 0
	logs.clear()
	add_log("新しい育成を開始しました。")
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


func get_current_space() -> Dictionary:
	var spaces := get_spaces()
	if spaces.is_empty():
		return {}
	return spaces[int(player.get("position", 0)) % spaces.size()]


func set_adult_content_enabled(enabled: bool) -> void:
	player["adult_content_enabled"] = enabled
	add_log("18+素材: %s" % ("有効" if enabled else "無効"))
	changed.emit()


func roll_dice() -> void:
	if is_in_battle():
		add_log("戦闘中はサイコロを振れません。")
		return

	var spaces := get_spaces()
	if spaces.is_empty():
		add_log("盤面データが空です。")
		return

	last_roll = rng.randi_range(1, 6)
	var old_position := int(player.get("position", 0))
	var new_position := old_position
	for _i in range(last_roll):
		new_position += 1
		if new_position >= spaces.size():
			new_position = 0
			_pass_start()

	player["position"] = new_position
	player["turn"] = int(player.get("turn", 0)) + 1
	add_log("サイコロ: %d / %s に移動。" % [last_roll, get_current_space().get("label", "マス")])
	_resolve_space(get_current_space())
	changed.emit()


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
	add_log("休息して回復しました。")
	changed.emit()


func _pass_start() -> void:
	player["day"] = int(player.get("day", 1)) + 1
	_heal(10, 2)
	add_log("STARTを通過。Day %d になりました。" % int(player.get("day", 1)))


func _resolve_space(space: Dictionary) -> void:
	match String(space.get("type", "")):
		"start":
			_heal(6, 1)
			add_log("拠点で少し回復しました。")
		"train":
			_train_stat(String(space.get("stat", "str")), 2, 2)
		"event":
			_request_event(String(space.get("category", "daily")))
		"encounter":
			start_encounter(false)
		"rest":
			_heal(18, 4)
			add_log("%sで休みました。" % space.get("label", "休息"))
		"shop":
			var reward := rng.randi_range(8, 18)
			_apply_effects({"gold": reward})
			add_log("報酬として %d G を得ました。" % reward)
		"boss":
			start_boss()
		_:
			add_log("何も起きませんでした。")


func _train_stat(stat: String, amount: int, stamina_cost: int) -> void:
	if int(player.get("stamina", 0)) < stamina_cost:
		add_log("スタミナ不足。休息が必要です。")
		return

	_apply_effects({"stamina": -stamina_cost})
	if stat == "all":
		_apply_effects({"str": 1, "charm": 1, "mind": 1})
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
		if category == "adult":
			event_requested.emit({
				"id": "adult_disabled",
				"category": "system",
				"title": "18+素材は無効です",
				"body": "成人向けイベント枠に止まりました。設定を有効にすると、この枠であなたの用意した文章と画像を再生できます。",
				"image_path": "",
				"adult_only": false,
				"choices": [{"label": "閉じる", "effects": {"mind": 1}}]
			})
		else:
			add_log("イベント候補がありません。")
		return

	var picked: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
	if not player["gallery"].has(picked.get("id", "")):
		player["gallery"].append(picked.get("id", ""))
	event_requested.emit(picked.duplicate(true))
	add_log("イベント: %s" % picked.get("title", "イベント"))


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
	var enemy: Dictionary = enemies[rng.randi_range(0 if not strong else min(1, max_index), max_index)]
	_start_battle(enemy)


func start_boss() -> void:
	var enemies: Array = enemies_data.get("enemies", [])
	if enemies.is_empty():
		add_log("敵データがありません。")
		return
	_start_battle(enemies.back())


func _start_battle(enemy: Dictionary) -> void:
	battle = {
		"active": true,
		"enemy": enemy.duplicate(true),
		"enemy_hp": int(enemy.get("hp", 20)),
		"guard": false
	}
	add_log("%s が現れました。" % enemy.get("name", "敵"))
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
		_enemy_turn()
	changed.emit()


func _damage_enemy(damage: int, action_name: String) -> void:
	battle["enemy_hp"] = max(0, int(battle.get("enemy_hp", 0)) - damage)
	add_log("%sで %d ダメージ。" % [action_name, damage])
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

	if int(player.get("hp", 0)) <= 0:
		player["hp"] = 1
		player["gold"] = max(0, int(player.get("gold", 0)) - 10)
		battle.clear()
		add_log("倒れましたが、拠点に戻って立て直しました。10Gを失いました。")


func _win_battle() -> void:
	var enemy: Dictionary = battle.get("enemy", {})
	var gold := int(enemy.get("reward_gold", 0))
	var bond := int(enemy.get("reward_bond", 0))
	_apply_effects({"gold": gold, "bond": bond})
	add_log("%s に勝利。%d G を獲得。" % [enemy.get("name", "敵"), gold])
	battle.clear()


func _heal(hp_amount: int, stamina_amount: int) -> void:
	_apply_effects({"hp": hp_amount, "stamina": stamina_amount})


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
		elif key == "max_hp":
			player["max_hp"] = max(1, int(player.get("max_hp", 100)) + amount)
		elif key == "max_stamina":
			player["max_stamina"] = max(1, int(player.get("max_stamina", 10)) + amount)


func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		add_log("セーブに失敗しました。")
		return
	file.store_string(JSON.stringify({"player": player}, "\t"))
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
		player = parsed["player"]
		battle.clear()
		add_log("ロードしました。")
	else:
		add_log("セーブデータを読めませんでした。")
	changed.emit()


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
		"bond":
			return "親密度"
		_:
			return stat
