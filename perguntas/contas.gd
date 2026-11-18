extends RefCounted
## Sorteia as contas de matematica das bolhas de resposta.
## O nivel acompanha a fase: 0 = Rua do Nordeste, 1 = Fortaleza, 2 = Rio de Janeiro.
##
## Devolve um Dictionary assim:
##   {"expressao": "7 + 5", "resposta": 12, "opcoes": [13, 12, 10], "dica": "..."}
## "opcoes" ja vem embaralhada e sempre contem a resposta certa.
##
## Uso (sem precisar instanciar): CONTAS.sortear(fase)

const QUANTAS_OPCOES := 3


static func sortear(nivel: int) -> Dictionary:
	var conta: Dictionary
	if nivel <= 0:
		conta = _soma_ou_subtracao(1, 9)
	elif nivel == 1:
		conta = _soma_ou_subtracao(5, 15)
	else:
		conta = _multiplicacao(2, 9)
	conta.opcoes = _montar_opcoes(conta.resposta, conta.erros)
	conta.erase("erros")   # so servia para montar as opcoes
	return conta


static func _soma_ou_subtracao(minimo: int, maximo: int) -> Dictionary:
	var a := randi_range(minimo, maximo)
	var b := randi_range(minimo, maximo)
	var resposta: int
	var expressao: String
	var dica: String
	if randf() < 0.5:
		resposta = a + b
		expressao = "%d + %d" % [a, b]
		dica = "Para somar, comece pelo número maior e conte para frente."
	else:
		# o maior numero vem primeiro para o resultado nunca ficar negativo
		var maior := maxi(a, b)
		var menor := mini(a, b)
		resposta = maior - menor
		expressao = "%d - %d" % [maior, menor]
		dica = "Para subtrair, comece pelo primeiro número e conte para trás."
	# respostas erradas parecidas com a certa: errar a contagem por 1, 2 ou 3
	var erros := [resposta - 3, resposta - 2, resposta - 1, resposta + 1, resposta + 2, resposta + 3]
	return {"expressao": expressao, "resposta": resposta, "erros": erros, "dica": dica}


static func _multiplicacao(minimo: int, maximo: int) -> Dictionary:
	var a := randi_range(minimo, maximo)
	var b := randi_range(minimo, maximo)
	var resposta := a * b
	# erros comuns na tabuada: pegar o vizinho (a x (b-1) ou a x (b+1)) ou errar por 1
	var erros := [a * (b - 1), a * (b + 1), resposta - 1, resposta + 1]
	var dica := "%d x %d é o mesmo que somar o %d, %d vezes." % [a, b, a, b]
	return {"expressao": "%d x %d" % [a, b], "resposta": resposta, "erros": erros, "dica": dica}


## Junta a resposta certa com algumas erradas sorteadas (sem repetir e sem negativos).
static func _montar_opcoes(resposta: int, erros: Array) -> Array:
	var candidatos := erros.duplicate()
	candidatos.shuffle()
	var opcoes := [resposta]
	for valor in candidatos:
		if opcoes.size() >= QUANTAS_OPCOES:
			break
		if valor < 0 or opcoes.has(valor):
			continue
		opcoes.append(valor)
	opcoes.shuffle()   # a certa nao fica sempre na mesma bolha
	return opcoes
