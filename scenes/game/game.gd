extends Node

enum State { DIALOGUE, BATTLE, LOSE, RESULT }

const CHAR_IDS := ["reimu", "marisa", "sakuya", "reisen", "sanae", "youmu"]
const GALLERY_SCENE := preload("res://scenes/gallery/gallery.tscn")

@onready var background: TextureRect = $Background
@onready var bgm_player: AudioStreamPlayer = $BGMPlayer
@onready var battle_layer: CanvasLayer = $BattleLayer
@onready var enemy_sprite: TextureRect = $BattleLayer/EnemySprite
@onready var enemy_hp_bar: ProgressBar = $BattleLayer/EnemyHPBar
@onready var enemy_hp_label: Label = $BattleLayer/EnemyHPLabel
@onready var enemy_hp_value_label: Label = $BattleLayer/EnemyHPValueLabel
@onready var player_hp_bar: ProgressBar = $BattleLayer/PlayerHPBar
@onready var player_hp_label: Label = $BattleLayer/PlayerHPLabel
@onready var player_hp_value_label: Label = $BattleLayer/PlayerHPValueLabel
@onready var stage_label: Label = $BattleLayer/StageLabel
@onready var phase_label: Label = $BattleLayer/PhaseLabel
@onready var coin_label: Label = $BattleLayer/CoinLabel
@onready var player_sd_sprite: TextureRect = $BattleLayer/PlayerSDSprite
@onready var player_level_label: Label = $BattleLayer/PlayerLevelLabel
@onready var player_xp_bar: ProgressBar = $BattleLayer/PlayerXPBar
@onready var tap_button: Button = $BattleLayer/TapButton
@onready var dialogue_layer = $DialogueLayer
@onready var lose_layer = $LoseLayer
@onready var result_layer = $ResultLayer
@onready var option_wheel = $OptionWheel

var player_data: CharacterData
var all_chars: Array[CharacterData] = []
var enemy_list: Array[CharacterData] = []
var current_enemy: CharacterData
var current_enemy_index: int = 0
var current_phase: int = 1
var max_phase: int = 3

var enemy_hp: float
var enemy_max_hp: float
var enemy_damage: float
var player_hp: float
var player_max_hp: float
var tap_damage: float
var battle_active: bool = false
var attack_timer: float = 0.0
const ENEMY_ATTACK_INTERVAL: float = 2.0
const TAP_DAMAGE: float = 10.0
const ENEMY_DAMAGE: float = 10.0
const XP_PER_TAP: int = 1
const ENEMY_HP_GROWTH_PER_STAGE: float = 0.3
const ENEMY_ATK_GROWTH_PER_STAGE: float = 0.2
const COIN_PER_TAP: int = 1
const COIN_PER_FORM: int = 10
const COIN_STAGE_CLEAR_BONUS: int = 30

var _state: State = State.DIALOGUE
var _last_stage_enemy: CharacterData = null
# ステージ開始時点でクリア済みだったか(初回クリア時の勝利会話まで飛ばさないため)
var _stage_was_cleared: bool = false

func _ready() -> void:
	_load_characters()
	dialogue_layer.visible = false
	battle_layer.visible = false
	lose_layer.visible = false
	result_layer.visible = false

	tap_button.pressed.connect(_on_tap_enemy)
	lose_layer.retry_requested.connect(_on_retry)
	lose_layer.title_requested.connect(_on_title)
	result_layer.next_requested.connect(_on_next_enemy)

	option_wheel.setup(all_chars)
	option_wheel.player_char_selected.connect(_on_player_char_selected)
	option_wheel.opponent_selected.connect(_on_opponent_selected)
	option_wheel.bgm_selected.connect(_on_bgm_selected)
	option_wheel.gallery_requested.connect(_on_gallery_requested)
	option_wheel.title_requested.connect(_on_title_requested)

	start_stage()

func _load_characters() -> void:
	for cid in CHAR_IDS:
		var res := load("res://resources/characters/%s.tres" % cid) as CharacterData
		if res:
			all_chars.append(res)
	if all_chars.is_empty():
		push_error("No character data found")
		return
	player_data = all_chars[0]
	_rebuild_enemy_list()

func _rebuild_enemy_list() -> void:
	enemy_list.clear()
	for c in all_chars:
		if c != player_data:
			enemy_list.append(c)

func start_stage() -> void:
	if current_enemy_index >= enemy_list.size():
		push_warning("All enemies defeated — game complete")
		return
	current_enemy = enemy_list[current_enemy_index]
	current_phase = 1
	max_phase = current_enemy.battle_forms.size()
	_stage_was_cleared = GameState.is_stage_cleared(player_data.char_id, current_enemy.char_id)
	option_wheel.current_player = player_data
	option_wheel.current_opponent = current_enemy
	if _last_stage_enemy != null and current_enemy != _last_stage_enemy \
			and not GameState.bgm_keep_on_opponent_change:
		GameState.selected_bgm_path = ""
	_last_stage_enemy = current_enemy
	apply_stage_visuals(current_enemy)
	start_first_talk()

func apply_stage_visuals(enemy: CharacterData) -> void:
	background.texture = enemy.stage_background
	if GameState.selected_bgm_path != "":
		switch_bgm(load(GameState.selected_bgm_path))
	else:
		switch_bgm(enemy.stage_bgm)

func switch_bgm(new_stream: AudioStream) -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(bgm_player, "volume_db", -80.0, 0.3)
	tween.tween_callback(func():
		bgm_player.stream = new_stream
		bgm_player.volume_db = 0.0
		bgm_player.play()
	)

# 設定が有効で、かつステージ開始時点でクリア済みなら会話を飛ばす
func _skip_talk_enabled() -> bool:
	return GameState.skip_cleared_dialogue and _stage_was_cleared

func start_first_talk() -> void:
	if _skip_talk_enabled():
		start_battle_phase()
		return
	_state = State.DIALOGUE
	battle_active = false
	battle_layer.visible = false
	option_wheel.visible = false
	var csv := "res://assets/dialogues/%s/%s_vs_%s_talk1.csv" % [
		player_data.char_id, player_data.char_id, current_enemy.char_id
	]
	dialogue_layer.left_char_image.texture = player_data.tatie_sprite
	dialogue_layer.right_char_image.texture = current_enemy.tatie_sprite
	dialogue_layer.start_dialogue(csv, player_data, current_enemy, start_battle_phase)

func start_battle_phase() -> void:
	_state = State.BATTLE
	dialogue_layer.visible = false
	battle_layer.visible = true
	option_wheel.visible = true

	var form_index := current_phase - 1
	enemy_sprite.texture = current_enemy.battle_forms[form_index]
	player_sd_sprite.texture = player_data.sd_sprite

	_refresh_player_stats()
	_refresh_enemy_stats()

	enemy_hp = enemy_max_hp
	player_hp = player_max_hp

	enemy_hp_bar.max_value = enemy_max_hp
	enemy_hp_bar.value = enemy_hp
	player_hp_bar.max_value = player_max_hp
	player_hp_bar.value = player_hp
	_update_xp_ui()
	_update_battle_hud()

	attack_timer = 0.0
	battle_active = true

# レベルに応じたプレイヤーの最大HP・タップ攻撃力を反映
func _refresh_player_stats() -> void:
	player_max_hp = player_data.max_hp + GameState.hp_bonus(player_data.char_id)
	tap_damage = TAP_DAMAGE + GameState.atk_bonus(player_data.char_id)

# ステージ(倒した敵の数)に応じて敵のHP・攻撃力を強化
func _refresh_enemy_stats() -> void:
	var stage := float(current_enemy_index)
	enemy_max_hp = current_enemy.max_hp * (1.0 + ENEMY_HP_GROWTH_PER_STAGE * stage)
	enemy_damage = ENEMY_DAMAGE * (1.0 + ENEMY_ATK_GROWTH_PER_STAGE * stage)

func _update_xp_ui() -> void:
	var lvl: int = GameState.get_char_level(player_data.char_id)
	var xp: int = GameState.get_char_xp(player_data.char_id)
	var to_next: int = GameState.xp_to_next(lvl)
	player_level_label.text = "Lv.%d  XP %d/%d" % [lvl, xp, to_next]
	player_xp_bar.max_value = to_next
	player_xp_bar.value = xp

# ステージ・フェーズ・名前・コインなど戦闘HUD全体を更新
func _update_battle_hud() -> void:
	stage_label.text = "Stage %d" % (current_enemy_index + 1)
	phase_label.text = "Phase %d/%d" % [current_phase, max_phase]
	enemy_hp_label.text = current_enemy.display_name
	player_hp_label.text = player_data.display_name
	_update_coin_ui()
	_update_hp_labels()

func _update_coin_ui() -> void:
	coin_label.text = "コイン %d" % GameState.coins

func _update_hp_labels() -> void:
	enemy_hp_value_label.text = "%d / %d" % [roundi(enemy_hp), roundi(enemy_max_hp)]
	player_hp_value_label.text = "%d / %d" % [roundi(player_hp), roundi(player_max_hp)]

func _process(delta: float) -> void:
	if not battle_active:
		return
	attack_timer += delta
	if attack_timer >= ENEMY_ATTACK_INTERVAL:
		attack_timer = 0.0
		_execute_enemy_attack()

func _on_tap_enemy() -> void:
	if not battle_active:
		return
	enemy_hp = maxf(enemy_hp - tap_damage, 0.0)
	enemy_hp_bar.value = enemy_hp
	GameState.add_coins(COIN_PER_TAP)
	var levels_gained: int = GameState.add_xp(player_data.char_id, XP_PER_TAP)
	if levels_gained > 0:
		_on_level_up()
	_update_xp_ui()
	_update_coin_ui()
	_update_hp_labels()
	if enemy_hp <= 0.0:
		_on_enemy_form_defeated()

# レベルアップ: 最大HP・攻撃力を再計算し、増えた分のHPを回復
func _on_level_up() -> void:
	var old_max := player_max_hp
	_refresh_player_stats()
	player_hp = minf(player_hp + (player_max_hp - old_max), player_max_hp)
	player_hp_bar.max_value = player_max_hp
	player_hp_bar.value = player_hp
	_update_hp_labels()
	player_level_label.modulate = Color(1.0, 0.9, 0.2)
	var tween := create_tween()
	tween.tween_property(player_level_label, "modulate", Color.WHITE, 0.6)

func _execute_enemy_attack() -> void:
	player_hp = maxf(player_hp - enemy_damage, 0.0)
	player_hp_bar.value = player_hp
	_update_hp_labels()
	if player_hp <= 0.0:
		_on_player_death()

func _on_enemy_form_defeated() -> void:
	battle_active = false
	# フェーズ撃破報酬。ステージが進むほど敵HP増加率と同じ係数で増える
	var reward := int(COIN_PER_FORM * (1.0 + ENEMY_HP_GROWTH_PER_STAGE * float(current_enemy_index)))
	if current_phase >= max_phase:
		reward += COIN_STAGE_CLEAR_BONUS
		GameState.mark_stage_cleared(player_data.char_id, current_enemy.char_id)
	GameState.add_coins(reward)
	GameState.save_progress()
	_update_coin_ui()
	if current_phase < max_phase:
		current_phase += 1
		_start_middle_talk()
	else:
		_start_win_talk()

func _start_middle_talk() -> void:
	# 形態ごとの会話: 1形態目撃破後はtalk2、2形態目撃破後はtalk3
	var csv := "res://assets/dialogues/%s/%s_vs_%s_talk%d.csv" % [
		player_data.char_id, player_data.char_id, current_enemy.char_id, current_phase
	]
	if _skip_talk_enabled() or not FileAccess.file_exists(csv):
		start_battle_phase()
		return
	_state = State.DIALOGUE
	battle_layer.visible = false
	option_wheel.visible = false
	dialogue_layer.left_char_image.texture = player_data.tatie_sprite
	dialogue_layer.right_char_image.texture = current_enemy.tatie_sprite
	dialogue_layer.start_dialogue(csv, player_data, current_enemy, start_battle_phase)

func _start_win_talk() -> void:
	_state = State.DIALOGUE
	battle_layer.visible = false
	option_wheel.visible = false
	if _skip_talk_enabled():
		_show_result()
		return
	var csv := "res://assets/dialogues/%s/%s_vs_%s_win.csv" % [
		player_data.char_id, player_data.char_id, current_enemy.char_id
	]
	dialogue_layer.left_char_image.texture = player_data.tatie_sprite
	dialogue_layer.right_char_image.texture = current_enemy.tatie_sprite
	dialogue_layer.start_dialogue(csv, player_data, current_enemy, _show_result)

func _show_result() -> void:
	_state = State.RESULT
	var is_final := current_enemy_index >= enemy_list.size() - 1
	result_layer.show_result(is_final)

func _on_next_enemy() -> void:
	current_enemy_index += 1
	start_stage()

func _on_player_death() -> void:
	battle_active = false
	_state = State.LOSE
	battle_layer.visible = false
	option_wheel.visible = false
	if _skip_talk_enabled():
		_show_lose()
		return
	var csv := "res://assets/dialogues/%s/%s_vs_%s_lose.csv" % [
		player_data.char_id, player_data.char_id, current_enemy.char_id
	]
	dialogue_layer.left_char_image.texture = player_data.tatie_sprite
	dialogue_layer.right_char_image.texture = current_enemy.tatie_sprite
	dialogue_layer.start_dialogue(csv, player_data, current_enemy, _show_lose)

func _show_lose() -> void:
	lose_layer.show_lose(player_data.defeated_sprite)

func _on_retry() -> void:
	start_battle_phase()

func _on_title() -> void:
	get_tree().change_scene_to_file("res://scenes/title/title.tscn")

func _on_player_char_selected(c: CharacterData) -> void:
	if c == player_data:
		return
	player_data = c
	_rebuild_enemy_list()
	var idx := enemy_list.find(current_enemy)
	if idx != -1:
		current_enemy_index = idx
	else:
		current_enemy_index = mini(current_enemy_index, enemy_list.size() - 1)
	start_stage()

func _on_opponent_selected(c: CharacterData) -> void:
	if c == current_enemy:
		return
	var idx := enemy_list.find(c)
	if idx == -1:
		return
	current_enemy_index = idx
	start_stage()

func _on_bgm_selected(path: String) -> void:
	if path != "":
		switch_bgm(load(path))
	else:
		switch_bgm(current_enemy.stage_bgm)

# 図鑑をオーバーレイ表示する。閉じるとホイールが開いたままの状態に戻る
func _on_gallery_requested() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var gallery := GALLERY_SCENE.instantiate()
	gallery.overlay_mode = true
	gallery.closed.connect(layer.queue_free)
	layer.add_child(gallery)
	add_child(layer)

func _on_title_requested() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title/title.tscn")
