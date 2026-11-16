extends CharacterBody2D
## Personagem do Flappy: gravidade, impulso ao tocar, inclinação e animação.
## As skins são uma spritesheet horizontal (ex.: reizinho_lado.png = 4 quadros).

signal started   ## primeiro toque: sai do modo "parado"
signal flapped   ## a cada impulso
signal died      ## bateu no chão
signal restarted ## voltou ao estado parado

enum State { IDLE, FLYING, DEAD }

@export_group("Física")
@export var gravity: float = 1000.0
@export var flap_velocity: float = -300.0
@export var max_fall_speed: float = 480.0
@export var ceiling_y: float = 8.0          ## não deixa sair pelo topo da tela

@export_group("Inclinação")
@export var tilt_up_deg: float = -25.0      ## bico para cima ao subir
@export var tilt_down_deg: float = 80.0     ## mergulho ao cair
@export var tilt_speed: float = 8.0

@export_group("Animação / Skin")
@export var skin_texture: Texture2D: set = set_skin_texture
@export var skin_frames: int = 4: set = set_skin_frames
@export var anim_fps: float = 8.0
@export var flap_anim_fps: float = 18.0     ## bate as asas mais rápido logo após o impulso
@export var idle_bob_amount: float = 4.0
@export var idle_bob_speed: float = 5.0

@onready var sprite: Sprite2D = $Sprite2D

var state: State = State.IDLE
var _start_pos: Vector2
var _anim_time := 0.0
var _boost_time := 0.0
var _idle_time := 0.0
var _can_restart := false


func _ready() -> void:
	_start_pos = position
	_apply_skin()


## Troca de skin em tempo de execução (usado mais pra frente no seletor de skins).
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


func _unhandled_input(event: InputEvent) -> void:
	if not _is_flap_input(event):
		return
	match state:
		State.IDLE:
			state = State.FLYING
			started.emit()
			flap()
		State.FLYING:
			flap()
		State.DEAD:
			if _can_restart:
				reset()


func _is_flap_input(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_UP, KEY_W]
	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return event.pressed
	return false


func flap() -> void:
	velocity.y = flap_velocity
	_boost_time = 0.25
	_squash()
	flapped.emit()


func _squash() -> void:
	sprite.scale = Vector2(0.85, 1.15)
	create_tween().tween_property(sprite, "scale", Vector2.ONE, 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	match state:
		State.IDLE:
			_idle_time += delta
			position.y = _start_pos.y + sin(_idle_time * idle_bob_speed) * idle_bob_amount
			rotation = 0.0
		State.FLYING:
			_apply_gravity(delta)
			move_and_slide()
			if position.y < ceiling_y:
				position.y = ceiling_y
				velocity.y = max(velocity.y, 0.0)
			_update_tilt(delta)
			if is_on_floor():
				_die()
		State.DEAD:
			if not is_on_floor():
				_apply_gravity(delta)
				move_and_slide()
			rotation = lerp_angle(rotation, deg_to_rad(90.0), tilt_speed * delta)


func _apply_gravity(delta: float) -> void:
	velocity.x = 0.0
	velocity.y = min(velocity.y + gravity * delta, max_fall_speed)


func _update_tilt(delta: float) -> void:
	# Mapeia a velocidade vertical para um ângulo: subindo = bico pra cima, caindo = mergulho.
	var t := inverse_lerp(flap_velocity, max_fall_speed, velocity.y)
	var target := deg_to_rad(lerpf(tilt_up_deg, tilt_down_deg, clampf(t, 0.0, 1.0)))
	# Ao subir, gira rápido; ao cair, gira mais devagar (sensação clássica).
	var speed := tilt_speed * (2.0 if target < rotation else 1.0)
	rotation = lerp_angle(rotation, target, speed * delta)


func _process(delta: float) -> void:
	if state == State.DEAD:
		return
	_boost_time = max(0.0, _boost_time - delta)
	var fps := flap_anim_fps if _boost_time > 0.0 else anim_fps
	_anim_time += delta * fps
	sprite.frame = int(_anim_time) % skin_frames


## Chamado pelos obstaculos (fios, lixo, vidro, garrafa, papel) quando encostam no gato.
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
	sprite.frame = 0
	restarted.emit()
