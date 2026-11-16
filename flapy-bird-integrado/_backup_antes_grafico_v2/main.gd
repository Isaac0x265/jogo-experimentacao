extends Node2D

const MENU_SCENE := "res://scenes/menu.tscn"
const HINT_START := "TOQUE PARA VOAR"
const HINT_RESTART := "TENTE DE NOVO"

const OBSTACULO := preload("res://scenes/obstaculo.tscn")
const PROJETIL := preload("res://scenes/projetil.tscn")

## Cada fase = um lugar do Brasil com seus problemas ambientais.
## Listas com itens repetidos funcionam como "peso" no sorteio.
const FASES := [
	{
		"nome": "RUA DO NORDESTE",
		"cenario": preload("res://scenes/scenery_rua.tscn"),
		"cima": ["fio"],
		"baixo": ["lixo", "lixo", "vidro"],
		"aereos": ["garrafa", "papel"],
	},
	{
		"nome": "FORTALEZA",
		"cenario": preload("res://scenes/scenery_fortaleza.tscn"),
		"cima": ["rede"],
		"baixo": ["esgoto", "esgoto", "entulho"],
		"aereos": ["sacola", "sacola", "pet"],
	},
	{
		"nome": "RIO DE JANEIRO",
		"cenario": preload("res://scenes/scenery_rio.tscn"),
		"cima": ["balao"],
		"baixo": ["baia", "deslizamento"],
		"aereos": ["balaozinho", "balaozinho", "pet"],
		"aereo_y": [30.0, 220.0],      # baloes nascem no alto e vao descendo
	},
]

## Mensagem de conscientizacao mostrada quando o gato bate em cada obstaculo.
## (Fonte sem acentos. Dados das fases 2+ no relatorio "Problemas ambientais das fases".)
const MSG_PLASTICO := "PLASTICO NO MAR!\n\nLEVE SEU LIXO DE VOLTA\nDA PRAIA E RECICLE NO\nECOPONTO. PLASTICO VIRA\nMICROPLASTICO!"
const MSG_BALAO := "BALAO!\n\nSOLTAR BALAO E CRIME E\nQUEIMA A FLORESTA!\nVIU UM? DENUNCIE A\nLINHA VERDE."
const MENSAGENS := {
	"fio": "FIO SOLTO!\n\nFIOS CAIDOS PODEM DAR\nCHOQUE. NAO ENCOSTE E\nAVISE A COMPANHIA\nDE ENERGIA.",
	"lixo": "LIXO NA RUA!\n\nLIXO FORA DO LUGAR\nENTOPE BUEIROS E\nCAUSA ALAGAMENTOS.",
	"vidro": "CACOS DE VIDRO!\n\nEMBRULHE VIDRO QUEBRADO\nEM JORNAL ANTES DE\nJOGAR FORA: PROTEGE\nOS GARIS.",
	"garrafa": "GARRAFA JOGADA!\n\nVIDRO E 100% RECICLAVEL.\nLEVE AO PONTO DE COLETA\n(LIXEIRA VERDE).",
	"papel": "PAPEL NA RUA!\n\nPAPEL JOGADO NA RUA\nVAI PARAR NO BUEIRO.\nRECICLE NA LIXEIRA AZUL.",
	"esgoto": "ESGOTO NO MAR!\n\nESGOTO NAO E CHUVA!\nLIGUE SUA CASA A REDE\nDA CAGECE E VEJA O\nBOLETIM DA SEMACE\nANTES DO BANHO.",
	"entulho": "ENTULHO NO MANGUE!\n\nMANGUE E BERCARIO DO\nMAR! NAO JOGUE ENTULHO\nNO COCO: CHAME O\nLIMPEZINHA PELO 156.",
	"baia": "LIXO NA BAIA!\n\nLIXO NA RUA VIRA LIXO\nNA BAIA! JOGUE NO LIXO\nE SEPARE O RECICLAVEL.",
	"deslizamento": "DESLIZAMENTO!\n\nARVORE SEGURA O MORRO!\nNAO JOGUE LIXO NA\nENCOSTA E, SE A SIRENE\nTOCAR, SAIA JA.",
	"balao": MSG_BALAO,
	"balaozinho": MSG_BALAO,
	"rede": MSG_PLASTICO,
	"sacola": MSG_PLASTICO,
	"pet": MSG_PLASTICO,
}

@export var pontos_por_fase := 10           ## pontos para avancar de fase
@export var fase_inicial := 0               ## 0 = Rua do Nordeste, 1 = Fortaleza, 2 = Rio (para testar)
@export_group("Obstaculos")
@export var intervalo_obstaculos := 2.4     ## segundos entre um par e outro
@export var abertura := 112.0               ## tamanho do buraco entre o obstaculo de cima e o de baixo
@export var centro_min := 130.0             ## abertura mais alta possivel
@export var centro_max := 330.0             ## abertura mais baixa possivel (chao em y=440)
@export_group("Objetos no ar")
@export var aereo_min := 3.0                ## tempo minimo entre objetos no ar
@export var aereo_max := 5.5
@export var aereo_y_min := 60.0
@export var aereo_y_max := 380.0

@onready var player: CharacterBody2D = $Player
@onready var hint: Label = $UI/Hint
@onready var aviso: Label = $UI/Aviso
@onready var lbl_pontos: Label = $UI/Pontos
@onready var lbl_fase: Label = $UI/Fase
@onready var scenery: Node2D = $Scenery
@onready var obstaculos: Node2D = $Obstaculos

var pontos := 0
var fase := 0
var _player_start_y := 0.0
var _timer_obst := Timer.new()
var _timer_aereo := Timer.new()
var _motivo := ""   ## o que acertou o gato ("" = caiu no chao)


func _ready() -> void:
	Skins.apply_to(player)
	_player_start_y = player.position.y
	player.started.connect(_on_player_started)
	player.died.connect(_on_player_died)
	player.restarted.connect(_on_player_restarted)

	_timer_obst.wait_time = intervalo_obstaculos
	_timer_obst.timeout.connect(_criar_obstaculo)
	add_child(_timer_obst)
	_timer_aereo.one_shot = true
	_timer_aereo.timeout.connect(_jogar_objeto)
	add_child(_timer_aereo)

	_on_player_restarted()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(MENU_SCENE)


func _process(_delta: float) -> void:
	scenery.follow(player.position.y - _player_start_y)


# ---------- Fases ----------

func _trocar_cenario(indice: int, com_transicao: bool) -> void:
	var antigo := scenery
	var novo: Node2D = FASES[indice].cenario.instantiate()
	add_child(novo)
	move_child(novo, antigo.get_index() + 1)    # logo acima do antigo, atras de tudo o resto
	novo.scrolling = antigo.scrolling
	scenery = novo
	if com_transicao:
		novo.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(novo, "modulate:a", 1.0, 1.5)
		tw.tween_callback(antigo.queue_free)
	else:
		antigo.queue_free()


func _avancar_fase() -> void:
	fase += 1
	_trocar_cenario(fase, true)
	lbl_fase.text = "FASE %d\n\n%s" % [fase + 1, FASES[fase].nome]
	lbl_fase.visible = true
	lbl_fase.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(lbl_fase, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func(): lbl_fase.visible = false)


func _on_passou() -> void:
	if _motivo != "":
		return
	pontos += 1
	lbl_pontos.text = str(pontos)
	if pontos % pontos_por_fase == 0 and fase < FASES.size() - 1:
		_avancar_fase()


# ---------- Obstaculos ----------

func _criar_obstaculo() -> void:
	var f: Dictionary = FASES[fase]
	var o := OBSTACULO.instantiate()
	o.position.x = 310.0                        # nasce fora da tela, a direita
	o.velocidade = scenery.speed                # anda junto com o chao
	o.x_do_gato = player.position.x
	obstaculos.add_child(o)
	o.configurar(randf_range(centro_min, centro_max), abertura, f.cima.pick_random(), f.baixo.pick_random())
	o.bateu.connect(_on_bateu)
	o.passou.connect(_on_passou)


func _jogar_objeto() -> void:
	var p := PROJETIL.instantiate()
	obstaculos.add_child(p)
	var f: Dictionary = FASES[fase]
	var faixa: Array = f.get("aereo_y", [aereo_y_min, aereo_y_max])
	p.configurar(f.aereos.pick_random(), randf_range(faixa[0], faixa[1]))
	p.bateu.connect(_on_bateu)
	_timer_aereo.start(randf_range(aereo_min, aereo_max))   # agenda o proximo


func _on_bateu(tipo: String) -> void:
	if _motivo != "":
		return
	_motivo = tipo
	player.hit()          # o gato "morre" e cai (o player emite died)


func _parar_obstaculos() -> void:
	_timer_obst.stop()
	_timer_aereo.stop()
	for o in obstaculos.get_children():
		o.set_process(false)


func _limpar_obstaculos() -> void:
	for o in obstaculos.get_children():
		o.queue_free()


# ---------- Estados do jogo ----------

func _on_player_started() -> void:
	hint.visible = false
	lbl_pontos.visible = true
	_criar_obstaculo()
	_timer_obst.start()
	_timer_aereo.start(randf_range(aereo_min, aereo_max))


func _on_player_died() -> void:
	scenery.scrolling = false   # o mundo para quando o gato cai
	_parar_obstaculos()
	if _motivo != "":
		aviso.text = MENSAGENS[_motivo] + "\n\nPONTOS: %d" % pontos
		aviso.visible = true
	hint.text = HINT_RESTART
	hint.visible = true


func _on_player_restarted() -> void:
	_parar_obstaculos()
	_limpar_obstaculos()
	if fase != fase_inicial or scenery.scene_file_path != FASES[fase_inicial].cenario.resource_path:
		fase = fase_inicial
		_trocar_cenario(fase, false)
	scenery.scrolling = true
	pontos = 0
	lbl_pontos.text = "0"
	lbl_pontos.visible = false
	lbl_fase.visible = false
	_motivo = ""
	aviso.visible = false
	hint.text = HINT_START
	hint.visible = true
