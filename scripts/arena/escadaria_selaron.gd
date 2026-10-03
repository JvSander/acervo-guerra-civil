class_name ArenaSelaron
extends Node2D
## Arena 1 do GDD: ESCADARIA SELARÓN, de noite, com chuva fina.
##
## Arte provisória desenhada por código até chegarem as imagens de
## referência. O cenário tem camadas com paralaxe (as de trás andam menos
## que a câmera). As camadas paradas são desenhadas uma vez só; chuva,
## água descendo os degraus e neon piscando são redesenhados a cada frame.
## Coordenadas do mundo da luta (chão em y = 0), como se a câmera estivesse
## no ponto padrão (0, -220).
##
## Detalhes: azulejos vermelhos nos degraus e verde, amarelo e azul nos
## muros, bar com neon na esquerda, porta de aço pichada na direita,
## fiação com tênis pendurado, o Cristo iluminado lá no alto e o letreiro
## SELARÓN com defeito (o vírus CASCATA mexendo nos neons da cidade).

const CAM_PADRAO := Vector2(0.0, -220.0)
const FONTE := preload("res://fontes/BebasNeue-Regular.woff2")
## Fundo da rua: onde começam os prédios e a escadaria.
const BASE := -34.0

const ROSA := Color(1.0, 0.18, 0.56)
const CIANO := Color(0.25, 0.9, 1.0)
const AMARELO := Color(1.0, 0.8, 0.22)
const VERDE := Color(0.25, 1.0, 0.45)
const LUZ_POSTE := Color(1.0, 0.7, 0.36)
const NEVOA := Color(0.11, 0.06, 0.16)
const POSTES_X := [-430.0, 430.0]
const ALTURA_LAMPIAO := -232.0

static var _tex_brilho: GradientTexture2D

var _camadas: Array = []
var _frente: Chuva


func _ready() -> void:
	_camada(Ceu.new(), 0.0)
	_camada(Morro.new(), 0.1)
	_camada(Casario.new(), 0.3)
	_camada(Escadaria.new(), 0.55)
	_camada(Fachadas.new(), 0.8)
	_camada(Neon.new(), 0.8)
	_camada(Chao.new(), 1.0)
	_camada(Postes.new(), 1.0)
	atualizar(CAM_PADRAO)


func _camada(no: Node2D, fator: float) -> void:
	add_child(no)
	_camadas.append([no, fator])


## Chuva que cai na frente dos lutadores (a Luta põe acima de tudo).
func criar_frente() -> Node2D:
	_frente = Chuva.new()
	_frente.z_index = 10
	return _frente


## Move as camadas conforme a câmera (paralaxe).
func atualizar(cam: Vector2) -> void:
	var d := cam - CAM_PADRAO
	for c in _camadas:
		(c[0] as Node2D).position = d * (1.0 - float(c[1]))
	if _frente:
		_frente.cam = cam


# ------------------------------------------------------------ ajudantes

static func textura_brilho() -> GradientTexture2D:
	if _tex_brilho == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.2, 0.55, 1.0])
		g.colors = PackedColorArray([
			Color(1, 1, 1, 1), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0.15), Color(1, 1, 1, 0),
		])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_tex_brilho = t
	return _tex_brilho


## Brilho redondo e suave (luz de poste, neon, janela).
static func brilho(ci: CanvasItem, centro: Vector2, raio: float, cor: Color, achatado := 1.0) -> void:
	var r := Vector2(raio, raio * achatado)
	ci.draw_texture_rect(textura_brilho(), Rect2(centro - r, r * 2.0), false, cor)


## Retângulo com degradê vertical.
static func degrade(ci: CanvasItem, r: Rect2, cima: Color, baixo: Color) -> void:
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	ci.draw_polygon(pts, PackedColorArray([cima, cima, baixo, baixo]))


static func elipse(ci: CanvasItem, centro: Vector2, raios: Vector2, cor: Color) -> void:
	ci.draw_set_transform(centro, 0.0, Vector2(raios.x / raios.y, 1.0))
	ci.draw_circle(Vector2.ZERO, raios.y, cor)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Letreiro de neon: o contorno das letras vira o tubo de vidro.
## 'forca' 0 desenha o tubo apagado.
static func texto_neon(ci: CanvasItem, pos: Vector2, texto: String, tamanho: int, cor: Color, forca := 1.0) -> void:
	var al := HORIZONTAL_ALIGNMENT_LEFT
	if forca <= 0.05:
		ci.draw_string_outline(FONTE, pos, texto, al, -1, tamanho, 2, Color(cor.darkened(0.75), 0.6))
		return
	ci.draw_string_outline(FONTE, pos, texto, al, -1, tamanho, 10, Color(cor, 0.12 * forca))
	ci.draw_string_outline(FONTE, pos, texto, al, -1, tamanho, 5, Color(cor, 0.3 * forca))
	ci.draw_string_outline(FONTE, pos, texto, al, -1, tamanho, 2, Color(cor.lerp(Color.WHITE, 0.2), forca))
	ci.draw_string_outline(FONTE, pos, texto, al, -1, tamanho, 1, Color(1, 1, 1, 0.55 * forca))


static func largura_texto(texto: String, tamanho: int) -> float:
	return FONTE.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x


## Pichação com spray: contorno escuro, cor e escorridos.
static func pichacao(ci: CanvasItem, pos: Vector2, texto: String, tamanho: int, cor: Color, inclinacao: float) -> void:
	var tr := Transform2D(Vector2(1, inclinacao * 0.4), Vector2(inclinacao, 1), pos)
	ci.draw_set_transform_matrix(tr)
	var al := HORIZONTAL_ALIGNMENT_LEFT
	ci.draw_string_outline(FONTE, Vector2(2, 2), texto, al, -1, tamanho, 5, Color(0, 0, 0, 0.6))
	ci.draw_string_outline(FONTE, Vector2.ZERO, texto, al, -1, tamanho, 4, Color(0.02, 0.02, 0.03))
	ci.draw_string(FONTE, Vector2.ZERO, texto, al, -1, tamanho, cor.darkened(0.25))
	ci.draw_string(FONTE, Vector2(0, -1), texto, al, -1, tamanho, Color(cor, 0.5))
	var w := largura_texto(texto, tamanho)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(texto)
	for i in 7:
		var x := rng.randf_range(2.0, w - 2.0)
		var comp := rng.randf_range(4.0, 16.0)
		ci.draw_line(Vector2(x, 0), Vector2(x, comp), cor.darkened(0.3), 1.5)
		ci.draw_circle(Vector2(x, comp), 1.3, cor.darkened(0.3))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Nó de luz com mistura aditiva: o desenho vem de uma função da camada.
class Luz extends Node2D:
	var desenhar: Callable

	func _init(f: Callable) -> void:
		desenhar = f
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = m
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	func _draw() -> void:
		desenhar.call(self)


# ------------------------------------------------------------ céu

class Ceu extends Node2D:
	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	func _draw() -> void:
		var meio := Color(0.06, 0.035, 0.1)
		ArenaSelaron.degrade(self, Rect2(-720, -560, 1440, 330), Color(0.012, 0.016, 0.045), meio)
		ArenaSelaron.degrade(self, Rect2(-720, -231, 1440, 340), meio, Color(0.17, 0.07, 0.2))
		# brilho da cidade no horizonte e a lua escondida atrás das nuvens
		ArenaSelaron.brilho(self, Vector2(0, -190), 760, Color(0.5, 0.12, 0.42, 0.22), 0.32)
		ArenaSelaron.brilho(self, Vector2(230, -375), 110, Color(0.55, 0.65, 0.9, 0.18))
		ArenaSelaron.brilho(self, Vector2(230, -375), 26, Color(0.8, 0.85, 1.0, 0.22))
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 30:
			var c := Vector2(rng.randf_range(-720, 720), rng.randf_range(-520, -340))
			var w := rng.randf_range(70, 200)
			var h := w * rng.randf_range(0.16, 0.26)
			ArenaSelaron.elipse(self, c + Vector2(0, h * 0.35), Vector2(w, h), Color(0.16, 0.08, 0.2, 0.35))
			ArenaSelaron.elipse(self, c, Vector2(w, h), Color(0.03, 0.035, 0.07, 0.8))


# ------------------------------------------------------------ morro e Cristo

class Morro extends Node2D:
	## x do Corcovado (o Cristo fica entre o cronômetro e o nome do P1).
	const CORCOVADO := -150.0

	static func crista(x: float) -> float:
		var y := -262.0 + 26.0 * sin(x * 0.0043 + 0.8) + 15.0 * sin(x * 0.013 + 2.0) + 6.0 * sin(x * 0.041)
		return y - 116.0 * exp(-pow((x - ArenaSelaron.Morro.CORCOVADO) / 60.0, 2.0))

	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	func _draw() -> void:
		var pts := PackedVector2Array([Vector2(-720, 120)])
		var x := -720.0
		while x <= 720.0:
			pts.append(Vector2(x, crista(x)))
			x += 12.0
		pts.append(Vector2(720, 120))
		draw_colored_polygon(pts, Color(0.03, 0.026, 0.055))
		# Cristo Redentor iluminado no alto do Corcovado
		var topo := Vector2(CORCOVADO, crista(CORCOVADO))
		ArenaSelaron.brilho(self, topo + Vector2(0, -16), 64, Color(0.6, 0.7, 1.0, 0.28))
		var pedra := Color(0.72, 0.78, 0.92)
		draw_rect(Rect2(topo.x - 3, topo.y - 6, 6, 6), Color(0.28, 0.3, 0.4))
		draw_colored_polygon(PackedVector2Array([
			topo + Vector2(-2.8, -6), topo + Vector2(2.8, -6), topo + Vector2(2.0, -24), topo + Vector2(-2.0, -24),
		]), pedra)
		draw_rect(Rect2(topo.x - 11, topo.y - 22.5, 22, 2.5), pedra)
		draw_circle(topo + Vector2(0, -26.5), 2.2, pedra)
		# luzes das casas no morro (mais casas na parte de baixo)
		var rng := RandomNumberGenerator.new()
		rng.seed = 21
		var cores := [Color(1.0, 0.75, 0.4), Color(1.0, 0.9, 0.7), Color(0.95, 0.55, 0.3), Color(0.7, 0.8, 1.0)]
		for i in 620:
			var lx := rng.randf_range(-720, 720)
			var cy := crista(lx)
			var ly := rng.randf_range(cy + 6.0, -150.0)
			if rng.randf() > 0.2 + 0.8 * inverse_lerp(cy, -150.0, ly):
				continue
			var c: Color = cores[rng.randi() % cores.size()]
			draw_rect(Rect2(lx, ly, 2.0 if rng.randf() < 0.3 else 1.0, 1.0), Color(c, rng.randf_range(0.35, 0.9)))


# ------------------------------------------------------------ casario de Santa Teresa

class Casario extends Node2D:
	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 33
		var paredes := [
			Color(0.2, 0.15, 0.1), Color(0.1, 0.16, 0.18), Color(0.2, 0.11, 0.15), Color(0.11, 0.12, 0.2),
			Color(0.17, 0.17, 0.12),
		]
		for fila in [[-300.0, 0.45], [-256.0, 0.6], [-208.0, 0.75]]:
			var base: float = fila[0]
			var luz: float = fila[1]
			var x := -720.0
			while x < 720.0:
				var w := rng.randf_range(38, 86)
				var h := rng.randf_range(30, 58)
				var y0 := base + rng.randf_range(-10, 10)
				if rng.randf() < 0.18:
					# árvore no meio das casas
					var verde := Color(0.025, 0.06, 0.045).lerp(ArenaSelaron.NEVOA, 1.0 - luz)
					var c := Vector2(x + w * 0.5, y0 - h * 0.4)
					for k in 5:
						var desloc := Vector2(rng.randf_range(-w * 0.4, w * 0.4), rng.randf_range(-h * 0.3, h * 0.2))
						draw_circle(c + desloc, rng.randf_range(12, 22), verde)
					x += w * 0.8
					continue
				var parede: Color = paredes[rng.randi() % paredes.size()]
				parede = parede.darkened(1.0 - luz).lerp(ArenaSelaron.NEVOA, 0.4 * (1.0 - luz))
				draw_rect(Rect2(x, y0 - h, w, h + 140), parede)
				var telha := Color(0.22, 0.08, 0.06).darkened(1.0 - luz)
				draw_colored_polygon(PackedVector2Array([
					Vector2(x - 4, y0 - h), Vector2(x + w * 0.5, y0 - h - rng.randf_range(10, 18)), Vector2(x + w + 4, y0 - h),
				]), telha)
				for jx in int(w / 16.0):
					for jy in int(h / 22.0):
						var sorteio := rng.randf()
						var cj := Color(0.02, 0.02, 0.04)
						if sorteio < 0.3:
							cj = Color(1.0, 0.68, 0.32).darkened(0.25 * (1.0 - luz) + rng.randf_range(0.0, 0.3))
						elif sorteio < 0.36:
							cj = Color(0.45, 0.6, 1.0).darkened(0.3)
						draw_rect(Rect2(x + 6 + jx * 16, y0 - h + 8 + jy * 22, 6, 10), cj)
				x += w + rng.randf_range(-6, 4)
		# névoa por cima, para empurrar o casario para longe
		ArenaSelaron.degrade(self, Rect2(-720, -420, 1440, 330), Color(ArenaSelaron.NEVOA, 0.0), Color(ArenaSelaron.NEVOA, 0.55))


# ------------------------------------------------------------ escadaria

class Escadaria extends Node2D:
	const DEGRAUS := 26
	## Cada degrau de cima fica deste tanto menor (perspectiva).
	const K := 0.952
	const MEIA := 236.0
	const MURO := 240.0
	const REJUNTE := Color(0.025, 0.022, 0.035)
	const PISO := Color(0.07, 0.065, 0.09)
	const CORES_DEGRAU := [
		[Color(0.7, 0.08, 0.07), 80], [Color(0.8, 0.6, 0.1), 5], [Color(0.07, 0.42, 0.22), 4],
		[Color(0.1, 0.22, 0.62), 6], [Color(0.78, 0.78, 0.74), 5],
	]
	const CORES_MURO := [
		[Color(0.82, 0.62, 0.1), 28], [Color(0.07, 0.45, 0.24), 26], [Color(0.1, 0.24, 0.62), 26],
		[Color(0.66, 0.08, 0.07), 10], [Color(0.78, 0.78, 0.74), 10],
	]

	## Por degrau: [y da base, meia largura, altura do espelho, altura do piso, escala]
	var degraus: Array = []
	var topo := 0.0
	## Fios de água descendo: [degrau (com fração), x de -1 a 1, força]
	var gotas: Array = []
	var _agua: Node2D
	var _rng := RandomNumberGenerator.new()

	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var y := ArenaSelaron.BASE
		for i in DEGRAUS:
			var s := pow(K, i)
			var e := 15.0 * s
			var p := 4.6 * s
			degraus.append([y, MEIA * s, e, p, s])
			y -= e + p
		topo = y
		add_child(ArenaSelaron.Luz.new(_luzes))
		_agua = ArenaSelaron.Luz.new(_desenhar_agua)
		add_child(_agua)
		for i in 34:
			gotas.append([_rng.randf() * DEGRAUS, _rng.randf_range(-0.92, 0.92), _rng.randf_range(0.3, 1.0)])

	func _process(delta: float) -> void:
		for g in gotas:
			g[0] = float(g[0]) - delta * 6.5
			if float(g[0]) < 0.0:
				g[0] = float(g[0]) + DEGRAUS
				g[1] = _rng.randf_range(-0.92, 0.92)
		_agua.queue_redraw()

	func _cor(rng: RandomNumberGenerator, prof: float, tabela: Array) -> Color:
		var total := 0
		for t in tabela:
			total += int(t[1])
		var sorteio := rng.randi() % total
		var cor: Color = tabela[0][0]
		for t in tabela:
			sorteio -= int(t[1])
			if sorteio < 0:
				cor = t[0]
				break
		var v := rng.randf_range(0.82, 1.14)
		cor = Color(cor.r * v, cor.g * v, cor.b * v)
		return cor.darkened(0.48 + 0.22 * prof).lerp(ArenaSelaron.NEVOA, 0.12 + 0.62 * prof)

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1990
		_muro(-1.0, rng)
		_muro(1.0, rng)
		_patamar(rng)
		var n := degraus.size()
		for i in n:
			var d: Array = degraus[i]
			var y: float = d[0]
			var w: float = d[1]
			var e: float = d[2]
			var p: float = d[3]
			var prof := float(i) / n
			# espelho do degrau: uma fileira de azulejos, quase todos vermelhos
			draw_rect(Rect2(-w, y - e, 2.0 * w, e), REJUNTE)
			var colunas := 13
			var tw := 2.0 * w / colunas
			for c in colunas:
				draw_rect(Rect2(-w + c * tw + 0.6, y - e + 0.6, tw - 1.2, e - 1.2), _cor(rng, prof, CORES_DEGRAU))
			# sombra embaixo de cada espelho (o degrau ganha volume)
			ArenaSelaron.degrade(self, Rect2(-w, y - e * 0.45, 2.0 * w, e * 0.45), Color(0, 0, 0.02, 0.0), Color(0, 0, 0.02, 0.45))
			# piso molhado: reflete o vermelho do degrau de cima
			var piso := PISO.lerp(Color(0.3, 0.05, 0.06), 0.25).darkened(prof * 0.5).lerp(ArenaSelaron.NEVOA, prof * 0.5)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-w, y - e), Vector2(w, y - e), Vector2(w * K, y - e - p), Vector2(-w * K, y - e - p),
			]), piso)
			# quina molhada brilhando
			draw_line(Vector2(-w, y - e), Vector2(w, y - e), Color(0.75, 0.6, 0.8, 0.5 * (1.0 - prof)), 1.0)
		# a escada some na neblina lá em cima
		ArenaSelaron.degrade(self, Rect2(-MEIA, topo - 110.0, 2.0 * MEIA, 230.0), Color(ArenaSelaron.NEVOA, 0.75), Color(ArenaSelaron.NEVOA, 0.0))
		# sombra no pé da escada (os lutadores ficam na frente e precisam aparecer)
		ArenaSelaron.degrade(self, Rect2(-MEIA - 120, ArenaSelaron.BASE - 150, 2.0 * MEIA + 240, 152),
			Color(0, 0, 0.02, 0.0), Color(0, 0, 0.02, 0.45))

	## Muro de um lado da escada: uma faixa que sobe junto com os degraus.
	func _muro(lado: float, rng: RandomNumberGenerator) -> void:
		var n := degraus.size()
		var contorno := PackedVector2Array()
		for i in n:
			contorno.append(Vector2(lado * float(degraus[i][1]), float(degraus[i][0])))
		for i in range(n - 1, -1, -1):
			contorno.append(Vector2(lado * float(degraus[i][1]), float(degraus[i][0]) - MURO * float(degraus[i][4])))
		draw_colored_polygon(contorno, REJUNTE)
		for i in n - 1:
			var d0: Array = degraus[i]
			var d1: Array = degraus[i + 1]
			var a0 := Vector2(lado * float(d0[1]), float(d0[0]))
			var a1 := Vector2(lado * float(d1[1]), float(d1[0]))
			var b0 := a0 + Vector2(0, -MURO * float(d0[4]))
			var b1 := a1 + Vector2(0, -MURO * float(d1[4]))
			var prof := float(i) / n
			for u in 2:
				for v in 13:
					var q := PackedVector2Array([
						_bil(a0, a1, b0, b1, u / 2.0, v / 13.0), _bil(a0, a1, b0, b1, (u + 1) / 2.0, v / 13.0),
						_bil(a0, a1, b0, b1, (u + 1) / 2.0, (v + 1) / 13.0), _bil(a0, a1, b0, b1, u / 2.0, (v + 1) / 13.0),
					])
					var centro := (q[0] + q[1] + q[2] + q[3]) * 0.25
					for k in 4:
						q[k] = centro + (q[k] - centro) * 0.84
					draw_colored_polygon(q, _cor(rng, prof * 0.85, CORES_MURO))
		# beirada de pedra no alto do muro e plantas caindo por cima
		var beirada := PackedVector2Array()
		for i in n:
			beirada.append(Vector2(lado * float(degraus[i][1]), float(degraus[i][0]) - MURO * float(degraus[i][4])))
		draw_polyline(beirada, Color(0.2, 0.18, 0.22), 3.0)
		for i in range(0, n - 4, 3):
			var b: Vector2 = beirada[i]
			var s: float = degraus[i][4]
			var verde := Color(0.03, 0.09, 0.05).lerp(ArenaSelaron.NEVOA, float(i) / n * 0.6)
			draw_circle(b + Vector2(-lado * 4.0 * s, 2.0 * s), rng.randf_range(5.0, 9.0) * s, verde)
			for k in 3:
				var comp := rng.randf_range(10.0, 40.0) * s
				var ini := b + Vector2(-lado * rng.randf_range(0.0, 10.0) * s, 0.0)
				draw_line(ini, ini + Vector2(rng.randf_range(-3.0, 3.0), comp), verde, maxf(1.0, 1.6 * s))
		# frente do muro (de cara para a rua), quase toda escondida pelos prédios
		var x0 := lado * MEIA
		var largura := 120.0
		var r := Rect2(minf(x0, x0 + lado * largura), ArenaSelaron.BASE - MURO, largura, MURO)
		draw_rect(r, REJUNTE)
		for cx in 8:
			for cy in 16:
				draw_rect(Rect2(r.position.x + cx * 15.0 + 1.0, r.position.y + cy * 15.0 + 1.0, 13.0, 13.0), _cor(rng, 0.1, CORES_MURO))

	func _bil(a0: Vector2, a1: Vector2, b0: Vector2, b1: Vector2, u: float, v: float) -> Vector2:
		return a0.lerp(a1, u).lerp(b0.lerp(b1, u), v)

	## Patamar lá em cima: parede de azulejos, lampião e a escada virando.
	func _patamar(rng: RandomNumberGenerator) -> void:
		var dt: Array = degraus[degraus.size() - 1]
		var wt: float = float(dt[1]) * K
		var alto: float = MURO * float(dt[4]) * K
		var r := Rect2(-wt - 2.0, topo - alto, 2.0 * wt + 4.0, alto)
		draw_rect(r, REJUNTE)
		var cols := 12
		var linhas := 6
		for cx in cols:
			for cy in linhas:
				var tw := r.size.x / cols
				var th := r.size.y / linhas
				draw_rect(Rect2(r.position.x + cx * tw + 0.5, r.position.y + cy * th + 0.5, tw - 1.0, th - 1.0), _cor(rng, 0.95, CORES_MURO))
		var l := Vector2(-wt * 0.45, topo - alto * 0.62)
		draw_rect(Rect2(l.x - 0.5, l.y - 10, 1.0, 10), Color(0.02, 0.02, 0.03))
		draw_rect(Rect2(l.x - 2.5, l.y - 1, 5, 6), Color(1.0, 0.78, 0.45))

	func _luzes(ci: CanvasItem) -> void:
		var dt: Array = degraus[degraus.size() - 1]
		var wt: float = float(dt[1]) * K
		var alto: float = MURO * float(dt[4]) * K
		ArenaSelaron.brilho(ci, Vector2(-wt * 0.45, topo - alto * 0.62 + 2), 46, Color(ArenaSelaron.LUZ_POSTE, 0.4))
		# o neon da rua pinta o pé da escada
		ArenaSelaron.brilho(ci, Vector2(-250, -110), 190, Color(ArenaSelaron.ROSA, 0.13), 0.9)
		ArenaSelaron.brilho(ci, Vector2(250, -150), 170, Color(ArenaSelaron.AMARELO, 0.08), 1.1)
		ArenaSelaron.brilho(ci, Vector2(0, -60), 260, Color(ArenaSelaron.LUZ_POSTE, 0.05), 0.5)

	func _desenhar_agua(ci: CanvasItem) -> void:
		for g in gotas:
			var i := int(g[0])
			var d: Array = degraus[i]
			var e: float = d[2]
			var s: float = d[4]
			var y: float = float(d[0]) - e
			var x: float = float(g[1]) * float(d[1])
			var forca: float = g[2]
			var fr := float(g[0]) - i
			ci.draw_line(Vector2(x - 3.0 * s, y), Vector2(x + 3.0 * s, y), Color(0.55, 0.72, 1.0, 0.45 * forca * s), 1.0)
			# filete escorrendo pelo espelho
			ci.draw_line(Vector2(x, y), Vector2(x, y + e * (1.0 - fr)), Color(0.5, 0.65, 1.0, 0.25 * forca * s), 1.0)


# ------------------------------------------------------------ prédios da rua

class Fachadas extends Node2D:
	const FERRO := Color(0.02, 0.02, 0.03)

	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(ArenaSelaron.Luz.new(_luzes))

	func _draw() -> void:
		_predio_esquerda()
		_predio_direita()
		_fiacao()

	func _manchas(r: Rect2, semente: int) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = semente
		for i in 22:
			var c := Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
			var raio := Vector2(rng.randf_range(10, 40), rng.randf_range(16, 60))
			ArenaSelaron.elipse(self, c, raio, Color(0, 0, 0.01, rng.randf_range(0.08, 0.2)))
		for i in 10:
			# reboco caído mostrando tijolo
			var p := Vector2(rng.randf_range(r.position.x, r.end.x - 30), rng.randf_range(r.position.y, r.end.y - 20))
			for t in 5:
				var dx := 0.0 if t % 2 == 0 else 4.0
				draw_rect(Rect2(p.x + dx, p.y + t * 4.0, 8, 3), Color(0.16, 0.07, 0.05, 0.7))
				draw_rect(Rect2(p.x + dx + 9, p.y + t * 4.0, 8, 3), Color(0.16, 0.07, 0.05, 0.7))

	func _janela(r: Rect2, acesa: bool, silhueta: bool) -> void:
		draw_rect(r.grow(4), Color(0.14, 0.12, 0.14))
		if acesa:
			ArenaSelaron.degrade(self, r, Color(0.5, 0.28, 0.1), Color(0.7, 0.45, 0.16))
			if silhueta:
				var s := Color(0.12, 0.05, 0.03)
				var c := r.get_center() + Vector2(6, -6)
				draw_circle(c + Vector2(0, -12), 6, s)
				draw_rect(Rect2(c.x - 8, c.y - 5, 16, r.end.y - c.y + 5), s)
			draw_line(Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), Color(0.14, 0.12, 0.14), 2.0)
		else:
			# venezianas fechadas
			draw_rect(r, Color(0.05, 0.13, 0.1))
			var y := r.position.y + 3
			while y < r.end.y:
				draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0.02, 0.06, 0.05), 1.0)
				y += 4
			draw_line(Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), Color(0.02, 0.05, 0.04), 2.0)

	func _sacada(x0: float, x1: float, y: float) -> void:
		draw_rect(Rect2(x0, y, x1 - x0, 7), Color(0.12, 0.1, 0.12))
		var x := x0 + 3.0
		while x < x1:
			draw_line(Vector2(x, y), Vector2(x, y - 26), FERRO, 1.5)
			x += 6.0
		draw_line(Vector2(x0, y - 26), Vector2(x1, y - 26), FERRO, 2.5)
		draw_line(Vector2(x0, y - 13), Vector2(x1, y - 13), FERRO, 1.0)

	func _plantas(x0: float, x1: float, y: float, semente: int) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = semente
		for i in 9:
			var c := Vector2(rng.randf_range(x0, x1), y - rng.randf_range(0, 8))
			draw_circle(c, rng.randf_range(5, 9), Color(0.03, 0.1, 0.06))
			var comp := rng.randf_range(8, 30)
			draw_line(c, c + Vector2(rng.randf_range(-4, 4), comp), Color(0.03, 0.09, 0.05), 1.5)

	func _predio_esquerda() -> void:
		var b := ArenaSelaron.BASE
		var r := Rect2(-700, -352, 460, b + 352)
		draw_rect(r, Color(0.085, 0.068, 0.095))
		_manchas(r, 4)
		# térreo: porta do bar em arco, com luz quente lá dentro
		var porta := Rect2(-398, -120, 56, b + 120)
		draw_rect(porta.grow(5), Color(0.15, 0.12, 0.13))
		draw_circle(Vector2(-370, -120), 33, Color(0.15, 0.12, 0.13))
		draw_circle(Vector2(-370, -120), 28, Color(0.38, 0.18, 0.06))
		ArenaSelaron.degrade(self, porta, Color(0.42, 0.2, 0.07), Color(0.64, 0.38, 0.14))
		var s := Color(0.09, 0.04, 0.03)
		draw_circle(Vector2(-382, -92), 6, s)
		draw_rect(Rect2(-390, -85, 17, 40), s)
		draw_circle(Vector2(-357, -88), 5.5, s)
		draw_rect(Rect2(-364, -81, 15, 36), s)
		draw_rect(Rect2(-398, -58, 56, 5), Color(0.2, 0.09, 0.04))
		# janela gradeada do bar
		var jan := Rect2(-482, -118, 50, 56)
		draw_rect(jan.grow(4), Color(0.15, 0.12, 0.13))
		ArenaSelaron.degrade(self, jan, Color(0.4, 0.2, 0.08), Color(0.55, 0.32, 0.12))
		for k in 6:
			draw_line(Vector2(jan.position.x + 4 + k * 8.5, jan.position.y), Vector2(jan.position.x + 4 + k * 8.5, jan.end.y), FERRO, 2.0)
		# pichação do ACERVO
		ArenaSelaron.pichacao(self, Vector2(-332, -54), "ACERVO", 26, ArenaSelaron.CIANO, -0.12)
		# cadeiras de plástico na calçada (é bar no Rio)
		for cx in [-450.0, -424.0]:
			var c := Color(0.55, 0.06, 0.06).darkened(0.35)
			draw_rect(Rect2(cx, b - 22, 16, 3), c)
			draw_rect(Rect2(cx + 12, b - 36, 4, 17), c)
			draw_line(Vector2(cx + 1, b - 19), Vector2(cx - 1, b), c, 2.0)
			draw_line(Vector2(cx + 15, b - 19), Vector2(cx + 16, b), c, 2.0)
		# divisão do térreo e primeiro andar
		draw_rect(Rect2(-700, -200, 460, 8), Color(0.14, 0.11, 0.13))
		_janela(Rect2(-470, -300, 44, 80), true, true)
		_janela(Rect2(-392, -300, 44, 80), false, false)
		_sacada(-482, -334, -212)
		_plantas(-480, -336, -238, 12)
		# cornija e platibanda
		draw_rect(Rect2(-700, -340, 460, 10), Color(0.15, 0.12, 0.14))
		draw_rect(Rect2(-700, -352, 460, 4), Color(0.12, 0.1, 0.12))
		for k in 30:
			draw_rect(Rect2(-696 + k * 15, -348, 5, 8), Color(0.12, 0.1, 0.12))
		# pilastra da esquina
		draw_rect(Rect2(-262, -352, 22, b + 352), Color(0.13, 0.105, 0.13))
		draw_line(Vector2(-241, -352), Vector2(-241, b), Color(ArenaSelaron.ROSA, 0.35), 1.0)

	func _predio_direita() -> void:
		var b := ArenaSelaron.BASE
		var r := Rect2(240, -336, 460, b + 336)
		draw_rect(r, Color(0.06, 0.075, 0.1))
		_manchas(r, 8)
		# porta de aço de enrolar, pichada pelo GRUPO B
		var aco := Rect2(298, -122, 140, b + 122)
		draw_rect(Rect2(aco.position.x - 6, aco.position.y - 16, aco.size.x + 12, 14), Color(0.12, 0.12, 0.15))
		draw_rect(aco.grow(3), Color(0.1, 0.1, 0.12))
		draw_rect(aco, Color(0.16, 0.17, 0.2))
		var y := aco.position.y + 2.0
		while y < aco.end.y:
			draw_line(Vector2(aco.position.x, y), Vector2(aco.end.x, y), Color(0.09, 0.1, 0.12), 1.0)
			draw_line(Vector2(aco.position.x, y + 1), Vector2(aco.end.x, y + 1), Color(0.25, 0.26, 0.3), 1.0)
			y += 5.0
		ArenaSelaron.pichacao(self, Vector2(310, -62), "GRUPO B", 30, ArenaSelaron.ROSA, -0.08)
		# portinha com lâmpada fraca
		draw_rect(Rect2(452, -104, 36, b + 104), Color(0.04, 0.04, 0.06))
		draw_rect(Rect2(452, -104, 36, b + 104), Color(0.12, 0.12, 0.15), false, 2.0)
		draw_circle(Vector2(470, -112), 3, Color(1.0, 0.85, 0.55))
		# primeiro andar
		draw_rect(Rect2(240, -196, 460, 7), Color(0.1, 0.11, 0.14))
		_janela(Rect2(392, -296, 42, 76), false, false)
		_janela(Rect2(468, -296, 42, 76), true, false)
		# ar-condicionado pingando, claro
		draw_rect(Rect2(396, -214, 34, 18), Color(0.3, 0.31, 0.34))
		for k in 5:
			draw_line(Vector2(400, -210 + k * 3), Vector2(426, -210 + k * 3), Color(0.15, 0.15, 0.18), 1.0)
		_sacada(380, 520, -212)
		_plantas(384, 516, -238, 31)
		# letreiro vertical (as letras de neon ficam na camada Neon)
		draw_rect(Rect2(260, -150, 3, 6), FERRO)
		draw_rect(Rect2(262, -292, 34, 146), Color(0.03, 0.03, 0.05))
		draw_rect(Rect2(262, -292, 34, 146), Color(0.1, 0.1, 0.12), false, 2.0)
		# cornija
		draw_rect(Rect2(240, -326, 460, 9), Color(0.1, 0.11, 0.14))
		draw_rect(Rect2(240, -336, 460, 4), Color(0.09, 0.1, 0.13))
		draw_rect(Rect2(240, -336, 20, b + 336), Color(0.1, 0.11, 0.15))
		draw_line(Vector2(240, -336), Vector2(240, b), Color(ArenaSelaron.AMARELO, 0.25), 1.0)

	## Fios atravessando a rua (e o tênis pendurado, claro).
	func _fiacao() -> void:
		var tenis_em := Vector2.ZERO
		for k in 4:
			var a := Vector2(-252, -318.0 + k * 9.0)
			var c := Vector2(252, -305.0 + k * 7.0)
			var flecha := 26.0 + k * 9.0
			var pts := PackedVector2Array()
			for i in 25:
				var t := float(i) / 24.0
				var p := a.lerp(c, t)
				p.y += flecha * 4.0 * t * (1.0 - t)
				pts.append(p)
				if k == 1 and i == 15:
					tenis_em = p
			draw_polyline(pts, FERRO, 2.5 if k == 2 else 1.5)
		for lado in [-1.0, 1.0]:
			var fim := tenis_em + Vector2(lado * 5.0, 18.0 + (lado + 1.0) * 3.0)
			draw_line(tenis_em, fim, Color(0.6, 0.6, 0.65), 1.0)
			draw_colored_polygon(PackedVector2Array([
				fim + Vector2(-3, 0), fim + Vector2(4, 0), fim + Vector2(9, 8), fim + Vector2(9, 11), fim + Vector2(-3, 11),
			]), Color(0.75, 0.75, 0.78))
			draw_rect(Rect2(fim.x - 3, fim.y + 9, 12, 2), Color(0.8, 0.1, 0.15))

	func _luzes(ci: CanvasItem) -> void:
		# luz que sai da porta e da janela do bar
		ArenaSelaron.brilho(ci, Vector2(-370, -60), 90, Color(1.0, 0.55, 0.2, 0.22), 1.0)
		ArenaSelaron.brilho(ci, Vector2(-457, -90), 50, Color(1.0, 0.55, 0.2, 0.18))
		ArenaSelaron.brilho(ci, Vector2(-448, -260), 50, Color(1.0, 0.6, 0.25, 0.12))
		ArenaSelaron.brilho(ci, Vector2(489, -258), 46, Color(1.0, 0.6, 0.25, 0.1))
		ArenaSelaron.brilho(ci, Vector2(470, -112), 26, Color(1.0, 0.8, 0.5, 0.3))


# ------------------------------------------------------------ letreiros de neon

class Neon extends Node2D:
	const LETREIRO := "SELARÓN"
	const SIMBOLOS := "01#@%&*"
	var t := 0.0
	var _falha := 0.0
	var _proxima_falha := 3.0
	var _rng := RandomNumberGenerator.new()

	func _init() -> void:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = m
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	func _process(delta: float) -> void:
		t += delta
		_proxima_falha -= delta
		if _proxima_falha <= 0.0:
			_falha = _rng.randf_range(0.25, 0.6)
			_proxima_falha = _rng.randf_range(3.0, 7.0)
		_falha = maxf(0.0, _falha - delta)
		queue_redraw()

	func _draw() -> void:
		# BAR (rosa), com o R falhando de vez em quando
		var ciclo := fmod(t, 6.0)
		var r_aceso := 1.0
		if ciclo > 4.2 and ciclo < 4.7 and fmod(t * 24.0, 2.0) < 1.0:
			r_aceso = 0.0
		ArenaSelaron.brilho(self, Vector2(-372, -170), 80, Color(ArenaSelaron.ROSA, 0.22), 0.55)
		var pos := Vector2(-394, -158)
		ArenaSelaron.texto_neon(self, pos, "BA", 30, ArenaSelaron.ROSA)
		ArenaSelaron.texto_neon(self, pos + Vector2(ArenaSelaron.largura_texto("BA", 30), 0), "R", 30, ArenaSelaron.ROSA, r_aceso)
		_taca(Vector2(-322, -184))
		ArenaSelaron.texto_neon(self, Vector2(-478, -100), "ABERTO", 12, ArenaSelaron.VERDE, 0.85)
		_letreiro(Vector2(279, -288))
		# TV ligada na janela da direita
		var tv := 0.5 + 0.5 * sin(t * 13.0) * sin(t * 3.7 + 1.0)
		ArenaSelaron.brilho(self, Vector2(413, -258), 44, Color(0.35, 0.5, 1.0, 0.1 + 0.12 * tv))
		draw_rect(Rect2(392, -296, 42, 76), Color(0.25, 0.35, 0.8, 0.08 + 0.12 * tv))

	## Taça de coquetel em neon ciano, com azeitona.
	func _taca(p: Vector2) -> void:
		var c := ArenaSelaron.CIANO
		ArenaSelaron.brilho(self, p + Vector2(0, 10), 34, Color(c, 0.2))
		var pts := PackedVector2Array([p + Vector2(-12, 0), p + Vector2(12, 0), p + Vector2(0, 13), p + Vector2(-12, 0)])
		for larg in [[6.0, 0.15], [3.0, 0.4], [1.5, 1.0]]:
			var cor := Color(c, float(larg[1]))
			draw_polyline(pts, cor, larg[0])
			draw_line(p + Vector2(0, 13), p + Vector2(0, 25), cor, larg[0])
			draw_line(p + Vector2(-7, 25), p + Vector2(7, 25), cor, larg[0])
		draw_circle(p + Vector2(4, 4), 2.5, Color(ArenaSelaron.VERDE, 0.9))

	## SELARÓN na vertical. Quando o vírus CASCATA mexe, as letras viram lixo
	## digital e o neon se separa em vermelho e azul.
	func _letreiro(topo: Vector2) -> void:
		var falhando := _falha > 0.0
		ArenaSelaron.brilho(self, topo + Vector2(0, 70), 84, Color(ArenaSelaron.AMARELO, 0.15), 1.7)
		for i in LETREIRO.length():
			var letra := LETREIRO[i]
			var pos := topo + Vector2(-ArenaSelaron.largura_texto(letra, 20) * 0.5, 22.0 + i * 19.0)
			if falhando:
				if _rng.randf() < 0.4:
					letra = SIMBOLOS[_rng.randi() % SIMBOLOS.length()]
				var desvio := Vector2(_rng.randf_range(-3.0, 3.0), 0.0)
				ArenaSelaron.texto_neon(self, pos + desvio, letra, 20, Color(1.0, 0.1, 0.3), 0.7)
				ArenaSelaron.texto_neon(self, pos - desvio, letra, 20, Color(0.1, 0.85, 1.0), 0.7)
			else:
				ArenaSelaron.texto_neon(self, pos, letra, 20, ArenaSelaron.AMARELO)
		var caixa := Rect2(topo.x - 15, topo.y, 30, 142)
		var forca := 0.4 if falhando else 0.85
		draw_rect(caixa.grow(2), Color(ArenaSelaron.VERDE, 0.2 * forca), false, 4.0)
		draw_rect(caixa, Color(ArenaSelaron.VERDE, forca), false, 1.5)


# ------------------------------------------------------------ rua

class Chao extends Node2D:
	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(ArenaSelaron.Luz.new(_reflexos))

	func _draw() -> void:
		var b := ArenaSelaron.BASE
		# calçada no pé dos prédios e meio-fio molhado
		draw_rect(Rect2(-720, b, 1440, 9), Color(0.08, 0.072, 0.095))
		draw_line(Vector2(-720, b + 9), Vector2(720, b + 9), Color(0.24, 0.22, 0.3), 1.0)
		# paralelepípedos: as fileiras crescem para a frente (perspectiva)
		draw_rect(Rect2(-720, b + 10, 1440, 150), Color(0.03, 0.03, 0.05))
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var y := b + 10.0
		var alt := 4.0
		var fila := 0
		while y < 120.0:
			var larg := alt * 2.6
			var x := -720.0 - (larg * 0.5 if fila % 2 == 1 else 0.0)
			while x < 720.0:
				var w := larg * rng.randf_range(0.85, 1.15)
				var tom := rng.randf_range(0.05, 0.095)
				draw_rect(Rect2(x + 0.5, y + 0.5, w - 1.0, alt - 1.0), Color(tom, tom * 0.95, tom * 1.3))
				draw_line(Vector2(x + 1.0, y + 0.5), Vector2(x + w - 2.0, y + 0.5), Color(0.3, 0.28, 0.42, 0.22), 1.0)
				x += w
			y += alt
			alt *= 1.13
			fila += 1
		# poças refletindo o céu roxo
		for p in [[Vector2(-250, 22), Vector2(70, 7)], [Vector2(130, 40), Vector2(90, 9)],
				[Vector2(-560, 52), Vector2(80, 8)], [Vector2(520, 14), Vector2(60, 6)]]:
			ArenaSelaron.elipse(self, p[0], p[1], Color(0.09, 0.065, 0.15, 0.9))
		# névoa baixa no pé dos prédios
		ArenaSelaron.degrade(self, Rect2(-720, b - 46, 1440, 52), Color(ArenaSelaron.NEVOA, 0.0), Color(ArenaSelaron.NEVOA, 0.5))
		# a frente da rua escurece (deixa o reflexo e o HUD legíveis)
		ArenaSelaron.degrade(self, Rect2(-720, 36, 1440, 90), Color(0, 0, 0.02, 0.0), Color(0, 0, 0.02, 0.75))

	## Reflexos das luzes na rua molhada: riscos que tremem para baixo.
	func _reflexos(ci: CanvasItem) -> void:
		var fontes := [
			[-372.0, ArenaSelaron.ROSA, 0.5, 46.0], [-322.0, ArenaSelaron.CIANO, 0.35, 24.0],
			[-457.0, ArenaSelaron.VERDE, 0.25, 26.0], [279.0, ArenaSelaron.AMARELO, 0.4, 26.0],
			[413.0, Color(0.4, 0.55, 1.0), 0.18, 30.0], [-430.0, ArenaSelaron.LUZ_POSTE, 0.4, 40.0],
			[430.0, ArenaSelaron.LUZ_POSTE, 0.4, 40.0], [0.0, Color(0.7, 0.15, 0.15), 0.12, 300.0],
		]
		var rng := RandomNumberGenerator.new()
		rng.seed = 9
		for f in fontes:
			var x: float = f[0]
			var cor: Color = f[1]
			var forca: float = f[2]
			var largura: float = f[3]
			var y := ArenaSelaron.BASE + 12.0
			while y < 100.0:
				var t := inverse_lerp(ArenaSelaron.BASE, 100.0, y)
				var w := largura * rng.randf_range(0.4, 1.0) * (1.0 + t)
				var a := forca * (1.0 - t) * rng.randf_range(0.4, 1.0)
				var x0 := x - w * 0.5 + rng.randf_range(-3.0, 3.0)
				ci.draw_line(Vector2(x0, y), Vector2(x0 + w, y), Color(cor, a), rng.randf_range(1.0, 2.0))
				y += rng.randf_range(2.0, 4.0) * (1.0 + t * 2.0)


# ------------------------------------------------------------ postes

class Postes extends Node2D:
	const FERRO := Color(0.03, 0.03, 0.045)

	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(ArenaSelaron.Luz.new(_luz))

	func _draw() -> void:
		for x in ArenaSelaron.POSTES_X:
			_poste(x)

	func _poste(x: float) -> void:
		var b := ArenaSelaron.BASE
		var l := Vector2(x, ArenaSelaron.ALTURA_LAMPIAO)
		draw_rect(Rect2(x - 10, b - 14, 20, 14), FERRO)
		draw_rect(Rect2(x - 6, b - 24, 12, 10), FERRO)
		draw_rect(Rect2(x - 3, l.y + 18, 6, b - 24 - (l.y + 18)), FERRO)
		for k in 3:
			draw_rect(Rect2(x - 5, b - 70 - k * 46, 10, 4), FERRO)
		# lampião colonial
		draw_rect(Rect2(x - 5, l.y + 14, 10, 6), FERRO)
		draw_colored_polygon(PackedVector2Array([
			l + Vector2(-10, -12), l + Vector2(10, -12), l + Vector2(7, 14), l + Vector2(-7, 14),
		]), Color(1.0, 0.84, 0.55))
		draw_line(l + Vector2(0, -12), l + Vector2(0, 14), FERRO, 1.5)
		draw_colored_polygon(PackedVector2Array([l + Vector2(-14, -12), l + Vector2(14, -12), l + Vector2(0, -24)]), FERRO)
		draw_circle(l + Vector2(0, -26), 2.5, FERRO)

	func _luz(ci: CanvasItem) -> void:
		var b := ArenaSelaron.BASE
		var c := ArenaSelaron.LUZ_POSTE
		for x in ArenaSelaron.POSTES_X:
			var l := Vector2(x, ArenaSelaron.ALTURA_LAMPIAO)
			# cone de luz até o chão
			ci.draw_polygon(PackedVector2Array([
				l + Vector2(-8, 14), l + Vector2(8, 14), Vector2(x + 95, b + 34), Vector2(x - 95, b + 34),
			]), PackedColorArray([Color(c, 0.16), Color(c, 0.16), Color(c, 0.0), Color(c, 0.0)]))
			ArenaSelaron.brilho(ci, l, 100, Color(c, 0.42))
			ArenaSelaron.brilho(ci, l, 24, Color(1.0, 0.95, 0.85, 0.75))
			ArenaSelaron.brilho(ci, Vector2(x, b + 16), 120, Color(c, 0.35), 0.16)


# ------------------------------------------------------------ chuva

class Chuva extends Node2D:
	const QUANTIDADE := 170
	var cam := ArenaSelaron.CAM_PADRAO
	## Gotas: [posição, velocidade, comprimento, alfa, y do chão onde cai]
	var gotas: Array = []
	## Respingos no chão: [posição, idade, alfa]
	var respingos: Array = []
	var _rng := RandomNumberGenerator.new()

	func _ready() -> void:
		for i in QUANTIDADE:
			gotas.append(_nova(true))

	func _nova(em_qualquer_altura: bool) -> Array:
		var perto := _rng.randf()
		var x := cam.x + _rng.randf_range(-560.0, 560.0)
		var y := cam.y + (_rng.randf_range(-300.0, 60.0) if em_qualquer_altura else _rng.randf_range(-340.0, -280.0))
		var vel := Vector2(1.2 + perto, 9.0 + perto * 6.0)
		return [Vector2(x, y), vel, 6.0 + perto * 12.0, 0.1 + perto * 0.28, lerpf(ArenaSelaron.BASE + 4.0, 70.0, perto)]

	func _physics_process(_delta: float) -> void:
		for i in gotas.size():
			var g: Array = gotas[i]
			var p: Vector2 = g[0] + g[1]
			if p.y >= float(g[4]):
				respingos.append([Vector2(p.x, float(g[4])), 0, g[3]])
				gotas[i] = _nova(false)
				continue
			if p.x > cam.x + 560.0:
				p.x -= 1120.0
			elif p.x < cam.x - 560.0:
				p.x += 1120.0
			g[0] = p
		for r in respingos:
			r[1] = int(r[1]) + 1
		respingos = respingos.filter(func(r): return int(r[1]) < 9)
		queue_redraw()

	func _draw() -> void:
		for g in gotas:
			var p: Vector2 = g[0]
			var v: Vector2 = g[1]
			var cor := Color(0.6, 0.7, 0.95, float(g[3]))
			# perto dos lampiões a chuva acende
			for x in ArenaSelaron.POSTES_X:
				var dy := p.y - ArenaSelaron.ALTURA_LAMPIAO
				if dy > -16.0 and absf(p.x - x) < 24.0 + dy * 0.45:
					cor = Color(1.0, 0.85, 0.6, minf(0.9, float(g[3]) * 2.6))
			draw_line(p, p - v.normalized() * float(g[2]), cor, 1.0)
		for r in respingos:
			var t := float(r[1]) / 9.0
			draw_set_transform(r[0], 0.0, Vector2(1.0, 0.3))
			draw_arc(Vector2.ZERO, 2.0 + t * 7.0, 0.0, TAU, 12, Color(0.7, 0.8, 1.0, (1.0 - t) * float(r[2]) * 1.5), 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
