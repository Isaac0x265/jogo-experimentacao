extends Node2D

const MENU_SCENE := "res://scenes/menu.tscn"
const HINT_START := "TOQUE PARA VOAR"
const HINT_RESTART := "TENTE DE NOVO"

@onready var player: CharacterBody2D = $Player
@onready var hint: Label = $UI/Hint
@onready var scenery: Node2D = $Scenery

var _player_start_y := 0.0


func _ready() -> void:
	Skins.apply_to(player)
	_player_start_y = player.position.y
	player.started.connect(_on_player_started)
	player.died.connect(_on_player_died)
	player.restarted.connect(_on_player_restarted)
	_on_player_restarted()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(MENU_SCENE)


func _process(_delta: float) -> void:
	scenery.follow(player.position.y - _player_start_y)


func _on_player_started() -> void:
	hint.visible = false


func _on_player_died() -> void:
	scenery.scrolling = false   # o mundo para quando o gato cai
	hint.text = HINT_RESTART
	hint.visible = true


func _on_player_restarted() -> void:
	scenery.scrolling = true
	hint.text = HINT_START
	hint.visible = true
