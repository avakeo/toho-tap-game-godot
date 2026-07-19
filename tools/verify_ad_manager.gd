extends SceneTree

# AdManager が非モバイル環境で擬似リワードを返すことを検証する
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var manager: Node = (load("res://scripts/ad_manager.gd") as GDScript).new()
	root.add_child(manager)
	print("is_ready=", manager.is_ready())
	manager.rewarded.connect(func(placement: String) -> void:
		print("signal rewarded placement=", placement))
	manager.show_rewarded("verify_test", func(success: bool) -> void:
		print("result=", success)
		quit(0))
