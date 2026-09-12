extends Control

@onready var tap_hint: Label = $TapHint

var _started := false

func _ready() -> void:
	var blink := create_tween().set_loops()
	blink.tween_property(tap_hint, "modulate:a", 0.5, 0.7)
	blink.tween_property(tap_hint, "modulate:a", 1.0, 0.7)

# 画面のどこをタップ(クリック)してもスタートする
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_start_game()
	elif event is InputEventScreenTouch and event.pressed:
		_start_game()

func _start_game() -> void:
	if _started:
		return
	_started = true
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")
