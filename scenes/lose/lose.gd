extends CanvasLayer

@onready var player_lose_image: TextureRect = $PlayerLoseImage
@onready var retry_button: Button = $RetryButton
@onready var title_button: Button = $TitleButton

signal retry_requested
signal title_requested

func show_lose(defeated_texture: Texture2D) -> void:
	player_lose_image.texture = defeated_texture
	visible = true

func _on_retry_button_pressed() -> void:
	visible = false
	retry_requested.emit()

func _on_title_button_pressed() -> void:
	visible = false
	title_requested.emit()
