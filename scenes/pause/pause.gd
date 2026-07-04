extends CanvasLayer

signal pause_requested
signal resume_requested
signal title_requested

@onready var pause_button: Button = $PauseButton
@onready var overlay: ColorRect = $Overlay
@onready var pause_panel: Panel = $PausePanel
@onready var resume_button: Button = $PausePanel/ResumeButton
@onready var title_button: Button = $PausePanel/TitleButton

func _ready() -> void:
	pause_button.pressed.connect(func(): pause_requested.emit())
	resume_button.pressed.connect(func(): resume_requested.emit())
	title_button.pressed.connect(func(): title_requested.emit())

func open() -> void:
	overlay.show()
	pause_panel.show()
	pause_button.hide()

func close() -> void:
	overlay.hide()
	pause_panel.hide()
	pause_button.show()
