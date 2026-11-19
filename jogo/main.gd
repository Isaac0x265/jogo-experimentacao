extends Node2D

const MENU_SCENE := "res://menu/menu.tscn"
const SAVE_PATH := "user://save.cfg"

const OBSTACULO := preload("res://obstaculos/obstaculo.tscn")
const PROJETIL := preload("res://obstaculos/projetil.tscn")
const PERGUNTA := preload("res://perguntas/pergunta.gd")   ## coluna de bolhas com respostas
const CONTAS := preload("res://perguntas/contas.gd")       ## sorteia as contas de cada fase
const TEX_FOLHA := preload("res://assets/ui/folha.png")

## Fases, textos educativos e dicas ficam em fases.gd (so dados, facil de editar).
const DADOS := preload("res://jogo/fases.gd")

@export var velocidade_mundo := 45.0        ## px/s do chao, dos obstaculos e das bolhas (era 60)
@export var pontos_por_fase := 10           ## obstaculos que precisa passar para mudar de fase
@export var fase_inicial := 0               ## 0 = Rua do Nordeste, 1 = Fortaleza, 2 = Rio (para testar)
@export_group("Pontuacao")
@export var perfeito_margem := 16.0         ## distancia (px) do meio do buraco que conta como PERFEITO
@export var perfeitos_por_mult := 3         ## PERFEITOS seguidos para subir o multiplicador
@export var mult_max := 4
@export var chance_folha := 0.35            ## chance de aparecer uma folha no buraco
@export var pontos_folha := 2               ## (multiplicado pelo multiplicador)
@export var bonus_fase := 5                 ## pontos extras ao completar uma fase
@export_group("Modo luva (mais facil)")
@export var modo_luva := true               ## jogo mais lento e com buracos maiores para jogar com a luva
@export var luva_gravidade := 620.0         ## (normal 1000) gato cai mais devagar
@export var luva_queda_max := 300.0         ## (normal 480)
@export var luva_abertura := 150.0          ## (normal 112) buraco maior
## (normal 2.4) segundos entre obstaculos. Distancia entre eles = velocidade x tempo:
## com o mundo mais devagar (45 px/s), 4.0 s mantem ~180 px, quase o mesmo de antes.
@export var luva_intervalo := 4.0
@export var luva_variacao_max := 70.0       ## buraco seguinte no maximo 70 px acima/abaixo do anterior
@export var luva_aereos_desde_fase := 1     ## objetos voando so a partir da 2a fase (0 = desde a 1a)
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
@export_group("Perguntas de matematica")
@export var perguntas_ativas := true
@export var obstaculos_entre_perguntas := 2  ## quantos obstaculos aparecem antes de cada coluna de bolhas
@export var alturas_bolhas: Array[float] = [150.0, 260.0, 370.0]   ## y de cada bolha (chao em y=440)
@export var pontos_acerto := 3              ## (multiplicado pelo multiplicador)
@export var erro_encerra_jogo := false      ## true = errar a conta derruba o gato, como bater num obstaculo
@export var tempo_bolhas_paradas := 3.0     ## segundos que as bolhas ficam paradas na lateral da tela
@export var x_bolhas_paradas := 240.0       ## onde elas param (a tela tem 288 px de largura)

@onready var player: CharacterBody2D = $Player
@onready var hud: CanvasLayer = $UI
@onready var sombra_gato: Sprite2D = $SombraGato
@onready var efeitos: Node2D = $Efeitos
@onready var scenery: Node2D = $Scenery
@onready var obstaculos: Node2D = $Obstaculos

var pontos := 0
var fase := 0
var recorde := 0
var _passados_fase := 0      ## obstaculos passados na fase atual
var _seq_perfeitos := 0      ## PERFEITOS seguidos
var _mult := 1
var _maior_mult := 1
var _perfeitos := 0
var _folhas := 0
var _novo_recorde := false
var _player_start_y := 0.0
var _ultimo_centro := -1.0
var _timer_obst := Timer.new()
var _timer_aereo := Timer.new()
var _motivo := ""   ## o que acertou o gato ("" = caiu no chao)
var _obstaculos_desde_pergunta := 0   ## obstaculos criados desde a ultima coluna de bolhas
var _acertos := 0                     ## contas certas nesta partida
var _perguntas := 0                   ## contas que apareceram nesta partida
var _conta_errada: Dictionary = {}    ## a conta que derrubou o gato (so com erro_encerra_jogo)
var _em_pergunta := false             ## true enquanto as bolhas estao na tela (sem obstaculos)


func _ready() -> void:
	Skins.apply_to(player)
	if modo_luva:
		_aplicar_modo_luva()
	recorde = _carregar_recorde()
	_player_start_y = player.position.y
	scenery.speed = velocidade_mundo
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


## Deixa o jogo mais facil para quem joga com a luva (o gesto da mao e mais lento que o teclado).
func _aplicar_modo_luva() -> void:
	player.gravity = luva_gravidade
	player.max_fall_speed = luva_queda_max
	abertura = luva_abertura
	intervalo_obstaculos = luva_intervalo
	aereo_min = 5.0
	aereo_max = 8.0


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
	var novo: Node2D = DADOS.FASES[indice].cenario.instantiate()
	add_child(novo)
	move_child(novo, antigo.get_index() + 1)    # logo acima do antigo, atras de tudo o resto
	novo.scrolling = antigo.scrolling
	novo.speed = velocidade_mundo               # cada cenario novo nasce com 60; usa a nossa
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
	_passados_fase = 0
	_trocar_cenario(fase, true)
	hud.piscar(0.8)
	hud.mostrar_fase(fase + 1, DADOS.FASES[fase].nome)
	hud.progresso(0, pontos_por_fase, fase, DADOS.FASES.size())
	_somar(bonus_fase, "FASE!", Color("f0b25a"))


# ---------- Pontuacao ----------

## O gato passou por um par de obstaculos.
func _on_passou(o: Node2D) -> void:
	if _motivo != "":
		return
	var centro: float = (o.cima.position.y + o.baixo.position.y) / 2.0
	var perfeito := absf(player.position.y - centro) <= perfeito_margem
	if perfeito:
		_perfeitos += 1
		_seq_perfeitos += 1
	else:
		_seq_perfeitos = 0
	_atualizar_mult()
	var ganho := (2 if perfeito else 1) * _mult
	if perfeito:
		_somar(ganho, "PERFEITO!", Color("fff3a0"))
	else:
		_somar(ganho, "", Color("fff8ec"))
	_contar_progresso()


## +1 na barra da fase (passar um obstaculo ou acertar uma conta). Se encheu, muda de fase.
func _contar_progresso() -> void:
	_passados_fase += 1
	hud.progresso(_passados_fase, pontos_por_fase, fase, DADOS.FASES.size())
	if _passados_fase >= pontos_por_fase and fase < DADOS.FASES.size() - 1:
		_avancar_fase()


# ---------- Perguntas de matematica ----------

## Comeca o "modo pergunta": para de criar obstaculos e limpa o caminho ate as bolhas.
func _entrar_modo_pergunta() -> void:
	_em_pergunta = true
	_timer_obst.stop()
	_timer_aereo.stop()
	_tirar_obstaculos_da_frente()
	_criar_pergunta()


## Acabou a pergunta (acertou, errou ou passou direto): os obstaculos voltam.
func _sair_modo_pergunta() -> void:
	if _motivo != "":     # o gato caiu: nao volta a criar nada
		return
	_em_pergunta = false
	# Cria o proximo obstaculo ja (se esperasse o timer, ficaria ~9 s sem nada na tela).
	# call_deferred = "faz no fim deste quadro": quando o gato toca a bolha, o Godot esta
	# no meio do calculo de colisoes e nao deixa criar outro objeto com colisao nessa hora.
	_criar_obstaculo.call_deferred()
	_timer_obst.start()
	_timer_aereo.start(randf_range(aereo_min, aereo_max))


## Some com os obstaculos e objetos voando que o gato ainda nao passou
## (com um "puf"), para o caminho ate as bolhas ficar livre.
func _tirar_obstaculos_da_frente() -> void:
	for o in obstaculos.get_children():
		var ainda_na_frente: bool = o.position.x > player.position.x - 30.0
		if not ainda_na_frente:
			continue
		var y_do_puf: float = o.position.y
		if "cima" in o:     # obstaculo de cima/baixo: o "puf" sai do meio do buraco
			y_do_puf = (o.cima.position.y + o.baixo.position.y) / 2.0
		_particulas(Vector2(o.position.x, y_do_puf), [Color("fff8ec"), Color("d9b98c")], 14, 90.0, 0.0)
		o.queue_free()


func _criar_pergunta() -> void:
	var conta := CONTAS.sortear(fase)
	var p := PERGUNTA.new()
	p.position.x = 310.0                        # nasce fora da tela, a direita (igual ao obstaculo)
	p.velocidade = scenery.speed
	p.x_do_gato = player.position.x
	p.x_parada = x_bolhas_paradas
	p.tempo_parada = tempo_bolhas_paradas
	obstaculos.add_child(p)                     # fica junto dos obstaculos: para e some com eles
	p.configurar(conta, alturas_bolhas)
	p.respondeu.connect(_on_respondeu.bind(p))
	p.passou_sem_responder.connect(_on_passou_sem_responder.bind(p))
	_perguntas += 1
	_ultimo_centro = p.y_da_resposta            # o proximo buraco nasce perto da bolha certa
	hud.mostrar_pergunta(conta.expressao)


func _on_respondeu(acertou: bool, p: Node2D) -> void:
	if _motivo != "":
		return
	if acertou:
		_acertos += 1
		_particulas(player.position, [Color("fff8ec"), Color("8fd3ff")], 12, 80.0, 0.0)
		_somar(pontos_acerto * _mult, "CERTO!", Color("9be08a"))
		hud.resposta_pergunta(true, p.conta.expressao, p.conta.resposta)
		_contar_progresso()
	else:
		_errou_conta(p.conta)
	_sair_modo_pergunta()


func _on_passou_sem_responder(p: Node2D) -> void:
	if _motivo != "":
		return
	_errou_conta(p.conta)
	_sair_modo_pergunta()


## Errou ou nao respondeu: mostra a resposta certa e o multiplicador volta para x1.
func _errou_conta(conta: Dictionary) -> void:
	_seq_perfeitos = 0
	_atualizar_mult()
	hud.resposta_pergunta(false, conta.expressao, conta.resposta)
	if erro_encerra_jogo:
		_conta_errada = conta
		_on_bateu("conta")      # derruba o gato; a tela de fim explica a conta
	else:
		_texto_flutuante("ERROU!", Color("e5786a"), Vector2(10, -24))


func _atualizar_mult() -> void:
	_mult = mini(1 + _seq_perfeitos / perfeitos_por_mult, mult_max)
	_maior_mult = maxi(_maior_mult, _mult)
	var cheios := perfeitos_por_mult if _mult >= mult_max else _seq_perfeitos % perfeitos_por_mult
	hud.combo(_mult, cheios, perfeitos_por_mult)


func _somar(ganho: int, texto: String, cor: Color) -> void:
	pontos += ganho
	hud.pontos(pontos)
	if pontos > recorde:
		recorde = pontos
		hud.recorde(recorde, true)
		if not _novo_recorde:
			_novo_recorde = true
			_texto_flutuante("RECORDE!", Color("f0b25a"), Vector2(-10, -44))
	_efeito_ponto("+%d %s" % [ganho, texto], cor)


func _pegou_folha(folha: Area2D) -> void:
	if _motivo != "" or player.state == 2:   # 2 = State.DEAD no player.gd
		return
	_folhas += 1
	_particulas(folha.global_position, [Color("d8f0a0"), Color("7cbf5a")], 10, 70.0, 0.0)
	folha.queue_free()
	_somar(pontos_folha * _mult, "FOLHA", Color("b8e08a"))


func _carregar_recorde() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		return int(cfg.get_value("jogo", "recorde", 0))
	return 0


func _salvar_recorde() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)      # mantem o que ja existe (ex.: skin escolhida)
	cfg.set_value("jogo", "recorde", recorde)
	cfg.save(SAVE_PATH)


# ---------- Obstaculos ----------

func _criar_obstaculo() -> void:
	# A cada N obstaculos, o proximo espaco vira uma coluna de bolhas com uma conta.
	if perguntas_ativas and _obstaculos_desde_pergunta >= obstaculos_entre_perguntas:
		_obstaculos_desde_pergunta = 0
		_entrar_modo_pergunta()
		return
	_obstaculos_desde_pergunta += 1
	var f: Dictionary = DADOS.FASES[fase]
	var o := OBSTACULO.instantiate()
	o.position.x = 310.0                        # nasce fora da tela, a direita
	o.velocidade = scenery.speed                # anda junto com o chao
	o.x_do_gato = player.position.x
	obstaculos.add_child(o)
	var centro := randf_range(centro_min, centro_max)
	if modo_luva and _ultimo_centro > 0.0:      # evita buraco muito longe do anterior
		centro = clampf(centro, _ultimo_centro - luva_variacao_max, _ultimo_centro + luva_variacao_max)
	_ultimo_centro = centro
	o.configurar(centro, abertura, f.cima.pick_random(), f.baixo.pick_random())
	o.bateu.connect(_on_bateu)
	o.passou.connect(_on_passou.bind(o))
	if randf() < chance_folha:
		_criar_folha(o)


## Folha no meio do buraco: anda junto com o obstaculo e flutua de leve.
func _criar_folha(o: Node2D) -> void:
	var folha := Area2D.new()
	folha.position = Vector2(0, (o.cima.position.y + o.baixo.position.y) / 2.0)
	var s := Sprite2D.new()
	s.texture = TEX_FOLHA
	s.scale = Vector2(2, 2)
	folha.add_child(s)
	var forma := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 10.0
	forma.shape = c
	folha.add_child(forma)
	o.add_child(folha)
	folha.body_entered.connect(func(b): if b is CharacterBody2D: _pegou_folha(folha))
	var tw := s.create_tween().set_loops()
	tw.tween_property(s, "position:y", -4.0, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(s, "position:y", 4.0, 0.5).set_trans(Tween.TRANS_SINE)


func _jogar_objeto() -> void:
	if modo_luva and fase < luva_aereos_desde_fase:
		_timer_aereo.start(randf_range(aereo_min, aereo_max))   # ainda nao: so reagenda
		return
	var p := PROJETIL.instantiate()
	obstaculos.add_child(p)
	var f: Dictionary = DADOS.FASES[fase]
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
	_ultimo_centro = player.position.y            # 1o buraco perto de onde o gato esta
	hud.comecou()
	_criar_obstaculo()
	_timer_obst.start()
	_timer_aereo.start(randf_range(aereo_min, aereo_max))


func _on_player_died() -> void:
	scenery.scrolling = false   # o mundo para quando o gato cai
	_parar_obstaculos()
	_poeira(player.position)
	hud.piscar(0.45)
	if _motivo == "":
		_tremer(3.0)                # bateu no chao
	if _novo_recorde:
		_salvar_recorde()
	hud.mostrar_fim(_montar_explicacao(_motivo))


func _montar_explicacao(tipo: String) -> Dictionary:
	var d := {
		"pontos": pontos, "recorde": recorde, "fase": fase, "total_fases": DADOS.FASES.size(),
		"perfeitos": _perfeitos, "folhas": _folhas, "maior_mult": _maior_mult,
		"novo_recorde": _novo_recorde, "acertos": _acertos, "perguntas": _perguntas,
	}
	if tipo == "conta":   # errou a conta (so acontece com erro_encerra_jogo ligado)
		d.titulo = "CONTA ERRADA!"
		d.aconteceu = "A bolha certa era a do %d." % _conta_errada.resposta
		d.importa_titulo = "A CONTA"
		d.importa = "%s = %d" % [_conta_errada.expressao, _conta_errada.resposta]
		d.ajudar_titulo = "DICA"
		d.ajudar = _conta_errada.dica
		d.icone = null
	elif DADOS.INFO.has(tipo):
		var i: Array = DADOS.INFO[tipo]
		d.titulo = i[0]
		d.aconteceu = i[1]
		d.importa_titulo = "POR QUE IMPORTA?"
		d.importa = i[2]
		d.ajudar_titulo = "COMO AJUDAR"
		d.ajudar = i[3]
		var caminho := "res://assets/ui/icones/%s.png" % i[4]
		d.icone = load(caminho) if ResourceLoader.exists(caminho) else null
	else:   # caiu no chao
		d.titulo = "O GATO CAIU!"
		d.aconteceu = "Faltou bater as asas a tempo."
		d.importa_titulo = "DICA VERDE"
		d.importa = DADOS.DICAS_VERDES.pick_random()
		d.ajudar_titulo = "DICA DE JOGO"
		d.ajudar = DADOS.DICAS_JOGO.pick_random()
		d.icone = TEX_FOLHA
	return d


func _on_player_restarted() -> void:
	_parar_obstaculos()
	_limpar_obstaculos()
	if fase != fase_inicial or scenery.scene_file_path != DADOS.FASES[fase_inicial].cenario.resource_path:
		fase = fase_inicial
		_trocar_cenario(fase, false)
	scenery.scrolling = true
	pontos = 0
	_passados_fase = 0
	_seq_perfeitos = 0
	_mult = 1
	_maior_mult = 1
	_perfeitos = 0
	_folhas = 0
	_novo_recorde = false
	_motivo = ""
	_obstaculos_desde_pergunta = 0
	_acertos = 0
	_perguntas = 0
	_conta_errada = {}
	_em_pergunta = false
	hud.inicio(recorde, fase, DADOS.FASES.size(), pontos_por_fase)


# ---------- Efeitos ----------

## Treme a tela (move o mundo; a interface fica parada).
func _tremer(forca: float) -> void:
	var tw := create_tween()
	for i in 6:
		tw.tween_property(self, "position", Vector2(randf_range(-forca, forca), randf_range(-forca, forca)), 0.04)
		forca *= 0.75
	tw.tween_property(self, "position", Vector2.ZERO, 0.04)


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


func _efeito_ponto(texto: String, cor: Color) -> void:
	_particulas(player.position + Vector2(6, 0), [cor, Color("9be08a")], 8, 60.0, 0.0)
	_texto_flutuante(texto.strip_edges(), cor, Vector2(10, -24))


## Texto que sobe e some perto do gato ("+2 PERFEITO!", "RECORDE!"...).
func _texto_flutuante(texto: String, cor: Color, deslocamento: Vector2) -> void:
	var l := Label.new()
	l.text = texto
	var ls := LabelSettings.new()
	ls.font_size = 8
	ls.font_color = cor
	ls.outline_size = 3
	ls.outline_color = Color("8a5f4a")
	l.label_settings = ls
	l.position = player.position + deslocamento
	l.position.x = minf(l.position.x, 288.0 - texto.length() * 8.0 - 4.0)   # nao sai da tela
	efeitos.add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 22.0, 0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)
