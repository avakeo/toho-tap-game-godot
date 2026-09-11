extends CanvasLayer

@onready var player_lose_image: TextureRect = $PlayerLoseImage
@onready var revive_button: Button = $ReviveButton
@onready var retry_button: Button = $RetryButton
@onready var title_button: Button = $TitleButton

signal retry_requested
signal title_requested
# 動画広告を最後まで視聴し、復活が確定したときに通知
signal revive_requested

const AD_PLACEMENT := "lose_revive"
var _ad_in_progress := false

func _ready() -> void:
	revive_button.pressed.connect(_on_revive_button_pressed)
	retry_button.pressed.connect(_on_retry_button_pressed)
	title_button.pressed.connect(_on_title_button_pressed)
	AdManager.availability_changed.connect(func(_available: bool) -> void: _refresh_revive_button())

# can_revive=false のとき(復活を使い切った等)は復活ボタンを出さない
func show_lose(defeated_texture: Texture2D, can_revive: bool = true) -> void:
	player_lose_image.texture = defeated_texture
	revive_button.visible = can_revive
	_ad_in_progress = false
	_refresh_revive_button()
	visible = true

func _refresh_revive_button() -> void:
	var ready := AdManager.is_ready() and not _ad_in_progress
	revive_button.disabled = not ready
	if _ad_in_progress:
		revive_button.text = "動画を再生中..."
	elif ready:
		revive_button.text = "▶ 動画を見て復活"
	else:
		revive_button.text = "動画を準備中..."

func _on_revive_button_pressed() -> void:
	if _ad_in_progress:
		return
	_ad_in_progress = true
	_refresh_revive_button()
	AdManager.show_rewarded(AD_PLACEMENT, func(success: bool) -> void:
		_ad_in_progress = false
		if success:
			visible = false
			revive_requested.emit()
		else:
			_refresh_revive_button())

func _on_retry_button_pressed() -> void:
	visible = false
	retry_requested.emit()

func _on_title_button_pressed() -> void:
	visible = false
	title_requested.emit()
