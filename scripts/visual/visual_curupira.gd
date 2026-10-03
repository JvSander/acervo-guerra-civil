extends Esqueleto
## Arte provisória da CURUPIRA: cabelo de fogo (como na lenda), top verde,
## calça de abadá branca, corda de capoeira em neon verde-mata e pés descalços.

const PELE := Color(0.5, 0.33, 0.24)
const TOP := Color(0.06, 0.19, 0.12)
const ABADA := Color(0.84, 0.86, 0.88)
const FOGO_FORA := Color(0.86, 0.16, 0.06)
const FOGO_MEIO := Color(1.0, 0.45, 0.08)
const FOGO_DENTRO := Color(1.0, 0.82, 0.3)


func _init() -> void:
	paleta = {
		"pele": PELE,
		"cabelo": Color(0.75, 0.18, 0.06),
		"camisa": TOP,
		"calca": ABADA,
		"sapato": PELE,
		"olho": Color(0.45, 1.0, 0.6),
	}


func desenhar_corpo(jt: Dictionary) -> void:
	braco(jt["ombro"], jt["cot_t"], jt["mao_t"], false)
	perna(jt["joe_t"], jt["pe_t"], jt["quadril"], false)
	tronco(jt)
	perna(jt["joe_f"], jt["pe_f"], jt["quadril"], true)
	cabeca(jt)
	braco(jt["ombro"], jt["cot_f"], jt["mao_f"], true)
	_corda(jt)


func braco(ombro: Vector2, cotovelo: Vector2, mao: Vector2, da_frente: bool) -> void:
	var tom := 1.0 if da_frente else 0.68
	segmento(ombro, cotovelo, 9, 8, escurecer(PELE, tom))
	segmento(cotovelo, mao, 8, 7, escurecer(PELE, tom))
	circulo(mao, 4.5, escurecer(PELE, tom))
	if _passe == 1 and not eh_reflexo:
		# tatuagem de neon (cipó) no antebraço
		var a := cotovelo.lerp(mao, 0.2)
		var b := cotovelo.lerp(mao, 0.8)
		var n := (b - a).normalized().orthogonal() * 2.0
		var c := Color(cor_neon, 0.85 * tom)
		draw_polyline(PackedVector2Array([a, a.lerp(b, 0.33) + n, a.lerp(b, 0.66) - n, b]), c, 1.0)
		if da_frente:
			contorno_neon(ombro, cotovelo, 9, Color(cor_neon, 0.7))


func perna(joelho: Vector2, pe: Vector2, quadril: Vector2, da_frente: bool) -> void:
	var tom := 1.0 if da_frente else 0.62
	var calca := escurecer(ABADA, tom)
	segmento(quadril, joelho, 18, 15, calca)
	var tornozelo := pe + (joelho - pe).normalized() * 6.0
	segmento(joelho, tornozelo, 15, 17, calca)
	pe_desenho(joelho, pe, escurecer(PELE, tom), 16.0, 6.0)
	if _passe == 1 and not eh_reflexo and da_frente:
		contorno_neon(quadril, joelho, 18, Color(cor_neon, 0.55))
		contorno_neon(joelho, tornozelo, 16, Color(cor_neon, 0.55))


func tronco(jt: Dictionary) -> void:
	var q: Vector2 = jt["quadril"]
	var o: Vector2 = jt["ombro"]
	var d: Vector2 = jt["dir_tronco"]
	var n := d.rotated(PI * 0.5)
	circulo(q, 12, ABADA)
	var barriga := PackedVector2Array([
		q + n * 10 + d * 4, q + n * 9 + d * 26, q - n * 11 + d * 26, q - n * 11 + d * 4,
	])
	poligono(barriga, PELE)
	var top := PackedVector2Array([
		q + n * 10 + d * 22, o - d * 12 + n * 14, o + n * 8, o - n * 8, o - d * 12 - n * 12, q - n * 11 + d * 22,
	])
	poligono(top, TOP)
	circulo(o, 8, PELE)
	if _passe == 1 and not eh_reflexo:
		linha_neon(q + n * 10 + d * 22, q - n * 11 + d * 22, 1.2, Color(cor_neon, 0.8))
		contorno_neon(q - n * 11 + d * 22, o - d * 12 - n * 12, 3.0, cor_neon)


## Corda de capoeira na cintura, com as pontas balançando na ginga.
func _corda(jt: Dictionary) -> void:
	if _passe == 0 or eh_reflexo:
		return
	var q: Vector2 = jt["quadril"]
	var d: Vector2 = jt["dir_tronco"]
	var n := d.rotated(PI * 0.5)
	var cinto := q + d * 2.0
	draw_line(cinto - n * 13, cinto + n * 12, Color(cor_neon, 0.35), 5.0)
	draw_line(cinto - n * 13, cinto + n * 12, cor_neon, 2.0)
	var no := cinto + n * 8
	var balanco := sin(float(t) * 0.18) * 4.0
	for k in 2:
		var ponta := no + Vector2(-3.0 + k * 5.0 + balanco, 20.0 + k * 4.0)
		var meio := no.lerp(ponta, 0.5) + Vector2(balanco * 0.5, 0)
		draw_polyline(PackedVector2Array([no, meio, ponta]), cor_neon, 1.6)
		draw_circle(ponta, 1.8, cor_neon)


func cabeca(jt: Dictionary) -> void:
	var c: Vector2 = jt["cabeca"]
	var r: float = corpo["cabeca"]
	var up: Vector2 = jt["dir_cabeca"]
	var v := -up
	var u := up.rotated(PI * 0.5)
	_fogo(c, u, v, r, true)
	segmento(jt["ombro"] + (jt["dir_tronco"] as Vector2) * 2.0, c + v * r * 0.7, 8, 8, PELE)
	desenhar_rosto(c, u, v, r, PELE)
	_fogo(c, u, v, r, false)


## Cabelo de fogo: línguas que sobem e tremulam. 'atras' desenha a parte
## que fica atrás da cabeça.
func _fogo(c: Vector2, u: Vector2, v: Vector2, r: float, atras: bool) -> void:
	var tt := float(t)
	var camadas := [[FOGO_FORA, 1.0], [FOGO_MEIO, 0.7], [FOGO_DENTRO, 0.42]]
	if eh_reflexo:
		camadas = [[FOGO_FORA, 1.0]]
	var linguas := 5 if atras else 3
	for camada in camadas:
		var cor_fogo: Color = camada[0]
		var esc: float = camada[1]
		for i in linguas:
			var k := float(i) / float(linguas - 1)
			# ângulo na volta da cabeça: 0 = rosto, 90 = topo, 180 = nuca
			var theta := deg_to_rad(lerpf(70.0, 200.0, k) if atras else lerpf(55.0, 115.0, k))
			var raiz := c + (u * cos(theta) - v * sin(theta)) * r * 0.85
			var fase := tt * 0.21 + i * 1.7
			var alto := (r * (1.4 if atras else 0.9) + sin(fase) * r * 0.35) * esc
			var ponta := raiz - v * alto - u * (r * 0.5 + cos(fase * 1.3) * r * 0.25) * esc
			var lado := (ponta - raiz).normalized().orthogonal() * r * 0.45 * esc
			poligono(PackedVector2Array([raiz + lado, ponta, raiz - lado]), cor_fogo)
	if atras:
		circulo(c - u * r * 0.3 - v * r * 0.25, r * 1.0, FOGO_FORA)
		if not eh_reflexo:
			circulo(c - u * r * 0.4 - v * r * 0.3, r * 0.62, FOGO_MEIO)
