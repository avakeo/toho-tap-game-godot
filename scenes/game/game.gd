extends Node

enum State { DIALOGUE, BATTLE, LOSE, RESULT }

const CHAR_IDS := ["reimu", "marisa", "sakuya", "reisen", "sanae", "youmu"]

@onready var background: TextureRect = $Background
@onready var bgm_player: AudioStreamPlayer = $BGMPlayer
@onready var battle_layer: CanvasLayer = $BattleLayer
@onready var enemy_sprite: TextureRect = $BattleLayer/EnemySprite
@onready var enemy_hp_bar: ProgressBar = $BattleLayer/EnemyHPBar
@onready var player_hp_bar: ProgressBar = $BattleLayer/PlayerHPBar
@onready var tap_button: Button = $BattleLayer/TapButton
@onready var dialogue_layer = $DialogueLayer
@onready var lose_layer = $LoseLayer
@onready var result_layer = $ResultLayer

var player_data: CharacterData
var enemy_list: Array[CharacterData] = []
var current_enemy: CharacterData
var current_enemy_index: int = 0
var current_phase: int = 1
var max_phase: int = 3

var enemy_hp: float
var player_hp: float
var battle_active: bool = false
var attack_timer: float = 0.0
const ENEMY_ATTACK_INTERVAL: float = 2.0
const TAP_DAMAGE: float = 10.0
const ENEMY_DAMAGE: float = 10.0

var _state: State = State.DIALOGUE

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

	start_stage()

func _load_characters() -> void:
	var all_chars: Array[CharacterData] = []
	for cid in CHAR_IDS:
		var res := load("res://resources/characters/%s.tres" % cid) as CharacterData
		if res:
			all_chars.append(res)
	if all_chars.is_empty():
		push_error("No character data found")
		return
	player_data = all_chars[0]
	for i in range(1, all_chars.size()):
		enemy_list.append(all_chars[i])

func start_stage() -> void:
	if current_enemy_index >= enemy_list.size():
		push_warning("All enemies defeated — game complete")
		return
	current_enemy = enemy_list[current_enemy_index]
	current_phase = 1
	max_phase = current_enemy.battle_forms.size()
	apply_stage_visuals(current_enemy)
	start_first_talk()

func apply_stage_visuals(enemy: CharacterData) -> void:
	background.texture = enemy.stage_background
	switch_bgm(enemy.stage_bgm)

func switch_bgm(new_stream: AudioStream) -> void:
	var tween := create_tween()
	tween.tween_property(bgm_player, "volume_db", -80.0, 0.3)
	tween.tween_callback(func():
		bgm_player.stream = new_stream
		bgm_player.volume_db = 0.0
		bgm_player.play()
	)

func start_first_talk() -> void:
	_state = State.DIALOGUE
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

	var form_index := current_phase - 1
	enemy_sprite.texture = current_enemy.battle_forms[form_index]

	enemy_hp = current_enemy.max_hp
	player_hp = player_data.max_hp

	enemy_hp_bar.max_value = current_enemy.max_hp
	enemy_hp_bar.value = enemy_hp
	player_hp_bar.max_value = player_data.max_hp
	player_hp_bar.value = player_hp

	attack_timer = 0.0
	battle_active = true

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
	enemy_hp -= TAP_DAMAGE
	enemy_hp_bar.value = enemy_hp
	if enemy_hp <= 0.0:
		_on_enemy_form_defeated()

func _execute_enemy_attack() -> void:
	player_hp -= ENEMY_DAMAGE
	player_hp_bar.value = player_hp
	if player_hp <= 0.0:
		_on_player_death()

func _on_enemy_form_defeated() -> void:
	battle_active = false
	if current_phase < max_phase:
		current_phase += 1
		_start_middle_talk()
	else:
		_start_win_talk()

func _start_middle_talk() -> void:
	_state = State.DIALOGUE
	battle_layer.visible = false
	var csv := "res://assets/dialogues/%s/%s_vs_%s_talk2.csv" % [
		player_data.char_id, player_data.char_id, current_enemy.char_id
	]
	dialogue_layer.left_char_image.texture = player_data.tatie_sprite
	dialogue_layer.right_char_image.texture = current_enemy.tatie_sprite
	dialogue_layer.start_dialogue(csv, player_data, current_enemy, start_battle_phase)

func _start_win_talk() -> void:
	_state = State.DIALOGUE
	battle_layer.visible = false
	var csv := "res://assets/dialogues/%s/%s_vs_%s_win.csv" % [
		player_data.char_id, player_data.char_id, current_enemy.char_id
	]
	dialogue_layer.left_char_image.texture = player_data.tatie_sprite
	dialogue_layer.right_char_image.texture = current_enemy.tatie_sprite
	dialogue_layer.start_dialogue(csv, player_data, current_enemy, _show_result)

func _show_result() -> void:
	_state = State.RESULT
	result_layer.show_result()

func _on_next_enemy() -> void:
	current_enemy_index += 1
	start_stage()

func _on_player_death() -> void:
	battle_active = false
	_state = State.LOSE
	battle_layer.visible = false
	var csv := "res://assets/dialogues/%s/%s_vs_%s_lose.csv" % [
		player_data.char_id, player_data.char_id, current_enemy.char_id
	]
	dialogue_layer.left_char_image.texture = player_data.tatie_sprite
	dialogue_layer.right_char_image.texture = current_enemy.tatie_sprite
	dialogue_layer.start_dialogue(csv, player_data, current_enemy, _show_lose)

func _show_lose() -> void:
	lose_layer.show_lose(current_enemy.defeated_sprite)

func _on_retry() -> void:
	start_battle_phase()

func _on_title() -> void:
	get_tree().reload_current_scene()
