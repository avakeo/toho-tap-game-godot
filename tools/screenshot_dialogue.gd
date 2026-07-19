extends SceneTree

# 対話パートを実描画してスクリーンショットを保存する(目視確認用)
# 使い方: godot --path . -s res://tools/screenshot_dialogue.gd -- <left_id> <right_id> <out.png>

const CHAR_DIR := "res://resources/characters/"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var left_id: String = args[0] if args.size() > 0 else "reimu"
	var right_id: String = args[1] if args.size() > 1 else "reisen"
	var out_path: String = args[2] if args.size() > 2 else "user://dialogue_screenshot.png"
	var dialogue := (load("res://scenes/dialogue/dialogue.tscn") as PackedScene).instantiate()
	root.add_child(dialogue)
	var left: CharacterData = load(CHAR_DIR + left_id + ".tres")
	var right: CharacterData = load(CHAR_DIR + right_id + ".tres")
	dialogue.start_dialogue("res://%s_vs_%s_talk1.csv" % [left_id, right_id], left, right, func() -> void: pass)
	for i in 4:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out_path)
	print("saved: ", out_path, " size=", img.get_size())
	quit(0)
