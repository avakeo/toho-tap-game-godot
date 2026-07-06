extends CanvasLayer

@onready var next_button: Button = $NextButton
@onready var result_label: Label = $ResultLabel

signal next_requested

func _ready() -> void:
	next_button.pressed.connect(_on_next_button_pressed)

func show_result() -> void:
	result_label.text = "勝利！"
	next_button.visible = true
	visible = true

func _on_next_button_pressed() -> void:
	visible = false
	next_requested.emit()
