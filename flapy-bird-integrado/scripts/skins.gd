extends Node
## Autoload "Skins": lista de skins disponíveis + skin escolhida (salva em disco).
## Para adicionar uma skin nova, basta colocar mais um item em LIST.

const SAVE_PATH := "user://save.cfg"

const LIST: Array[Dictionary] = [
	{
		"id": "gato",
		"name": "Gato",
		"side": preload("res://assets/skins/gato_lado.png"),    # usada no jogo
		"front": preload("res://assets/skins/gato_frente.png"), # usada no menu
		"frames": 4,
	},
]

var selected_id: String = LIST[0].id


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		var saved: String = cfg.get_value("skins", "selected", selected_id)
		if index_of(saved) >= 0:
			selected_id = saved


func index_of(id: String) -> int:
	for i in LIST.size():
		if LIST[i].id == id:
			return i
	return -1


func current() -> Dictionary:
	return LIST[max(0, index_of(selected_id))]


func select(id: String) -> void:
	if index_of(id) < 0:
		return
	selected_id = id
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("skins", "selected", selected_id)
	cfg.save(SAVE_PATH)


func apply_to(player: Node) -> void:
	var s := current()
	player.set_skin(s.side, s.frames)
