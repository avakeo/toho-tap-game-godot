extends SceneTree

# 対話パートの立ち絵が全キャラ共通の目線ラインに揃うかを検証する
const CHAR_PATHS := [
	"res://resources/characters/reimu.tres",
	"res://resources/characters/marisa.tres",
	"res://resources/characters/sakuya.tres",
	"res://resources/characters/reisen.tres",
	"res://resources/characters/sanae.tres",
	"res://resources/characters/youmu.tres",
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var dialogue := (load("res://scenes/dialogue/dialogue.tscn") as PackedScene).instantiate()
	root.add_child(dialogue)
	var chars: Array[CharacterData] = []
	for path in CHAR_PATHS:
		chars.append(load(path))
	var vp: Vector2 = root.get_visible_rect().size
	print("viewport=", vp, " expected_eye_line=", vp.y * dialogue.TATIE_EYE_LINE_RATIO)
	for i in chars.size():
		var left := chars[i]
		var right := chars[(i + 1) % chars.size()]
		dialogue.start_dialogue("res://no_such_file.csv", left, right, func() -> void: pass)
		for side in [["L", dialogue.left_char_image, left], ["R", dialogue.right_char_image, right]]:
			var rect: TextureRect = side[1]
			var chara: CharacterData = side[2]
			var eye_y: float = rect.position.y + chara.tatie_eye_ratio * rect.size.y
			print("%s %s: pos=%s size=%s eye_y=%.1f" % [side[0], chara.char_id, rect.position, rect.size, eye_y])
	quit(0)
