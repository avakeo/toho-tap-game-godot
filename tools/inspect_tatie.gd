extends SceneTree

# 対話パート立ち絵の寸法と不透明ピクセル領域(used_rect)を調査する
const CHAR_PATHS := [
	"res://resources/characters/reimu.tres",
	"res://resources/characters/marisa.tres",
	"res://resources/characters/sakuya.tres",
	"res://resources/characters/reisen.tres",
	"res://resources/characters/sanae.tres",
	"res://resources/characters/youmu.tres",
]

func _init() -> void:
	for path in CHAR_PATHS:
		var data: CharacterData = load(path)
		if data == null:
			print(path, ": LOAD FAILED")
			continue
		_report(data.char_id + "/base", data.tatie_sprite)
		for expr in data.tatie_expressions:
			_report(data.char_id + "/" + expr, data.tatie_expressions[expr])
	quit(0)

func _report(label: String, tex: Texture2D) -> void:
	if tex == null:
		print(label, ": null")
		return
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	var used := img.get_used_rect()
	print("%s: size=%s used=%s" % [label, img.get_size(), used])
