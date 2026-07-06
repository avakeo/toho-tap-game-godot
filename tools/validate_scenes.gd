extends SceneTree

# ヘッドレスで全シーンを読み込み・インスタンス化してスクリプトエラーを検出する
const SCENES := [
	"res://scenes/title/title.tscn",
	"res://scenes/game/game.tscn",
	"res://scenes/dialogue/dialogue.tscn",
	"res://scenes/gallery/gallery.tscn",
	"res://scenes/option_wheel/option_wheel.tscn",
	"res://scenes/result/result.tscn",
	"res://scenes/lose/lose.tscn",
]

func _init() -> void:
	var failed := false
	for path in SCENES:
		var packed: PackedScene = load(path)
		if packed == null:
			push_error("LOAD FAILED: " + path)
			failed = true
			continue
		var inst := packed.instantiate()
		if inst == null:
			push_error("INSTANTIATE FAILED: " + path)
			failed = true
			continue
		print("OK: ", path)
		inst.free()
	print("RESULT: ", "FAILED" if failed else "ALL OK")
	quit(1 if failed else 0)
