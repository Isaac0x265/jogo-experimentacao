extends Area2D
## Uma bolha com um numero dentro. O gato escolhe a resposta voando ate ela.
## E desenhada por codigo (_draw), entao nao precisa de imagem.

signal tocada(bolha: Area2D)   ## o gato encostou nesta bolha

const RAIO := 22.0
const COR_AGUA := Color(0.6, 0.85, 1.0, 0.45)
const COR_CERTA := Color(0.608, 0.78, 0.478, 0.85)    # verde da barra de progresso
const COR_ERRADA := Color(0.898, 0.471, 0.416, 0.85)  # vermelho do multiplicador x4
const COR_BORDA := Color(1, 0.973, 0.925)             # creme do HUD
const COR_MARROM := Color(0.541, 0.373, 0.29)         # contorno do texto do HUD

var valor := 0
var _cor_fundo := COR_AGUA
var _tw_flutuar: Tween


func configurar(numero: int) -> void:
	valor = numero

	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = RAIO
	forma.shape = circulo
	add_child(forma)

	var texto := Label.new()
	texto.text = str(numero)
	var estilo := LabelSettings.new()
	estilo.font_size = 16
	estilo.font_color = COR_BORDA
	estilo.outline_size = 4
	estilo.outline_color = COR_MARROM
	texto.label_settings = estilo
	# caixa do tamanho da bolha, com o texto centralizado dentro
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	texto.size = Vector2(RAIO * 2.0, RAIO * 2.0)
	texto.position = Vector2(-RAIO, -RAIO)
	add_child(texto)

	# So conta se quem encostou foi o gato (CharacterBody2D), igual aos obstaculos.
	body_entered.connect(_on_body_entered)

	# sobe e desce de leve, como bolha de sabao
	var y_base := position.y
	_tw_flutuar = create_tween().set_loops()
	_tw_flutuar.tween_property(self, "position:y", y_base - 3.0, 0.6).set_trans(Tween.TRANS_SINE)
	_tw_flutuar.tween_property(self, "position:y", y_base + 3.0, 0.6).set_trans(Tween.TRANS_SINE)


func _on_body_entered(corpo: Node2D) -> void:
	if corpo is CharacterBody2D:
		tocada.emit(self)


func _draw() -> void:
	draw_circle(Vector2.ZERO, RAIO, _cor_fundo)
	draw_arc(Vector2.ZERO, RAIO, 0.0, TAU, 32, COR_BORDA, 2.0)
	draw_circle(Vector2(-RAIO * 0.45, -RAIO * 0.45), 3.0, COR_BORDA)   # brilho da bolha


## O gato tocou nesta bolha: fica verde ou vermelha, cresce e some.
func estourar(acertou: bool) -> void:
	_cor_fundo = COR_CERTA if acertou else COR_ERRADA
	queue_redraw()
	# set_deferred: nao pode desligar a colisao no meio do sinal de colisao
	set_deferred("monitoring", false)
	_tw_flutuar.kill()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.5, 1.5), 0.25)
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(hide)


## Mostra qual era a resposta certa quando o jogador errou.
func destacar_certa() -> void:
	_cor_fundo = COR_CERTA
	queue_redraw()
	set_deferred("monitoring", false)
	var tw := create_tween().set_loops(3)
	tw.tween_property(self, "scale", Vector2(1.25, 1.25), 0.15)
	tw.tween_property(self, "scale", Vector2.ONE, 0.15)
