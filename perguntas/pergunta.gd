extends Node2D
## Uma coluna de bolhas com respostas para a conta que aparece na tela.
## Anda para a esquerda junto com o chao, igual aos obstaculos (obstaculo.gd).
## O main.gd cria, chama configurar() e escuta os dois sinais abaixo.

signal respondeu(acertou: bool)    ## o gato tocou numa bolha (certa ou errada)
signal passou_sem_responder        ## a coluna passou e o gato nao tocou em nenhuma bolha

const BOLHA := preload("res://perguntas/bolha.gd")

var velocidade := 60.0       ## o main passa a mesma velocidade do chao (Scenery.speed)
var x_do_gato := 80.0
var conta: Dictionary = {}   ## a conta sorteada por contas.gd
var y_da_resposta := 0.0     ## altura da bolha certa (o main usa para posicionar o proximo buraco)
var _respondida := false
var _bolhas: Array = []


## nova_conta: resultado de contas.gd | alturas: um y para cada bolha
func configurar(nova_conta: Dictionary, alturas: Array) -> void:
	conta = nova_conta
	var opcoes: Array = conta.opcoes
	for i in opcoes.size():
		var bolha := BOLHA.new()
		bolha.position = Vector2(0, alturas[i])
		add_child(bolha)
		bolha.configurar(opcoes[i])
		bolha.tocada.connect(_on_bolha_tocada)
		_bolhas.append(bolha)
		if opcoes[i] == conta.resposta:
			y_da_resposta = alturas[i]


func _on_bolha_tocada(bolha: Area2D) -> void:
	if _respondida:   # so vale a primeira bolha tocada
		return
	_respondida = true
	var acertou: bool = bolha.valor == conta.resposta
	bolha.estourar(acertou)
	if not acertou:
		_mostrar_certa()
	respondeu.emit(acertou)


func _mostrar_certa() -> void:
	for bolha in _bolhas:
		if bolha.valor == conta.resposta:
			bolha.destacar_certa()


func _process(delta: float) -> void:
	position.x -= velocidade * delta
	# Espera a coluna passar inteira pelo gato antes de dizer que ele nao respondeu.
	var ja_passou_do_gato := position.x < x_do_gato - BOLHA.RAIO - 16.0
	if not _respondida and ja_passou_do_gato:
		_respondida = true
		_mostrar_certa()
		passou_sem_responder.emit()
	if position.x < -40.0:
		queue_free()
