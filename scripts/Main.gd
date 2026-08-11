extends Control

const UI_FONT := preload("res://assets/fonts/NotoSansCJKjp-Regular.otf")

const SPACE_COLORS := {
	"start": Color("#3d7a59"),
	"fork": Color("#6d6675"),
	"train": Color("#4b638f"),
	"event": Color("#8662a8"),
	"encounter": Color("#9a4f4f"),
	"rest": Color("#4d7d8b"),
	"shop": Color("#8a7148"),
	"boss": Color("#a84e78"),
	"goal": Color("#b8944f"),
	"empty": Color("#252a34")
}

var board_buttons: Array[Button] = []
var stats_label: Label
var log_label: Label
var event_panel: PanelContainer
var event_title: Label
var event_body: RichTextLabel
var event_image: TextureRect
var choice_box: VBoxContainer
var battle_panel: PanelContainer
var battle_title: Label
var battle_body: Label
var route_panel: PanelContainer
var route_status: Label
var route_box: VBoxContainer
var roll_button: Button
var adult_check: CheckBox
var game_state


func _ready() -> void:
	game_state = get_node("/root/GameState")
	game_state.changed.connect(_render)
	game_state.event_requested.connect(_show_event)
	_apply_ui_theme()
	_build_ui()
	_render()


func _apply_ui_theme() -> void:
	var app_theme := Theme.new()
	app_theme.default_font = UI_FONT
	app_theme.default_font_size = 16
	theme = app_theme


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("#171a21")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)

	var title := Label.new()
	title.text = "ルート分岐育成RPG"
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	adult_check = CheckBox.new()
	adult_check.text = "18+素材"
	adult_check.tooltip_text = "成人向けイベント枠を有効にします。素材はdata/events.jsonで差し替えます。"
	adult_check.toggled.connect(_on_adult_toggled)
	header.add_child(adult_check)

	var new_button := _make_button("New", Color("#394050"))
	new_button.tooltip_text = "新規ゲーム"
	new_button.pressed.connect(game_state.new_game)
	header.add_child(new_button)

	var save_button := _make_button("Save", Color("#394050"))
	save_button.pressed.connect(game_state.save_game)
	header.add_child(save_button)

	var load_button := _make_button("Load", Color("#394050"))
	load_button.pressed.connect(game_state.load_game)
	header.add_child(load_button)

	var main_row := HBoxContainer.new()
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_theme_constant_override("separation", 12)
	root.add_child(main_row)

	var board_panel := PanelContainer.new()
	board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_panel.add_theme_stylebox_override("panel", _panel_style(Color("#202632")))
	main_row.add_child(board_panel)

	var board_margin := MarginContainer.new()
	board_margin.add_theme_constant_override("margin_left", 12)
	board_margin.add_theme_constant_override("margin_top", 12)
	board_margin.add_theme_constant_override("margin_right", 12)
	board_margin.add_theme_constant_override("margin_bottom", 12)
	board_panel.add_child(board_margin)

	var board_grid := GridContainer.new()
	board_grid.columns = game_state.get_board_width()
	board_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_grid.add_theme_constant_override("h_separation", 8)
	board_grid.add_theme_constant_override("v_separation", 8)
	board_margin.add_child(board_grid)

	board_buttons.clear()
	for i in range(game_state.get_board_width() * game_state.get_board_height()):
		var button := Button.new()
		button.custom_minimum_size = Vector2(78, 62)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		board_grid.add_child(button)
		board_buttons.append(button)

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(360, 0)
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 10)
	main_row.add_child(side)

	stats_label = Label.new()
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.add_theme_font_size_override("font_size", 16)
	side.add_child(_wrap_panel(stats_label, Color("#202632"), Vector2(0, 122)))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	side.add_child(actions)

	roll_button = _make_button("Roll", Color("#cf6f51"))
	roll_button.pressed.connect(game_state.roll_dice)
	actions.add_child(roll_button)

	var rest_button := _make_button("Rest", Color("#4d7d8b"))
	rest_button.pressed.connect(game_state.rest)
	actions.add_child(rest_button)

	var train_row := HBoxContainer.new()
	train_row.add_theme_constant_override("separation", 8)
	side.add_child(train_row)

	var str_button := _make_button("筋力", Color("#4b638f"))
	str_button.pressed.connect(func() -> void: game_state.manual_train("str"))
	train_row.add_child(str_button)

	var charm_button := _make_button("魅力", Color("#8662a8"))
	charm_button.pressed.connect(func() -> void: game_state.manual_train("charm"))
	train_row.add_child(charm_button)

	var mind_button := _make_button("知性", Color("#4d7d8b"))
	mind_button.pressed.connect(func() -> void: game_state.manual_train("mind"))
	train_row.add_child(mind_button)

	route_panel = PanelContainer.new()
	route_panel.add_theme_stylebox_override("panel", _panel_style(Color("#20292f")))
	side.add_child(route_panel)

	var route_margin := MarginContainer.new()
	route_margin.add_theme_constant_override("margin_left", 10)
	route_margin.add_theme_constant_override("margin_top", 10)
	route_margin.add_theme_constant_override("margin_right", 10)
	route_margin.add_theme_constant_override("margin_bottom", 10)
	route_panel.add_child(route_margin)

	var route_inner := VBoxContainer.new()
	route_inner.add_theme_constant_override("separation", 8)
	route_margin.add_child(route_inner)

	var route_title := Label.new()
	route_title.text = "ルート選択"
	route_title.add_theme_font_size_override("font_size", 18)
	route_inner.add_child(route_title)

	route_status = Label.new()
	route_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	route_inner.add_child(route_status)

	route_box = VBoxContainer.new()
	route_box.add_theme_constant_override("separation", 6)
	route_inner.add_child(route_box)

	battle_panel = PanelContainer.new()
	battle_panel.add_theme_stylebox_override("panel", _panel_style(Color("#2b2025")))
	side.add_child(battle_panel)

	var battle_margin := MarginContainer.new()
	battle_margin.add_theme_constant_override("margin_left", 10)
	battle_margin.add_theme_constant_override("margin_top", 10)
	battle_margin.add_theme_constant_override("margin_right", 10)
	battle_margin.add_theme_constant_override("margin_bottom", 10)
	battle_panel.add_child(battle_margin)

	var battle_box := VBoxContainer.new()
	battle_box.add_theme_constant_override("separation", 8)
	battle_margin.add_child(battle_box)

	battle_title = Label.new()
	battle_title.add_theme_font_size_override("font_size", 18)
	battle_box.add_child(battle_title)

	battle_body = Label.new()
	battle_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battle_box.add_child(battle_body)

	var battle_actions := HBoxContainer.new()
	battle_actions.add_theme_constant_override("separation", 8)
	battle_box.add_child(battle_actions)

	var attack_button := _make_button("攻撃", Color("#9a4f4f"))
	attack_button.pressed.connect(game_state.battle_attack)
	battle_actions.add_child(attack_button)

	var skill_button := _make_button("スキル", Color("#8662a8"))
	skill_button.pressed.connect(game_state.battle_skill)
	battle_actions.add_child(skill_button)

	var guard_button := _make_button("防御", Color("#4b638f"))
	guard_button.pressed.connect(game_state.battle_guard)
	battle_actions.add_child(guard_button)

	var flee_button := _make_button("離脱", Color("#394050"))
	flee_button.pressed.connect(game_state.battle_flee)
	battle_actions.add_child(flee_button)

	event_panel = PanelContainer.new()
	event_panel.visible = false
	event_panel.add_theme_stylebox_override("panel", _panel_style(Color("#24202e")))
	side.add_child(event_panel)

	var event_margin := MarginContainer.new()
	event_margin.add_theme_constant_override("margin_left", 10)
	event_margin.add_theme_constant_override("margin_top", 10)
	event_margin.add_theme_constant_override("margin_right", 10)
	event_margin.add_theme_constant_override("margin_bottom", 10)
	event_panel.add_child(event_margin)

	var event_box := VBoxContainer.new()
	event_box.add_theme_constant_override("separation", 8)
	event_margin.add_child(event_box)

	event_title = Label.new()
	event_title.add_theme_font_size_override("font_size", 18)
	event_box.add_child(event_title)

	event_image = TextureRect.new()
	event_image.custom_minimum_size = Vector2(0, 150)
	event_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	event_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	event_box.add_child(event_image)

	event_body = RichTextLabel.new()
	event_body.custom_minimum_size = Vector2(0, 110)
	event_body.fit_content = true
	event_body.bbcode_enabled = false
	event_body.scroll_active = false
	event_box.add_child(event_body)

	choice_box = VBoxContainer.new()
	choice_box.add_theme_constant_override("separation", 6)
	event_box.add_child(choice_box)

	log_label = Label.new()
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(_wrap_panel(log_label, Color("#202632"), Vector2(0, 160)))


func _render() -> void:
	var p: Dictionary = game_state.player
	var stats: Dictionary = p.get("stats", {})
	var progress_text := "クリア済み" if bool(p.get("finished", false)) else "残り歩数 %d" % int(p.get("pending_steps", 0))
	stats_label.text = "%s / Turn %d / %s\nHP %d/%d  ST %d/%d  Gold %dG\n筋力 %d  魅力 %d  知性 %d  親密度 %d" % [
		p.get("name", "主人公"),
		int(p.get("turn", 0)),
		progress_text,
		int(p.get("hp", 0)),
		int(p.get("max_hp", 0)),
		int(p.get("stamina", 0)),
		int(p.get("max_stamina", 0)),
		int(p.get("gold", 0)),
		int(stats.get("str", 0)),
		int(stats.get("charm", 0)),
		int(stats.get("mind", 0)),
		int(stats.get("bond", 0))
	]

	adult_check.set_pressed_no_signal(bool(p.get("adult_content_enabled", false)))
	roll_button.disabled = game_state.is_in_battle() or game_state.needs_route_choice() or int(p.get("pending_steps", 0)) > 0 or bool(p.get("finished", false))

	var position := int(p.get("position", 0))
	var width: int = game_state.get_board_width()
	for i in range(board_buttons.size()):
		var cell_x := i % width
		var cell_y := floori(float(i) / float(width))
		var space: Dictionary = game_state.get_space_at_cell(cell_x, cell_y)
		if space.is_empty():
			board_buttons[i].text = ""
			board_buttons[i].tooltip_text = "空きマス"
			board_buttons[i].disabled = true
			board_buttons[i].add_theme_stylebox_override("disabled", _button_style(SPACE_COLORS["empty"], false))
			continue

		var type_name := String(space.get("type", ""))
		var base_color: Color = SPACE_COLORS.get(type_name, Color("#394050"))
		var is_current := int(space.get("id", -1)) == position
		var text_prefix := "現在\n" if is_current else ""
		board_buttons[i].disabled = false
		board_buttons[i].tooltip_text = String(space.get("description", ""))
		board_buttons[i].text = "%s%02d\n%s" % [text_prefix, int(space.get("id", -1)), space.get("label", "")]
		board_buttons[i].add_theme_stylebox_override("normal", _button_style(base_color.lightened(0.16 if is_current else 0.0), is_current))
		board_buttons[i].add_theme_stylebox_override("hover", _button_style(base_color.lightened(0.12), is_current))
		board_buttons[i].add_theme_stylebox_override("pressed", _button_style(base_color.darkened(0.1), is_current))

	if game_state.is_in_battle():
		var enemy: Dictionary = game_state.battle.get("enemy", {})
		battle_panel.visible = true
		battle_title.text = "戦闘: %s" % enemy.get("name", "敵")
		battle_body.text = "敵HP %d/%d\n攻撃力 %d" % [
			int(game_state.battle.get("enemy_hp", 0)),
			int(enemy.get("hp", 0)),
			int(enemy.get("attack", 0))
		]
	else:
		battle_panel.visible = false

	_render_route_choices()
	log_label.text = "\n".join(game_state.logs)


func _render_route_choices() -> void:
	_clear_children(route_box)
	var options: Array = game_state.get_route_options()
	route_panel.visible = options.size() > 0 and not game_state.is_in_battle()
	if not route_panel.visible:
		return

	var pending_steps := int(game_state.player.get("pending_steps", 0))
	if pending_steps > 0:
		route_status.text = "残り%d歩。進む先を選んでください。" % pending_steps
	else:
		route_status.text = "次のサイコロで進むルートを選べます。"

	var selected_id := int(game_state.player.get("selected_next_id", -1))
	for raw_option in options:
		var option: Dictionary = raw_option
		var next_id := int(option.get("id", -1))
		var label := String(option.get("route_label", option.get("label", "ルート")))
		var button := _make_button(label, Color("#4b638f"))
		button.tooltip_text = String(option.get("description", ""))
		if next_id == selected_id:
			button.text = "選択中: %s" % label
			button.disabled = true
		else:
			button.pressed.connect(func() -> void: game_state.choose_route(next_id))
		route_box.add_child(button)


func _show_event(event_data: Dictionary) -> void:
	event_panel.visible = true
	event_title.text = String(event_data.get("title", "イベント"))
	event_body.text = String(event_data.get("body", ""))
	_clear_children(choice_box)

	var image_path := String(event_data.get("image_path", ""))
	if image_path != "" and ResourceLoader.exists(image_path):
		event_image.texture = load(image_path)
		event_image.visible = true
	else:
		event_image.texture = null
		event_image.visible = false

	var choices: Array = event_data.get("choices", [])
	if choices.is_empty():
		var close_button := _make_button("閉じる", Color("#394050"))
		close_button.pressed.connect(_hide_event)
		choice_box.add_child(close_button)
		return

	for raw_choice in choices:
		var choice: Dictionary = raw_choice.duplicate(true)
		var button := _make_button(String(choice.get("label", "選択")), Color("#8662a8"))
		button.pressed.connect(func() -> void:
			game_state.apply_choice(choice)
			event_panel.visible = false
		)
		choice_box.add_child(button)


func _on_adult_toggled(enabled: bool) -> void:
	game_state.set_adult_content_enabled(enabled)


func _hide_event() -> void:
	event_panel.visible = false


func _wrap_panel(content: Control, color: Color, min_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(color))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	margin.add_child(content)
	return panel


func _make_button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(72, 38)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("normal", _button_style(color, false))
	button.add_theme_stylebox_override("hover", _button_style(color.lightened(0.08), false))
	button.add_theme_stylebox_override("pressed", _button_style(color.darkened(0.08), false))
	button.add_theme_stylebox_override("disabled", _button_style(Color("#2d313b"), false))
	return button


func _panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("#3a4050")
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


func _button_style(color: Color, highlighted: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("#f1c453") if highlighted else Color("#596173")
	style.border_width_left = 3 if highlighted else 1
	style.border_width_top = 3 if highlighted else 1
	style.border_width_right = 3 if highlighted else 1
	style.border_width_bottom = 3 if highlighted else 1
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

