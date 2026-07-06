extends SceneTree

# SDスプライトの不透明ピクセル領域(used_rect)を調査する
const SD_PATHS := {
	"reimu": "res://assets/sprites/characters/reimu/reimuSD.png",
	"marisa": "res://assets/sprites/characters/marisa/marisaSD.png",
	"sakuya": "res://assets/sprites/characters/sakuya/sakuyaSD1.png",
	"reisen": "res://assets/sprites/characters/reisen/reisenSD.png",
	"sanae": "res://assets/sprites/characters/sanae/sanaeSD.png",
	"youmu": "res://assets/sprites/characters/youmu/yomuSD.png",
}

func _init() -> void:
	for cid in SD_PATHS:
		var tex: Texture2D = load(SD_PATHS[cid])
		if tex == null:
			print(cid, ": LOAD FAILED")
			continue
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		var used := img.get_used_rect()
		print("%s: size=%s used=%s" % [cid, img.get_size(), used])
	quit(0)
