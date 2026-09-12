extends Node

# 擬似バナー表示時に、戦闘中の全レイヤーと動的な図鑑オーバーレイが
# バナー上端までの安全領域へ収まることを検証する。
const LAYER_NAMES := [
	"BattleLayer",
	"DialogueLayer",
	"LoseLayer",
	"ResultLayer",
	"LevelUpLayer",
	"OptionWheel",
]

@onready var game: Node = $Game
var _failed := false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	await get_tree().process_frame
	var viewport_height := game.get_viewport().get_visible_rect().size.y
	var window_height := float(DisplayServer.window_get_size().y)
	if window_height <= 0.0:
		window_height = viewport_height
	var test_banner_height := int(window_height * 0.07)
	game._apply_banner_inset(test_banner_height)
	await get_tree().process_frame
	var expected_bottom := viewport_height \
			- float(test_banner_height) * (viewport_height / window_height)

	for layer_name in LAYER_NAMES:
		_check_safe_root(game.get_node(layer_name) as CanvasLayer, expected_bottom)

	game._on_gallery_requested()
	await get_tree().process_frame
	var gallery_layer := game.get_node_or_null("GalleryOverlayLayer") as CanvasLayer
	if gallery_layer == null:
		_fail("GalleryOverlayLayer was not created")
	else:
		_check_safe_root(gallery_layer, expected_bottom)
		if not gallery_layer.has_node("SafeRoot/Gallery"):
			_fail("Gallery was not moved under SafeRoot")

	print("RESULT: ", "FAILED" if _failed else "ALL OK")
	get_tree().quit(1 if _failed else 0)

func _check_safe_root(layer: CanvasLayer, expected_bottom: float) -> void:
	var safe_root := layer.get_node_or_null("SafeRoot") as Control
	if safe_root == null:
		_fail(layer.name + " has no SafeRoot")
		return
	var actual_bottom := safe_root.position.y + safe_root.size.y
	if not is_equal_approx(actual_bottom, expected_bottom):
		_fail("%s bottom=%f expected=%f" % [layer.name, actual_bottom, expected_bottom])
	else:
		print("OK: ", layer.name, " safe_bottom=", actual_bottom)

func _fail(message: String) -> void:
	_failed = true
	push_error(message)
