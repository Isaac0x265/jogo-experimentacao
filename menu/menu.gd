extends Control
## Menu principal + tela de seleção de skins.
## Teclado: setas / W-S para mover, Enter ou Espaço para escolher, Esc para voltar,
## ← → para trocar de skin. Também funciona com mouse e toque.

const GAME_SCENE := "res://jogo/main.tscn"

const TEXT := Color("fff8ec")
const OUTLINE := Color("8a5f4a")
const HIGHLIGHT := Color("ffd27f")
const ITEM_SIZE := 16   # Press Start 2P fica nítida em múltiplos de 8

@onready var main_page: VBoxContainer = $MainPage
@onready var skins_page: Control = $SkinsPage
@onready var skins_options: VBoxContainer = $SkinsPage/Options
@onready var preview: Sprite2D = $SkinsPage/Frame/Preview
@onready var skin_name: Label = $SkinsPage/SkinName
@onready var skin_status: Label = $SkinsPage/Status
@onready var arrow_left: Label = $SkinsPage/ArrowLeft
@onready var arrow_right: Label = $SkinsPage/ArrowRight
@onready var cursor: Control = $Cursor
@onready var fade: ColorRect = $Fade

var _ls_normal := LabelSettings.new()
var _ls_selected := LabelSettings.new()
var _pages := {}               # página -> Array[Label]
var _page: Control
var _items: Array = []
var _index := 0
var _skin_index := 0
var _busy := false
var _t := 0.0


func _ready() -> void:
	for ls in [_ls_normal, _ls_selected]:
		ls.font_size = ITEM_SIZE
		ls.outline_size = 4
		ls.outline_color = OUTLINE
		ls.shadow_size = 0
		ls.shadow_color = Color(OUTLINE, 0.35)
		ls.shadow_offset = Vector2(1, 2)
	_ls_normal.font_color = TEXT
	_ls_selected.font_color = HIGHLIGHT

	_pages[main_page] = _make_items(main_page, [
		["JOGAR", func(): _go_to(GAME_SCENE)],
		["SKINS", func(): _show_page(skins_page)],
		["SAIR", func(): get_tree().quit()],
	])
	_pages[skins_page] = _make_items(skins_options, [
		["USAR", _equip_skin],
		["VOLTAR", func(): _show_page(main_page)],
	])

	arrow_left.gui_input.connect(_on_arrow_input.bind(-1))
	arrow_right.gui_input.connect(_on_arrow_input.bind(1))

	_skin_index = max(0, Skins.index_of(Skins.selected_id))
	_refresh_skin()
	_show_page(main_page)

	fade.modulate.a = 1.0
	create_tween().tween_property(fade, "modulate:a", 0.0, 0.4)


func _make_items(parent: Container, entries: Array) -> Array:
	var labels := []
	for e in entries:
		var l := Label.new()
		l.text = e[0]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.label_settings = _ls_normal
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.set_meta("action", e[1])
		l.mouse_entered.connect(_on_item_hover.bind(l))
		l.gui_input.connect(_on_item_input.bind(l))
		parent.add_child(l)
		labels.append(l)
	return labels


func _show_page(page: Control) -> void:
	_page = page
	main_page.visible = page == main_page
	skins_page.visible = page == skins_page
	_items = _pages[page]
	if page == skins_page:
		_skin_index = max(0, Skins.index_of(Skins.selected_id))
		_refresh_skin()
	_select(0)


func _select(i: int) -> void:
	_index = wrapi(i, 0, _items.size())
	for k in _items.size():
		_items[k].label_settings = _ls_selected if k == _index else _ls_normal


func _activate() -> void:
	if _busy or _items.is_empty():
		return
	var action: Callable = _items[_index].get_meta("action")
	action.call()


func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		return
	var handled := true
	if event.is_action_pressed("ui_up") or _is_key(event, KEY_W):
		_select(_index - 1)
	elif event.is_action_pressed("ui_down") or _is_key(event, KEY_S):
		_select(_index + 1)
	elif event.is_action_pressed("ui_accept"):
		_activate()
	elif event.is_action_pressed("ui_cancel") and _page == skins_page:
		_show_page(main_page)
	elif event.is_action_pressed("ui_left") and _page == skins_page:
		_cycle_skin(-1)
	elif event.is_action_pressed("ui_right") and _page == skins_page:
		_cycle_skin(1)
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _is_key(event: InputEvent, key: Key) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == key


func _on_item_hover(label: Label) -> void:
	var i := _items.find(label)
	if i >= 0:
		_select(i)


func _on_item_input(event: InputEvent, label: Label) -> void:
	if _is_click(event):
		_on_item_hover(label)
		_activate()


func _on_arrow_input(event: InputEvent, dir: int) -> void:
	if _is_click(event):
		_cycle_skin(dir)


func _is_click(event: InputEvent) -> bool:
	return (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)


# ---------- Skins ----------

func _cycle_skin(dir: int) -> void:
	if Skins.LIST.size() <= 1:
		return
	_skin_index = wrapi(_skin_index + dir, 0, Skins.LIST.size())
	_refresh_skin()


func _equip_skin() -> void:
	Skins.select(Skins.LIST[_skin_index].id)
	_refresh_skin()
	# Pulinho de feedback ao equipar
	preview.scale = Vector2(2.4, 1.7)
	create_tween().tween_property(preview, "scale", Vector2(2, 2), 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _refresh_skin() -> void:
	var s: Dictionary = Skins.LIST[_skin_index]
	preview.texture = s.front
	preview.hframes = s.frames
	skin_name.text = String(s.name).to_upper()
	skin_status.text = "EQUIPADO" if s.id == Skins.selected_id else "%d / %d" % [_skin_index + 1, Skins.LIST.size()]
	var many := Skins.LIST.size() > 1
	arrow_left.modulate.a = 1.0 if many else 0.35
	arrow_right.modulate.a = 1.0 if many else 0.35


# ---------- Animação / transição ----------

func _process(delta: float) -> void:
	_t += delta
	if skins_page.visible:
		preview.frame = int(_t * 6.0) % preview.hframes
		preview.position.y = 58 + roundf(sin(_t * 3.0) * 2.0)
	_update_cursor()


func _update_cursor() -> void:
	cursor.visible = not _items.is_empty()
	if not cursor.visible:
		return
	var l: Label = _items[_index]
	var w := l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, ITEM_SIZE).x
	var x := l.global_position.x + (l.size.x - w) * 0.5 - 18.0 + roundf(sin(_t * 6.0) * 2.0)
	var y := l.global_position.y + l.size.y * 0.5 - 5.0
	cursor.position = Vector2(x, y).round()


func _go_to(path: String) -> void:
	_busy = true
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, 0.35)
	tw.tween_callback(func(): get_tree().change_scene_to_file(path))
