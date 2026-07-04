extends CanvasLayer

signal player_char_selected(char_data: CharacterData)
signal opponent_selected(char_data: CharacterData)
signal bgm_selected(path: String)

const JP_FONT := preload("res://assets/fonts/NotoSansJP-Regular.ttf")

@onready var toggle_button: Button = $ToggleButton
@onready var char_button: Button = $CharButton
@onready var bgm_button: Button = $BGMButton
@onready var volume_button: Button = $VolumeButton
@onready var gacha_button: Button = $GachaButton

@onready var char_panel: Panel = $CharPanel
@onready var player_list: VBoxContainer = $CharPanel/Columns/PlayerColumn/PlayerScroll/PlayerList
@onready var opponent_list: VBoxContainer = $CharPanel/Columns/OpponentColumn/OpponentScroll/OpponentList
@onready var char_close: Button = $CharPanel/CloseButton

@onready var bgm_panel: Panel = $BGMPanel
@onready var bgm_list: VBoxContainer = $BGMPanel/BGMScroll/BGMList
@onready var bgm_close: Button = $BGMPanel/CloseButton
@onready var bgm_choice_panel: Panel = $BGMPanel/ChoicePanel
@onready var bgm_keep_button: Button = $BGMPanel/ChoicePanel/KeepButton
@onready var bgm_reset_button: Button = $BGMPanel/ChoicePanel/ResetButton

@onready var volume_panel: Panel = $VolumePanel
@onready var volume_slider: HSlider = $VolumePanel/VolumeSlider
@onready var volume_close: Button = $VolumePanel/CloseButton

@onready var gacha_panel: Panel = $GachaPanel
@onready var roll_button: Button = $GachaPanel/RollButton
@onready var result_image: TextureRect = $GachaPanel/ResultImage
@onready var result_label: Label = $GachaPanel/ResultLabel
@onready var gacha_close: Button = $GachaPanel/CloseButton

var _chars: Array[CharacterData] = []
var _wheel_open := false
var _pending_bgm_path := ""

var current_player: CharacterData
var current_opponent: CharacterData

func _ready() -> void:
	toggle_button.pressed.connect(_on_toggle)
	char_button.pressed.connect(_on_char_button)
	bgm_button.pressed.connect(_on_bgm_button)
	volume_button.pressed.connect(_open_panel.bind(volume_panel))
	gacha_button.pressed.connect(_open_panel.bind(gacha_panel))
	char_close.pressed.connect(char_panel.hide)
	bgm_close.pressed.connect(bgm_panel.hide)
	volume_close.pressed.connect(volume_panel.hide)
	gacha_close.pressed.connect(gacha_panel.hide)
	roll_button.pressed.connect(_on_roll)
	volume_slider.value_changed.connect(_on_volume_changed)
	bgm_keep_button.pressed.connect(_on_bgm_choice.bind(true))
	bgm_reset_button.pressed.connect(_on_bgm_choice.bind(false))

	var master := AudioServer.get_bus_index("Master")
	volume_slider.set_value_no_signal(db_to_linear(AudioServer.get_bus_volume_db(master)) * 100.0)

	_set_wheel_buttons_visible(false)

func setup(chars: Array[CharacterData]) -> void:
	_chars = chars

func close_wheel() -> void:
	_wheel_open = false
	_set_wheel_buttons_visible(false)
	for p in [char_panel, bgm_panel, volume_panel, gacha_panel]:
		p.hide()
	get_tree().paused = false

func _on_toggle() -> void:
	if _wheel_open:
		close_wheel()
	else:
		_wheel_open = true
		get_tree().paused = true
		_set_wheel_buttons_visible(true)

func _set_wheel_buttons_visible(open: bool) -> void:
	var buttons := [char_button, bgm_button, volume_button, gacha_button]
	for b in buttons:
		b.visible = open
	if not open:
		return
	var tween := create_tween()
	var delay := 0.0
	for b in buttons:
		b.modulate.a = 0.0
		tween.parallel().tween_property(b, "modulate:a", 1.0, 0.15).set_delay(delay)
		delay += 0.05

func _open_panel(panel: Panel) -> void:
	for p in [char_panel, bgm_panel, volume_panel, gacha_panel]:
		p.hide()
	panel.show()

func _on_char_button() -> void:
	_rebuild_char_lists()
	_open_panel(char_panel)

func _on_bgm_button() -> void:
	bgm_choice_panel.hide()
	_rebuild_bgm_list()
	_open_panel(bgm_panel)

func _make_list_button(label: String) -> Button:
	var b := Button.new()
	b.text = label
	b.add_theme_font_override("font", JP_FONT)
	b.add_theme_font_size_override("font_size", 36)
	b.custom_minimum_size = Vector2(0, 84)
	b.clip_text = true
	return b

func _rebuild_char_lists() -> void:
	for child in player_list.get_children():
		child.queue_free()
	for child in opponent_list.get_children():
		child.queue_free()
	for c in _chars:
		if GameState.owned_char_ids.has(c.char_id):
			var pb := _make_list_button(c.display_name + ("（使用中）" if c == current_player else ""))
			pb.disabled = c == current_player
			pb.pressed.connect(_on_player_chosen.bind(c))
			player_list.add_child(pb)
	for c in _chars:
		if c == current_player:
			continue
		var ob := _make_list_button(c.display_name + ("（対戦中）" if c == current_opponent else ""))
		ob.disabled = c == current_opponent
		ob.pressed.connect(_on_opponent_chosen.bind(c))
		opponent_list.add_child(ob)

func _rebuild_bgm_list() -> void:
	for child in bgm_list.get_children():
		child.queue_free()
	var default_btn := _make_list_button("ステージ標準" + ("（選択中）" if GameState.selected_bgm_path == "" else ""))
	default_btn.disabled = GameState.selected_bgm_path == ""
	default_btn.pressed.connect(_on_bgm_chosen.bind(""))
	bgm_list.add_child(default_btn)
	for path in GameState.owned_bgm_paths:
		var bname: String = path.get_file().get_basename()
		var b := _make_list_button(bname + ("（選択中）" if path == GameState.selected_bgm_path else ""))
		b.disabled = path == GameState.selected_bgm_path
		b.pressed.connect(_on_bgm_chosen.bind(path))
		bgm_list.add_child(b)

func _on_player_chosen(c: CharacterData) -> void:
	close_wheel()
	player_char_selected.emit(c)

func _on_opponent_chosen(c: CharacterData) -> void:
	close_wheel()
	opponent_selected.emit(c)

func _on_bgm_chosen(path: String) -> void:
	if path == "":
		GameState.selected_bgm_path = ""
		_rebuild_bgm_list()
		bgm_selected.emit("")
		return
	_pending_bgm_path = path
	bgm_choice_panel.show()

func _on_bgm_choice(keep_on_opponent_change: bool) -> void:
	GameState.selected_bgm_path = _pending_bgm_path
	GameState.bgm_keep_on_opponent_change = keep_on_opponent_change
	bgm_choice_panel.hide()
	_rebuild_bgm_list()
	bgm_selected.emit(_pending_bgm_path)

func _on_volume_changed(value: float) -> void:
	var master := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(value / 100.0, 0.0001)))
	AudioServer.set_bus_mute(master, value <= 0.0)

func _on_roll() -> void:
	var pool: Array[Dictionary] = []
	for c in _chars:
		pool.append({"type": "char", "char": c})
	for p in GameState.all_bgm_paths():
		pool.append({"type": "bgm", "path": p})
	if pool.is_empty():
		return
	var prize: Dictionary = pool.pick_random()
	if prize.type == "char":
		var c: CharacterData = prize.char
		var dup: bool = GameState.owned_char_ids.has(c.char_id)
		if not dup:
			GameState.owned_char_ids.append(c.char_id)
		result_image.texture = c.tatie_sprite
		if dup:
			result_label.text = "【キャラ】%s\n（すでに持っている）" % c.display_name
		else:
			result_label.text = "【キャラ】%s を手に入れた！\nキャラ変更で使えるよ" % c.display_name
	else:
		var path: String = prize.path
		var dup: bool = GameState.owned_bgm_paths.has(path)
		if not dup:
			GameState.owned_bgm_paths.append(path)
		result_image.texture = null
		var bname: String = path.get_file().get_basename()
		if dup:
			result_label.text = "♪【BGM】%s\n（すでに持っている）" % bname
		else:
			result_label.text = "♪【BGM】%s を手に入れた！\nBGM変更で聴けるよ" % bname
