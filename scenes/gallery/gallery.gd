extends Control

signal closed

# ゲーム中からオーバーレイ表示された場合true。閉じるとシーン遷移せず呼び出し元に戻る
var overlay_mode := false

const CHAR_IDS := ["reimu", "marisa", "sakuya", "reisen", "sanae", "youmu"]
const TALK_KINDS := [["talk1", "開幕"], ["talk2", "中間①"], ["talk3", "中間②"], ["win", "勝利"], ["lose", "敗北"]]
const PLACEHOLDER_TEXT := "会話が用意されていない"
const FONT := preload("res://assets/fonts/NotoSansJP-Regular.ttf")

@onready var back_button: Button = $BackButton
@onready var list_scroll: ScrollContainer = $ListScroll
@onready var list_box: VBoxContainer = $ListScroll/ListBox
@onready var detail_panel: Control = $DetailPanel
@onready var detail_title: Label = $DetailPanel/DetailTitle
@onready var to_list_button: Button = $DetailPanel/ToListButton
@onready var form_image: TextureRect = $DetailPanel/FormImage
@onready var form_label: Label = $DetailPanel/FormLabel
@onready var form_buttons: HBoxContainer = $DetailPanel/FormButtons
@onready var talk_buttons: HBoxContainer = $DetailPanel/TalkButtons
@onready var talk_text: RichTextLabel = $DetailPanel/TalkScroll/TalkText

var chars := {}
var current_player_id := ""
var current_enemy_id := ""

func _ready() -> void:
	for cid in CHAR_IDS:
		var res := load("res://resources/characters/%s.tres" % cid) as CharacterData
		if res:
			chars[cid] = res
	if overlay_mode:
		back_button.text = "戻る"
	back_button.pressed.connect(_on_back_to_title)
	to_list_button.pressed.connect(_show_list)
	_build_form_buttons()
	_build_talk_buttons()
	_build_list()
	_show_list()

func _on_back_to_title() -> void:
	if overlay_mode:
		closed.emit()
		return
	get_tree().change_scene_to_file("res://scenes/title/title.tscn")

func _show_list() -> void:
	detail_panel.visible = false
	list_scroll.visible = true
	back_button.visible = true

func _styled_button(label: String, font_size: int) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.add_theme_font_override("font", FONT)
	btn.add_theme_font_size_override("font_size", font_size)
	return btn

func _build_list() -> void:
	for player in CHAR_IDS:
		for enemy in CHAR_IDS:
			if enemy == player:
				continue
			var cleared: bool = GameState.is_stage_cleared(player, enemy)
			var label := "%s vs %s" % [chars[player].display_name, chars[enemy].display_name]
			if not cleared:
				label += "　（未クリア）"
			var btn := _styled_button(label, 40)
			btn.custom_minimum_size = Vector2(0, 100)
			if cleared:
				btn.pressed.connect(_open_detail.bind(player, enemy))
			else:
				btn.disabled = true
			list_box.add_child(btn)

func _build_form_buttons() -> void:
	for i in 3:
		var btn := _styled_button("形態%d" % (i + 1), 32)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_set_form.bind(i))
		form_buttons.add_child(btn)

func _build_talk_buttons() -> void:
	for kind in TALK_KINDS:
		var btn := _styled_button(kind[1], 30)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_load_dialogue.bind(kind[0]))
		talk_buttons.add_child(btn)

func _open_detail(player: String, enemy: String) -> void:
	current_player_id = player
	current_enemy_id = enemy
	detail_title.text = "%s vs %s" % [chars[player].display_name, chars[enemy].display_name]
	list_scroll.visible = false
	back_button.visible = false
	detail_panel.visible = true
	_set_form(0)
	_load_dialogue("talk1")

func _set_form(index: int) -> void:
	var enemy: CharacterData = chars[current_enemy_id]
	var forms := enemy.battle_forms
	if forms.is_empty():
		form_image.texture = null
		form_label.text = ""
		return
	index = clampi(index, 0, forms.size() - 1)
	form_image.texture = forms[index]
	form_label.text = "%s　形態 %d/%d" % [enemy.display_name, index + 1, forms.size()]
	for i in form_buttons.get_child_count():
		form_buttons.get_child(i).visible = i < forms.size()

func _load_dialogue(kind: String) -> void:
	var path := "res://assets/dialogues/%s/%s_vs_%s_%s.csv" % [
		current_player_id, current_player_id, current_enemy_id, kind
	]
	talk_text.clear()
	var lines := _parse_csv(path)
	if lines.is_empty():
		talk_text.add_text("（この会話は未収録です）")
		return
	for l in lines:
		talk_text.push_color(Color(1.0, 0.62, 0.67))
		talk_text.add_text(l[0])
		talk_text.pop()
		talk_text.add_text("\n" + l[1] + "\n\n")

# dialogue.gdと同じ規則でCSVを読み、[話者表示名, 本文] の配列を返す
func _parse_csv(path: String) -> Array:
	var result: Array = []
	if not FileAccess.file_exists(path):
		return result
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
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
		if speaker.is_empty() or text.is_empty() or speaker.begins_with("#"):
			continue
		if text.begins_with(PLACEHOLDER_TEXT):
			continue
		result.append([_resolve_display_name(speaker), text])
	return result

func _resolve_display_name(speaker: String) -> String:
	if chars.has(speaker):
		return chars[speaker].display_name
	return speaker
