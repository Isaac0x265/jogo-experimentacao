extends SceneTree
## Gera a pixel art das fases 2 (Fortaleza) e 3 (Rio de Janeiro): cenarios e obstaculos.
## Tudo e desenhado por codigo e e deterministico (sempre gera a mesma imagem).
##
## Como rodar (na pasta do projeto):
##   godot --headless --path . -s ferramentas/gerar_arte_fases23.gd
##
## Regras que o jogo espera (nao mude sem mexer no codigo):
##   - camadas do cenario: 576x512 (repetem na horizontal), ceu 288x512
##   - chao em y = 440 (colisao do Ground)
##   - obstaculos: mesmos tamanhos/quadros dos arquivos antigos
##   - "corpos" (galeria_corpo, entulho_corpo, baia_corpo, lama_corpo, balao_corpo)
##     repetem na vertical, entao sao desenhados "dando a volta" em cima/embaixo

const W := 576
const H := 512
const CHAO := 440
const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
const CEN_F := "res://assets/cenarios/fortaleza/"
const CEN_R := "res://assets/cenarios/rio/"
const OBS_F := "res://assets/obstaculos/fortaleza/"
const OBS_R := "res://assets/obstaculos/rio/"

## Fonte 3x5 (so as letras da placa)
const FONTE := {
	"I": ["111", "010", "010", "010", "111"],
	"M": ["10001", "11011", "10101", "10001", "10001"],
	"P": ["110", "101", "110", "100", "100"],
	"R": ["110", "101", "110", "101", "101"],
	"O": ["010", "101", "101", "101", "010"],
}

var rng := RandomNumberGenerator.new()


# =====================================================================
# Tela: uma imagem com funcoes de desenho em pixel
# =====================================================================
class Tela:
	var img: Image
	var w: int
	var h: int
	var wrap_x := false
	var wrap_y := false

	func _init(largura: int, altura: int, wx := false, wy := false) -> void:
		w = largura
		h = altura
		wrap_x = wx
		wrap_y = wy
		img = Image.create(w, h, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))

	func _p(x: int, y: int) -> Vector2i:
		if wrap_x: x = posmod(x, w)
		if wrap_y: y = posmod(y, h)
		return Vector2i(x, y)

	func _ok(p: Vector2i) -> bool:
		return p.x >= 0 and p.y >= 0 and p.x < w and p.y < h

	func px(x: int, y: int, c: Color) -> void:
		if c.a <= 0.0:
			return
		var p := _p(x, y)
		if not _ok(p):
			return
		if c.a >= 0.999:
			img.set_pixelv(p, c)
		else:
			var b := img.get_pixelv(p)
			img.set_pixelv(p, c if b.a <= 0.0 else b.blend(c))

	func cor(x: int, y: int) -> Color:
		var p := _p(x, y)
		if not _ok(p):
			return Color(0, 0, 0, 0)
		return img.get_pixelv(p)

	func cheio(x: int, y: int) -> bool:
		return cor(x, y).a > 0.0

	func rect(x: int, y: int, rw: int, rh: int, c: Color) -> void:
		for j in rh:
			for i in rw:
				px(x + i, y + j, c)

	func circ(cx: int, cy: int, r: int, c: Color) -> void:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if dx * dx + dy * dy <= r * r + r:
					px(cx + dx, cy + dy, c)

	func elip(cx: int, cy: int, rx: float, ry: float, c: Color) -> void:
		for dy in range(-int(ry) - 1, int(ry) + 2):
			for dx in range(-int(rx) - 1, int(rx) + 2):
				var v := (dx * dx) / (rx * rx + 0.01) + (dy * dy) / (ry * ry + 0.01)
				if v <= 1.05:
					px(cx + dx, cy + dy, c)

	func linha(x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
		var dx := absi(x1 - x0)
		var dy := -absi(y1 - y0)
		var sx := 1 if x0 < x1 else -1
		var sy := 1 if y0 < y1 else -1
		var err := dx + dy
		while true:
			px(x0, y0, c)
			if x0 == x1 and y0 == y1:
				break
			var e2 := 2 * err
			if e2 >= dy:
				err += dy
				x0 += sx
			if e2 <= dx:
				err += dx
				y0 += sy

	## Contorno de 1 px: pixel vazio encostado num cheio vira a cor do vizinho escurecida
	## (ou uma cor fixa). Isso e o que da o "peso" de pixel art aos sprites.
	func contorno(fixa := Color(0, 0, 0, 0), forca := 0.6) -> void:
		var novos := {}
		for y in h:
			for x in w:
				if cheio(x, y):
					continue
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var v := cor(x + d.x, y + d.y)
					if v.a > 0.5:
						novos[Vector2i(x, y)] = fixa if fixa.a > 0.0 else Color(v.darkened(forca), 1.0)
						break
		for p in novos:
			px(p.x, p.y, novos[p])

	func salvar(caminho: String) -> void:
		var erro := img.save_png(caminho)
		print(("OK   " if erro == OK else "ERRO ") + caminho)


# =====================================================================
# Utilitarios
# =====================================================================
func hx(s: String) -> Color:
	return Color(s)


func pal(lista: Array) -> Array:
	return lista.map(func(s): return Color(s))


func bayer(x: int, y: int) -> float:
	return (BAYER[posmod(y, 4)][posmod(x, 4)] + 0.5) / 16.0


## Escolhe uma cor da rampa com dithering ordenado (v vai de 0 ate pal.size()-1).
func rampa(p: Array, v: float, x: int, y: int) -> Color:
	v = clampf(v, 0.0, p.size() - 1.0)
	var b := int(floor(v))
	var i := b + (1 if v - b > bayer(x, y) else 0)
	return p[mini(i, p.size() - 1)]


## Halo com dithering em volta de um ponto (sol, chamas...).
func halo(t: Tela, cx: int, cy: int, r0: int, r1: int, forca: float, clarear := 0.3) -> void:
	for y in range(cy - r1, cy + r1 + 1):
		for x in range(cx - r1, cx + r1 + 1):
			var d := Vector2(x - cx, y - cy).length()
			if d > r0 and d <= r1:
				var a := (1.0 - (d - r0) / (r1 - r0)) * forca
				if bayer(x, y) < a:
					var atual := t.cor(x, y)
					if atual.a <= 0.0:   # fundo transparente (sprite): brilho alaranjado
						t.px(x, y, Color(1.0, 0.78, 0.35, 0.55))
					else:
						t.px(x, y, atual.lightened(clarear))


func nuvem(t: Tela, cx: int, cy: int, larg: int, cores: Array) -> void:
	# cores: [luz, base, sombra, sombra_baixo]
	var mask := {}
	var n := maxi(3, larg / 12)
	for i in n:
		var meio := i > 0 and i < n - 1
		var bx := cx - larg / 2 + int((i + 0.5) / n * larg)
		var r := rng.randi_range(5, 8) + (4 if meio else 0)
		var by := cy - int(r * 0.45) - (rng.randi_range(0, 3) if meio else 0)
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if dx * dx + dy * dy <= r * r + r and by + dy <= cy + 3:
					mask[Vector2i(bx + dx, by + dy)] = true
	for x in range(cx - larg / 2, cx + larg / 2 + 1):
		for y in range(cy, cy + 4):
			mask[Vector2i(x, y)] = true
	for p in mask:
		var c: Color = cores[1]
		if p.y >= cy:
			c = cores[2]
		if not mask.has(p + Vector2i(0, 1)):
			c = cores[3]
		elif not mask.has(p + Vector2i(-1, -2)) and p.y < cy:
			c = cores[0]
		t.px(p.x, p.y, c)


func passaro(t: Tela, x: int, y: int, c: Color) -> void:
	for p in [Vector2i(-3, 0), Vector2i(-2, 1), Vector2i(-1, 1), Vector2i(0, 2), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 0)]:
		t.px(x + p.x, y + p.y, c)


func palmeira(t: Tela, bx: int, by: int, altura: int, incl: float, folhas: Array) -> void:
	# folhas: [escura, media, clara]
	var tronco := pal(["b08758", "8f6a43", "6a4b2e", "5a3e25"])
	t.elip(bx + int(incl) + 2, by + 2, 14, 2, Color(0, 0, 0, 0.13))   # sombra no chao
	var topo := Vector2i(bx, by)
	for i in altura:
		var s := float(i) / altura
		var x := bx + int(round(incl * s * s))
		var y := by - i
		var larg := 4 if s < 0.55 else 3
		for k in larg:
			var c: Color = tronco[0] if k == 0 else (tronco[2] if k == larg - 1 else tronco[1])
			if i % 5 == 0:
				c = tronco[3] if k > 0 else tronco[2]
			t.px(x + k, y, c)
		topo = Vector2i(x + 1, y)
	# folhas: hastes curvas com foliolos caindo
	var angulos := [200.0, 165.0, 130.0, 95.0, 55.0, 20.0, -15.0]
	for a in angulos:
		var rad := deg_to_rad(a)
		var dir := Vector2(cos(rad), -sin(rad))
		var comp := rng.randf_range(20.0, 27.0)
		var caida := 0.25 if absf(a - 95.0) < 40.0 else 0.6
		var passos := int(comp * 1.6)
		for k in passos:
			var s := float(k) / passos
			var p := Vector2(topo) + dir * s * comp + Vector2(0, caida * s * s * comp)
			var tg := (dir + Vector2(0, 2.0 * caida * s)).normalized()
			var nrm := Vector2(-tg.y, tg.x)
			if nrm.y < 0:
				nrm = -nrm
			if k % 2 == 0 and s > 0.08:
				var fl := int(round(5.0 * (1.0 - s) + 2.0))
				for j in fl:
					var q1 := p + nrm * j + Vector2(0, j * 0.4)
					var q2 := p - nrm * j * 0.7 + Vector2(0, j * 0.5)
					t.px(int(q1.x), int(q1.y), folhas[0])
					t.px(int(q2.x), int(q2.y), folhas[1] if j < fl - 1 else folhas[2])
			t.px(int(p.x), int(p.y), folhas[1] if s > 0.15 else folhas[2])
	# cocos
	for o in [Vector2i(-3, 3), Vector2i(1, 4), Vector2i(4, 2)]:
		t.circ(topo.x + o.x, topo.y + o.y, 2, hx("6e4c22"))
		t.px(topo.x + o.x - 1, topo.y + o.y - 1, hx("a37a3a"))


# =====================================================================
# FASE 2 - FORTALEZA (Beira-Mar: mar verde-agua, jangadas, coqueiros)
# =====================================================================
const F_HORIZONTE := 292

func f_ceu() -> void:
	rng.seed = 201
	var t := Tela.new(288, 512)
	var p := pal(["3d7fc4", "4f95d2", "66aade", "82bfe6", "a3d3ec", "c4e4ef", "e2f0e8", "f6f2d6"])
	for y in 512:
		for x in 288:
			t.px(x, y, rampa(p, float(y) / F_HORIZONTE * (p.size() - 1), x, y))
	halo(t, 214, 118, 18, 46, 0.55, 0.22)
	t.circ(214, 118, 17, hx("fff3c8"))
	t.circ(214, 118, 15, hx("fffbe8"))
	t.salvar(CEN_F + "1_ceu.png")


func f_nuvens() -> void:
	rng.seed = 202
	var t := Tela.new(W, H, true)
	var cores := pal(["ffffff", "f2f8fb", "d3e4ef", "b2cde0"])
	for n in [[40, 70, 70], [150, 150, 46], [262, 52, 92], [372, 122, 60], [470, 40, 76], [528, 182, 42]]:
		nuvem(t, n[0], n[1], n[2], cores)
	for b in [[100, 110], [111, 104], [304, 172], [420, 92], [430, 98]]:
		passaro(t, b[0], b[1], hx("5a6670"))
	t.salvar(CEN_F + "0_nuvens.png")


func jangada(t: Tela, x: int, y: int, esc: float, vela: Color, faixa: Color) -> void:
	var hv := int(26 * esc)
	var lv := int(15 * esc)
	var lc := int(6 * esc) + 2
	# reflexo
	for k in range(-lc, lc + 1, 2):
		t.px(x + k, y + 3, hx("2a8aa0"))
	# casco
	t.rect(x - lc, y, lc * 2 + 1, maxi(1, int(2 * esc)), hx("6b4630"))
	t.rect(x - lc, y, lc * 2 + 1, 1, hx("8f6142"))
	# mastro
	t.linha(x, y, x, y - hv, hx("5a4030"))
	# vela (triangulo inclinado para tras, borda curva)
	for r in hv:
		var s := float(r) / hv
		var largura := int(round(s * lv * (1.0 - 0.18 * sin(PI * s))))
		var yy := y - hv + r
		for k in range(1, largura + 1):
			var c := vela
			if s > 0.45 and s < 0.62:
				c = faixa
			elif k == largura:
				c = vela.darkened(0.15)
			t.px(x + k, yy, c)


func f_mar() -> void:
	rng.seed = 203
	var t := Tela.new(W, H, true)
	# predios ao longe (Meireles / Mucuripe)
	var x := 300
	while x < 600:
		var lw := rng.randi_range(10, 20)
		var ph := rng.randi_range(18, 64)
		var fundo := rng.randf() < 0.4
		var cb := hx("b9d1de") if fundo else hx("9fbccd")
		t.rect(x, F_HORIZONTE - ph, lw, ph, cb)
		t.rect(x, F_HORIZONTE - ph, lw, 1, hx("d4e4ec"))
		t.rect(x + lw - 2, F_HORIZONTE - ph + 1, 2, ph - 1, cb.darkened(0.08))
		for wy in range(F_HORIZONTE - ph + 3, F_HORIZONTE - 2, 3):
			for wx in range(x + 2, x + lw - 2, 3):
				t.px(wx, wy, hx("d9e8ef") if rng.randf() < 0.7 else hx("86a6ba"))
		x += lw + rng.randi_range(-3, 4)
	# mar
	var p := pal(["dff4ee", "a6e0da", "7fd0cd", "5bbfc4", "3fabb9", "2f98ad", "2687a1"])
	for y in range(F_HORIZONTE, H):
		var v := pow(float(y - F_HORIZONTE) / (H - F_HORIZONTE), 0.8) * (p.size() - 1)
		for xx in W:
			t.px(xx, y, rampa(p, v, xx, y))
	t.rect(0, F_HORIZONTE, W, 1, hx("eefaf5"))
	for i in 520:
		var sy := F_HORIZONTE + 3 + int(pow(rng.randf(), 1.5) * 210)
		var sx := rng.randi_range(0, W)
		var comp := 1 + (sy - F_HORIZONTE) / 45
		t.rect(sx, sy, comp, 1, Color(hx("effcf8"), 0.85))
		t.rect(sx + 1, sy + 1, comp, 1, Color(hx("23809a"), 0.6))
	# Ponte dos Ingleses
	var x0 := 50
	var x1 := 250
	for px_ in range(x0, x1, 12):
		t.rect(px_, 334, 2, 19, hx("6b4630"))
		t.px(px_ + 1, 334, hx("4a2f20"))
		for k in range(353, 359, 2):
			t.rect(px_ - 1 + (k % 4) / 2, k, 3, 1, Color(hx("23809a"), 0.8))
	t.rect(x0, 330, x1 - x0, 1, hx("c99a6a"))
	t.rect(x0, 331, x1 - x0, 2, hx("9a6a42"))
	t.rect(x0, 333, x1 - x0, 1, hx("5f3f2a"))
	t.rect(x0, 325, x1 - x0 - 26, 1, hx("f2ede4"))
	for px_ in range(x0, x1 - 26, 5):
		t.rect(px_, 325, 1, 5, hx("f2ede4"))
	for px_ in range(x0 + 20, x1 - 26, 50):
		t.rect(px_, 315, 1, 15, hx("4a4a50"))
		t.rect(px_ - 1, 313, 3, 2, hx("fff2b0"))
	t.rect(x1 - 24, 318, 22, 12, hx("f2e8d5"))
	t.rect(x1 - 6, 318, 4, 12, hx("d8ccb5"))
	t.rect(x1 - 20, 321, 3, 3, hx("6fa8c8"))
	t.rect(x1 - 13, 322, 3, 8, hx("6b4630"))
	for r in 8:
		t.rect(x1 - 26 + r, 310 + r, 26 - r * 2, 1, hx("d0503a") if r < 7 else hx("9a3526"))
	# jangadas
	jangada(t, 120, 302, 0.4, hx("ffffff"), hx("e8604f"))
	jangada(t, 386, 314, 0.55, hx("f6ead0"), hx("d0503a"))
	jangada(t, 470, 352, 0.85, hx("ffffff"), hx("3a6fc4"))
	jangada(t, 296, 376, 1.05, hx("f2d38a"), hx("d0503a"))
	jangada(t, 18, 344, 0.7, hx("f8f4ea"), hx("3e9a52"))
	t.salvar(CEN_F + "2_mar.png")


func barraca(t: Tela, x: int, base: int) -> void:
	t.elip(x + 17, base + 2, 22, 2, Color(0, 0, 0, 0.13))
	# parede de madeira
	t.rect(x, base - 18, 34, 18, hx("b07a45"))
	for k in range(x + 3, x + 34, 4):
		t.rect(k, base - 18, 1, 18, hx("8f5f34"))
	t.rect(x + 32, base - 18, 2, 18, hx("7a4f2a"))
	t.rect(x + 4, base - 16, 26, 7, hx("5a3a26"))
	t.rect(x + 2, base - 9, 30, 2, hx("d4a066"))
	t.rect(x + 2, base - 7, 30, 1, hx("8f5f34"))
	for k in [8, 12, 16]:
		t.circ(x + k, base - 11, 2, hx("5f9e45"))
		t.px(x + k - 1, base - 12, hx("8cc46a"))
	t.rect(x + 22, base - 14, 2, 4, hx("f2ede4"))   # copo
	# telhado de palha
	for r in 13:
		var y := base - 30 + r
		var ex := 10 - int(r * 14 / 12.0)
		for k in range(x + ex - 2, x + 36 - ex):
			var c := hx("dcb862")
			if (k + y) % 3 == 0:
				c = hx("b8923f")
			if r < 2:
				c = hx("f0d483")
			t.px(k, y, c)
	for k in range(x - 4, x + 38):
		if k % 2 == 0:
			t.px(k, base - 17, hx("c9a14c"))
	t.rect(x + 10, base - 27, 15, 5, hx("e8473a"))
	t.rect(x + 10, base - 27, 15, 1, hx("f2786a"))
	for k in range(x + 12, x + 24, 3):
		t.rect(k, base - 25, 2, 1, hx("fff2e8"))


func guarda_sol(t: Tela, x: int, base: int, c1: Color, c2: Color) -> void:
	t.elip(x + 3, base + 2, 13, 2, Color(0, 0, 0, 0.15))
	t.linha(x, base, x, base - 27, hx("eae6dc"))
	t.linha(x + 1, base, x + 1, base - 27, hx("b9b4aa"))
	var cy := base - 27
	for dy in range(-8, 1):
		for dx in range(-15, 16):
			if (dx * dx) / 225.0 + (dy * dy) / 64.0 <= 1.0:
				var c := c1 if posmod(dx + 15, 10) < 5 else c2
				if dy == 0:
					c = c.darkened(0.25)
				elif dy < -5 and dx < 0:
					c = c.lightened(0.2)
				t.px(x + dx, cy + dy, c)
	for dx in range(-15, 16):
		if posmod(dx + 15, 5) == 2:
			t.px(x + dx, cy + 1, (c1 if posmod(dx + 15, 10) < 5 else c2).darkened(0.3))
	# cadeira de praia
	for k in 10:
		t.px(x + 6 + k, base - 3, c1 if k % 4 < 2 else hx("fffaf0"))
		t.px(x + 6 + k, base - 2, hx("8f6a43") if k % 9 == 0 else Color(0, 0, 0, 0))
	for k in 6:
		t.px(x + 16 + k / 2, base - 4 - k, c1 if k % 4 < 2 else hx("fffaf0"))


func f_orla() -> void:
	rng.seed = 204
	var t := Tela.new(W, H, true)
	for x in W:
		var fy := 402 + int(round(2.0 * sin(x * TAU / 48.0) + sin(x * TAU / 18.0 + 1.0)))
		t.px(x, fy - 2, Color(hx("c4f0ea"), 0.7))
		t.rect(x, fy - 1, 1, 3, hx("f5fcf9"))
		for y in range(fy + 2, H):
			var c := rampa(pal(["c9ae78", "d9be86", "e8cd96", "f0d6a0"]), (y - fy - 2) / 3.5, x, y)
			t.px(x, y, c)
		if x % 7 == 0:
			t.px(x, fy + 3, hx("eadcb7"))
	for k in range(0, W, 3):
		t.px(k + rng.randi_range(0, 2), rng.randi_range(416, 438), hx("e2c48c"))
	barraca(t, 70, 434)
	barraca(t, 336, 434)
	guarda_sol(t, 200, 436, hx("e8473a"), hx("fff6ea"))
	guarda_sol(t, 252, 434, hx("f2c230"), hx("3a6fc4"))
	guarda_sol(t, 470, 436, hx("3e9a52"), hx("fff6ea"))
	guarda_sol(t, 556, 434, hx("ee7d2e"), hx("fff6ea"))
	var folhas := pal(["2f7d3c", "4aa14f", "7fcb62"])
	palmeira(t, 30, 436, 118, 7.0, folhas)
	palmeira(t, 150, 436, 98, -9.0, folhas)
	palmeira(t, 296, 436, 128, 10.0, folhas)
	palmeira(t, 412, 436, 108, -6.0, folhas)
	palmeira(t, 518, 436, 122, 5.0, folhas)
	t.salvar(CEN_F + "3_orla.png")


func f_areia() -> void:
	rng.seed = 205
	var t := Tela.new(W, H, true)
	for y in range(CHAO, H):
		for x in W:
			var c := hx("f0d39c")
			var r := rng.randf()
			if r < 0.07:
				c = hx("e2c085")
			elif r < 0.12:
				c = hx("fae6bb")
			t.px(x, y, c)
	t.rect(0, CHAO, W, 1, hx("fff2cc"))
	t.rect(0, CHAO + 1, W, 1, hx("f8e2b0"))
	for linha_y in [452, 467, 482, 498]:
		for x in W:
			if posmod(x, 9) < 6:
				t.px(x, linha_y + int(round(1.5 * sin(x / 11.0 + linha_y))), hx("ddbb80"))
	for i in 40:
		var x := rng.randi_range(0, W)
		var y := rng.randi_range(CHAO + 6, H - 4)
		match rng.randi_range(0, 4):
			0:   # concha
				t.rect(x, y, 3, 2, hx("f6dcd4"))
				t.px(x + 1, y + 1, hx("d9a8a0"))
			1:   # estrela-do-mar
				for o in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
					t.px(x + o.x, y + o.y, hx("f08a4a"))
				t.px(x, y, hx("f8b07a"))
			2:   # pegadas
				t.rect(x, y, 2, 3, hx("dcba82"))
				t.rect(x + 4, y + 2, 2, 3, hx("dcba82"))
			3:   # pedrinha
				t.rect(x, y, 2, 1, hx("c8ad82"))
			_:   # alga
				t.px(x, y, hx("6b8a4a"))
				t.px(x + 1, y - 1, hx("5b7a3a"))
				t.px(x + 2, y, hx("6b8a4a"))
	t.salvar(CEN_F + "4_areia.png")


# =====================================================================
# FASE 3 - RIO DE JANEIRO (fim de tarde: Pao de Acucar, Cristo, favela, calcadao)
# =====================================================================
const R_HORIZONTE := 350

func r_ceu() -> void:
	rng.seed = 301
	var t := Tela.new(288, 512)
	var p := pal(["5a7fc0", "7590c9", "9a9fcf", "bfaacb", "dbb3b8", "efbfa4", "f8cf9a", "fbdca8"])
	for y in 512:
		for x in 288:
			t.px(x, y, rampa(p, float(y) / R_HORIZONTE * (p.size() - 1), x, y))
	halo(t, 150, 290, 18, 52, 0.6, 0.18)
	t.circ(150, 290, 17, hx("ffe2a8"))
	t.circ(150, 290, 15, hx("fff1cf"))
	t.salvar(CEN_R + "1_ceu.png")


func r_nuvens() -> void:
	rng.seed = 302
	var t := Tela.new(W, H, true)
	var cores := pal(["fff1e2", "fbe0cf", "e6bcc2", "c39cb8"])
	for n in [[60, 60, 110], [232, 132, 70], [336, 42, 90], [470, 100, 120], [548, 196, 50]]:
		nuvem(t, n[0], n[1], n[2], cores)
	for b in [[180, 96], [190, 90], [402, 160], [412, 166]]:
		passaro(t, b[0], b[1], hx("6b5a78"))
	t.salvar(CEN_R + "0_nuvens.png")


func onda(x: float, p1: float, p2: float, f1: int, f2: int) -> float:
	return sin(x / W * TAU * f1 + p1) * 0.6 + sin(x / W * TAU * f2 + p2) * 0.4


func r_baia() -> void:
	rng.seed = 303
	var t := Tela.new(W, H, true)
	# serras ao fundo (perspectiva atmosferica)
	for x in W:
		var y1 := int(296 - 20 * onda(x, 0.5, 1.3, 2, 5))
		for y in range(y1, R_HORIZONTE):
			t.px(x, y, hx("cdb8d4") if y == y1 else hx("b9a3c4"))
		var y2 := int(322 - 14 * onda(x, 2.0, 0.4, 3, 7))
		for y in range(y2, R_HORIZONTE):
			t.px(x, y, rampa(pal(["9d93ad", "8a8aa0"]), (y - y2) / 12.0, x, y))
	# Corcovado com o Cristo
	# perfil irregular: encosta longa a esquerda, paredao ingreme a direita
	var cx := 110
	var floresta := pal(["8a9b88", "778a78", "66796a", "57695c"])
	for dx in range(-120, 60):
		var top: float
		if dx < 0:
			top = 214 - dx * 0.62 + sin(dx * 0.21) * 3.0 + sin(dx * 0.07) * 5.0
		else:
			top = 214 + dx * 1.9 + sin(dx * 0.5) * 1.5
		var it := int(top)
		for y in range(it, R_HORIZONTE):
			var d := y - it
			var c: Color = rampa(floresta, 0.6 + d / 26.0 + (0.8 if dx > 2 else 0.0), cx + dx, y)
			if dx > -6 and dx < 24 and d < 34 - absi(dx - 8):   # rocha nua perto do pico
				c = hx("a39d97") if dx < 8 else hx("86807b")
			if d == 0:
				c = hx("a9b8a3") if dx < 0 else hx("7d8c7e")
			elif d < 3 and dx < 0 and bayer(cx + dx, y) < 0.5:
				c = floresta[0]
			t.px(cx + dx, y, c)
	# manchas de mata mais escura
	for i in 40:
		var mx := cx + rng.randi_range(-110, 40)
		var my := rng.randi_range(270, 345)
		if t.cor(mx, my).a > 0.0 and t.cor(mx, my - 4).a > 0.0:
			t.circ(mx, my, rng.randi_range(1, 3), floresta[3])
	var cristo := ["....#....", "....#....", "#########", "...###...", "...###...", "...###...", "...###...", "..#####..", "..#####.."]
	for r in cristo.size():
		for k in 9:
			if cristo[r][k] == "#":
				t.px(cx - 4 + k, 212 - 9 + r, hx("f2e3d6") if k < 5 else hx("c9b5ab"))
	# Morro da Urca e Pao de Acucar
	var rocha := pal(["c9b0a6", "a8928e", "8d7a7c", "7e6c72"])
	for dx in range(-36, 37):
		var top := int(300 + pow(absf(dx) / 36.0, 2.0) * 50)
		for y in range(top, R_HORIZONTE):
			var c := rampa(pal(["6f9068", "5e7d5c", "4c6a4c"]), (y - top) / 10.0 + (dx + 36) / 40.0, 395 + dx, y)
			if y - top < 2:
				c = hx("86a67c")
			t.px(395 + dx, y, c)
	for dx in range(-30, 31):
		var e := absf(dx) / 30.0 * (1.15 if dx > 0 else 1.0)
		var top := int(228 + pow(minf(e, 1.0), 1.8) * 122)
		for y in range(top, R_HORIZONTE):
			var lado := (dx + 30) / 60.0
			var c: Color = rocha[0] if lado < 0.3 else (rocha[1] if lado < 0.62 else rocha[3])
			if lado >= 0.3 and lado < 0.62 and bayer(465 + dx, y) < (lado - 0.3) * 1.2:
				c = rocha[2]
			if posmod(dx * 7 + 3, 11) == 0 and y > top + 4 and posmod(y + dx, 9) < 5:
				c = rocha[2]
			if y > 322 and bayer(465 + dx, y) < (y - 322) / 22.0:
				c = hx("5e7d5c") if lado < 0.6 else hx("4c6a4c")
			t.px(465 + dx, y, c)
	# bondinho
	t.linha(330, 344, 395, 301, hx("4a3f4a"))
	t.linha(395, 300, 458, 234, hx("4a3f4a"))
	for g in [[360, 325], [426, 268]]:
		t.px(g[0], g[1] + 1, hx("4a3f4a"))
		t.rect(g[0] - 1, g[1] + 2, 4, 3, hx("d64a3a"))
		t.px(g[0], g[1] + 3, hx("fff1cf"))
	# agua da baia
	var p := pal(["c9b8c8", "aeaabd", "93a0b5", "7894a5", "5d8296", "4a7086", "3b5f76"])
	for y in range(R_HORIZONTE, H):
		var v := pow(float(y - R_HORIZONTE) / (H - R_HORIZONTE), 0.75) * (p.size() - 1)
		for x in W:
			t.px(x, y, rampa(p, v, x, y))
	t.rect(0, R_HORIZONTE, W, 1, hx("e6d2d0"))
	for i in 480:
		var sy := R_HORIZONTE + 3 + int(pow(rng.randf(), 1.4) * 160)
		var sx := rng.randi_range(0, W)
		var comp := 1 + (sy - R_HORIZONTE) / 40
		t.rect(sx, sy, comp, 1, Color(hx("ffe6c4"), 0.8))
		t.rect(sx + 1, sy + 1, comp, 1, Color(hx("33556b"), 0.55))
	# barca Rio-Niteroi
	t.rect(286, 357, 40, 4, hx("f2efe8"))
	t.rect(286, 360, 40, 1, hx("d64a3a"))
	t.rect(286, 361, 40, 1, hx("4a4a55"))
	t.rect(294, 352, 24, 5, hx("e6e1d6"))
	for k in range(296, 316, 3):
		t.px(k, 354, hx("4a5a6a"))
	t.rect(304, 348, 4, 4, hx("d64a3a"))
	for k in range(-20, 0, 3):
		t.px(286 + k, 362 + (k % 2), Color(hx("ffffff"), 0.6))
	# veleiros
	for b in [[60, 368, 0.5], [214, 384, 0.7], [520, 374, 0.6]]:
		jangada(t, b[0], b[1], b[2], hx("fbf6ee"), hx("fbf6ee"))
	t.salvar(CEN_R + "2_baia.png")


func morro_y(x: float) -> float:
	var h := 0.0
	for m in [[150.0, 165.0, 128.0], [430.0, 175.0, 134.0], [292.0, 70.0, 56.0]]:
		var d := absf(fposmod(x - m[0] + W / 2.0, W) - W / 2.0)
		if d < m[1]:
			h = maxf(h, m[2] * (cos(PI * d / m[1]) * 0.5 + 0.5))
	return CHAO - h


func casa(t: Tela, x: int, base: int, lw: int, lh: int) -> void:
	var tijolo := rng.randf() < 0.55
	var pasteis := ["e8c47a", "9cc3d5", "e59a8a", "b9d39a", "f2e6d0", "d9a3c4", "f0a868"]
	var c := hx("b9643f") if tijolo else hx(pasteis[rng.randi_range(0, pasteis.size() - 1)])
	var topo := base - lh
	for y in range(topo, base):
		for k in lw:
			var cc := c
			if k >= lw - 2:
				cc = c.darkened(0.22)
			elif tijolo and posmod(k + (y / 2) * 2, 4) == 0 and y % 2 == 0:
				cc = hx("a85532")
			t.px(x + k, y, cc)
	t.rect(x, topo, 1, lh, c.darkened(0.45))
	# laje (cinza) ou telhado de barro
	if rng.randf() < 0.75:
		t.rect(x, topo - 1, lw, 1, hx("d8d2c8"))
		t.rect(x, topo, lw, 1, hx("9e968c"))
	else:
		t.rect(x - 1, topo - 2, lw + 2, 2, hx("b04a32"))
		t.rect(x - 1, topo - 2, lw + 2, 1, hx("cf6a48"))
	# janelas (algumas acesas no fim de tarde)
	for wx in range(x + 2, x + lw - 3, 4):
		t.rect(wx, topo + 3, 2, 2, hx("ffd27a") if rng.randf() < 0.18 else hx("3a3038"))
	if lh >= 9 and rng.randf() < 0.4:
		t.rect(x + lw - 5, base - 4, 2, 4, hx("4a3a32"))
	# caixa d'agua azul e antena
	var r := rng.randf()
	if r < 0.28:
		var cx := x + rng.randi_range(1, maxi(1, lw - 5))
		t.rect(cx, topo - 4, 4, 3, hx("4a86c0"))
		t.rect(cx, topo - 4, 4, 1, hx("7fb0dd"))
	elif r < 0.38:
		var ax := x + lw / 2
		t.rect(ax, topo - 5, 1, 4, hx("5a5560"))
		t.rect(ax - 2, topo - 4, 5, 1, hx("5a5560"))


func r_morro() -> void:
	rng.seed = 304
	var t := Tela.new(W, H, true)
	var verde := pal(["729561", "5f8050", "4f6d44"])
	for x in W:
		var top := int(morro_y(x))
		for y in range(top, CHAO):
			var c: Color = verde[1]
			var r := rng.randf()
			if r < 0.12:
				c = verde[2]
			elif r < 0.2:
				c = verde[0]
			if y - top < 1:
				c = hx("86a874")
			t.px(x, y, c)
	# copas de arvores na crista
	for i in 70:
		var x := rng.randi_range(0, W)
		var y := int(morro_y(x)) + rng.randi_range(0, 6)
		if y >= CHAO - 30:
			continue
		var r := rng.randi_range(3, 5)
		t.circ(x, y, r, verde[2])
		t.circ(x - 1, y - 1, r - 1, verde[1])
		t.px(x - r / 2, y - r + 1, hx("8cb878"))
	# casas em fileiras (de tras para frente, cada fileira cobre a de tras)
	var top_min := int(morro_y(150))
	for linha_y in range(top_min + 10, CHAO + 4, 8):
		var x := 0
		while x < W:
			var lw := rng.randi_range(8, 13)
			var lh := rng.randi_range(7, 10)
			if morro_y(x + lw / 2.0) < linha_y - 6 and rng.randf() > 0.12:
				casa(t, x, linha_y, lw, lh)
				x += lw + (1 if rng.randf() < 0.3 else 0)
			else:
				x += rng.randi_range(3, 8)
	# palmeiras imperiais na orla, na frente da favela
	var folhas := pal(["2f6b3a", "3f8a48", "6cb35a"])
	palmeira(t, 66, 438, 66, 3.0, folhas)
	palmeira(t, 300, 438, 72, -4.0, folhas)
	palmeira(t, 506, 438, 62, 4.0, folhas)
	t.salvar(CEN_R + "3_morro.png")


func r_calcadao() -> void:
	rng.seed = 305
	var t := Tela.new(W, H, true)
	t.rect(0, CHAO, W, 1, hx("f2ece2"))
	t.rect(0, CHAO + 1, W, 2, hx("d6cec2"))
	t.rect(0, CHAO + 3, W, 1, hx("9c9387"))
	for y in range(CHAO + 4, H):
		for x in W:
			var v := (y - CHAO - 4) + 5.0 * sin(x * TAU / 48.0)
			var preto := posmod(int(floor((v + 1000.0) / 7.0)), 2) == 0
			var c := hx("3b3540") if preto else hx("efe8db")
			if rng.randf() < 0.07:
				c = hx("4a434f") if preto else hx("e0d7c8")
			if y < CHAO + 7:
				c = c.darkened(0.08)
			t.px(x, y, c)
	t.salvar(CEN_R + "4_calcadao.png")


# =====================================================================
# OBSTACULOS - pecas reutilizaveis (lixo, tijolo, saco de rafia...)
# =====================================================================
func garrafa(t: Tela, x: int, y: int, deitada: bool, corpo: Color, rotulo: Color, tampa: Color) -> void:
	# garrafa PET pequena (3x8 em pe ou 8x3 deitada) com brilho, rotulo e tampa
	if deitada:
		t.rect(x, y, 7, 3, corpo)
		t.rect(x, y, 7, 1, corpo.lightened(0.45))
		t.rect(x + 2, y, 3, 3, rotulo)
		t.px(x + 7, y + 1, corpo)
		t.px(x + 8, y + 1, tampa)
	else:
		t.rect(x, y + 1, 3, 7, corpo)
		t.rect(x, y + 1, 1, 7, corpo.lightened(0.45))
		t.rect(x, y + 3, 3, 2, rotulo)
		t.px(x + 1, y, tampa)


func sacola_mini(t: Tela, x: int, y: int, w: int, h: int, cor: Color) -> void:
	t.elip(x + w / 2, y + h / 2, w / 2.0, h / 2.0, cor)
	for k in range(1, w - 1, 3):
		t.px(x + k, y + h / 2 - 1 + posmod(k, 2), cor.darkened(0.15))
	t.px(x + w - 2, y + h - 2, cor.darkened(0.25))
	t.px(x + 1, y + 1, cor.lightened(0.3))


func lata(t: Tela, x: int, y: int, cor: Color) -> void:
	t.rect(x, y, 3, 5, cor)
	t.rect(x, y, 3, 1, hx("d8dcdf"))
	t.px(x, y + 1, cor.lightened(0.35))
	t.px(x + 2, y + 3, cor.darkened(0.3))


func chinelo(t: Tela, x: int, y: int) -> void:
	t.rect(x, y + 1, 7, 2, hx("f2c230"))
	t.rect(x, y + 2, 7, 1, hx("c99a1c"))
	t.px(x + 2, y, hx("3a8a4a"))
	t.px(x + 3, y, hx("3a8a4a"))
	t.px(x + 4, y + 1, hx("3a8a4a"))


func isopor(t: Tela, x: int, y: int, w: int, h: int) -> void:
	t.rect(x, y, w, h, hx("f4f1e8"))
	t.rect(x, y, w, 1, hx("ffffff"))
	t.rect(x + w - 1, y + 1, 1, h - 1, hx("cfcabd"))
	for k in range(1, w - 1, 2):
		t.px(x + k, y + 1 + posmod(k, h - 1), hx("d9d4c8"))


func pneu(t: Tela, cx: int, cy: int, r: int) -> void:
	t.circ(cx, cy, r, hx("1e1e1e"))
	t.circ(cx, cy, r - 3, Color(0, 0, 0, 0))
	for a in 12:
		var ang := a * TAU / 12.0
		t.px(cx + int(round(cos(ang) * (r - 1))), cy + int(round(sin(ang) * (r - 1))), hx("3a3a3a"))
	t.px(cx - r + 1, cy - 2, hx("5a5a5a"))
	t.px(cx - 2, cy - r + 1, hx("5a5a5a"))


func furo_pneu(t: Tela, cx: int, cy: int, r: int, fundo: Color) -> void:
	t.circ(cx, cy, r - 3, fundo)


## Tijolo baiano (ceramica laranja com furos) - o tijolo mais comum nas obras do Nordeste
func bloco_baiano(t: Tela, x: int, y: int, quebrado := false) -> void:
	for j in 6:
		for i in 10:
			if quebrado and i + j > 12:
				continue
			var c := hx("c8642f")
			if j == 0: c = hx("de8150")
			elif j == 5 or i == 9: c = hx("98451f")
			t.px(x + i, y + j, c)
	for hy in [2, 4]:
		for hxx in [1, 4, 7]:
			if not (quebrado and hxx + hy > 9):
				t.rect(x + hxx, y + hy - 1, 2, 1, hx("5a2a14"))


## Saco de rafia branco cheio de entulho (o "saco de entulho" de obra)
func saco_rafia(t: Tela, x: int, y: int, w: int, h: int, listra: Color) -> void:
	for j in h:
		var recuo := 1 if (j == 0 or j == h - 1) else 0
		for i in range(recuo, w - recuo):
			var c := hx("ebe8de") if posmod(i + j, 2) == 0 else hx("d9d5c8")
			if j == h / 3:
				c = listra
			if i >= w - 2 or j >= h - 2:
				c = c.darkened(0.18)
			t.px(x + i, y + j, c)
	# pedacos de entulho aparecendo na boca do saco
	for k in range(2, w - 2, 3):
		t.px(x + k, y, hx("8f877a"))
		t.px(x + k + 1, y - 1, hx("c8642f") if k % 2 == 0 else hx("a39a8a"))


func entulho_fundo(t: Tela, x0: int, x1: int, y0: int, y1: int) -> void:
	var p := pal(["6f675c", "857c6f", "9a9182", "b0a796"])
	for y in range(y0, y1):
		for x in range(x0, x1):
			var c := rampa(p, 1.4 + sin(x * 1.3 + y * 0.7) * 0.9 + sin(y * 2.1 - x * 0.4) * 0.6, x, y)
			if posmod(x * 7 + y * 13, 23) == 0:
				c = hx("c8642f")
			t.px(x, y, c)


func vergalhao(t: Tela, x0: int, y0: int, x1: int, y1: int) -> void:
	t.linha(x0, y0, x1, y1, hx("7a3e22"))
	t.linha(x0 + 1, y0, x1 + 1, y1, hx("b06a3a"))


func sujeira_oleo(t: Tela, x0: int, x1: int, y0: int, y1: int) -> void:
	# agua escura com manchas de oleo furta-cor
	for y in range(y0, y1):
		for x in range(x0, x1):
			t.px(x, y, hx("1f2b2a") if bayer(x, y) < 0.65 else hx("2a3a37"))
	for i in int((x1 - x0) * (y1 - y0) / 18.0):
		var x := rng.randi_range(x0, x1 - 3)
		var y := rng.randi_range(y0, y1 - 1)
		var cores := ["6a4a8a", "3f7a6a", "8a7a3a", "5a6aa0"]
		t.rect(x, y, rng.randi_range(1, 3), 1, Color(hx(cores[rng.randi_range(0, 3)]), 0.75))


# =====================================================================
# OBSTACULOS - FORTALEZA
# =====================================================================

## Rede de pesca abandonada ("rede fantasma"): nylon emaranhado, algas,
## lixo e bichos presos - e uma tartaruga enroscada embaixo.
func o_rede() -> void:
	rng.seed = 411
	var t := Tela.new(32, 400)
	# cabos de borda (corda torcida)
	for y in 388:
		for lado in [5, 26]:
			var x: int = lado + int(round(sin(y * 0.045 + lado) * 1.0))
			var cores := ["c9b07a", "9a8350", "7a6638"]
			t.px(x, y, hx(cores[posmod(y, 3)]))
			t.px(x + 1, y, hx(cores[posmod(y + 1, 3)]))
	# malha em losango, com nos e trechos rasgados
	var nos := []
	for j in 78:
		var linha := []
		for i in 5:
			var x := 7 + i * 5 + (2 if j % 2 == 1 else 0) + rng.randi_range(-1, 1)
			var y := j * 5 + rng.randi_range(-1, 1)
			linha.append(Vector2i(mini(x, 25), y))
		nos.append(linha)
	var fios := ["3f7f6a", "4a7fa6", "5e8a74", "3a6a8a"]
	for j in nos.size() - 1:
		for i in 5:
			var a: Vector2i = nos[j][i]
			var vizinhos := [i, i - 1] if j % 2 == 0 else [i, i + 1]
			for v in vizinhos:
				if v < 0 or v > 4 or rng.randf() < 0.07:
					continue
				var b: Vector2i = nos[j + 1][v]
				t.linha(a.x, a.y, b.x, b.y, hx(fios[rng.randi_range(0, 3)]))
			t.px(a.x, a.y, hx("24493e"))
	# algas e incrustacoes
	for i in 30:
		var x := rng.randi_range(7, 25)
		var y := rng.randi_range(60, 380)
		t.circ(x, y, rng.randi_range(0, 1), hx("2f5a3a") if rng.randf() < 0.6 else hx("6b5a3a"))
		t.px(x, y - 1, hx("5f8a4a"))
	# coisas presas na rede (na parte de baixo, que e a que aparece na tela)
	garrafa(t, 10, 150, false, hx("cdeee0"), hx("e04a3a"), hx("d6402f"))
	sacola_mini(t, 15, 178, 9, 6, hx("f2f2ee"))
	t.rect(19, 184, 1, 4, hx("e2e4e0"))
	# peixe preso
	for p in [[9, 212], [17, 282]]:
		var fx: int = p[0]
		var fy: int = p[1]
		t.rect(fx, fy, 6, 3, hx("b8c4cc"))
		t.rect(fx, fy, 6, 1, hx("7f8f9a"))
		t.px(fx + 6, fy - 1, hx("8f9aa2"))
		t.px(fx + 6, fy + 3, hx("8f9aa2"))
		t.px(fx + 7, fy + 1, hx("8f9aa2"))
		t.px(fx + 1, fy + 1, hx("1a1a1a"))
	chinelo(t, 12, 240)
	lata(t, 20, 258, hx("d6402f"))
	garrafa(t, 8, 305, true, hx("cdeee0"), hx("3a6fc4"), hx("2f6fc0"))
	sacola_mini(t, 14, 322, 8, 5, hx("3a3a3a"))
	# tartaruga enroscada
	var cx := 16
	var cy := 356
	for f in [[-6, -3], [5, -3], [-6, 4], [5, 4]]:
		t.elip(cx + f[0], cy + f[1], 2.5, 1.2, hx("8a9a5a"))
	t.circ(cx, cy - 6, 2, hx("9aa86a"))
	t.px(cx - 1, cy - 7, hx("1a1a1a"))
	t.px(cx + 1, cy - 7, hx("1a1a1a"))
	t.elip(cx, cy, 6, 4.5, hx("6b7a3a"))
	t.elip(cx - 1, cy - 1, 4, 3, hx("7d8c45"))
	for pl in [[-2, -1], [2, -1], [0, 2], [-3, 2], [3, 2]]:
		t.px(cx + pl[0], cy + pl[1], hx("4f5a2a"))
	t.px(cx - 3, cy - 3, hx("a3b265"))
	# fios da rede passando por cima da tartaruga
	t.linha(cx - 8, cy - 5, cx + 7, cy + 3, hx("3f7f6a"))
	t.linha(cx - 7, cy + 4, cx + 6, cy - 6, hx("4a7fa6"))
	# cabo de chumbo, boias e fiapos soltos
	t.rect(5, 386, 23, 1, hx("7a6638"))
	for b in [8, 16, 24]:
		t.elip(b, 391, 3, 2, hx("f0782a"))
		t.px(b - 1, 390, hx("ffb070"))
		t.px(b + 2, 392, hx("b8501c"))
	for k in [6, 11, 14, 20, 23, 27]:
		for d in rng.randi_range(2, 5):
			t.px(k + int(round(sin(d * 1.3 + k))), 393 + d, hx("3f7f6a"))
	t.contorno(Color(0, 0, 0, 0), 0.5)
	t.salvar(OBS_F + "rede_cima.png")


func concreto_manilha(t: Tela, x0: int, x1: int, y: int) -> void:
	var p := pal(["d3d5d0", "bcbeb9", "a6a8a2", "8f918b", "767872"])
	for x in range(x0, x1):
		var s := float(x - x0) / (x1 - x0 - 1)
		var v := 0.6 + s * 3.4 if s > 0.15 else s * 4.0
		t.px(x, y, rampa(p, v, x, y))


## Galeria de esgoto na praia: manilhas de concreto despejando a "lingua negra".
func o_galeria() -> void:
	rng.seed = 412
	var esgoto := pal(["2a2925", "35332e", "45423a", "5a564b"])
	# --- topo: cabeceira de concreto com o cano jorrando (2 quadros) ---
	var t := Tela.new(72, 26)
	for f in 2:
		var o := f * 36
		for y in range(6, 26):
			concreto_manilha(t, o + 3, o + 33, y)
		t.rect(o + 3, 6, 30, 1, hx("dfe1dc"))
		t.rect(o + 3, 7, 30, 1, hx("b5b7b2"))
		for m in [[6, 9], [29, 11], [8, 22], [27, 20]]:
			t.px(o + m[0], m[1], hx("7f8a6a"))
		# boca do cano (vista de frente)
		t.circ(o + 18, 15, 8, hx("c9cbc6"))
		t.circ(o + 18, 15, 7, hx("a8aaa4"))
		for k in range(-7, 8):
			t.px(o + 18 + k, 15 + int(sqrt(maxf(0.0, 49.0 - k * k))), hx("7a7c76"))
		t.circ(o + 18, 15, 5, hx("141413"))
		t.rect(o + 15, 11, 7, 2, hx("0c0c0b"))
		# esgoto saindo e escorrendo pela frente (animado)
		for y in range(16, 26):
			var larg := 4 + (y - 16) / 3
			for x in range(o + 18 - larg, o + 18 + larg + 1):
				var c := rampa(esgoto, 1.2 + sin((y - f * 2) * 1.6 + x * 0.5) * 1.3, x, y)
				if posmod(y + f * 2 + x, 5) == 0:
					c = hx("6a6658")
				t.px(x, y, c)
		for k in range(-4, 5):
			if posmod(k + f, 2) == 0:
				t.px(o + 18 + k, 16, hx("bdb9aa"))
		for s in ([[11, 20], [25, 22], [13, 24]] if f == 0 else [[12, 22], [24, 20], [26, 24]]):
			t.px(o + s[0], s[1], hx("45423a"))
	t.contorno(Color(0, 0, 0, 0), 0.5)
	# mau cheiro e moscas (depois do contorno, para ficarem finos)
	for f in 2:
		var o := f * 36
		for base in [10, 26]:
			for y in 6:
				t.px(o + base + int(round(sin(y * 1.2 + f * PI + base) * 1.3)), y, Color(hx("9ab36a"), 0.85))
		var moscas := [[7, 3], [30, 1], [21, 0]] if f == 0 else [[9, 1], [28, 4], [16, 2]]
		for m in moscas:
			t.px(o + m[0], m[1], hx("161616"))
			t.px(o + m[0] + 1, m[1] - 1, Color(hx("c9d8e0"), 0.8))
	t.salvar(OBS_F + "galeria_topo.png")

	# --- corpo: manilhas empilhadas, manchadas de esgoto (repete na vertical) ---
	var c := Tela.new(28, 16, false, true)
	for y in 16:
		concreto_manilha(c, 2, 26, y)
	for x in range(1, 27):
		c.px(x, 0, hx("c9cbc6"))
		c.px(x, 1, hx("aeb0aa"))
		c.px(x, 14, hx("6f716b"))
		c.px(x, 15, hx("5a5c57"))
	for s in [[8, 2, 12], [9, 2, 12], [18, 2, 8], [14, 3, 5]]:
		for y in range(s[1], s[1] + s[2]):
			c.px(s[0], y, hx("3d3b35") if y < s[1] + s[2] - 2 else hx("4d4a42"))
	c.px(8, 13, hx("2b2a27"))
	for m in [[3, 13], [4, 13], [23, 2], [24, 13], [12, 13]]:
		c.px(m[0], m[1], hx("6f8f45"))
	c.contorno(Color(0, 0, 0, 0), 0.5)
	c.salvar(OBS_F + "galeria_corpo.png")

	# --- base: a "lingua negra" escorrendo pela areia ate o mar ---
	var b := Tela.new(48, 22)
	for y in range(11, 22):
		var hw := 5.0 + (y - 11) * 2.0 + sin(y * 1.3) * 1.0
		var meio := 24.0 + (y - 11) * 0.5
		for x in range(int(meio - hw), int(meio + hw) + 1):
			var v := 1.0 + sin(x * 0.8 + y * 1.1) * 1.1
			var cc := rampa(esgoto, v, x, y)
			if absf(x - meio) > hw - 1.0:
				cc = hx("8f8a78")
			b.px(x, y, cc)
	for s in [[14, 17], [30, 19], [36, 16], [21, 20], [40, 20]]:
		b.rect(s[0], s[1], 2, 1, hx("b9b5a5"))
	for s in [[26, 15], [33, 18]]:
		b.px(s[0], s[1], Color(hx("6a5f8a"), 0.8))
		b.px(s[0] + 1, s[1], Color(hx("4a7a6a"), 0.8))
	b.rect(17, 18, 3, 1, hx("f4f4f0"))
	b.px(16, 18, hx("e8e0c8"))
	b.px(20, 18, hx("e8e0c8"))
	b.px(38, 15, hx("d6402f"))
	for y in range(3, 13):
		concreto_manilha(b, 10, 38, y)
	for x in range(9, 39):
		b.px(x, 3, hx("c9cbc6"))
		b.px(x, 12, hx("6f716b"))
	b.rect(16, 6, 1, 4, hx("3d3b35"))
	b.rect(28, 5, 1, 6, hx("3d3b35"))
	b.contorno(Color(0, 0, 0, 0), 0.45)
	b.salvar(OBS_F + "galeria_base.png")

	# --- placa IMPROPRIO ---
	var p := Tela.new(44, 16)
	p.rect(21, 10, 3, 6, hx("8d8f8a"))
	p.rect(23, 10, 1, 6, hx("6d6f6a"))
	p.rect(1, 0, 42, 11, hx("d23b2e"))
	p.rect(1, 0, 42, 1, hx("8e2018"))
	p.rect(1, 10, 42, 1, hx("8e2018"))
	p.rect(1, 0, 1, 11, hx("8e2018"))
	p.rect(42, 0, 1, 11, hx("8e2018"))
	p.rect(2, 1, 40, 1, hx("ea6a5a"))
	var x := 4
	for letra in "IMPROPRIO":
		var g: Array = FONTE[letra]
		for r in 5:
			for k in g[r].length():
				if g[r][k] == "1":
					p.px(x + k, 3 + r, hx("fff6ec"))
		x += g[0].length() + 1
	p.contorno()
	p.salvar(OBS_F + "placa_improprio.png")


func vaso_sanitario(t: Tela, x: int, y: int) -> void:
	# vaso jogado no entulho (visto de lado): caixa, assento, bacia e pe
	t.rect(x, y, 5, 7, hx("eef1f2"))
	t.rect(x, y, 5, 1, hx("ffffff"))
	t.rect(x + 4, y + 1, 1, 6, hx("c3cdd2"))
	t.rect(x + 1, y - 1, 3, 1, hx("d8dfe2"))
	t.elip(x + 8, y + 8, 5, 2.5, hx("eef1f2"))
	t.rect(x + 4, y + 6, 9, 1, hx("dfe5e8"))
	t.rect(x + 6, y + 8, 5, 1, hx("6a7a80"))
	t.rect(x + 6, y + 10, 4, 3, hx("dfe5e8"))
	t.rect(x + 9, y + 10, 1, 3, hx("b9c4ca"))
	t.linha(x + 9, y + 6, x + 11, y + 9, hx("8a989e"))


## Entulho de obra jogado no mangue: tijolo baiano, sacos de rafia, concreto,
## vergalhao, tabua com prego, azulejo e ate vaso sanitario.
func o_entulho() -> void:
	rng.seed = 413
	var c := Tela.new(30, 32, false, true)
	entulho_fundo(c, 1, 29, 0, 32)
	saco_rafia(c, 1, 1, 15, 10, hx("4f8a5a"))
	bloco_baiano(c, 17, 1)
	bloco_baiano(c, 18, 7, true)
	concreto(c, 1, 13, 13, 6)
	vergalhao(c, 12, 15, 17, 11)
	c.rect(16, 13, 5, 4, hx("f4f6f8"))
	c.rect(16, 13, 5, 1, hx("ffffff"))
	c.rect(17, 14, 1, 1, hx("3a6fc4"))
	c.rect(19, 15, 1, 1, hx("3a6fc4"))
	bloco_baiano(c, 20, 13)
	c.linha(2, 25, 26, 19, hx("9a6a3a"))
	c.linha(2, 26, 26, 20, hx("7a4f2a"))
	c.linha(3, 24, 25, 18, hx("b8884e"))
	c.px(14, 21, hx("c9ccd0"))
	c.px(14, 20, hx("8a8e92"))
	bloco_baiano(c, 1, 26, true)
	saco_rafia(c, 12, 25, 16, 7, hx("3a6fa0"))
	c.contorno(Color(0, 0, 0, 0), 0.55)
	c.salvar(OBS_F + "entulho_corpo.png")

	var t := Tela.new(36, 18)
	t.elip(18, 15, 15, 3.5, hx("857c6f"))
	entulho_fundo(t, 4, 33, 13, 18)
	t.linha(19, 15, 33, 5, hx("9a6a3a"))
	t.linha(20, 15, 34, 5, hx("7a4f2a"))
	saco_rafia(t, 18, 8, 11, 8, hx("4f8a5a"))
	t.rect(22, 6, 3, 2, hx("d9d5c8"))
	vaso_sanitario(t, 4, 3)
	vergalhao(t, 30, 16, 33, 1)
	bloco_baiano(t, 9, 13, true)
	t.contorno(Color(0, 0, 0, 0), 0.55)
	t.salvar(OBS_F + "entulho_topo.png")


func concreto(t: Tela, x: int, y: int, lw: int, lh: int) -> void:
	for j in lh:
		var corte := 1 if (j == 0 or j == lh - 1) else 0
		for i in range(corte, lw - corte):
			var c := hx("a3a19b")
			if j == 0: c = hx("c2c0b9")
			elif j == lh - 1: c = hx("7d7b76")
			elif i == lw - 1 - corte: c = hx("8a8882")
			elif posmod(i * 5 + j * 3, 11) == 0: c = hx("8f8d87")
			t.px(x + i, y + j, c)
	t.linha(x + 2, y + 1, x + lw / 2, y + lh - 2, hx("7d7b76"))


## Mangue (raizes-escora do mangue-vermelho) com lama, entulho misturado e um aratu.
func o_mangue() -> void:
	rng.seed = 414
	var t := Tela.new(96, 26)
	for f in 2:
		var o := f * 48
		for y in range(18, 26):
			for x in range(o, o + 48):
				t.px(x, y, hx("3e3226") if bayer(x, y) < 0.55 else hx("4f4030"))
		for x in range(o + 1, o + 47):
			t.px(x, 18, Color(hx("56706a"), 0.9))
			if posmod(x + f, 6) == 0:
				t.px(x, 19, hx("7f9f98"))
		# raizes em arco
		for lado in [-1, 1]:
			var i := 0
			for abre in [4, 8, 12, 16, 21]:
				var a := Vector2(o + 24 + lado * 1, 1 + i * 2)
				var fim := Vector2(o + 24 + lado * abre, 21)
				var ctrl := Vector2(o + 24 + lado * (abre + 4), 1 + i * 2)
				for k in 30:
					var s := k / 29.0
					var p := a.lerp(ctrl, s).lerp(ctrl.lerp(fim, s), s)
					t.px(int(p.x), int(p.y), hx("8a5a42"))
					t.px(int(p.x), int(p.y) - 1, hx("a87458"))
					t.px(int(p.x), int(p.y) + 1, hx("5e3a2a"))
					if k % 7 == 3:
						t.px(int(p.x), int(p.y), hx("c9a080"))
				i += 1
		t.rect(o + 22, 0, 5, 6, hx("7a4a36"))
		t.rect(o + 22, 0, 1, 6, hx("a87458"))
		for l in [[17, 2], [31, 3], [20, 6], [29, 7]]:
			t.elip(o + l[0], l[1], 2.5, 1.2, hx("3f7a3a"))
			t.px(o + l[0] - 1, l[1] - 1, hx("6fae4f"))
		# entulho e sacola misturados na lama
		bloco_baiano(t, o + 33, 19, true)
		sacola_mini(t, o + 9, 10, 5, 4, hx("f2f2ee"))
		t.px(o + 15, 21, hx("cdeee0"))
		t.px(o + 16, 21, hx("e04a3a"))
		# aratu (caranguejo vermelho do mangue)
		var cx := o + (6 if f == 0 else 9)
		t.elip(cx, 17, 3, 1.8, hx("c8402a"))
		t.px(cx - 1, 16, hx("e8704a"))
		t.px(cx + 1, 16, hx("8a2a1c"))
		t.px(cx - 1, 14, hx("f4f4f0"))
		t.px(cx + 1, 14, hx("f4f4f0"))
		t.px(cx - 1, 15, hx("8a2a1c"))
		t.px(cx + 1, 15, hx("8a2a1c"))
		var gy := 16 if f == 0 else 13
		t.rect(cx - 5, gy, 2, 2, hx("e05a3f"))
		t.rect(cx + 4, gy, 2, 2, hx("e05a3f"))
		for k in [-3, -2, 2, 3]:
			t.px(cx + k, 19, hx("a8361f"))
	t.contorno(Color(0, 0, 0, 0), 0.55)
	t.salvar(OBS_F + "mangue_base.png")


## Garrafa PET de refrigerante (2 litros) com rotulo, tampa e fundo petaloide.
func o_pet() -> void:
	var t := Tela.new(8, 18)
	t.rect(2, 1, 4, 2, hx("d6402f"))
	t.px(2, 1, hx("f07060"))
	t.rect(2, 3, 4, 1, hx("a83020"))
	t.rect(3, 4, 2, 1, hx("cdeee0"))
	t.rect(2, 5, 4, 1, hx("cdeee0"))
	t.rect(1, 6, 6, 9, hx("cdeee0"))
	t.rect(5, 6, 2, 9, hx("9fcab8"))
	t.rect(2, 5, 1, 10, hx("ffffff"))
	t.rect(1, 9, 6, 3, hx("e04a3a"))
	t.px(2, 10, hx("fff2e8"))
	t.px(4, 10, hx("fff2e8"))
	t.px(5, 11, hx("b83020"))
	for k in [1, 3, 5]:
		t.px(k, 15, hx("b8dccc"))
		t.px(k + 1, 16, hx("b8dccc"))
	t.rect(1, 15, 6, 1, hx("cdeee0"))
	t.contorno(hx("3f6a5a"))
	t.salvar(OBS_F + "pet.png")


## Sacola de supermercado boiando como agua-viva (tartarugas confundem com comida).
func o_sacola() -> void:
	var t := Tela.new(32, 16)
	for f in 2:
		var o := f * 16
		for alca in [3, 9]:
			for p in [Vector2i(0, 4), Vector2i(0, 3), Vector2i(0, 2), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 2), Vector2i(3, 3), Vector2i(3, 4)]:
				t.px(o + alca + p.x, p.y, hx("f2f2ee"))
		for y in range(4, 12):
			var hw := 5 + (1 if y > 5 and y < 10 else 0) - (1 if y == 11 else 0)
			for x in range(o + 8 - hw, o + 8 + hw):
				var c := Color(hx("f6f6f2"), 0.95)
				if posmod(x - y + f, 5) == 0:
					c = Color(hx("d8dcdc"), 0.95)
				if x >= o + 8 + hw - 2:
					c = Color(hx("c3c9c9"), 0.95)
				t.px(x, y, c)
		# estampa do mercado
		t.rect(o + 6, 6, 4, 3, hx("3a6fc4"))
		t.px(o + 7, 7, hx("ffffff"))
		t.px(o + 8, 7, hx("f2c230"))
		t.rect(o + 5, 10, 6, 1, hx("e04a3a"))
		for i in 4:
			var base := o + 4 + i * 2 + (1 if i > 1 else 0)
			var comp := 3 + posmod(i + f, 2)
			for k in comp:
				t.px(base + int(round(sin(k * 1.1 + f * 1.8 + i))), 12 + k, Color(hx("eceeec"), 0.9))
	t.contorno(hx("8a9494"))
	t.salvar(OBS_F + "sacola.png")


# =====================================================================
# OBSTACULOS - RIO
# =====================================================================

## Papel de seda colorido com losangos e estrelas, iluminado por dentro pela bucha.
func cor_papel(x: int, y: int, x0: int, larg: float, brilho: float) -> Color:
	var s := clampf((x - x0) / larg, 0.0, 0.999)
	var gomo := int(s * 8)
	var faixa := posmod(y, 32) / 16
	var dentro_gomo := (s * 8.0 - gomo) * 4.0
	var gy := posmod(y, 16)
	var c: Color
	if faixa == 0:
		c = hx("d63a2a") if gomo % 2 == 0 else hx("f2c230")
		if absf(dentro_gomo - 2.0) + absf(gy - 7.5) * 0.5 <= 1.6:
			c = hx("fff2dc") if gomo % 2 == 0 else hx("2f62b8")
	else:
		c = hx("2f62b8") if gomo % 2 == 0 else hx("2f9a4a")
		var dx := absf(dentro_gomo - 2.0)
		var dy := absf(gy - 7.5)
		if (dx < 0.6 and dy < 2.6) or (dy < 0.6 and dx < 1.6):
			c = hx("f8d850")
	c = c.lerp(hx("ffb040"), 0.12 + brilho)
	if s < 0.18:
		c = c.lightened(0.18)
	elif s > 0.62:
		c = c.darkened((s - 0.62) * 0.75)
	if absf(s * 8.0 - round(s * 8.0)) < 0.05:
		c = c.darkened(0.28)
	if gy == 15:
		c = c.lerp(hx("fff6e0"), 0.55)
	return c


func o_balao() -> void:
	rng.seed = 511
	var c := Tela.new(34, 32, false, true)
	for y in 32:
		for x in range(1, 33):
			var cc := cor_papel(x, y, 1, 32.0, 0.0)
			if rng.randf() < 0.05:
				cc = cc.lightened(0.08)
			c.px(x, y, cc)
	c.contorno(Color(0, 0, 0, 0), 0.55)
	c.salvar(OBS_R + "balao_corpo.png")

	# boca: papel brilhando, aro de arame e a bucha acesa pingando parafina
	var t := Tela.new(80, 44)
	for f in 2:
		var o := f * 40
		var cx := o + 20
		for y in 21:
			var hw := 16 - int(round(pow(y / 20.0, 1.25) * 9))
			for x in range(cx - hw, cx + hw):
				t.px(x, y, cor_papel(x - (cx - hw), y, 0, hw * 2.0, (y / 20.0) * 0.45))
		t.rect(cx - 7, 21, 14, 2, hx("3a3030"))
		t.rect(cx - 7, 21, 14, 1, hx("8a7a70"))
		t.linha(cx - 6, 23, cx - 1, 29, hx("4a4040"))
		t.linha(cx + 5, 23, cx, 29, hx("4a4040"))
	t.contorno(Color(0, 0, 0, 0), 0.55)
	var fogo := pal(["c8301a", "f06a1e", "ffb43a", "fff3b0"])
	for f in 2:
		var o := f * 40
		var cx := o + 20
		halo(t, cx, 27, 3, 13, 0.55, 0.35)
		# chama subindo da bucha
		for y in range(19, 33):
			var s := (32 - y) / 13.0
			var larg := 4.5 * (1.0 - pow(s, 1.6)) + 0.6
			var meio := cx + sin(s * 6.0 + f * 2.6) * 1.3 * s
			for x in range(cx - 7, cx + 8):
				var d := absf(x - meio) / larg
				if d <= 1.0:
					t.px(x, y, fogo[clampi(int((1.0 - d) * 3.6 - s * 1.3), 0, 3)])
		t.circ(cx, 30, 2, hx("3a2414"))
		t.px(cx, 29, hx("ffb43a"))
		t.px(cx - 1, 31, hx("f06a1e"))
		# parafina pingando e fagulhas caindo (perigo de incendio!)
		var gotas := [[0, 35], [-1, 40], [3, 37], [-4, 33], [5, 42], [-6, 39]] if f == 0 else [[0, 38], [1, 43], [-3, 36], [4, 34], [-5, 42], [6, 38]]
		for i in gotas.size():
			var g: Array = gotas[i]
			t.px(cx + g[0], g[1], hx("fff3b0") if i < 2 else (hx("ffb43a") if i < 4 else hx("f06a1e")))
			if i < 2:
				t.px(cx + g[0], g[1] - 1, Color(hx("ffb43a"), 0.7))
	t.salvar(OBS_R + "balao_boca.png")

	# baloezinho caindo aceso (2 quadros)
	var b := Tela.new(28, 20)
	for f in 2:
		var o := f * 14
		for y in range(1, 12):
			var hw := int(round(5.5 * sqrt(maxf(0.0, 1.0 - pow((y - 5.0) / 6.5, 2)))))
			if y >= 9:
				hw = 3 - (y - 9) / 2
			for x in range(o + 7 - hw, o + 7 + hw):
				b.px(x, y, cor_papel((x - (o + 7 - hw)) * 4, y * 2, 0, maxf(1.0, hw * 8.0), y / 11.0 * 0.4))
		b.rect(o + 5, 12, 4, 1, hx("3a3030"))
	b.contorno(Color(0, 0, 0, 0), 0.55)
	for f in 2:
		var o := f * 14
		halo(b, o + 7, 11, 1, 5, 0.6, 0.35)
		for p in [[7, 10, 3], [6, 11, 2], [7, 11, 3], [8, 11, 2], [7, 12, 1], [6 + f, 13, 0]]:
			b.px(o + p[0], p[1], fogo[p[2]])
		var fag := [[6, 15], [8, 18], [5, 17]] if f == 0 else [[8, 15], [6, 18], [9, 17]]
		for g in fag:
			b.px(o + g[0], g[1], hx("ffb43a"))
	b.salvar(OBS_R + "balaozinho.png")


## Lixo boiando na Baia de Guanabara: agua oleosa, garrafas, isopor, pneu...
func o_baia() -> void:
	rng.seed = 512
	var c := Tela.new(32, 32, false, true)
	sujeira_oleo(c, 1, 31, 0, 32)
	pneu(c, 9, 7, 6)
	furo_pneu(c, 9, 7, 6, hx("263634"))
	garrafa(c, 17, 1, false, hx("cdeee0"), hx("e04a3a"), hx("2f6fc0"))
	garrafa(c, 22, 3, false, hx("4f9a5a"), hx("f2efe6"), hx("f2efe6"))
	garrafa(c, 26, 1, false, hx("8a5a2a"), hx("f2c230"), hx("c9ccd0"))
	isopor(c, 17, 11, 9, 5)
	sacola_mini(c, 2, 14, 9, 6, hx("f2f2ee"))
	sacola_mini(c, 24, 15, 7, 6, hx("2a2a2a"))
	garrafa(c, 11, 17, true, hx("cdeee0"), hx("3a6fc4"), hx("d6402f"))
	lata(c, 2, 22, hx("d6402f"))
	chinelo(c, 6, 24)
	garrafa(c, 15, 22, true, hx("4f9a5a"), hx("f2efe6"), hx("f2efe6"))
	sacola_mini(c, 23, 23, 8, 5, hx("3a6fc4"))
	isopor(c, 4, 28, 7, 3)
	lata(c, 13, 27, hx("c9ccd0"))
	garrafa(c, 18, 28, true, hx("cdeee0"), hx("e04a3a"), hx("2f6fc0"))
	for e in [[28, 10], [14, 9], [29, 29], [1, 31]]:
		c.px(e[0], e[1], hx("8a9490"))
		c.px(e[0] + 1, e[1], hx("a9b2ad"))
	c.contorno(Color(0, 0, 0, 0), 0.5)
	c.salvar(OBS_R + "baia_corpo.png")

	# topo: lixo amontoado com uma garca em cima
	var t := Tela.new(36, 18)
	t.elip(18, 14, 15, 4, hx("263634"))
	sujeira_oleo(t, 4, 33, 13, 18)
	garrafa(t, 6, 6, false, hx("4f9a5a"), hx("f2efe6"), hx("f2efe6"))
	garrafa(t, 10, 8, false, hx("cdeee0"), hx("e04a3a"), hx("2f6fc0"))
	sacola_mini(t, 13, 9, 8, 5, hx("f2f2ee"))
	isopor(t, 4, 12, 7, 3)
	lata(t, 21, 10, hx("d6402f"))
	# garca-branca em pe no lixo (pernas longas, pescoco em S, bico amarelo)
	t.rect(26, 11, 1, 5, hx("2a2a2a"))
	t.rect(28, 11, 1, 5, hx("2a2a2a"))
	t.px(25, 15, hx("2a2a2a"))
	t.px(29, 15, hx("2a2a2a"))
	for p in [[24, 9], [25, 8], [26, 8], [27, 8], [28, 8], [25, 9], [26, 9], [27, 9], [28, 9], [29, 9], [26, 10], [27, 10], [28, 10], [23, 10]]:
		t.px(p[0], p[1], hx("f6f6f2"))
	for p in [[25, 10], [24, 10], [29, 10]]:
		t.px(p[0], p[1], hx("cfd6d8"))
	for p in [[29, 7], [30, 6], [30, 5], [29, 4], [29, 3], [30, 2]]:
		t.px(p[0], p[1], hx("f6f6f2"))
	t.rect(30, 1, 2, 2, hx("f6f6f2"))
	t.rect(32, 2, 3, 1, hx("e8c040"))
	t.px(31, 1, hx("1a1a1a"))
	t.contorno(Color(0, 0, 0, 0), 0.5)
	t.salvar(OBS_R + "baia_topo.png")

	# ecobarreira: boias amarelas presas por corrente segurando o lixo
	var e := Tela.new(52, 18)
	sujeira_oleo(e, 1, 51, 10, 18)
	for x in range(1, 51):
		e.px(x, 10, hx("4a6d6c"))
		if posmod(x, 3) == 0:
			for y in range(13, 17):
				e.px(x, y, Color(hx("101818"), 0.7))
	# lixo acumulado atras da barreira (itens de verdade, nao listras)
	isopor(e, 3, 5, 7, 3)
	garrafa(e, 10, 6, true, hx("cdeee0"), hx("e04a3a"), hx("2f6fc0"))
	sacola_mini(e, 19, 4, 8, 5, hx("f2f2ee"))
	garrafa(e, 27, 6, true, hx("4f9a5a"), hx("f2efe6"), hx("f2efe6"))
	lata(e, 36, 4, hx("d6402f"))
	sacola_mini(e, 39, 5, 7, 4, hx("2a2a2a"))
	isopor(e, 45, 6, 5, 2)
	chinelo(e, 31, 3)
	for k in 7:
		var x := 2 + k * 7
		e.rect(x, 7, 6, 5, hx("f08a2a"))
		e.rect(x, 7, 6, 1, hx("ffc070"))
		e.rect(x, 11, 6, 1, hx("b8601c"))
		e.rect(x + 5, 8, 1, 3, hx("d0701f"))
		e.px(x + 6, 9, hx("6a6a6a"))
		e.px(x + 6, 10, hx("4a4a4a"))
	e.contorno(Color(0, 0, 0, 0), 0.5)
	e.salvar(OBS_R + "ecobarreira.png")


func barro(t: Tela, x0: int, x1: int, y0: int, y1: int) -> void:
	# barro vermelho dos morros do Rio, em camadas, com escorridos molhados
	var p := pal(["6e3420", "8a4428", "a65a32", "bd6e40"])
	for y in range(y0, y1):
		for x in range(x0, x1):
			var v := 1.6 + sin(y * 0.55 + sin(x * 0.3) * 1.2) * 1.1 + sin(x * 0.9 + y * 0.2) * 0.3
			var c := rampa(p, v, x, y)
			if posmod(x * 2 + y, 13) == 0:
				c = hx("5a2a18")
			t.px(x, y, c)


func pedra_granito(t: Tela, x: int, y: int, r: int) -> void:
	t.circ(x, y, r, hx("8f8c88"))
	t.circ(x - 1, y - 1, maxi(1, r - 2), hx("a9a6a1"))
	t.px(x - r / 2, y - r / 2, hx("d0cdc8"))
	t.px(x + r - 1, y + 1, hx("66635f"))
	t.px(x, y + 1, hx("4a4846"))
	t.px(x + 1, y - 1, hx("d8d5d0"))


func caixa_dagua(t: Tela, x: int, y: int) -> void:
	t.rect(x, y + 1, 8, 6, hx("3a7ac0"))
	t.rect(x + 1, y, 6, 1, hx("6fa5dd"))
	t.rect(x, y + 1, 8, 1, hx("5a92d0"))
	t.rect(x + 6, y + 2, 2, 5, hx("2a5a98"))
	t.px(x + 1, y + 3, hx("8fbdea"))


## Deslizamento de terra: barro vermelho, pedras, raizes, cano quebrado,
## casa de tijolo cedendo, caixa d'agua caida e a sirene da Defesa Civil.
func o_deslizamento() -> void:
	rng.seed = 513
	var c := Tela.new(32, 32, false, true)
	barro(c, 1, 31, 0, 32)
	for k in range(0, 32, 2):
		c.px(8 + int(round(sin(k * 0.4) * 2.0)), k, hx("5a2a18"))
		c.px(23 + int(round(sin(k * 0.3 + 1.0) * 2.0)), k, Color(hx("d08a5a"), 0.8))
	for s in [[7, 5, 3], [22, 14, 4], [11, 23, 2], [25, 28, 3], [4, 16, 2]]:
		pedra_granito(c, s[0], s[1], s[2])
	for k in 12:
		c.px(15 + int(round(sin(k * 0.8) * 1.5)), 2 + k, hx("d8b890"))
	c.linha(16, 18, 21, 23, hx("eeeeee"))
	c.linha(16, 19, 21, 24, hx("bfbfbf"))
	bloco_baiano(c, 2, 9, true)
	for k in range(-2, 3):
		c.px(2, 20 + k, hx("6f9a4a"))
		c.px(29, 6 + k, hx("6f9a4a"))
	c.contorno(Color(0, 0, 0, 0), 0.5)
	c.salvar(OBS_R + "lama_corpo.png")

	var t := Tela.new(80, 26)
	for f in 2:
		var o := f * 40
		for y in range(11, 26):
			for x in range(o + 3, o + 38):
				var dx := (x - (o + 20)) / 17.0
				var dy := (y - 23) / 12.0
				if dx * dx + dy * dy <= 1.0:
					var v := 1.6 + sin(y * 0.55 + x * 0.3) * 1.1
					t.px(x, y, rampa(pal(["6e3420", "8a4428", "a65a32", "bd6e40"]), v, x, y))
		# arvore arrancada com a raiz para cima
		t.linha(o + 4, 21, o + 12, 9, hx("6b4a30"))
		t.linha(o + 5, 21, o + 13, 9, hx("8a6440"))
		t.circ(o + 5, 21, 3, hx("6e3420"))
		for r in [[2, 23], [7, 24], [3, 19]]:
			t.px(o + r[0], r[1], hx("d8b890"))
		t.circ(o + 9, 6, 4, hx("3f7a3a"))
		t.circ(o + 13, 5, 3, hx("4f8a45"))
		t.px(o + 8, 4, hx("6fae4f"))
		# canto de casa de tijolo baiano cedendo
		for y in range(6, 17):
			var desl := (y - 6) / 4
			for x in range(o + 18, o + 30):
				var cc := hx("c8642f")
				if posmod(y, 3) == 2 or posmod(x + (y / 3) * 3, 6) == 0:
					cc = hx("b9ab98")
				t.px(x + desl, y, cc)
		t.rect(o + 18, 5, 12, 1, hx("c9c2b8"))
		t.rect(o + 22, 9, 3, 3, hx("2a2228"))
		t.rect(o + 22, 9, 3, 1, hx("3a6fc4"))
		t.linha(o + 27, 7, o + 26, 12, hx("3a2a22"))
		caixa_dagua(t, o + 15, 0)
		pedra_granito(t, o + 30, 20, 3)
		# sirene da Defesa Civil: poste com cornetas
		t.rect(o + 35, 6, 2, 20, hx("7d7f80"))
		t.rect(o + 35, 6, 1, 20, hx("a5a7a8"))
		for lado in [-1, 1]:
			var bx := o + 35 + (0 if lado < 0 else 1)
			for k in 4:
				t.rect(bx + lado * (1 + k), 3 - k / 2, 1, 2 + k, hx("a0a4a8"))
			t.rect(bx + lado * 4, 2, 1, 4, hx("4a4e52"))
	t.contorno(Color(0, 0, 0, 0), 0.5)
	for f in 2:
		var o := f * 40
		if f == 0:
			halo(t, o + 36, 1, 1, 6, 0.7, 0.35)
			t.rect(o + 35, 0, 2, 2, hx("ff4030"))
			for a in [[30, 2], [30, 4], [29, 3]]:
				t.px(o + a[0], a[1], Color(hx("fff3c4"), 0.9))
		else:
			t.rect(o + 35, 0, 2, 2, hx("7a2018"))
			for a in [[28, 1], [28, 5], [27, 3]]:
				t.px(o + a[0], a[1], Color(hx("fff3c4"), 0.6))
	t.salvar(OBS_R + "deslizamento_topo.png")

	# boca de lobo entupida, transbordando agua suja
	var b := Tela.new(48, 16)
	for y in range(11, 16):
		for x in 48:
			b.px(x, y, hx("4a4a4e") if bayer(x, y) < 0.7 else hx("56565a"))
	b.elip(24, 13, 23, 2.5, Color(hx("6b6152"), 0.95))
	for s in [[8, 13], [30, 14], [38, 12], [17, 14]]:
		b.rect(s[0], s[1], 3, 1, hx("9a907c"))
	b.rect(6, 2, 36, 9, hx("b5b3ad"))
	b.rect(6, 2, 36, 1, hx("d6d4ce"))
	b.rect(6, 3, 36, 1, hx("c4c2bc"))
	b.rect(40, 3, 2, 8, hx("8a8882"))
	b.rect(12, 6, 24, 5, hx("151515"))
	garrafa(b, 13, 7, true, hx("4f9a5a"), hx("f2efe6"), hx("f2efe6"))
	sacola_mini(b, 23, 5, 7, 5, hx("f2f2ee"))
	b.rect(31, 8, 4, 2, hx("8a5a32"))
	b.px(32, 7, hx("a8743a"))
	b.px(21, 9, hx("6f9a4a"))
	for k in range(14, 35, 3):
		b.rect(k, 11, 1, 3, hx("6a6a6e"))
	b.rect(14, 11, 21, 1, hx("8a8a8e"))
	garrafa(b, 38, 12, true, hx("cdeee0"), hx("e04a3a"), hx("2f6fc0"))
	b.contorno(Color(0, 0, 0, 0), 0.5)
	b.salvar(OBS_R + "bueiro.png")


# =====================================================================
func _initialize() -> void:
	f_ceu()
	f_nuvens()
	f_mar()
	f_orla()
	f_areia()
	r_ceu()
	r_nuvens()
	r_baia()
	r_morro()
	r_calcadao()
	o_rede()
	o_galeria()
	o_entulho()
	o_mangue()
	o_pet()
	o_sacola()
	o_balao()
	o_baia()
	o_deslizamento()
	print("Pronto: arte das fases 2 e 3 gerada.")
	quit()
