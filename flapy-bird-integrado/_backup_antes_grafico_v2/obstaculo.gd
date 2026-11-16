extends Node2D
## Par de obstaculos com uma abertura no meio. Cada fase escolhe os tipos:
##   CIMA  -> "fio" (fios de poste soltos) | "rede" (rede de pesca abandonada com lixo)
##            "balao" (balao gigante de Sao Joao com a bucha acesa)
##   BAIXO -> "lixo"    : lixeira no chao com lixo empilhado por cima
##            "vidro"   : cacos no chao (fios descem e o gato passa rente ao chao)
##            "esgoto"  : galeria (manilha) despejando esgoto, com placa IMPROPRIO
##            "entulho" : entulho jogado em cima das raizes do mangue
##            "baia"    : lixo da Baia de Guanabara preso na ecobarreira
##            "deslizamento": lama e pedras descendo o morro, bueiro entupido, sirene

signal bateu(tipo: String)   ## tipo do obstaculo em que o gato encostou
signal passou                ## o gato passou pela abertura (+1 ponto)

const CHAO_Y := 440.0        ## y do chao (topo da colisao do Ground no main)
const ALTURA_CACOS := 12.0
const D := "res://assets/obstaculos/"
const F := "res://assets/obstaculos/fortaleza/"
const R := "res://assets/obstaculos/rio/"
const TEX := {
	"fio": preload(D + "fios_cima.png"),            # 2 quadros 32x400, ponta em y=384
	"rede": preload(F + "rede_cima.png"),           # 32x400, boias em y~392
	"lixeira": preload(D + "lixeira.png"),
	"pilha_lixo": preload(D + "pilha_lixo.png"),
	"topo_lixo": preload(D + "topo_lixo.png"),
	"cacos": preload(D + "cacos_chao.png"),
	"galeria_topo": preload(F + "galeria_topo.png"),
	"galeria_corpo": preload(F + "galeria_corpo.png"),
	"galeria_base": preload(F + "galeria_base.png"),
	"placa": preload(F + "placa_improprio.png"),
	"entulho_topo": preload(F + "entulho_topo.png"),
	"entulho_corpo": preload(F + "entulho_corpo.png"),
	"mangue": preload(F + "mangue_base.png"),
	"balao_corpo": preload(R + "balao_corpo.png"),        # 34x32, repete
	"balao_boca": preload(R + "balao_boca.png"),          # 2 quadros 40x44, chama na ponta
	"baia_corpo": preload(R + "baia_corpo.png"),
	"baia_topo": preload(R + "baia_topo.png"),
	"ecobarreira": preload(R + "ecobarreira.png"),
	"lama_corpo": preload(R + "lama_corpo.png"),
	"deslizamento_topo": preload(R + "deslizamento_topo.png"),
	"bueiro": preload(R + "bueiro.png"),
}

var velocidade := 60.0       ## o main passa a mesma velocidade do chao (Scenery.speed)
var x_do_gato := 80.0
var tipo_cima := "fio"
var tipo_baixo := "lixo"
var _ja_passou := false
var _t := 0.0
var _animados: Array = []    ## [Sprite2D, quadros por segundo]

@onready var cima: Area2D = $Cima
@onready var baixo: Area2D = $Baixo
@onready var forma_cima: CollisionShape2D = $Cima/CollisionShape2D
@onready var forma_baixo: CollisionShape2D = $Baixo/CollisionShape2D
@onready var visual_cima: Node2D = $Cima/Visual
@onready var visual_baixo: Node2D = $Baixo/Visual


func _ready() -> void:
	# So conta se quem encostou foi o gato (CharacterBody2D), nao o chao nem outro objeto.
	cima.body_entered.connect(func(b): if b is CharacterBody2D: bateu.emit(tipo_cima))
	baixo.body_entered.connect(func(b): if b is CharacterBody2D: bateu.emit(tipo_baixo))


## centro_y = meio da abertura | abertura = tamanho do buraco
func configurar(centro_y: float, abertura: float, t_cima: String, t_baixo: String) -> void:
	tipo_cima = t_cima
	tipo_baixo = t_baixo
	var borda := centro_y + abertura / 2.0           # onde comeca o obstaculo de baixo
	if t_baixo == "vidro":
		borda = CHAO_Y - ALTURA_CACOS                # cacos ficam no chao
	cima.position.y = borda - abertura
	baixo.position.y = borda
	_montar_cima()
	_montar_baixo(CHAO_Y - borda)


func _montar_cima() -> void:
	match tipo_cima:
		"rede":
			_sprite(visual_cima, TEX.rede, Vector2(-16, -394))
			_retangulo(forma_cima, 22.0, 800.0, -400.0)
		"balao":
			_coluna(visual_cima, TEX.balao_corpo, 34, -800.0, -43.0)
			_animar(_sprite(visual_cima, TEX.balao_boca, Vector2(-20, -44), 2), 8.0)   # chama tremendo
			_retangulo(forma_cima, 30.0, 790.0, -405.0)
		_:
			_animar(_sprite(visual_cima, TEX.fio, Vector2(-16, -384), 2), 10.0)   # faisca piscando
			_retangulo(forma_cima, 12.0, 800.0, -400.0)


func _montar_baixo(altura: float) -> void:
	match tipo_baixo:
		"vidro":
			_animar(_sprite(visual_baixo, TEX.cacos, Vector2(-22, altura - 16), 2), 4.0)
			_retangulo(forma_baixo, 38.0, altura, altura / 2.0)
		"lixo":
			_coluna(visual_baixo, TEX.pilha_lixo, 32, 10.0, altura - 48.0)
			_sprite(visual_baixo, TEX.topo_lixo, Vector2(-18, -4))
			_sprite(visual_baixo, TEX.lixeira, Vector2(-18, altura - 44))
			_retangulo(forma_baixo, 26.0, altura, altura / 2.0)
		"esgoto":
			_coluna(visual_baixo, TEX.galeria_corpo, 28, 10.0, altura - 14.0)
			_sprite(visual_baixo, TEX.galeria_base, Vector2(-24, altura - 22))
			_sprite(visual_baixo, TEX.placa, Vector2(12, altura - 16))
			_animar(_sprite(visual_baixo, TEX.galeria_topo, Vector2(-18, -14), 2), 8.0)
			_retangulo(forma_baixo, 28.0, altura, altura / 2.0)
		"entulho":
			_coluna(visual_baixo, TEX.entulho_corpo, 30, 10.0, altura - 22.0)
			_sprite(visual_baixo, TEX.entulho_topo, Vector2(-18, -4))
			_animar(_sprite(visual_baixo, TEX.mangue, Vector2(-24, altura - 26), 2), 3.0)
			_retangulo(forma_baixo, 28.0, altura, altura / 2.0)
		"baia":
			_coluna(visual_baixo, TEX.baia_corpo, 32, 10.0, altura - 12.0)
			_sprite(visual_baixo, TEX.baia_topo, Vector2(-18, -4))
			_sprite(visual_baixo, TEX.ecobarreira, Vector2(-26, altura - 18))
			_retangulo(forma_baixo, 28.0, altura, altura / 2.0)
		"deslizamento":
			_coluna(visual_baixo, TEX.lama_corpo, 32, 12.0, altura - 8.0)
			_animar(_sprite(visual_baixo, TEX.deslizamento_topo, Vector2(-20, -12), 2), 3.0)   # sirene piscando
			_sprite(visual_baixo, TEX.bueiro, Vector2(-24, altura - 16))
			_retangulo(forma_baixo, 30.0, altura, altura / 2.0)


## Corpo que estica: repete a textura na vertical de y0 ate y1.
func _coluna(pai: Node2D, tex: Texture2D, largura: int, y0: float, y1: float) -> void:
	var s := _sprite(pai, tex, Vector2(-largura / 2.0, y0))
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, largura, maxf(0.0, y1 - y0))


func _sprite(pai: Node2D, tex: Texture2D, pos: Vector2, quadros := 1) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = pos
	s.hframes = quadros
	pai.add_child(s)
	return s


func _animar(s: Sprite2D, fps: float) -> void:
	_animados.append([s, fps])


func _retangulo(forma: CollisionShape2D, largura: float, altura: float, centro_y: float) -> void:
	var r := RectangleShape2D.new()
	r.size = Vector2(largura, altura)
	forma.shape = r
	forma.position = Vector2(0, centro_y)


func _process(delta: float) -> void:
	position.x -= velocidade * delta
	_t += delta
	for a in _animados:
		a[0].frame = int(_t * a[1]) % a[0].hframes
	if not _ja_passou and position.x < x_do_gato:
		_ja_passou = true
		passou.emit()
	if position.x < -40.0:
		queue_free()
