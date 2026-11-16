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
@onready var placar: PanelContainer = $UI/Placar
@onready var lbl_pontos: Label = $UI/Placar/HBox/Pontos
@onready var banner: PanelContainer = $UI/FaseBanner
@onready var aviso_box: PanelContainer = $UI/AvisoBox
@onready var aviso_icone: TextureRect = $UI/AvisoBox/VBox/Icone
@onready var aviso_titulo: Label = $UI/AvisoBox/VBox/Titulo
@onready var aviso_corpo: Label = $UI/AvisoBox/VBox/Corpo
@onready var aviso_pontos: Label = $UI/AvisoBox/VBox/PontosFim
@onready var escurecer: ColorRect = $UI/Escurecer
@onready var flash: ColorRect = $UI/Flash
@onready var sombra_gato: Sprite2D = $SombraGato
@onready var efeitos: Node2D = $Efeitos
@onready var scenery: Node2D = $Scenery
@onready var obstaculos: Node2D = $Obstaculos

var pontos := 0
var fase := 0
var _player_start_y := 0.0
var _timer_obst := Timer.new()
var _timer_aereo := Timer.new()
var _motivo := ""   ## o que acertou o gato ("" = caiu no chao)
var _banner_tw: Tween

## Icone mostrado na caixa de mensagem para cada tipo de obstaculo.
const ICONES := {
	"fio": "fio", "lixo": "lixo", "vidro": "vidro", "garrafa": "garrafa", "papel": "papel",
	"esgoto": "esgoto", "entulho": "entulho", "rede": "plastico", "sacola": "plastico", "pet": "plastico",
	"baia": "baia", "deslizamento": "deslizamento", "balao": "balao", "balaozinho": "balao",
}


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
	# sombra do gato no chao: menor e mais clara quanto mais alto ele voa
	var altura := clampf((440.0 - player.position.y) / 400.0, 0.0, 1.0)
	sombra_gato.position.x = player.position.x
	sombra_gato.scale = Vector2.ONE * lerpf(1.0, 0.45, altura)
	sombra_gato.modulate.a = lerpf(0.9, 0.25, altura)


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
	_piscar(0.8)
	$UI/FaseBanner/VBox/Topo/Numero.text = "FASE %d" % (fase + 1)
	$UI/FaseBanner/VBox/Nome.text = FASES[fase].nome
	if _banner_tw: _banner_tw.kill()
	banner.position.y = -80.0
	_banner_tw = create_tween()
	_banner_tw.tween_property(banner, "position:y", 70.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tw.tween_interval(2.2)
	_banner_tw.tween_property(banner, "position:y", -80.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


func _on_passou() -> void:
	if _motivo != "":
		return
	pontos += 1
	lbl_pontos.text = str(pontos)
	_efeito_ponto()
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
	_tremer(5.0)
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
	placar.visible = true
	_criar_obstaculo()
	_timer_obst.start()
	_timer_aereo.start(randf_range(aereo_min, aereo_max))


func _on_player_died() -> void:
	scenery.scrolling = false   # o mundo para quando o gato cai
	_parar_obstaculos()
	_poeira(player.position)
	_piscar(0.45)
	if _motivo == "":
		_tremer(3.0)                # bateu no chao
	else:
		_mostrar_aviso(_motivo)
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
	placar.visible = false
	if _banner_tw: _banner_tw.kill()
	banner.position.y = -80.0
	_motivo = ""
	aviso_box.visible = false
	escurecer.visible = false
	hint.text = HINT_START
	hint.visible = true


# ---------- Mensagem de fim de jogo ----------

func _mostrar_aviso(tipo: String) -> void:
	var partes: PackedStringArray = MENSAGENS[tipo].split("\n\n", true, 1)
	aviso_titulo.text = partes[0]
	aviso_corpo.text = partes[1] if partes.size() > 1 else ""
	aviso_pontos.text = "PONTOS: %d" % pontos
	var caminho := "res://assets/ui/icones/%s.png" % ICONES.get(tipo, "lixo")
	aviso_icone.texture = load(caminho) if ResourceLoader.exists(caminho) else null
	escurecer.visible = true
	escurecer.modulate.a = 0.0
	aviso_box.visible = true
	aviso_box.pivot_offset = aviso_box.size / 2.0
	aviso_box.scale = Vector2(0.6, 0.6)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(escurecer, "modulate:a", 1.0, 0.3)
	tw.tween_property(aviso_box, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------- Efeitos ----------

## Treme a tela (move o mundo; a interface fica parada).
func _tremer(forca: float) -> void:
	var tw := create_tween()
	for i in 6:
		tw.tween_property(self, "position", Vector2(randf_range(-forca, forca), randf_range(-forca, forca)), 0.04)
		forca *= 0.75
	tw.tween_property(self, "position", Vector2.ZERO, 0.04)


## Clarao rapido na tela inteira.
func _piscar(intensidade: float) -> void:
	flash.modulate.a = intensidade
	create_tween().tween_property(flash, "modulate:a", 0.0, 0.35)


## Pontinhos voando (poeira/estrelinhas) a partir de uma posicao.
func _particulas(pos: Vector2, cores: Array, qtd: int, vel: float, gravidade: float) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = qtd
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.7
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = vel * 0.5
	p.initial_velocity_max = vel
	p.gravity = Vector2(0, gravidade)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.0
	var g := Gradient.new()
	g.colors = PackedColorArray(cores)
	p.color_initial_ramp = g
	efeitos.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


func _poeira(pos: Vector2) -> void:
	_particulas(pos, [Color("fff3c4"), Color("d9b98c"), Color("8a5f4a")], 22, 120.0, 260.0)


func _efeito_ponto() -> void:
	_particulas(player.position + Vector2(6, 0), [Color("fff3a0"), Color("9be08a")], 8, 60.0, 0.0)
	# "+1" subindo
	var l := Label.new()
	l.text = "+1"
	var ls := LabelSettings.new()
	ls.font_size = 8
	ls.font_color = Color("fff8ec")
	ls.outline_size = 3
	ls.outline_color = Color("8a5f4a")
	l.label_settings = ls
	l.position = player.position + Vector2(10, -24)
	efeitos.add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 22.0, 0.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tw.chain().tween_callback(l.queue_free)
	# placar da um pulinho
	placar.pivot_offset = placar.size / 2.0
	placar.scale = Vector2(1.25, 1.25)
	create_tween().tween_property(placar, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
