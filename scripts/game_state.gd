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

# レベル・XPは全キャラ共有
var player_level: int = 1
var player_xp: int = 0

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

# 操作SE(ボタン押下時)。ファイルが無ければ鳴らさない
const UI_SE_PATH_CANDIDATES := [
	"res://assets/sounds/se/ui.ogg",
	"res://assets/sounds/se/ui.mp3",
	"res://assets/sounds/se/ui.wav",
]
# UI操作SEを鳴らさないボタンのグループ名(例: 攻撃タップは専用SEがあるため除外)
const NO_UI_SE_GROUP := "no_ui_se"
var _ui_se_stream: AudioStream
var _ui_se_player: AudioStreamPlayer

func _ready() -> void:
	_ensure_se_bus()
	load_progress()
	apply_volumes()
	_setup_ui_se()

# 操作SEの読み込みと、全シーンのボタン押下への自動配線を用意する
func _setup_ui_se() -> void:
	for path in UI_SE_PATH_CANDIDATES:
		if ResourceLoader.exists(path):
			_ui_se_stream = load(path)
			break
	_ui_se_player = AudioStreamPlayer.new()
	_ui_se_player.bus = SE_BUS_NAME
	add_child(_ui_se_player)
	# 既存・今後生成される全ボタンの pressed に操作SEをつなぐ
	get_tree().node_added.connect(_on_node_added)
	_wire_existing_buttons(get_tree().root)

func _wire_existing_buttons(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_wire_existing_buttons(child)

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		var btn: BaseButton = node
		if btn.is_in_group(NO_UI_SE_GROUP):
			return
		if not btn.pressed.is_connected(play_ui_se):
			btn.pressed.connect(play_ui_se)

func play_ui_se() -> void:
	if _ui_se_stream == null or _ui_se_player == null:
		return
	_ui_se_player.stream = _ui_se_stream
	_ui_se_player.play()

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

func xp_to_next(level: int) -> int:
	return XP_BASE_TO_NEXT + (level - 1) * XP_GROWTH_PER_LEVEL

# 経験値を加算し、上がったレベル数を返す(レベルは全キャラ共有)
func add_xp(amount: int) -> int:
	player_xp += amount
	var gained := 0
	while player_xp >= xp_to_next(player_level):
		player_xp -= xp_to_next(player_level)
		player_level += 1
		gained += 1
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

func hp_bonus() -> float:
	return HP_PER_LEVEL * float(player_level - 1)

func atk_bonus() -> float:
	return ATK_PER_LEVEL * float(player_level - 1)

func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "player_level", player_level)
	cfg.set_value("progress", "player_xp", player_xp)
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
	player_level = cfg.get_value("progress", "player_level", 0)
	player_xp = cfg.get_value("progress", "player_xp", 0)
	if player_level > 0:
		return
	# 旧セーブ(キャラ別レベル)からの移行: 一番高いレベルを共有レベルとして引き継ぐ
	player_level = 1
	if cfg.has_section("levels"):
		for cid in cfg.get_section_keys("levels"):
			var entry: Dictionary = cfg.get_value("levels", cid)
			if entry.get("level", 1) > player_level:
				player_level = entry.get("level", 1)
				player_xp = entry.get("xp", 0)

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
