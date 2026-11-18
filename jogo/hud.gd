extends CanvasLayer
## Interface do jogo: placar, multiplicador, progresso da fase, recorde,
## aviso de fase e a tela de derrota com a explicacao do problema ambiental.
## O main.gd so chama as funcoes publicas daqui.

const TELA := Vector2(288, 512)
const COR_PIP_VAZIO := Color(1, 0.973, 0.925, 0.35)
const CORES_MULT := {
	1: Color("fff8ec"),
	2: Color("9bc77a"),
	3: Color("f0b25a"),
	4: Color("e5786a"),
}

@onready var flash: ColorRect = $Flash
@onready var escurecer: ColorRect = $Escurecer
@onready var topo: Control = $Topo
@onready var fase_txt: Label = $Topo/FaseChip/VBox/Linha/FaseTxt
@onready var progresso_barra: ProgressBar = $Topo/FaseChip/VBox/Progresso
@onready var recorde_chip: PanelContainer = $Topo/RecordeChip
@onready var recorde_valor: Label = $Topo/RecordeChip/VBox/Valor
@onready var placar: PanelContainer = $Topo/Placar
@onready var pontos_lbl: Label = $Topo/Placar/HBox/Pontos
@onready var mult_lbl: Label = $Topo/Combo/Mult
@onready var pips: Array[ColorRect] = [$Topo/Combo/Pip1, $Topo/Combo/Pip2, $Topo/Combo/Pip3]
@onready var dica: VBoxContainer = $Dica
@onready var banner: PanelContainer = $FaseBanner
@onready var fim: PanelContainer = $Fim

var _pontos_exibidos := 0.0
var _mult_atual := 1
var _recorde_batido := false
var _tw_pontos: Tween
var _tw_banner: Tween
var _tw_rodape: Tween
var _tw_recorde: Tween

## Painel da conta de matematica ("7 + 5 = ?"). Criado por codigo em _criar_painel_pergunta().
const PERGUNTA_Y := 448.0                        # em cima do chao (chao em y=440), longe do aviso de fase
const COR_TEXTO_PERGUNTA := Color(0.541, 0.373, 0.29)   # marrom do HUD
const COR_ACERTO := Color(0.33, 0.56, 0.24)             # verde do "toque para tentar de novo"
const COR_ERRO := Color(0.78, 0.25, 0.2)                # vermelho do HUD
var _pergunta_painel: PanelContainer
var _pergunta_texto: Label
var _tw_pergunta: Tween


func _ready() -> void:
	banner.position.y = -80.0
	fim.visible = false
	escurecer.visible = false
	topo.visible = false
	_criar_painel_pergunta()


func _criar_painel_pergunta() -> void:
	_pergunta_painel = PanelContainer.new()
	# IGNORE: o painel nao pode "engolir" o clique do mouse que faz o gato voar
	_pergunta_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.992, 0.965, 0.914, 0.92)    # mesmo creme do placar
	fundo.border_color = COR_TEXTO_PERGUNTA
	fundo.set_border_width_all(2)
	fundo.set_corner_radius_all(4)
	fundo.set_content_margin_all(6)
	_pergunta_painel.add_theme_stylebox_override("panel", fundo)

	_pergunta_texto = Label.new()
	var estilo := LabelSettings.new()
	estilo.font_size = 16
	estilo.font_color = COR_TEXTO_PERGUNTA
	_pergunta_texto.label_settings = estilo
	_pergunta_painel.add_child(_pergunta_texto)

	add_child(_pergunta_painel)
	# logo acima do placar: o aviso de fase e a tela de fim continuam por cima dele
	move_child(_pergunta_painel, topo.get_index() + 1)
	_pergunta_painel.visible = false


# ---------- Estados ----------

## Tela de "pronto para voar".
func inicio(recorde: int, fase: int, total_fases: int, por_fase: int) -> void:
	fim.visible = false
	escurecer.visible = false
	dica.visible = true
	topo.visible = false
	_recorde_batido = false
	if _tw_banner: _tw_banner.kill()
	banner.position.y = -80.0
	_pontos_exibidos = 0.0
	pontos_lbl.text = "0"
	recorde_valor.text = str(recorde)
	recorde_chip.modulate = Color.WHITE
	combo(1, 0, 3)
	progresso(0, por_fase, fase, total_fases, true)
	esconder_pergunta()


## O gato comecou a voar: esconde a dica e o placar desce do topo.
func comecou() -> void:
	dica.visible = false
	topo.visible = true
	topo.position.y = -50.0
	create_tween().tween_property(topo, "position:y", 0.0, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------- Placar ----------

## Atualiza os pontos com contagem animada e um "pulinho" no placar.
func pontos(valor: int) -> void:
	if _tw_pontos: _tw_pontos.kill()
	_tw_pontos = create_tween()
	_tw_pontos.tween_method(_mostrar_pontos, _pontos_exibidos, float(valor), 0.35)
	_pular(placar, 1.25)


func _mostrar_pontos(v: float) -> void:
	_pontos_exibidos = v
	pontos_lbl.text = str(int(round(v)))
	# mantem o placar centralizado mesmo quando o numero cresce
	placar.reset_size()
	placar.position.x = roundf((TELA.x - placar.size.x) / 2.0)


func recorde(valor: int, novo: bool) -> void:
	recorde_valor.text = str(valor)
	if novo and not _recorde_batido:
		_recorde_batido = true
		# o chip do recorde fica piscando dourado enquanto voce supera o recorde
		_tw_recorde = create_tween().set_loops(4)
		_tw_recorde.tween_property(recorde_chip, "modulate", Color(1.15, 1.0, 0.6), 0.15)
		_tw_recorde.tween_property(recorde_chip, "modulate", Color.WHITE, 0.15)
	if novo:
		_pular(recorde_chip, 1.15)


## mult = multiplicador atual | cheios = bolinhas preenchidas rumo ao proximo
func combo(mult: int, cheios: int, por_mult: int) -> void:
	mult_lbl.text = "x%d" % mult
	mult_lbl.label_settings.font_color = CORES_MULT.get(mult, CORES_MULT[4])
	for i in pips.size():
		pips[i].visible = i < por_mult
		pips[i].color = CORES_MULT.get(min(mult + 1, 4), CORES_MULT[4]) if i < cheios else COR_PIP_VAZIO
	if mult > _mult_atual:
		_pular(mult_lbl, 1.8)
		piscar(0.25)
	_mult_atual = mult


func progresso(feitos: int, total: int, fase: int, total_fases: int, instantaneo := false) -> void:
	fase_txt.text = "%d/%d" % [fase + 1, total_fases]
	progresso_barra.max_value = total
	var alvo := float(mini(feitos, total))
	if instantaneo:
		progresso_barra.value = alvo
	else:
		create_tween().tween_property(progresso_barra, "value", alvo, 0.3)


# ---------- Aviso de fase ----------

func mostrar_fase(numero: int, nome: String) -> void:
	$FaseBanner/VBox/Topo/Numero.text = "FASE %d" % numero
	$FaseBanner/VBox/Nome.text = nome
	if _tw_banner: _tw_banner.kill()
	banner.position.y = -80.0
	_tw_banner = create_tween()
	_tw_banner.tween_property(banner, "position:y", 70.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw_banner.tween_interval(2.2)
	_tw_banner.tween_property(banner, "position:y", -80.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


# ---------- Pergunta de matematica ----------

## Mostra a conta que o jogador precisa responder, ex.: "7 + 5 = ?".
func mostrar_pergunta(expressao: String) -> void:
	if _tw_pergunta: _tw_pergunta.kill()    # cancela o "sumir" da resposta anterior
	_pergunta_texto.text = "%s = ?" % expressao
	_pergunta_texto.label_settings.font_color = COR_TEXTO_PERGUNTA
	_pergunta_painel.visible = true
	_centralizar_pergunta()
	_pular(_pergunta_painel, 1.2)


## Depois de responder: mostra a conta completa em verde (acertou) ou vermelho (errou) e some.
func resposta_pergunta(acertou: bool, expressao: String, resposta: int) -> void:
	if _tw_pergunta: _tw_pergunta.kill()
	_pergunta_texto.text = "%s = %d" % [expressao, resposta]
	_pergunta_texto.label_settings.font_color = COR_ACERTO if acertou else COR_ERRO
	_pergunta_painel.visible = true
	_centralizar_pergunta()
	_pular(_pergunta_painel, 1.3)
	_tw_pergunta = create_tween()
	_tw_pergunta.tween_interval(1.5)
	_tw_pergunta.tween_callback(esconder_pergunta)


func esconder_pergunta() -> void:
	if _tw_pergunta: _tw_pergunta.kill()
	_pergunta_painel.visible = false


func _centralizar_pergunta() -> void:
	_pergunta_painel.reset_size()   # ajusta o tamanho ao texto novo
	_pergunta_painel.position = Vector2(roundf((TELA.x - _pergunta_painel.size.x) / 2.0), PERGUNTA_Y)


# ---------- Tela de derrota ----------

## info: icone, titulo, aconteceu, importa_titulo, importa, ajudar_titulo, ajudar,
##       pontos, recorde, fase, total_fases, perfeitos, folhas, maior_mult, novo_recorde
func mostrar_fim(info: Dictionary) -> void:
	if _tw_banner: _tw_banner.kill()
	banner.position.y = -80.0
	esconder_pergunta()

	var icone: TextureRect = $Fim/VBox/Icone
	var tex: Texture2D = info.get("icone")
	icone.visible = tex != null
	if tex:
		icone.texture = tex
		var k := clampf(floorf(64.0 / tex.get_height()), 1.0, 3.0)   # escala inteira: pixel art nitido
		icone.custom_minimum_size = tex.get_size() * k

	$Fim/VBox/Titulo.text = info.titulo
	$Fim/VBox/Aconteceu.text = info.aconteceu
	$Fim/VBox/ImportaTitulo.text = info.importa_titulo
	$Fim/VBox/Importa.text = info.importa
	$Fim/VBox/AjudarTitulo.text = info.ajudar_titulo
	$Fim/VBox/Ajudar.text = info.ajudar
	$Fim/VBox/Stats/Pontos/Valor.text = str(info.pontos)
	$Fim/VBox/Stats/Recorde/Valor.text = str(info.recorde)
	$Fim/VBox/Stats/Fase/Valor.text = "%d/%d" % [info.fase + 1, info.total_fases]
	# duas linhas: tudo numa linha so nao cabe no cartao
	var linha_bonus := "PERFEITOS %d  FOLHAS %d  MAX x%d" % [info.perfeitos, info.folhas, info.maior_mult]
	var linha_contas := "CONTAS CERTAS %d/%d" % [info.get("acertos", 0), info.get("perguntas", 0)]
	$Fim/VBox/Extra.text = linha_bonus + "\n" + linha_contas
	var novo: Label = $Fim/VBox/NovoRecorde
	novo.visible = info.novo_recorde

	escurecer.visible = true
	escurecer.modulate.a = 0.0
	fim.visible = true
	fim.reset_size()
	# centraliza o cartao no espaco abaixo do placar
	fim.position = Vector2(roundf((TELA.x - fim.size.x) / 2.0), roundf(maxf(52.0, 56.0 + (TELA.y - 56.0 - fim.size.y) / 2.0)))
	fim.pivot_offset = fim.size / 2.0
	fim.scale = Vector2(0.6, 0.6)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(escurecer, "modulate:a", 1.0, 0.3)
	tw.tween_property(fim, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# "toque para tentar de novo" piscando devagar
	var rodape: Label = $Fim/VBox/Rodape
	if _tw_rodape: _tw_rodape.kill()
	rodape.modulate.a = 1.0
	_tw_rodape = create_tween().set_loops()
	_tw_rodape.tween_property(rodape, "modulate:a", 0.35, 0.6)
	_tw_rodape.tween_property(rodape, "modulate:a", 1.0, 0.6)
	if info.novo_recorde:
		novo.pivot_offset = Vector2(novo.size.x / 2.0, 4)
		var tn := create_tween().set_loops(3)
		tn.tween_property(novo, "scale", Vector2(1.2, 1.2), 0.2)
		tn.tween_property(novo, "scale", Vector2.ONE, 0.2)


# ---------- Efeitos ----------

## Clarao rapido na tela inteira.
func piscar(intensidade: float) -> void:
	flash.modulate.a = intensidade
	create_tween().tween_property(flash, "modulate:a", 0.0, 0.35)


func _pular(c: Control, forca: float) -> void:
	c.pivot_offset = c.size / 2.0
	c.scale = Vector2(forca, forca)
	create_tween().tween_property(c, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
