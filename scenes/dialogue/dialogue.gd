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
@onready var name_label: Label = $DialogueBox/NameLabel
@onready var body_label: Label = $DialogueBox/BodyLabel
@onready var advance_button: Button = $AdvanceButton

var _lines: Array[DialogueLine] = []
var _current_index: int = 0
var _left_char: CharacterData
var _right_char: CharacterData
var _on_finished: Callable

func start_dialogue(csv_path: String, left_char: CharacterData, right_char: CharacterData, on_finished: Callable) -> void:
	_left_char = left_char
	_right_char = right_char
	_on_finished = on_finished
	_lines = _parse_csv(csv_path)
	_current_index = 0
	visible = true
	if _lines.is_empty():
		_finish()
		return
	_update_ui()

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
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue
		if first:
			first = false
			continue
		var cols := line.split(",", false, 2)
		if cols.size() < 2:
			continue
		var dl := DialogueLine.new(
			cols[0].strip_edges(),
			cols[1].strip_edges(),
			cols[2].strip_edges() if cols.size() > 2 else ""
		)
		result.append(dl)
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
