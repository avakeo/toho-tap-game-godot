extends SceneTree

# 会話CSVの検証ツール。
# 実行: godot --headless --path . -s tools/validate_dialogues.gd
# (Windowsは tools/validate_dialogues.bat をダブルクリックでも可)
#
# チェック内容:
#  - 対戦カードごとのファイル有無・執筆状況の一覧表
#  - 話者名がその対戦カードの2人と一致しているか
#  - 表情タグが定義済みのものか

const CHAR_IDS := ["reimu", "marisa", "sakuya", "reisen", "sanae", "youmu"]
const KINDS := ["talk1", "talk2", "talk3", "win", "lose"]
const VALID_EXPRESSIONS := ["", "shinken", "ressei", "odoroki", "warai"]
const PLACEHOLDER := "会話が用意されていない"

var display_names := {}

func _init() -> void:
	for cid in CHAR_IDS:
		var c = load("res://resources/characters/%s.tres" % cid)
		display_names[cid] = c.display_name if c else cid

	var issues: Array[String] = []
	print("")
	print("=== 会話データ執筆状況 (数字=行数, 未=プレースホルダのみ, 無=ファイルなし) ===")
	print("対戦カード          talk1  talk2  talk3  win    lose")
	for player in CHAR_IDS:
		for enemy in CHAR_IDS:
			if enemy == player:
				continue
			var cells: Array[String] = []
			for kind in KINDS:
				var path := "res://assets/dialogues/%s/%s_vs_%s_%s.csv" % [player, player, enemy, kind]
				cells.append(_check_file(path, player, enemy, issues))
			var name := "%s vs %s" % [display_names[player], display_names[enemy]]
			print("%-18s %-6s %-6s %-6s %-6s %-6s" % [name, cells[0], cells[1], cells[2], cells[3], cells[4]])
	print("")
	if issues.is_empty():
		print("問題は見つかりませんでした。")
	else:
		print("=== 要確認 (%d件) ===" % issues.size())
		for i in issues:
			print("  - " + i)
	quit()

# ファイルを検証し、一覧表用のセル文字列を返す
func _check_file(path: String, player: String, enemy: String, issues: Array[String]) -> String:
	if not FileAccess.file_exists(path):
		return "無"
	var file := FileAccess.open(path, FileAccess.READ)
	var count := 0
	var placeholder_only := true
	var first := true
	var line_no := 1
	while not file.eof_reached():
		var cols := file.get_csv_line()
		line_no += 1
		if first:
			first = false
			continue
		if cols.size() < 2:
			continue
		var speaker := cols[0].strip_edges()
		var text := cols[1].strip_edges()
		if speaker.is_empty() or text.is_empty() or speaker.begins_with("#"):
			continue
		if text.begins_with(PLACEHOLDER):
			continue
		placeholder_only = false
		count += 1
		# 「？？？」は正体を伏せた演出用として許可
		var ok_names: Array[String] = [player, enemy, display_names[player], display_names[enemy], "？？？"]
		if not ok_names.has(speaker):
			issues.append("%s:%d 話者「%s」がこのカードの2人と一致しない" % [path.get_file(), line_no - 1, speaker])
		var expr := cols[2].strip_edges() if cols.size() > 2 else ""
		if not VALID_EXPRESSIONS.has(expr):
			issues.append("%s:%d 未定義の表情タグ「%s」" % [path.get_file(), line_no - 1, expr])
	if placeholder_only:
		return "未"
	return str(count)
