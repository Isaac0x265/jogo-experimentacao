extends Node2D
## Uma camada do cenário desenhada por código.
## Tudo é desenhado num "ladrilho" de `width` px que se repete sem emenda
## (as ondas das colinas usam frequências que fecham certinho em `width`).
## Para trocar por arte própria depois: apague este nó e coloque um Sprite2D
## no lugar, dentro do mesmo Parallax2D.

enum Kind { SKY, SUN, CLOUDS, HILLS_FAR, HILLS_MID, HILLS_NEAR, GROUND }

@export var kind: Kind = Kind.SKY
@export var width := 288.0
@export var height := 512.0
@export var horizon_y := 330.0: set = set_horizon_y
@export var ground_y := 440.0

const SKY_TOP := Color("f8eedb")
const SKY_BOTTOM := Color("f4d2ae")
const SUN := Color("fff7e3")
const CLOUD := Color("fdf6ea")
const HILL_FAR := Color("dfdcb6")
const HILL_MID := Color("c3cd9c")
const HILL_NEAR := Color("a3bb85")
const TRUNK := Color("9a7a64")
const LEAF_A := Color("efbb94")
const LEAF_B := Color("e5a483")
const LEAF_C := Color("f4d3a2")
const FLOWER := Color("f6e2c2")
const FIREFLY := Color("fff3c4")
const GRASS := Color("b9d091")
const GRASS_LIGHT := Color("d3e3ad")
const GRASS_DARK := Color("8ea873")
const DIRT := Color("ecd5ac")
const DIRT_STRIPE := Color("dfc391")

# Colinas: [base relativa ao horizonte, amplitude, onda1, onda2, fase]
const HILLS := {
	Kind.HILLS_FAR: [-46.0, 14.0, 2, 5, 0.4],
	Kind.HILLS_MID: [-14.0, 12.0, 1, 4, 2.1],
	Kind.HILLS_NEAR: [22.0, 9.0, 3, 7, 4.0],
}

var _t := 0.0
var _clouds: Array[Vector3] = []   # x, y, largura
var _flowers: Array[Vector2] = []
var _flies: Array[Vector4] = []    # x, y, fase, velocidade


func _ready() -> void:
	_build()
	set_process(kind == Kind.HILLS_NEAR)  # só os vaga-lumes precisam animar


func set_horizon_y(value: float) -> void:
	horizon_y = value
	if is_node_ready():
		_build()
		queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + kind
	_clouds.clear()
	_flowers.clear()
	_flies.clear()
	match kind:
		Kind.CLOUDS:
			for i in 3:
				_clouds.append(Vector3(i * width / 3.0 + rng.randf_range(0, 50), rng.randf_range(24, 170), rng.randf_range(28, 56)))
		Kind.HILLS_NEAR:
			for i in 30:
				var fx := floorf(rng.randf() * width)
				_flowers.append(Vector2(fx, floorf(rng.randf_range(hill_y(fx) + 6.0, height - 6.0))))
			for i in 14:
				_flies.append(Vector4(rng.randf() * width, rng.randf_range(horizon_y - 120.0, height - 16.0), rng.randf() * TAU, rng.randf_range(0.6, 1.4)))


func hill_y(x: float, k: Kind = kind) -> float:
	var h: Array = HILLS[k]
	var a := TAU * x / width
	return floorf(horizon_y + h[0] + sin(a * h[2] + h[4]) * h[1] + sin(a * h[3] + h[4] * 1.7) * h[1] * 0.35)


func _draw() -> void:
	match kind:
		Kind.SKY:
			var bands := 10
			for i in bands:
				var y0 := floorf(horizon_y * i / bands)
				var y1 := floorf(horizon_y * (i + 1) / bands)
				draw_rect(Rect2(0, y0, width, y1 - y0 + 1), SKY_TOP.lerp(SKY_BOTTOM, float(i) / (bands - 1)))
			draw_rect(Rect2(0, horizon_y, width, height - horizon_y), SKY_BOTTOM)
		Kind.SUN:
			var p := Vector2(208, 132)
			draw_circle(p, 40, Color(SUN, 0.25))
			draw_circle(p, 32, Color(SUN, 0.45))
			draw_circle(p, 24, SUN)
		Kind.CLOUDS:
			for c in _clouds:
				_draw_cloud(Vector2(c.x, c.y).round(), c.z)
		Kind.HILLS_FAR:
			_draw_hill(HILL_FAR)
		Kind.HILLS_MID:
			_draw_hill(HILL_MID)
			for x in [24.0, 60.0, 190.0, 252.0]:
				_draw_tree(x, hill_y(x))
		Kind.HILLS_NEAR:
			_draw_hill(HILL_NEAR)
			for f in _flowers:
				draw_rect(Rect2(f, Vector2(2, 2)), FLOWER)
			for f in _flies:
				var a := 0.5 + 0.5 * sin(_t * f.w * 2.0 + f.z)
				var p := (Vector2(f.x, f.y) + Vector2(sin(_t * 0.7 + f.z) * 6.0, cos(_t * 0.9 + f.z) * 4.0)).round()
				draw_circle(p + Vector2(1, 1), 3, Color(FIREFLY, 0.25 * a))
				draw_rect(Rect2(p, Vector2(2, 2)), Color(FIREFLY, a))
		Kind.GROUND:
			_draw_ground()


func _draw_hill(color: Color) -> void:
	for x in range(0, int(width), 2):
		var y := hill_y(x)
		draw_rect(Rect2(x, y, 2, height - y + 16), color)


func _draw_tree(x: float, ground: float) -> void:
	draw_rect(Rect2(x - 2, ground - 22, 4, 26), TRUNK)
	draw_circle(Vector2(x - 7, ground - 26), 10, LEAF_B)
	draw_circle(Vector2(x + 7, ground - 28), 11, LEAF_B)
	draw_circle(Vector2(x, ground - 36), 12, LEAF_A)
	draw_circle(Vector2(x - 3, ground - 40), 5, LEAF_C)


func _draw_cloud(p: Vector2, w: float) -> void:
	var h := w * 0.28
	draw_rect(Rect2(p.x - w * 0.5, p.y, w, h * 0.6), CLOUD)
	draw_circle(p + Vector2(-w * 0.22, 0), h * 0.7, CLOUD)
	draw_circle(p + Vector2(w * 0.1, -h * 0.3), h, CLOUD)
	draw_circle(p + Vector2(w * 0.32, h * 0.05), h * 0.6, CLOUD)


func _draw_ground() -> void:
	# Grama com tufinhos
	draw_rect(Rect2(0, ground_y, width, 8), GRASS)
	draw_rect(Rect2(0, ground_y, width, 2), GRASS_LIGHT)
	for x in range(0, int(width), 12):
		draw_rect(Rect2(x + 4, ground_y - 2, 2, 2), GRASS_LIGHT)
		draw_rect(Rect2(x, ground_y + 6, 12, 2), GRASS_DARK if (x / 12) % 2 == 0 else GRASS)
	# Terra com listras diagonais (ajudam a perceber o movimento)
	var top := ground_y + 8
	draw_rect(Rect2(0, top, width, height - top), DIRT)
	for row in int(height - top):
		for x in range(0, int(width), 16):
			var sx := fposmod(x + row, width)
			draw_rect(Rect2(sx, top + row, 6, 1), DIRT_STRIPE)
