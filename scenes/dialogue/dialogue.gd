extends CanvasLayer

class DialogueLine:
	var speaker: String
	var text: String
	var expression: String

	func _init(s: String, t: String, e: String) -> void:
		speaker = s
		text = t
		expression = e

@onready var left_char_image: TextureRect = $LeftCharImage
@onready var right_char_image: TextureRect = $RightCharImage
@onready var name_label: Label = $DialogueBox/NamePlate/NameLabel
@onready var body_label: Label = $DialogueBox/BodyLabel
@onready var advance_hint: Label = $DialogueBox/AdvanceHint
@onready var advance_button: Button = $AdvanceButton

var _lines: Array[DialogueLine] = []
var _current_index: int = 0
var _left_char: CharacterData
var _right_char: CharacterData
var _on_finished: Callable

func _ready() -> void:
	advance_button.pressed.connect(_on_advance_pressed)
	var blink := create_tween().set_loops()
	blink.tween_property(advance_hint, "modulate:a", 0.2, 0.6)
	blink.tween_property(advance_hint, "modulate:a", 1.0, 0.6)

func start_dialogue(csv_path: String, left_char: CharacterData, right_char: CharacterData, on_finished: Callable) -> void:
	_left_char = left_char
	_right_char = right_char
	_on_finished = on_finished
	_lines = _parse_csv(csv_path)
	_current_index = 0
	left_char_image.texture = _left_char.get_tatie()
	right_char_image.texture = _right_char.get_tatie()
	visible = true
	if _lines.is_empty():
		_finish()
		return
	_update_ui()

# 未執筆ファイルに入っている仮テキスト。会話行として表示しない
const PLACEHOLDER_TEXT := "会話が用意されていない"

func _parse_csv(path: String) -> Array[DialogueLine]:
	var result: Array[DialogueLine] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var res_path := "res://" + path.lstrip("/")
		file = FileAccess.open(res_path, FileAccess.READ)
	if file == null:
		push_warning("dialogue: cannot open " + path)
		return result
	var first := true
	while not file.eof_reached():
		var cols := file.get_csv_line()
		if first:
			first = false
			continue
		if cols.size() < 2:
			continue
		var speaker := cols[0].strip_edges()
		var text := cols[1].strip_edges()
		if speaker.is_empty() or text.is_empty():
			continue
		if speaker.begins_with("#"):
			continue
		if text.begins_with(PLACEHOLDER_TEXT):
			continue
		var expression := cols[2].strip_edges() if cols.size() > 2 else ""
		result.append(DialogueLine.new(speaker, text, expression))
	return result

func _on_advance_pressed() -> void:
	_current_index += 1
	if _current_index >= _lines.size():
		_finish()
	else:
		_update_ui()

func _finish() -> void:
	visible = false
	_on_finished.call()

func _update_ui() -> void:
	if _current_index >= _lines.size():
		return
	var dl := _lines[_current_index]
	name_label.text = _resolve_display_name(dl.speaker)
	body_label.text = dl.text
	_update_focus(dl.speaker)
	# 話者側の立ち絵を表情差分に切り替える
	if dl.speaker == _left_char.char_id or dl.speaker == _left_char.display_name:
		left_char_image.texture = _left_char.get_tatie(dl.expression)
	else:
		right_char_image.texture = _right_char.get_tatie(dl.expression)

func _resolve_display_name(speaker: String) -> String:
	if speaker == _left_char.char_id or speaker == _left_char.display_name:
		return _left_char.display_name
	if speaker == _right_char.char_id or speaker == _right_char.display_name:
		return _right_char.display_name
	return speaker

func _update_focus(speaker: String) -> void:
	var left_active := (speaker == _left_char.char_id or speaker == _left_char.display_name)
	left_char_image.modulate = Color.WHITE if left_active else Color(0.5, 0.5, 0.5, 1.0)
	right_char_image.modulate = Color.WHITE if not left_active else Color(0.5, 0.5, 0.5, 1.0)
	# 話者を前面、相手を背面に(立ち絵は中央で少し重なるレイアウト)
	left_char_image.z_index = 2 if left_active else 1
	right_char_image.z_index = 1 if left_active else 2
