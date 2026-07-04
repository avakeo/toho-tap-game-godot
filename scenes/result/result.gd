extends CanvasLayer

@onready var next_button: Button = $NextButton
@onready var result_label: Label = $ResultLabel

signal next_requested

func _ready() -> void:
	next_button.pressed.connect(_on_next_button_pressed)

func show_result(is_final: bool = false) -> void:
	result_label.text = "全ステージクリア！" if is_final else "勝利！"
	next_button.visible = not is_final
	visible = true

func _on_next_button_pressed() -> void:
	visible = false
	next_requested.emit()
