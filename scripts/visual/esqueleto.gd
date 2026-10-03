class_name Esqueleto
extends Node2D
## Desenho procedural de um lutador a partir de uma pose de esqueleto.
##
## É a arte provisória da Parte 1: o corpo é montado com cinemática inversa
## (mãos e pés vão até os alvos da pose) e desenhado em duas passadas
## (contorno escuro e depois as cores), mais o contorno de neon de cada
## personagem. Quando os sprites em pixel art chegarem, este nó é trocado
## por um AnimatedSprite2D e a lógica de luta continua igual.
##
## Convenção: tudo é desenhado olhando para a DIREITA. O Lutador espelha o
## nó (scale.x = -1) quando olha para a esquerda. A origem é o chão, entre
## os pés; y negativo é para cima.

const CONTORNO := Color(0.015, 0.015, 0.035)

## Dimensões do corpo (vêm do Personagem).
var corpo: Dictionary = {}
## Pose atual já interpolada (vem do Lutador a cada frame).
var pose: Dictionary = {}
var cor_neon := Color.WHITE
## 0..1: deixa o corpo branco por um instante ao apanhar.
var flash := 0.0
## Reflexo no chão molhado: cores mais frias e sem detalhes de neon.
var eh_reflexo := false
## Estado do personagem que muda o desenho (ex.: guitarra na mão).
var extra: Dictionary = {}
## Contador de frames para animações do próprio desenho (cabelo, brilhos).
var t := 0
## Poses antigas para o rastro de neon dos especiais.
var rastros: Array = []

var paleta := {
	"pele": Color(0.72, 0.55, 0.45),
	"cabelo": Color(0.12, 0.09, 0.08),
	"camisa": Color(0.25, 0.27, 0.32),
	"calca": Color(0.15, 0.18, 0.28),
	"sapato": Color(0.08, 0.08, 0.1),
	"olho": Color(0.95, 0.97, 1.0),
}

var j: Dictionary = {}
var _passe := 1


# ------------------------------------------------------------------ juntas

## Cinemática inversa de dois ossos. Devolve [junta do meio, ponta].
## dobra = 1 gira para um lado (cotovelo para baixo/trás), -1 para o outro
## (joelho para frente).
static func ik(base: Vector2, alvo: Vector2, l1: float, l2: float, dobra: float) -> Array:
	var d := alvo - base
	var dist := d.length()
	if dist < 0.001:
		d = Vector2(0, 1)
		dist = 0.001
	var direcao := d / dist
	var dc := clampf(dist, absf(l1 - l2) + 0.01, l1 + l2 - 0.01)
	var cos_a := clampf((l1 * l1 + dc * dc - l2 * l2) / (2.0 * l1 * dc), -1.0, 1.0)
	var a := acos(cos_a)
	var meio := base + direcao.rotated(a * signf(dobra)) * l1
	return [meio, base + direcao * dc]


## Calcula as juntas de uma pose, no espaço do lutador (olhando para a direita).
static func calcular_juntas(p: Dictionary, c: Dictionary) -> Dictionary:
	var q: Vector2 = p["quadril"]
	var a_tr := deg_to_rad(float(p["tronco"]))
	var dir_tr := Vector2(sin(a_tr), -cos(a_tr))
	var ombro := dir_tr * float(c["tronco"])
	var a_cab := a_tr + deg_to_rad(float(p["cabeca"]))
	var dir_cab := Vector2(sin(a_cab), -cos(a_cab))
	var cabeca := ombro + dir_cab * (float(c["pescoco"]) + float(c["cabeca"]))
	var mao_f: Vector2 = p["mao_f"]
	var mao_t: Vector2 = p["mao_t"]
	var pe_f: Vector2 = p["pe_f"]
	var pe_t: Vector2 = p["pe_t"]
	var bf := ik(ombro, ombro + mao_f, c["braco"], c["antebraco"], float(p["cot_f"]))
	var bt := ik(ombro, ombro + mao_t, c["braco"], c["antebraco"], float(p["cot_t"]))
	var pf := ik(Vector2.ZERO, pe_f - q, c["coxa"], c["canela"], float(p["joe_f"]))
	var pt := ik(Vector2.ZERO, pe_t - q, c["coxa"], c["canela"], float(p["joe_t"]))
	var r := {
		"quadril": Vector2.ZERO, "ombro": ombro, "cabeca": cabeca,
		"cot_f": bf[0], "mao_f": bf[1], "cot_t": bt[0], "mao_t": bt[1],
		"joe_f": pf[0], "pe_f": pf[1], "joe_t": pt[0], "pe_t": pt[1],
	}
	var rot := deg_to_rad(float(p.get("rot", 0.0)))
	for k in r.keys():
		var v: Vector2 = r[k]
		r[k] = v.rotated(rot) + q
	r["dir_tronco"] = dir_tr.rotated(rot)
	r["dir_cabeca"] = dir_cab.rotated(rot)
	r["rot"] = rot
	# Ângulo da guitarra (ou de outro objeto na mão de trás), em graus.
	r["gt"] = deg_to_rad(float(p.get("gt", 90.0))) + rot
	return r


## Ponta de um objeto segurado: da mão, na direção 'ang', a 'comprimento'.
static func ponta(origem: Vector2, ang: float, comprimento: float) -> Vector2:
	return origem + Vector2(cos(ang), sin(ang)) * comprimento


# ------------------------------------------------------------------ desenho

func _draw() -> void:
	if pose.is_empty() or corpo.is_empty():
		return
	j = calcular_juntas(pose, corpo)
	if not eh_reflexo:
		_desenhar_rastros()
	for passe in 2:
		_passe = passe
		desenhar_corpo(j)
	_passe = 1
	if not eh_reflexo:
		desenhar_neon(j)


## Ordem padrão de um humanoide de perfil. Os personagens sobrescrevem as
## partes (braco, perna, tronco, cabeca) ou a ordem inteira.
func desenhar_corpo(jt: Dictionary) -> void:
	braco(jt["ombro"], jt["cot_t"], jt["mao_t"], false)
	perna(jt["joe_t"], jt["pe_t"], jt["quadril"], false)
	tronco(jt)
	perna(jt["joe_f"], jt["pe_f"], jt["quadril"], true)
	cabeca(jt)
	braco(jt["ombro"], jt["cot_f"], jt["mao_f"], true)


## Contorno de neon e detalhes que brilham (desenhados por cima de tudo).
func desenhar_neon(_jt: Dictionary) -> void:
	pass


func braco(ombro: Vector2, cotovelo: Vector2, mao: Vector2, da_frente: bool) -> void:
	var tom := 1.0 if da_frente else 0.72
	segmento(ombro, cotovelo, 11, 9, escurecer(paleta["camisa"], tom))
	segmento(cotovelo, mao, 9, 8, escurecer(paleta["pele"], tom))
	circulo(mao, 5.5, escurecer(paleta["pele"], tom))


func perna(joelho: Vector2, pe: Vector2, quadril: Vector2, da_frente: bool) -> void:
	var tom := 1.0 if da_frente else 0.7
	segmento(quadril, joelho, 16, 13, escurecer(paleta["calca"], tom))
	segmento(joelho, pe, 13, 11, escurecer(paleta["calca"], tom))
	pe_desenho(joelho, pe, escurecer(paleta["sapato"], tom), 20.0, 8.0)


func tronco(jt: Dictionary) -> void:
	var q: Vector2 = jt["quadril"]
	var o: Vector2 = jt["ombro"]
	var d: Vector2 = jt["dir_tronco"]
	var n := d.rotated(PI * 0.5)
	circulo(q, 13, paleta["calca"])
	var pts := PackedVector2Array([
		q + n * 12, o - d * 14 + n * 16, o + n * 10, o - n * 9, o - d * 12 - n * 13, q - n * 12,
	])
	poligono(pts, paleta["camisa"])
	circulo(o, 9, paleta["camisa"])


func cabeca(jt: Dictionary) -> void:
	var c: Vector2 = jt["cabeca"]
	var r: float = corpo["cabeca"]
	var v: Vector2 = -(jt["dir_cabeca"] as Vector2)  # para baixo da cabeça
	var u := (jt["dir_cabeca"] as Vector2).rotated(PI * 0.5)  # para frente do rosto
	segmento(jt["ombro"], c + v * r * 0.6, 10, 9, paleta["pele"])
	desenhar_rosto(c, u, v, r, paleta["pele"])


## Cabeça de perfil: crânio + mandíbula + nariz, olho e boca.
func desenhar_rosto(c: Vector2, u: Vector2, v: Vector2, r: float, pele: Color) -> void:
	circulo(c - v * r * 0.08, r, pele)
	var face := PackedVector2Array([
		c + u * r * 0.2 - v * r * 0.5,
		c + u * r * 0.86 - v * r * 0.25,
		c + u * r * 1.08 + v * r * 0.08,
		c + u * r * 0.86 + v * r * 0.25,
		c + u * r * 0.84 + v * r * 0.52,
		c + u * r * 0.62 + v * r * 0.88,
		c + u * r * 0.05 + v * r * 0.92,
		c - u * r * 0.4 + v * r * 0.55,
	])
	poligono(face, pele)
	if _passe == 0:
		return
	var fechado := float(pose.get("olhos", 0.0)) > 0.5
	var olho := c + u * r * 0.55 - v * r * 0.12
	if fechado or eh_reflexo:
		draw_line(olho - u * 2.5, olho + u * 2.0 + v * 0.8, cor(CONTORNO), 1.5)
	else:
		draw_rect(Rect2(olho - Vector2(1.5, 1.5), Vector2(3, 3)), cor(paleta["olho"]))
		draw_rect(Rect2(olho + u * 0.8 - Vector2(0.75, 0.75), Vector2(1.5, 1.5)), cor(CONTORNO))
	draw_line(olho - u * 3.0 - v * 3.2, olho + u * 2.5 - v * 3.6, cor(escurecer(paleta["cabelo"], 0.8)), 1.6)
	var boca := c + u * r * 0.72 + v * r * 0.55
	draw_line(boca - u * 2.5, boca + u * 1.0, cor(escurecer(pele, 0.55)), 1.2)


## Pé desenhado a partir do tornozelo. No chão fica reto; no ar segue a canela.
func pe_desenho(joelho: Vector2, tornozelo: Vector2, c: Color, comprimento: float, altura: float) -> void:
	var ang := 0.0
	var no_chao := absf(float(j.get("rot", 0.0))) < 0.01 and tornozelo.y > -3.0
	if not no_chao:
		ang = (tornozelo - joelho).angle() - PI * 0.5
	var frente := Vector2(cos(ang), sin(ang))
	var cima := frente.rotated(-PI * 0.5)
	var pts := PackedVector2Array([
		tornozelo - frente * 4 + cima * altura,
		tornozelo + frente * (comprimento * 0.55) + cima * (altura * 0.9),
		tornozelo + frente * comprimento + cima * (altura * 0.45),
		tornozelo + frente * comprimento,
		tornozelo - frente * 5,
	])
	poligono(pts, c)


func _desenhar_rastros() -> void:
	var n := rastros.size()
	for i in n:
		var r: Dictionary = rastros[i]
		var alfa := 0.08 + 0.22 * float(i + 1) / float(n + 1)
		var c := Color(cor_neon, alfa)
		for par in [["ombro", "cot_f"], ["cot_f", "mao_f"], ["quadril", "joe_f"], ["joe_f", "pe_f"],
				["quadril", "joe_t"], ["joe_t", "pe_t"], ["quadril", "ombro"], ["ombro", "cot_t"], ["cot_t", "mao_t"]]:
			draw_line(r[par[0]], r[par[1]], c, 7.0)
		draw_circle(r["cabeca"], 11.0, c)


# ------------------------------------------------------------ primitivas

## Cor final considerando a passada (contorno), o flash branco e o reflexo.
func cor(c: Color) -> Color:
	if _passe == 0:
		return CONTORNO
	var r := c
	if eh_reflexo:
		r = Color(r.r * 0.55, r.g * 0.65, r.b * 0.9, r.a)
	if flash > 0.0:
		r = r.lerp(Color.WHITE, flash)
	return r


func escurecer(c: Color, fator: float) -> Color:
	return Color(c.r * fator, c.g * fator, c.b * fator * (1.0 + (1.0 - fator) * 0.35), c.a)


func _largura(w: float) -> float:
	return w + 3.0 if _passe == 0 else w


## Segmento com espessura variável e pontas arredondadas (membros).
func segmento(a: Vector2, b: Vector2, wa: float, wb: float, c: Color) -> void:
	var cc := cor(c)
	var la := _largura(wa) * 0.5
	var lb := _largura(wb) * 0.5
	var d := b - a
	if d.length() > 0.5:
		var n := d.normalized().orthogonal()
		draw_colored_polygon(PackedVector2Array([a + n * la, b + n * lb, b - n * lb, a - n * la]), cc)
	draw_circle(a, la, cc)
	draw_circle(b, lb, cc)


func circulo(centro: Vector2, raio: float, c: Color) -> void:
	draw_circle(centro, raio + (1.5 if _passe == 0 else 0.0), cor(c))


func poligono(pts: PackedVector2Array, c: Color) -> void:
	if pts.size() < 3:
		return
	if _passe == 0:
		var fechado := pts.duplicate()
		fechado.append(pts[0])
		draw_polyline(fechado, CONTORNO, 3.0)
	draw_colored_polygon(pts, cor(c))


## Linha de neon (sem contorno), só na passada de cor.
func linha_neon(a: Vector2, b: Vector2, largura: float, c: Color) -> void:
	if _passe == 0 or eh_reflexo:
		return
	draw_line(a, b, Color(c, c.a * 0.35), largura + 2.0)
	draw_line(a, b, c, largura)


## Contorno de neon de um segmento, do lado de trás do corpo (luz de fundo).
func contorno_neon(a: Vector2, b: Vector2, largura_membro: float, c: Color) -> void:
	if eh_reflexo:
		return
	var d := b - a
	if d.length() < 1.0:
		return
	var n := d.normalized().orthogonal()
	if n.x > 0.0:
		n = -n
	var off := n * (largura_membro * 0.5 - 0.5)
	draw_line(a + off, b + off, Color(c, 0.85), 1.5)
