extends SceneTree

# 敗北画面の「動画を見て復活」とリザルト画面の「動画を見てXPボーナス」が
# 擬似視聴モードで正しくシグナルを発火することを検証する
var _revived := false
var _bonus := false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var ad_manager: Node = (load("res://scripts/ad_manager.gd") as GDScript).new()
	ad_manager.name = "AdManager"
	root.add_child(ad_manager)

	var lose: CanvasLayer = (load("res://scenes/lose/lose.tscn") as PackedScene).instantiate()
	root.add_child(lose)
	lose.revive_requested.connect(func() -> void: _revived = true)
	lose.show_lose(null, true)
	print("revive button visible=", lose.revive_button.visible, " disabled=", lose.revive_button.disabled)
	lose.revive_button.pressed.emit()
	await create_timer(1.0).timeout
	print("revived=", _revived, " lose hidden=", not lose.visible)

	lose.show_lose(null, false)
	print("revive button hidden when used up=", not lose.revive_button.visible)

	var result: CanvasLayer = (load("res://scenes/result/result.tscn") as PackedScene).instantiate()
	root.add_child(result)
	result.xp_bonus_requested.connect(func() -> void:
		_bonus = true
		result.show_bonus_granted("XP +30 獲得！"))
	result.show_result(30)
	print("bonus button text=", result.xp_bonus_button.text, " disabled=", result.xp_bonus_button.disabled)
	result.xp_bonus_button.pressed.emit()
	await create_timer(1.0).timeout
	print("bonus=", _bonus, " claimed text=", result.xp_bonus_button.text, " disabled=", result.xp_bonus_button.disabled)

	var ok: bool = _revived and _bonus and result.xp_bonus_button.disabled
	print("RESULT: ", "ALL OK" if ok else "FAILED")
	quit(0 if ok else 1)
