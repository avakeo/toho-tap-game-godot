extends Node

const SAVE_PATH := "user://save.cfg"
const XP_BASE_TO_NEXT := 10
const XP_GROWTH_PER_LEVEL := 5
const HP_PER_LEVEL := 10.0
const ATK_PER_LEVEL := 2.0

var owned_char_ids: Array[String] = ["reimu", "marisa"]
var owned_bgm_paths: Array[String] = []
var selected_bgm_path: String = ""
var bgm_keep_on_opponent_change: bool = true

# char_id -> {"level": int, "xp": int}
var char_levels: Dictionary = {}

var coins: int = 0

# クリア済みステージ。"操作キャラID_vs_敵キャラID" 形式で記録
var cleared_stages: Array = []

# クリア済みステージの会話をスキップするか(設定)
var skip_cleared_dialogue: bool = false

# 前回セッション(続きから再開用)。ステージ開始のたびに自動保存される
var session_player_id: String = ""
var session_enemy_id: String = ""

# ガチャ天井: 未所持キャラを引かずに回した回数
var gacha_pity_count: int = 0

# 音量設定(0-100)
var master_volume: float = 100.0
var se_volume: float = 100.0

const SE_BUS_NAME := "SE"

func _ready() -> void:
	_ensure_se_bus()
	load_progress()
	apply_volumes()

# SE専用バスが無ければ作る(効果音の音量を個別調整するため)
func _ensure_se_bus() -> void:
	if AudioServer.get_bus_index(SE_BUS_NAME) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, SE_BUS_NAME)

func apply_volumes() -> void:
	var master := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(master_volume / 100.0, 0.0001)))
	AudioServer.set_bus_mute(master, master_volume <= 0.0)
	var se := AudioServer.get_bus_index(SE_BUS_NAME)
	if se != -1:
		AudioServer.set_bus_volume_db(se, linear_to_db(maxf(se_volume / 100.0, 0.0001)))
		AudioServer.set_bus_mute(se, se_volume <= 0.0)

func set_session(player_id: String, enemy_id: String) -> void:
	session_player_id = player_id
	session_enemy_id = enemy_id
	save_progress()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_progress()

func get_char_level(char_id: String) -> int:
	if char_levels.has(char_id):
		return char_levels[char_id]["level"]
	return 1

func get_char_xp(char_id: String) -> int:
	if char_levels.has(char_id):
		return char_levels[char_id]["xp"]
	return 0

func xp_to_next(level: int) -> int:
	return XP_BASE_TO_NEXT + (level - 1) * XP_GROWTH_PER_LEVEL

# 経験値を加算し、上がったレベル数を返す
func add_xp(char_id: String, amount: int) -> int:
	var entry: Dictionary = char_levels.get(char_id, {"level": 1, "xp": 0})
	entry["xp"] += amount
	var gained := 0
	while entry["xp"] >= xp_to_next(entry["level"]):
		entry["xp"] -= xp_to_next(entry["level"])
		entry["level"] += 1
		gained += 1
	char_levels[char_id] = entry
	if gained > 0:
		save_progress()
	return gained

# 加算のみ。セーブは呼び出し側の節目(フェーズ撃破・終了時など)で行う
func add_coins(amount: int) -> void:
	coins += amount

func stage_key(player_id: String, enemy_id: String) -> String:
	return "%s_vs_%s" % [player_id, enemy_id]

func mark_stage_cleared(player_id: String, enemy_id: String) -> void:
	var key := stage_key(player_id, enemy_id)
	if not cleared_stages.has(key):
		cleared_stages.append(key)
		save_progress()

func is_stage_cleared(player_id: String, enemy_id: String) -> bool:
	return cleared_stages.has(stage_key(player_id, enemy_id))

func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	save_progress()
	return true

func hp_bonus(char_id: String) -> float:
	return HP_PER_LEVEL * float(get_char_level(char_id) - 1)

func atk_bonus(char_id: String) -> float:
	return ATK_PER_LEVEL * float(get_char_level(char_id) - 1)

func save_progress() -> void:
	var cfg := ConfigFile.new()
	for cid in char_levels:
		cfg.set_value("levels", cid, char_levels[cid])
	cfg.set_value("progress", "coins", coins)
	cfg.set_value("progress", "cleared_stages", cleared_stages)
	cfg.set_value("progress", "owned_char_ids", owned_char_ids)
	cfg.set_value("progress", "owned_bgm_paths", owned_bgm_paths)
	cfg.set_value("progress", "gacha_pity_count", gacha_pity_count)
	cfg.set_value("session", "player_id", session_player_id)
	cfg.set_value("session", "enemy_id", session_enemy_id)
	cfg.set_value("settings", "skip_cleared_dialogue", skip_cleared_dialogue)
	cfg.set_value("settings", "selected_bgm_path", selected_bgm_path)
	cfg.set_value("settings", "bgm_keep_on_opponent_change", bgm_keep_on_opponent_change)
	cfg.set_value("settings", "master_volume", master_volume)
	cfg.set_value("settings", "se_volume", se_volume)
	cfg.save(SAVE_PATH)

func load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	coins = cfg.get_value("progress", "coins", 0)
	cleared_stages = cfg.get_value("progress", "cleared_stages", [])
	gacha_pity_count = cfg.get_value("progress", "gacha_pity_count", 0)
	var saved_chars: Array = cfg.get_value("progress", "owned_char_ids", [])
	for cid in saved_chars:
		if not owned_char_ids.has(cid):
			owned_char_ids.append(cid)
	var saved_bgms: Array = cfg.get_value("progress", "owned_bgm_paths", [])
	for p in saved_bgms:
		if not owned_bgm_paths.has(p):
			owned_bgm_paths.append(p)
	session_player_id = cfg.get_value("session", "player_id", "")
	session_enemy_id = cfg.get_value("session", "enemy_id", "")
	skip_cleared_dialogue = cfg.get_value("settings", "skip_cleared_dialogue", false)
	selected_bgm_path = cfg.get_value("settings", "selected_bgm_path", "")
	if selected_bgm_path != "" and not ResourceLoader.exists(selected_bgm_path):
		selected_bgm_path = ""
	bgm_keep_on_opponent_change = cfg.get_value("settings", "bgm_keep_on_opponent_change", true)
	master_volume = cfg.get_value("settings", "master_volume", 100.0)
	se_volume = cfg.get_value("settings", "se_volume", 100.0)
	if not cfg.has_section("levels"):
		return
	for cid in cfg.get_section_keys("levels"):
		char_levels[cid] = cfg.get_value("levels", cid)

func all_bgm_paths() -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open("res://assets/sounds")
	if dir == null:
		return result
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir():
			var fname := f
			if fname.ends_with(".import"):
				fname = fname.trim_suffix(".import")
			elif fname.ends_with(".remap"):
				fname = fname.trim_suffix(".remap")
			if fname.get_extension() in ["mp3", "ogg", "wav"]:
				var p := "res://assets/sounds/" + fname
				if not result.has(p):
					result.append(p)
		f = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result
