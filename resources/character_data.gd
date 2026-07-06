class_name CharacterData
extends Resource

@export var char_id: String = ""
@export var display_name: String = ""
@export var battle_forms: Array[Texture2D] = []
@export var tatie_sprite: Texture2D
# 表情名("shinken"/"ressei"/"odoroki"/"warai") -> 立ち絵差分
@export var tatie_expressions: Dictionary = {}
@export var sd_sprite: Texture2D
# SD絵が左向きの場合true。バトルでは右向きに統一するため反転して表示する
@export var sd_faces_left: bool = false
@export var defeated_sprite: Texture2D
@export var stage_background: Texture2D
@export var stage_bgm: AudioStream
@export var max_hp: float = 100.0

# 表情差分があればそれを、無ければ通常立ち絵を返す
func get_tatie(expression: String = "") -> Texture2D:
	if expression != "" and tatie_expressions.has(expression):
		return tatie_expressions[expression]
	return tatie_sprite
