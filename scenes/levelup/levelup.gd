extends CanvasLayer

# レベルアップ時のポップアップ。動画広告を見るとステータス上昇が2倍になる
@onready var stats_label: Label = $StatsLabel
@onready var boost_label: Label = $BoostLabel
@onready var boost_button: Button = $BoostButton
@onready var continue_button: Button = $ContinueButton

# 動画広告を最後まで視聴し、追加ステータスの付与が確定したときに通知
signal boost_requested
# ポップアップが閉じられたときに通知(強化した・しないに関わらず)
signal closed

const AD_PLACEMENT := "level_up_boost"
var _ad_in_progress := false
var _boost_hp := 0
var _boost_atk := 0

func _ready() -> void:
	boost_button.pressed.connect(_on_boost_button_pressed)
	continue_button.pressed.connect(_close)
	AdManager.availability_changed.connect(func(_available: bool) -> void: _refresh_boost_button())

# level: 到達レベル、gained_hp/gained_atk: 通常のレベルアップで得た上昇量
# boost_hp/boost_atk: 動画視聴で追加される上昇量
func show_level_up(level: int, gained_hp: int, gained_atk: int, boost_hp: int, boost_atk: int) -> void:
	_boost_hp = boost_hp
	_boost_atk = boost_atk
	_ad_in_progress = false
	stats_label.text = "Lv.%d\n最大HP +%d ／ 攻撃力 +%d" % [level, gained_hp, gained_atk]
	boost_label.text = "動画を見るとさらに 最大HP +%d ／ 攻撃力 +%d" % [boost_hp, boost_atk]
	_refresh_boost_button()
	visible = true

func _refresh_boost_button() -> void:
	var ready := AdManager.is_ready() and not _ad_in_progress
	boost_button.disabled = not ready
	continue_button.disabled = _ad_in_progress
	if _ad_in_progress:
		boost_button.text = "動画を再生中..."
	elif ready:
		boost_button.text = "▶ 動画を見て強化"
	else:
		boost_button.text = "動画を準備中..."

func _on_boost_button_pressed() -> void:
	if _ad_in_progress:
		return
	_ad_in_progress = true
	_refresh_boost_button()
	AdManager.show_rewarded(AD_PLACEMENT, func(success: bool) -> void:
		_ad_in_progress = false
		if success:
			boost_requested.emit()
			_close()
		else:
			_refresh_boost_button())

func _close() -> void:
	visible = false
	closed.emit()
