extends Area2D
## Objeto no ar. Primeiro pisca um "!" na borda da tela (aviso), depois entra voando.
##   "garrafa" / "pet" : arremessados em arco (gravidade), girando
##   "papel"           : rapido e quase reto
##   "sacola"          : flutua ondulando, como uma agua-viva
##   "balaozinho"      : balao aceso caindo devagar e balancando

signal bateu(tipo: String)

const D := "res://assets/obstaculos/"
const CONFIG := {
	#            textura                              quadros  vel. x        vel. y       gravidade  giro  onda
	"garrafa": [preload(D + "garrafa.png"),           1, [-110, -140], [-130, -40], 150.0,     8.0,  0.0],
	"papel":   [preload(D + "papel.png"),             1, [-160, -200], [-25, 15],   40.0,      14.0, 0.0],
	"pet":     [preload(D + "fortaleza/pet.png"),     1, [-120, -150], [-110, -30], 130.0,     9.0,  0.0],
	"sacola":  [preload(D + "fortaleza/sacola.png"),  2, [-70, -90],   [0, 0],      0.0,       0.0,  18.0],
	"balaozinho": [preload(D + "rio/balaozinho.png"), 2, [-45, -65], [25, 40],    0.0,       0.0,  5.0],
}
const TEMPO_AVISO := 0.8

var tipo := "garrafa"
var velocidade := Vector2.ZERO
var gravidade := 0.0
var giro := 0.0
var onda := 0.0              ## amplitude da ondulacao (so a sacola usa)
var _y_base := 0.0
var _t := 0.0
var _aviso := TEMPO_AVISO

@onready var sprite: Sprite2D = $Sprite2D
@onready var alerta: Label = $Alerta


func configurar(t: String, y: float) -> void:
	tipo = t
	var c: Array = CONFIG[t]
	position = Vector2(304, y)                    # nasce fora da tela, a direita
	_y_base = y
	sprite.texture = c[0]
	sprite.hframes = c[1]
	velocidade = Vector2(randf_range(c[2][0], c[2][1]), randf_range(c[3][0], c[3][1]))
	gravidade = c[4]
	giro = c[5] * (1 if randf() < 0.5 else -1)
	onda = c[6]


func _ready() -> void:
	body_entered.connect(func(b): if sprite.visible and b is CharacterBody2D: bateu.emit(tipo))
	sprite.visible = false


func _process(delta: float) -> void:
	if _aviso > 0.0:                              # fase de aviso: "!" piscando
		_aviso -= delta
		alerta.visible = int(_aviso * 10.0) % 2 == 0
		if _aviso <= 0.0:
			alerta.visible = false
			sprite.visible = true
		return
	_t += delta
	velocidade.y += gravidade * delta             # gravidade -> trajetoria em arco
	position.x += velocidade.x * delta
	if onda > 0.0:
		_y_base += velocidade.y * delta               # deriva (o balaozinho vai descendo)
		position.y = _y_base + sin(_t * 3.0) * onda   # balanca / sobe e desce como agua-viva
		sprite.frame = int(_t * 4.0) % sprite.hframes
	else:
		position.y += velocidade.y * delta
		sprite.rotation += giro * delta
	if position.x < -30.0 or position.y > 540.0:
		queue_free()
