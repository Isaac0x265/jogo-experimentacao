extends Node2D
## Controla a rolagem do cenário (parallax).
## Cada camada é um Parallax2D: o `scroll_scale.x` dele diz a fração da
## velocidade do mundo que ela usa (1.0 = anda junto com o chão, 0.1 = bem longe).
## Para trocar o cenário depois, basta trocar o conteúdo de cada Parallax2D.

@export var speed := 60.0: set = set_speed            ## px/s do chão (os canos vão usar essa mesma velocidade)
@export var scrolling := true: set = set_scrolling
@export var horizon_y := 330.0
@export var show_ground := false
@export var vertical_follow := 0.05                   ## quanto o fundo reage à altura do personagem

var _follow_target := 0.0
var _follow := 0.0


func _ready() -> void:
	for n in find_children("*", "Node2D", true, false):
		if "horizon_y" in n and n != self:
			n.horizon_y = horizon_y
	$Ground.visible = show_ground
	_apply()


func set_speed(value: float) -> void:
	speed = value
	_apply()


func set_scrolling(value: bool) -> void:
	scrolling = value
	_apply()


## Desloca o fundo de leve para cima/baixo conforme o personagem sobe/desce.
## `offset` = quanto o personagem está acima (-) ou abaixo (+) do centro.
func follow(offset: float) -> void:
	_follow_target = -offset * vertical_follow


func _process(delta: float) -> void:
	_follow = lerpf(_follow, _follow_target, 4.0 * delta)
	for p in _layers():
		if p.scroll_scale.x < 1.0:   # o chão não sobe/desce (tem colisão)
			p.scroll_offset.y = roundf(_follow * p.scroll_scale.x * 2.0)


func _apply() -> void:
	if not is_node_ready():
		return
	for p in _layers():
		p.autoscroll = Vector2(-speed * p.scroll_scale.x, 0.0) if scrolling else Vector2.ZERO


func _layers() -> Array[Parallax2D]:
	var out: Array[Parallax2D] = []
	for c in get_children():
		if c is Parallax2D:
			out.append(c)
	return out
