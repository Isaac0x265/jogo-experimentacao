extends Node
## Recebe a distância da TechGlove por UDP.
## Formato esperado: {"distancia": 12.5} (cm)

signal troca_de_referencia(nova_distancia_cm: float)

const PORTA := 5005
const TEMPO_SEM_DADOS := 1.0

@export_group("Filtro do sensor")

## Quantas leituras entram no filtro de mediana.
## 5 é um bom equilíbrio entre estabilidade e resposta.
@export var tamanho_janela_mediana := 5

## Suavização quando a mão está quase parada.
## Menor = mais estável, porém mais lento.
@export_range(0.01, 1.0, 0.01) var filtro_lento := 0.08

## Suavização durante movimentos grandes.
## Maior = responde mais rápido à mão.
@export_range(0.01, 1.0, 0.01) var filtro_rapido := 0.45

## Diferença necessária para considerar que a mão está realmente se movendo.
@export var movimento_rapido_cm := 3.0

@export_group("Troca de superfície")

## Salto mínimo para detectar mesa, perna, chão etc.
@export var salto_minimo_cm := 10.0

## Velocidade mínima para considerar uma troca de referência.
@export var velocidade_salto_cm_s := 250.0


var udp := PacketPeerUDP.new()

## Leitura bruta recebida do sensor.
var distancia_cm: float = 0.0

## Leitura após mediana, antes do filtro final.
var distancia_filtrada: float = 0.0

## Leitura final: é esta que o Player deve usar.
var distancia_suave: float = 0.0

var conectado := false

var _ultimo_pacote := -100.0
var _ultima_leitura_bruta := -1.0
var _tempo_ultima_leitura := -1.0

var _amostras: Array[float] = []


func _ready() -> void:
	var erro := udp.bind(PORTA, "127.0.0.1")

	if erro == OK:
		print("TechGlove: esperando dados na porta %d..." % PORTA)
	else:
		print("Erro ao abrir a porta %d: %s" % [PORTA, erro])


func _exit_tree() -> void:
	udp.close()


func _process(_delta: float) -> void:
	while udp.get_available_packet_count() > 0:
		var mensagem := udp.get_packet().get_string_from_utf8()
		var dados = JSON.parse_string(mensagem)

		if dados is Dictionary and dados.has("distancia"):
			var leitura_bruta := float(dados["distancia"])

			# Ignora zero, negativos e leituras absurdas.
			if leitura_bruta <= 0.0 or leitura_bruta >= 400.0:
				continue

			_processar_leitura(leitura_bruta)

	var agora := Time.get_ticks_msec() / 1000.0

	if conectado and agora - _ultimo_pacote > TEMPO_SEM_DADOS:
		conectado = false
		_ultima_leitura_bruta = -1.0
		_tempo_ultima_leitura = -1.0
		_amostras.clear()

		print("TechGlove: conexão perdida.")


func _processar_leitura(leitura_bruta: float) -> void:
	var agora := Time.get_ticks_msec() / 1000.0
	var estava_conectado := conectado
	var mudou_referencia := false
	var intervalo := 0.033

	if _tempo_ultima_leitura >= 0.0:
		intervalo = maxf(agora - _tempo_ultima_leitura, 0.001)

	# Detecta mudança brusca: mesa para chão, chão para perna etc.
	if estava_conectado and _ultima_leitura_bruta >= 0.0:
		var variacao_bruta := absf(leitura_bruta - _ultima_leitura_bruta)
		var velocidade_bruta := variacao_bruta / intervalo

		mudou_referencia = (
			variacao_bruta >= salto_minimo_cm
			and velocidade_bruta >= velocidade_salto_cm_s
		)

	distancia_cm = leitura_bruta
	conectado = true
	_ultimo_pacote = agora
	_ultima_leitura_bruta = leitura_bruta
	_tempo_ultima_leitura = agora

	if mudou_referencia:
		# Descarta valores da superfície anterior.
		_amostras.clear()
		_amostras.append(leitura_bruta)

		distancia_filtrada = leitura_bruta
		distancia_suave = leitura_bruta

		# O Player mantém a mesma altura visual e reposiciona sua âncora.
		troca_de_referencia.emit(leitura_bruta)
		return

	_adicionar_amostra(leitura_bruta)

	# A mediana elimina leituras isoladas erradas do ultrassônico.
	distancia_filtrada = _calcular_mediana()

	if not estava_conectado:
		distancia_suave = distancia_filtrada
		return

	# Quando há mudança maior, o filtro responde mais depressa.
	# Em pequenas oscilações, fica bem mais estável.
	var diferenca := absf(distancia_filtrada - distancia_suave)

	var intensidade_movimento := clampf(
		diferenca / movimento_rapido_cm,
		0.0,
		1.0
	)

	var fator_suavizacao := lerpf(
		filtro_lento,
		filtro_rapido,
		intensidade_movimento
	)

	distancia_suave = lerpf(
		distancia_suave,
		distancia_filtrada,
		fator_suavizacao
	)


func _adicionar_amostra(valor: float) -> void:
	_amostras.append(valor)

	while _amostras.size() > tamanho_janela_mediana:
		_amostras.pop_front()


func _calcular_mediana() -> float:
	if _amostras.is_empty():
		return distancia_cm

	var valores_ordenados: Array[float] = _amostras.duplicate()
	valores_ordenados.sort()

	var meio := valores_ordenados.size() / 2

	# Caso o tamanho seja ímpar, retorna o valor central.
	if valores_ordenados.size() % 2 == 1:
		return valores_ordenados[meio]

	# Caso seja par, usa a média dos dois valores centrais.
	return (valores_ordenados[meio - 1] + valores_ordenados[meio]) / 2.0
