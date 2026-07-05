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

func _ready() -> void:
	load_progress()

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
	cfg.set_value("settings", "skip_cleared_dialogue", skip_cleared_dialogue)
	cfg.save(SAVE_PATH)

func load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	coins = cfg.get_value("progress", "coins", 0)
	cleared_stages = cfg.get_value("progress", "cleared_stages", [])
	skip_cleared_dialogue = cfg.get_value("settings", "skip_cleared_dialogue", false)
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
