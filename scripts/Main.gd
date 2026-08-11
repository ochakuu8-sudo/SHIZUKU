extends Control

const UI_FONT := preload("res://assets/fonts/NotoSansCJKjp-Regular.otf")
const BOARD_MAP_SCRIPT := preload("res://scripts/BoardMap.gd")
const MAP_NODE_SIZE := Vector2(104, 62)

const SPACE_COLORS := {
	"start": Color("#4f9470"),
	"fork": Color("#7a7284"),
	"train": Color("#5572a8"),
	"event": Color("#8d65b7"),
	"encounter": Color("#b05757"),
	"rest": Color("#5c95a1"),
	"shop": Color("#a9864e"),
	"boss": Color("#bd5b83"),
	"defeat": Color("#7d334c"),
	"empty": Color("#252a34")
}

var board_buttons: Array[Button] = []
var board_map
var board_scroll: ScrollContainer
var main_layout: GridContainer
var map_panel: PanelContainer
var hud_panel: VBoxContainer
var last_centered_position := -1
var map_dragging := false

var location_label: Label
var route_stage_label: Label
var meta_label: Label
var gold_label: Label
var hp_bar: ProgressBar
var stamina_bar: ProgressBar
var stat_labels: Dictionary = {}
var narration_label: RichTextLabel

var event_overlay: PanelContainer
var event_dialog: PanelContainer
var event_title: Label
var event_body: RichTextLabel
var event_image: TextureRect
var choice_box: VBoxContainer
var event_placeholder_cache: Dictionary = {}

var action_panel: PanelContainer
var battle_panel: PanelContainer
var battle_title: Label
var battle_body: Label
var route_panel: PanelContainer
var route_status: Label
var route_box: VBoxContainer
var narration_panel: PanelContainer
var orientation_overlay: PanelContainer
var roll_button: Button
var adult_check: CheckBox
var game_state


func _ready() -> void:
	game_state = get_node("/root/GameState")
	game_state.changed.connect(_render)
	game_state.event_requested.connect(_show_event)
	_apply_ui_theme()
	_build_ui()
	_apply_responsive_layout()
	_render()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and main_layout != null:
		_apply_responsive_layout()


func _apply_ui_theme() -> void:
	var app_theme := Theme.new()
	app_theme.default_font = UI_FONT
	app_theme.default_font_size = 16
	theme = app_theme


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("#10141c")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var page := MarginContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("margin_left", 12)
	page.add_theme_constant_override("margin_top", 10)
	page.add_theme_constant_override("margin_right", 12)
	page.add_theme_constant_override("margin_bottom", 10)
	add_child(page)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	page.add_child(root)

	root.add_child(_build_top_bar())

	main_layout = GridContainer.new()
	main_layout.columns = 2
	main_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_layout.add_theme_constant_override("h_separation", 12)
	main_layout.add_theme_constant_override("v_separation", 8)
	root.add_child(main_layout)

	main_layout.add_child(_build_map_panel())
	main_layout.add_child(_build_hud_panel())

	_build_event_overlay()
	_build_orientation_overlay()


func _build_top_bar() -> Control:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)

	var title := Label.new()
	title.text = "SHIZUKU"
	title.add_theme_font_size_override("font_size", 24)
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "ROUTE TRAINING RPG"
	subtitle.modulate = Color(1, 1, 1, 0.48)
	subtitle.add_theme_font_size_override("font_size", 11)
	title_box.add_child(subtitle)

	adult_check = CheckBox.new()
	adult_check.text = "敗北18+"
	adult_check.tooltip_text = "敗北時の成人向け差し替え枠を有効にします。素材はdata/events.jsonで差し替えます。"
	adult_check.toggled.connect(_on_adult_toggled)
	header.add_child(adult_check)

	var new_button := _make_utility_button("New")
	new_button.tooltip_text = "新規ゲーム"
	new_button.pressed.connect(func() -> void:
		last_centered_position = -1
		game_state.new_game()
	)
	header.add_child(new_button)

	var save_button := _make_utility_button("Save")
	save_button.pressed.connect(game_state.save_game)
	header.add_child(save_button)

	var load_button := _make_utility_button("Load")
	load_button.pressed.connect(func() -> void:
		last_centered_position = -1
		game_state.load_game()
	)
	header.add_child(load_button)
	return header


func _build_map_panel() -> Control:
	map_panel = PanelContainer.new()
	map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_panel.add_theme_stylebox_override("panel", _panel_style(Color("#161d28"), Color("#344052"), 1, 10))

	var board_margin := MarginContainer.new()
	board_margin.add_theme_constant_override("margin_left", 12)
	board_margin.add_theme_constant_override("margin_top", 12)
	board_margin.add_theme_constant_override("margin_right", 12)
	board_margin.add_theme_constant_override("margin_bottom", 12)
	map_panel.add_child(board_margin)

	board_scroll = ScrollContainer.new()
	board_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_scroll.follow_focus = false
	board_scroll.gui_input.connect(_on_map_pan_input)
	board_scroll.get_h_scroll_bar().modulate = Color(1, 1, 1, 0.18)
	board_scroll.get_v_scroll_bar().modulate = Color(1, 1, 1, 0.18)
	board_margin.add_child(board_scroll)

	board_map = BOARD_MAP_SCRIPT.new()
	board_map.configure(game_state.board_data)
	board_map.mouse_filter = Control.MOUSE_FILTER_PASS
	board_map.gui_input.connect(_on_map_pan_input)
	board_scroll.add_child(board_map)

	board_buttons.clear()
	for space in game_state.get_spaces():
		var button := _make_map_node_button(space)
		button.position = board_map.get_space_position(space)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		board_map.add_child(button)
		board_buttons.append(button)
	return map_panel


func _build_hud_panel() -> Control:
	hud_panel = VBoxContainer.new()
	hud_panel.custom_minimum_size = Vector2(342, 0)
	hud_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hud_panel.add_theme_constant_override("separation", 8)

	hud_panel.add_child(_build_status_card())
	hud_panel.add_child(_build_action_card())
	hud_panel.add_child(_build_route_card())
	hud_panel.add_child(_build_battle_card())
	hud_panel.add_child(_build_narration_card())
	return hud_panel


func _build_status_card() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 136)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#1b2431"), Color("#39475c"), 1, 10))

	var margin := _panel_margin(panel, 9)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	box.add_child(top)

	location_label = Label.new()
	location_label.text = "START"
	location_label.add_theme_font_size_override("font_size", 20)
	location_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(location_label)

	gold_label = Label.new()
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gold_label.add_theme_font_size_override("font_size", 17)
	top.add_child(gold_label)

	route_stage_label = Label.new()
	route_stage_label.modulate = Color(1, 1, 1, 0.58)
	route_stage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(route_stage_label)

	meta_label = Label.new()
	meta_label.modulate = Color("#f0c766")
	box.add_child(meta_label)

	hp_bar = _make_bar(Color("#d76f57"))
	box.add_child(_make_labeled_bar("HP", hp_bar))
	stamina_bar = _make_bar(Color("#63a7b4"))
	box.add_child(_make_labeled_bar("ST", stamina_bar))

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 6)
	box.add_child(stats)
	stats.add_child(_make_stat_chip("str", "筋力", Color("#5572a8")))
	stats.add_child(_make_stat_chip("charm", "魅力", Color("#8d65b7")))
	stats.add_child(_make_stat_chip("mind", "知性", Color("#5c95a1")))
	stats.add_child(_make_stat_chip("resolve", "覚悟", Color("#b88a56")))
	return panel


func _build_action_card() -> Control:
	action_panel = PanelContainer.new()
	action_panel.add_theme_stylebox_override("panel", _panel_style(Color("#18202a"), Color("#354052"), 1, 10))

	var margin := _panel_margin(action_panel, 8)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	roll_button = _make_button("サイコロを振る", Color("#d77555"), true)
	roll_button.custom_minimum_size = Vector2(0, 44)
	roll_button.add_theme_font_size_override("font_size", 19)
	roll_button.pressed.connect(game_state.roll_dice)
	box.add_child(roll_button)

	var rest_button := _make_button("休息", Color("#5c95a1"))
	rest_button.pressed.connect(game_state.rest)
	box.add_child(rest_button)

	var train_title := Label.new()
	train_title.text = "鍛錬"
	train_title.modulate = Color(1, 1, 1, 0.56)
	train_title.add_theme_font_size_override("font_size", 12)
	box.add_child(train_title)

	var train_row := HBoxContainer.new()
	train_row.add_theme_constant_override("separation", 6)
	box.add_child(train_row)

	var str_button := _make_button("筋力", Color("#5572a8"))
	str_button.pressed.connect(func() -> void: game_state.manual_train("str"))
	train_row.add_child(str_button)

	var charm_button := _make_button("魅力", Color("#8d65b7"))
	charm_button.pressed.connect(func() -> void: game_state.manual_train("charm"))
	train_row.add_child(charm_button)

	var mind_button := _make_button("知性", Color("#5c95a1"))
	mind_button.pressed.connect(func() -> void: game_state.manual_train("mind"))
	train_row.add_child(mind_button)
	return action_panel


func _build_route_card() -> Control:
	route_panel = PanelContainer.new()
	route_panel.add_theme_stylebox_override("panel", _panel_style(Color("#1d2830"), Color("#465767"), 1, 10))

	var margin := _panel_margin(route_panel, 8)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	var title := Label.new()
	title.text = "ルート選択"
	title.add_theme_font_size_override("font_size", 16)
	box.add_child(title)

	route_status = Label.new()
	route_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	route_status.modulate = Color(1, 1, 1, 0.68)
	box.add_child(route_status)

	route_box = VBoxContainer.new()
	route_box.add_theme_constant_override("separation", 6)
	box.add_child(route_box)
	return route_panel


func _build_battle_card() -> Control:
	battle_panel = PanelContainer.new()
	battle_panel.add_theme_stylebox_override("panel", _panel_style(Color("#2a1c22"), Color("#684050"), 1, 10))

	var margin := _panel_margin(battle_panel, 10)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	battle_title = Label.new()
	battle_title.add_theme_font_size_override("font_size", 18)
	box.add_child(battle_title)

	battle_body = Label.new()
	battle_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(battle_body)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)

	var attack_button := _make_button("攻撃", Color("#b05757"))
	attack_button.pressed.connect(game_state.battle_attack)
	row.add_child(attack_button)

	var skill_button := _make_button("スキル", Color("#8d65b7"))
	skill_button.pressed.connect(game_state.battle_skill)
	row.add_child(skill_button)

	var guard_button := _make_button("防御", Color("#5572a8"))
	guard_button.pressed.connect(game_state.battle_guard)
	row.add_child(guard_button)

	var flee_button := _make_button("離脱", Color("#394050"))
	flee_button.pressed.connect(game_state.battle_flee)
	row.add_child(flee_button)
	return battle_panel


func _build_narration_card() -> Control:
	narration_panel = PanelContainer.new()
	narration_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	narration_panel.add_theme_stylebox_override("panel", _panel_style(Color("#171e29"), Color("#303b4c"), 1, 10))

	var margin := _panel_margin(narration_panel, 8)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	var title := Label.new()
	title.text = "ログ"
	title.modulate = Color(1, 1, 1, 0.56)
	title.add_theme_font_size_override("font_size", 13)
	box.add_child(title)

	narration_label = RichTextLabel.new()
	narration_label.bbcode_enabled = false
	narration_label.scroll_active = false
	narration_label.fit_content = true
	narration_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(narration_label)
	return narration_panel


func _render() -> void:
	var p: Dictionary = game_state.player
	var stats: Dictionary = p.get("stats", {})
	var current_space: Dictionary = game_state.get_current_space()
	var pending_steps := int(p.get("pending_steps", 0))

	location_label.text = String(current_space.get("label", "現在地"))
	route_stage_label.text = String(current_space.get("description", ""))
	meta_label.text = "TURN %02d   残り歩数 %d" % [int(p.get("turn", 0)), pending_steps]
	gold_label.text = "%d G" % int(p.get("gold", 0))
	_set_bar(hp_bar, int(p.get("hp", 0)), int(p.get("max_hp", 100)))
	_set_bar(stamina_bar, int(p.get("stamina", 0)), int(p.get("max_stamina", 10)))
	_set_stat_text("str", "筋力", int(stats.get("str", 0)))
	_set_stat_text("charm", "魅力", int(stats.get("charm", 0)))
	_set_stat_text("mind", "知性", int(stats.get("mind", 0)))
	_set_stat_text("resolve", "覚悟", int(stats.get("resolve", 0)))

	adult_check.set_pressed_no_signal(bool(p.get("adult_content_enabled", false)))
	roll_button.disabled = game_state.is_in_battle() or game_state.needs_route_choice() or pending_steps > 0 or bool(p.get("finished", false))
	roll_button.text = "踏破済み" if bool(p.get("finished", false)) else "ルートを選択" if game_state.needs_route_choice() else "サイコロを振る"

	var position := int(p.get("position", 0))
	var route_options: Array = game_state.get_route_options()
	var option_ids: Array[int] = []
	for raw_option in route_options:
		option_ids.append(int(raw_option.get("id", -1)))
	board_map.set_focus_state(position, option_ids)

	for button in board_buttons:
		var space: Dictionary = game_state.get_space_by_id(int(button.get_meta("space_id")))
		var type_name := String(space.get("type", ""))
		var base_color: Color = SPACE_COLORS.get(type_name, Color("#394050"))
		var is_current := int(space.get("id", -1)) == position
		var is_option := option_ids.has(int(space.get("id", -1)))
		button.tooltip_text = String(space.get("description", ""))
		button.text = "%s%02d\n%s" % ["現在\n" if is_current else "", int(space.get("id", -1)), space.get("label", "")]
		button.add_theme_stylebox_override("normal", _button_style(base_color.lightened(0.18 if is_current else 0.08 if is_option else 0.0), is_current or is_option, 12))
		button.add_theme_stylebox_override("hover", _button_style(base_color.lightened(0.12), is_current or is_option, 12))
		button.add_theme_stylebox_override("pressed", _button_style(base_color.darkened(0.08), is_current or is_option, 12))
	_center_current_space(position)

	if game_state.is_in_battle():
		var enemy: Dictionary = game_state.battle.get("enemy", {})
		battle_panel.visible = true
		battle_title.text = "戦闘: %s" % enemy.get("name", "敵")
		battle_body.text = "敵HP %d/%d / 攻撃力 %d" % [
			int(game_state.battle.get("enemy_hp", 0)),
			int(enemy.get("hp", 0)),
			int(enemy.get("attack", 0))
		]
	else:
		battle_panel.visible = false

	_render_route_choices()
	action_panel.visible = not route_panel.visible and not battle_panel.visible
	narration_panel.visible = not route_panel.visible and not battle_panel.visible
	narration_label.text = "\n".join(game_state.logs.slice(maxi(0, game_state.logs.size() - 5), game_state.logs.size()))


func _render_route_choices() -> void:
	_clear_children(route_box)
	var options: Array = game_state.get_route_options()
	route_panel.visible = options.size() > 0 and not game_state.is_in_battle()
	if not route_panel.visible:
		return

	var pending_steps := int(game_state.player.get("pending_steps", 0))
	route_status.text = "残り%d歩。進む先を選んでください。" % pending_steps if pending_steps > 0 else "次に進むルートを選べます。"

	var selected_id := int(game_state.player.get("selected_next_id", -1))
	for raw_option in options:
		var option: Dictionary = raw_option
		var next_id := int(option.get("id", -1))
		var label := String(option.get("route_label", option.get("label", "ルート")))
		var button := _make_button(label, SPACE_COLORS.get(String(option.get("type", "")), Color("#5572a8")), true)
		button.tooltip_text = String(option.get("description", ""))
		if next_id == selected_id:
			button.text = "選択中: %s" % label
			button.disabled = true
		else:
			button.pressed.connect(func() -> void: game_state.choose_route(next_id))
		route_box.add_child(button)


func _build_event_overlay() -> void:
	event_overlay = PanelContainer.new()
	event_overlay.visible = false
	event_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	event_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	event_overlay.add_theme_stylebox_override("panel", _panel_style(Color(0.05, 0.07, 0.10, 0.86), Color(0, 0, 0, 0), 0, 0))
	add_child(event_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	event_overlay.add_child(center)

	event_dialog = PanelContainer.new()
	event_dialog.custom_minimum_size = Vector2(560, 0)
	event_dialog.add_theme_stylebox_override("panel", _panel_style(Color("#202536"), Color("#59657b"), 1, 12))
	center.add_child(event_dialog)

	var margin := _panel_margin(event_dialog, 16)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	event_title = Label.new()
	event_title.add_theme_font_size_override("font_size", 24)
	box.add_child(event_title)

	event_image = TextureRect.new()
	event_image.custom_minimum_size = Vector2(0, 190)
	event_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	event_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(event_image)

	event_body = RichTextLabel.new()
	event_body.custom_minimum_size = Vector2(0, 120)
	event_body.fit_content = true
	event_body.bbcode_enabled = false
	event_body.scroll_active = false
	box.add_child(event_body)

	choice_box = VBoxContainer.new()
	choice_box.add_theme_constant_override("separation", 7)
	box.add_child(choice_box)


func _show_event(event_data: Dictionary) -> void:
	event_overlay.visible = true
	event_overlay.move_to_front()
	orientation_overlay.move_to_front()
	event_title.text = String(event_data.get("title", "イベント"))
	event_body.text = String(event_data.get("body", ""))
	_clear_children(choice_box)

	var image_path := String(event_data.get("image_path", ""))
	if image_path != "" and ResourceLoader.exists(image_path):
		event_image.texture = load(image_path)
		event_image.visible = true
	else:
		event_image.texture = _make_event_placeholder(event_data)
		event_image.visible = true

	var choices: Array = event_data.get("choices", [])
	if choices.is_empty():
		var close_button := _make_button("閉じる", Color("#394050"))
		close_button.pressed.connect(_hide_event)
		choice_box.add_child(close_button)
		return

	for raw_choice in choices:
		var choice: Dictionary = raw_choice.duplicate(true)
		var button := _make_button(String(choice.get("label", "選択")), Color("#8d65b7"), true)
		button.pressed.connect(func() -> void:
			game_state.apply_choice(choice)
			event_overlay.visible = false
		)
		choice_box.add_child(button)


func _build_orientation_overlay() -> void:
	orientation_overlay = PanelContainer.new()
	orientation_overlay.visible = false
	orientation_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	orientation_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	orientation_overlay.add_theme_stylebox_override("panel", _panel_style(Color("#10141c"), Color("#2c3544"), 1, 0))
	add_child(orientation_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	orientation_overlay.add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(360, 0)
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := Label.new()
	title.text = "横向きにしてください"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	var body := Label.new()
	body.text = "スマホを横持ちにするとプレイできます。"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var portrait := viewport_size.y > viewport_size.x
	main_layout.columns = 1 if portrait else 2
	map_panel.custom_minimum_size = Vector2(0, 390) if portrait else Vector2.ZERO
	map_panel.size_flags_vertical = Control.SIZE_FILL if portrait else Control.SIZE_EXPAND_FILL
	hud_panel.custom_minimum_size = Vector2(0, 0) if portrait else Vector2(342, 0)
	hud_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	event_dialog.custom_minimum_size = Vector2(minf(560.0, maxf(320.0, viewport_size.x - 34.0)), 0)
	event_image.custom_minimum_size = Vector2(0, 150 if portrait else 190)
	orientation_overlay.visible = false
	last_centered_position = -1
	_center_current_space(int(game_state.player.get("position", 0)))


func _hide_event() -> void:
	event_overlay.visible = false


func _on_map_pan_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		_pan_map_by(event.relative)
		accept_event()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		map_dragging = event.pressed
		if map_dragging:
			accept_event()
		return

	if event is InputEventMouseMotion and map_dragging and bool(event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_pan_map_by(event.relative)
		accept_event()


func _pan_map_by(delta: Vector2) -> void:
	var max_horizontal: int = maxi(0, int(board_map.size.x - board_scroll.size.x))
	var max_vertical: int = maxi(0, int(board_map.size.y - board_scroll.size.y))
	board_scroll.scroll_horizontal = clampi(board_scroll.scroll_horizontal - int(delta.x), 0, max_horizontal)
	board_scroll.scroll_vertical = clampi(board_scroll.scroll_vertical - int(delta.y), 0, max_vertical)


func _make_event_placeholder(event_data: Dictionary) -> Texture2D:
	var key := String(event_data.get("space_type", event_data.get("category", "event")))
	if event_placeholder_cache.has(key):
		return event_placeholder_cache[key]

	var base: Color = SPACE_COLORS.get(key, SPACE_COLORS.get("event", Color("#8d65b7")))
	var image := Image.create(960, 360, false, Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		var vertical_t := float(y) / float(image.get_height() - 1)
		for x in range(image.get_width()):
			var horizontal_t := float(x) / float(image.get_width() - 1)
			var glow: float = maxf(0.0, 1.0 - Vector2(horizontal_t - 0.36, vertical_t - 0.42).length() * 2.4)
			var color: Color = Color("#10141c").lerp(base.darkened(0.12), 0.42 + glow * 0.34)
			color = color.lerp(Color("#f2d06b"), maxf(0.0, 0.16 - absf(vertical_t - 0.72)) * 0.42)
			image.set_pixel(x, y, color)

	var seed: int = absi(hash(key))
	for i in range(18):
		var cx := 52 + int((seed + i * 127) % 860)
		var cy := 42 + int((seed / maxi(1, i + 1) + i * 67) % 260)
		var radius := 2 + int((seed + i * 13) % 5)
		_draw_placeholder_diamond(image, Vector2i(cx, cy), radius, base.lightened(0.34))

	var texture: ImageTexture = ImageTexture.create_from_image(image)
	event_placeholder_cache[key] = texture
	return texture


func _draw_placeholder_diamond(image: Image, center: Vector2i, radius: int, color: Color) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		if y < 0 or y >= image.get_height():
			continue
		for x in range(center.x - radius, center.x + radius + 1):
			if x < 0 or x >= image.get_width():
				continue
			var distance: int = absi(x - center.x) + absi(y - center.y)
			if distance <= radius:
				var alpha: float = 0.18 * (1.0 - float(distance) / float(radius + 1))
				image.set_pixel(x, y, image.get_pixel(x, y).lerp(color, alpha))


func _on_adult_toggled(enabled: bool) -> void:
	game_state.set_adult_content_enabled(enabled)


func _center_current_space(position: int) -> void:
	if position == last_centered_position:
		return
	last_centered_position = position
	var space: Dictionary = game_state.get_space_by_id(position)
	if space.is_empty():
		return
	call_deferred("_apply_map_center", board_map.get_space_center(space))


func _apply_map_center(center: Vector2) -> void:
	var view_size := board_scroll.size
	board_scroll.scroll_horizontal = maxi(0, int(center.x - view_size.x * 0.42))
	board_scroll.scroll_vertical = maxi(0, int(center.y - view_size.y * 0.58))


func _set_bar(bar: ProgressBar, value: int, max_value: int) -> void:
	bar.max_value = max(1, max_value)
	bar.value = clamp(value, 0, max_value)


func _set_stat_text(key: String, title: String, value: int) -> void:
	if stat_labels.has(key):
		stat_labels[key].text = "%s\n%d" % [title, value]


func _panel_margin(parent: Control, size: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", size)
	margin.add_theme_constant_override("margin_top", size)
	margin.add_theme_constant_override("margin_right", size)
	margin.add_theme_constant_override("margin_bottom", size)
	parent.add_child(margin)
	return margin


func _make_labeled_bar(label_text: String, bar: ProgressBar) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(28, 0)
	label.modulate = Color(1, 1, 1, 0.62)
	row.add_child(label)
	row.add_child(bar)
	return row


func _make_bar(fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _bar_style(Color("#111721"), 7))
	bar.add_theme_stylebox_override("fill", _bar_style(fill_color, 7))
	return bar


func _make_stat_chip(key: String, title: String, color: Color) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(color.darkened(0.25), color.lightened(0.08), 1, 8))
	var margin := _panel_margin(panel, 6)
	var label := Label.new()
	label.text = "%s\n0" % title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	margin.add_child(label)
	stat_labels[key] = label
	return panel


func _make_map_node_button(space: Dictionary) -> Button:
	var type_name := String(space.get("type", ""))
	var color: Color = SPACE_COLORS.get(type_name, Color("#394050"))
	var button := Button.new()
	button.text = "%02d\n%s" % [int(space.get("id", -1)), space.get("label", "")]
	button.custom_minimum_size = MAP_NODE_SIZE
	button.size = MAP_NODE_SIZE
	button.set_meta("space_id", int(space.get("id", -1)))
	button.tooltip_text = String(space.get("description", ""))
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_stylebox_override("normal", _button_style(color, false, 12))
	button.add_theme_stylebox_override("hover", _button_style(color.lightened(0.08), false, 12))
	button.add_theme_stylebox_override("pressed", _button_style(color.darkened(0.08), false, 12))
	return button


func _make_utility_button(text: String) -> Button:
	var button := _make_button(text, Color("#303847"))
	button.custom_minimum_size = Vector2(64, 34)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	return button


func _make_button(text: String, color: Color, emphasized: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(72, 40)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("normal", _button_style(color, emphasized, 8))
	button.add_theme_stylebox_override("hover", _button_style(color.lightened(0.08), emphasized, 8))
	button.add_theme_stylebox_override("pressed", _button_style(color.darkened(0.08), emphasized, 8))
	button.add_theme_stylebox_override("disabled", _button_style(Color("#2b313c"), false, 8))
	return button


func _panel_style(color: Color, border: Color = Color("#3a4050"), border_width: int = 1, radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


func _button_style(color: Color, highlighted: bool, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("#f2ca69") if highlighted else Color("#5d6879")
	style.border_width_left = 3 if highlighted else 1
	style.border_width_top = 3 if highlighted else 1
	style.border_width_right = 3 if highlighted else 1
	style.border_width_bottom = 3 if highlighted else 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _bar_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
