extends CharacterBody2D
## Personagem controlado diretamente pela altura da TechGlove.
## A distância da mão define a altura do Player na tela.
## Também aceita o mouse (tecla M liga/desliga): o Player segue a altura do cursor.

signal started
signal died
signal restarted

enum State { IDLE, FLYING, DEAD }

@export_group("Física")
@export var gravity: float = 1000.0
@export var max_fall_speed: float = 480.0

@export_group("Controle proporcional pela TechGlove")

## Amplitude física usada pela régua virtual da luva.
@export var amplitude_luva_cm: float = 25.0

## Limites de altura na tela.
## Ajuste conforme a posição do teto e do chão da sua fase.
@export var altura_teto_y: float = 35.0
@export var altura_chao_y: float = 500.0

## Quão rápido o personagem acompanha a mão.
@export var velocidade_seguimento: float = 1100.0

@export_group("Controle por mouse")

## Tecla que liga/desliga o controle pelo mouse (a luva continua funcionando quando desligado).
@export var tecla_alternar_mouse: Key = KEY_M

## Começa o jogo com o mouse já ativo?
@export var mouse_ativo_no_inicio: bool = false

@export_group("Inclinação")
@export var tilt_up_deg: float = -25.0
@export var tilt_down_deg: float = 80.0
@export var tilt_speed: float = 8.0

@export_group("Animação / Skin")
@export var skin_texture: Texture2D: set = set_skin_texture
@export var skin_frames: int = 4: set = set_skin_frames
@export var anim_fps: float = 8.0
@export var idle_bob_amount: float = 4.0
@export var idle_bob_speed: float = 5.0

@onready var tech_glove = get_node_or_null("../TechGlove")
@onready var sprite: Sprite2D = $Sprite2D

var state: State = State.IDLE
var _start_pos: Vector2

var _anim_time := 0.0
var _idle_time := 0.0
var _can_restart := false

## Início da faixa física virtual.
## Ex.: se for 10, a faixa atual vai de 10 cm até 35 cm.
var _inicio_faixa_cm := 0.0
var _controle_luva_pronto := false

## Controle por mouse: o personagem acompanha a altura do cursor.
var controle_mouse := false
var _mouse_iniciou := false
var _aviso: Label
var _indicador: Label
var _aviso_tween: Tween


func _ready() -> void:
	_start_pos = position
	_apply_skin()
	_criar_avisos_mouse()

	if mouse_ativo_no_inicio:
		alternar_controle_mouse()

	if tech_glove != null and tech_glove.has_signal("troca_de_referencia"):
		tech_glove.troca_de_referencia.connect(_ao_trocar_referencia)


func set_skin(texture: Texture2D, frames: int) -> void:
	skin_texture = texture
	skin_frames = frames


func set_skin_texture(value: Texture2D) -> void:
	skin_texture = value

	if is_node_ready():
		_apply_skin()


func set_skin_frames(value: int) -> void:
	skin_frames = max(1, value)

	if is_node_ready():
		_apply_skin()


func _apply_skin() -> void:
	if skin_texture:
		sprite.texture = skin_texture

	sprite.hframes = skin_frames
	sprite.frame = 0


## A TechGlove detectou troca brusca de mesa/chão.
## A nova escala é posicionada para preservar a posição atual do personagem.
func _ao_trocar_referencia(nova_distancia_cm: float) -> void:
	if _controle_luva_pronto and state != State.DEAD:
		_reancorar_faixa(nova_distancia_cm)


func _reancorar_faixa(nova_distancia_cm: float) -> void:
	var porcentagem_altura := inverse_lerp(
		altura_teto_y,
		altura_chao_y,
		position.y
	)

	porcentagem_altura = clampf(porcentagem_altura, 0.0, 1.0)

	# A nova distância passa a representar a mesma altura visual.
	_inicio_faixa_cm = nova_distancia_cm - porcentagem_altura * amplitude_luva_cm


func controlar_altura_com_luva(delta: float) -> void:
	if tech_glove == null or not tech_glove.conectado:
		return

	var distancia: float = tech_glove.distancia_suave

	# Primeira leitura: cria uma faixa centrada na posição atual.
	if not _controle_luva_pronto:
		_reancorar_faixa(distancia)
		_controle_luva_pronto = true

	# Caso a mão saia gradualmente da faixa de 25 cm,
	# a faixa acompanha a mão sem teletransportar o personagem.
	if distancia < _inicio_faixa_cm:
		_inicio_faixa_cm = distancia

	elif distancia > _inicio_faixa_cm + amplitude_luva_cm:
		_inicio_faixa_cm = distancia - amplitude_luva_cm

	var porcentagem_mao := clampf(
		(distancia - _inicio_faixa_cm) / amplitude_luva_cm,
		0.0,
		1.0
	)

	# Distância menor = mão mais perto da superfície = Player mais alto.
	var altura_alvo := lerpf(altura_chao_y,
	 altura_teto_y,
	 porcentagem_mao)

	var proxima_altura := move_toward(
		position.y,
		altura_alvo,
		velocidade_seguimento * delta
	)

	velocity.x = 0.0
	velocity.y = (proxima_altura - position.y) / maxf(delta, 0.001)

	if state == State.IDLE:
		state = State.FLYING
		started.emit()


func _unhandled_input(event: InputEvent) -> void:
	# Tecla M (configurável) liga/desliga o controle pelo mouse.
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == tecla_alternar_mouse:
		alternar_controle_mouse()
		return

	# Teclado, toque ou clique servem para reiniciar após morrer.
	if state == State.DEAD and _can_restart and _is_action_input(event):
		reset()
		return

	# Com o mouse ativo, o jogo começa quando o mouse se mexe (ou ao clicar).
	if controle_mouse and state == State.IDLE and not _mouse_iniciou:
		if event is InputEventMouseMotion and event.relative.length() > 2.0:
			_mouse_iniciou = true
		elif event is InputEventMouseButton and event.pressed:
			_mouse_iniciou = true


## Liga/desliga o controle por mouse. Desligado, a luva volta a mandar.
func alternar_controle_mouse() -> void:
	controle_mouse = not controle_mouse
	_mouse_iniciou = false

	# Ao voltar para a luva, a faixa é reancorada na altura atual (sem teletransporte).
	if not controle_mouse:
		_controle_luva_pronto = false

	if _indicador != null:
		_indicador.visible = controle_mouse

	var tecla := OS.get_keycode_string(tecla_alternar_mouse)
	if controle_mouse:
		_mostrar_aviso("MOUSE LIGADO  (%s desliga)" % tecla)
	else:
		_mostrar_aviso("MOUSE DESLIGADO  (%s liga)" % tecla)


func controlar_altura_com_mouse(delta: float) -> void:
	# Parado no início até o jogador mexer o mouse.
	if state == State.IDLE and not _mouse_iniciou:
		return

	var altura_alvo := clampf(
		get_global_mouse_position().y,
		altura_teto_y,
		altura_chao_y
	)

	var proxima_altura := move_toward(
		position.y,
		altura_alvo,
		velocidade_seguimento * delta
	)

	velocity.x = 0.0
	velocity.y = (proxima_altura - position.y) / maxf(delta, 0.001)

	if state == State.IDLE:
		state = State.FLYING
		started.emit()


func _criar_avisos_mouse() -> void:
	var camada := CanvasLayer.new()
	camada.layer = 50
	add_child(camada)

	var estilo := LabelSettings.new()
	estilo.font_size = 10
	estilo.font_color = Color(1, 0.973, 0.925, 1)
	estilo.outline_size = 4
	estilo.outline_color = Color(0.541, 0.373, 0.29, 1)

	# Aviso rápido ao ligar/desligar
	_aviso = Label.new()
	_aviso.label_settings = estilo
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.position = Vector2(0, 92)
	_aviso.size = Vector2(288, 16)
	_aviso.modulate.a = 0.0
	camada.add_child(_aviso)

	# Indicador fixo enquanto o mouse estiver ativo
	_indicador = Label.new()
	_indicador.label_settings = estilo
	_indicador.text = "MOUSE"
	_indicador.position = Vector2(8, 492)
	_indicador.visible = false
	camada.add_child(_indicador)


func _mostrar_aviso(texto: String) -> void:
	if _aviso == null:
		return

	_aviso.text = texto
	_aviso.modulate.a = 1.0

	if _aviso_tween != null:
		_aviso_tween.kill()

	_aviso_tween = create_tween()
	_aviso_tween.tween_interval(1.4)
	_aviso_tween.tween_property(_aviso, "modulate:a", 0.0, 0.4)


func _is_action_input(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo and event.keycode in [
			KEY_SPACE,
			KEY_UP,
			KEY_W,
			KEY_ENTER
		]

	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT

	if event is InputEventScreenTouch:
		return event.pressed

	return false


func _physics_process(delta: float) -> void:
	if state != State.DEAD:
		if controle_mouse:
			controlar_altura_com_mouse(delta)
		else:
			controlar_altura_com_luva(delta)

	match state:
		State.IDLE:
			_idle_time += delta
			position.y = _start_pos.y + sin(_idle_time * idle_bob_speed) * idle_bob_amount
			rotation = 0.0

		State.FLYING:
			move_and_slide()

			if position.y < altura_teto_y:
				position.y = altura_teto_y
				velocity.y = 0.0

			_update_tilt(delta)

			if is_on_floor():
				_die()

		State.DEAD:
			if not is_on_floor():
				_apply_gravity(delta)
				move_and_slide()

			rotation = lerp_angle(
				rotation,
				deg_to_rad(90.0),
				tilt_speed * delta
			)


func _apply_gravity(delta: float) -> void:
	velocity.x = 0.0
	velocity.y = min(
		velocity.y + gravity * delta,
		max_fall_speed
	)


func _update_tilt(delta: float) -> void:
	var t := inverse_lerp(
		-velocidade_seguimento,
		velocidade_seguimento,
		velocity.y
	)

	var target := deg_to_rad(
		lerpf(
			tilt_up_deg,
			tilt_down_deg,
			clampf(t, 0.0, 1.0)
		)
	)

	var speed := tilt_speed * (2.0 if target < rotation else 1.0)

	rotation = lerp_angle(
		rotation,
		target,
		speed * delta
	)


func _process(delta: float) -> void:
	if state == State.DEAD:
		return

	_anim_time += delta * anim_fps
	sprite.frame = int(_anim_time) % skin_frames


func hit() -> void:
	if state == State.FLYING:
		_die()


func _die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	_can_restart = false
	died.emit()

	await get_tree().create_timer(0.5).timeout
	_can_restart = true


func reset() -> void:
	state = State.IDLE
	position = _start_pos
	velocity = Vector2.ZERO
	rotation = 0.0
	_idle_time = 0.0
	_can_restart = false
	_controle_luva_pronto = false
	_mouse_iniciou = false
	sprite.frame = 0
	restarted.emit()
