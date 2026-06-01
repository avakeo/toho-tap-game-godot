extends CanvasLayer

@onready var next_button: Button = $NextButton

signal next_requested

func show_result() -> void:
	visible = true

func _on_next_button_pressed() -> void:
	visible = false
	next_requested.emit()
