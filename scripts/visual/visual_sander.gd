extends Esqueleto
## Arte provisória do SANDER: jaqueta preta com friso azul-relâmpago,
## cabelo espetado com mecha azul e a guitarra em V com cordas que acendem.

const JAQUETA := Color(0.075, 0.085, 0.115)
const CAMISA := Color(0.3, 0.32, 0.37)
const JEANS := Color(0.13, 0.17, 0.29)
const TENIS := Color(0.06, 0.06, 0.08)
const GUITARRA := Color(0.05, 0.05, 0.07)
const BRACO_GUITARRA := Color(0.28, 0.17, 0.1)


func _init() -> void:
	paleta = {
		"pele": Color(0.78, 0.6, 0.5),
		"cabelo": Color(0.13, 0.09, 0.08),
		"camisa": CAMISA,
		"calca": JEANS,
		"sapato": TENIS,
		"olho": Color(0.92, 0.97, 1.0),
	}


func _tem_guitarra() -> bool:
	return bool(extra.get("guitarra", true))


func desenhar_corpo(jt: Dictionary) -> void:
	var guitarra_na_frente := float(pose.get("gt_frente", 0.0)) > 0.5
	braco(jt["ombro"], jt["cot_t"], jt["mao_t"], false)
	if _tem_guitarra() and not guitarra_na_frente:
		guitarra(jt["mao_t"], jt["gt"])
	perna(jt["joe_t"], jt["pe_t"], jt["quadril"], false)
	tronco(jt)
	perna(jt["joe_f"], jt["pe_f"], jt["quadril"], true)
	cabeca(jt)
	if _tem_guitarra() and guitarra_na_frente:
		guitarra(jt["mao_t"], jt["gt"])
		circulo(jt["mao_t"], 5.5, paleta["pele"])
	braco(jt["ombro"], jt["cot_f"], jt["mao_f"], true)


func braco(ombro: Vector2, cotovelo: Vector2, mao: Vector2, da_frente: bool) -> void:
	var tom := 1.0 if da_frente else 0.7
	segmento(ombro, cotovelo, 12, 10, escurecer(JAQUETA, tom))
	segmento(cotovelo, mao - (mao - cotovelo).normalized() * 3.0, 10, 9, escurecer(JAQUETA, tom))
	circulo(mao, 5.5, escurecer(paleta["pele"], tom))
	if _passe == 1 and da_frente:
		contorno_neon(ombro, cotovelo, 12, cor_neon)
		contorno_neon(cotovelo, mao, 10, cor_neon)


func perna(joelho: Vector2, pe: Vector2, quadril: Vector2, da_frente: bool) -> void:
	var tom := 1.0 if da_frente else 0.68
	segmento(quadril, joelho, 17, 14, escurecer(JEANS, tom))
	segmento(joelho, pe + (joelho - pe).normalized() * 4.0, 14, 12, escurecer(JEANS, tom))
	pe_desenho(joelho, pe, escurecer(TENIS, tom), 21.0, 9.0)
	if _passe == 1 and not eh_reflexo:
		# sola de neon do tênis
		var dirp := Vector2.RIGHT
		if not (absf(float(j.get("rot", 0.0))) < 0.01 and pe.y > -3.0):
			dirp = Vector2.from_angle((pe - joelho).angle() - PI * 0.5)
		draw_line(pe - dirp * 4.0, pe + dirp * 20.0, Color(cor_neon, 0.9 * tom), 1.5)
		if da_frente:
			contorno_neon(quadril, joelho, 17, Color(cor_neon, 0.5))


func tronco(jt: Dictionary) -> void:
	var q: Vector2 = jt["quadril"]
	var o: Vector2 = jt["ombro"]
	var d: Vector2 = jt["dir_tronco"]
	var n := d.rotated(PI * 0.5)
	circulo(q, 13, JEANS)
	# jaqueta aberta: costas e mangas pretas, camiseta aparecendo na frente
	var costas := PackedVector2Array([
		q + n * 4 + d * 4, o - d * 12 + n * 12, o + n * 8, o - n * 10, o - d * 12 - n * 14, q - n * 13 + d * 2,
	])
	poligono(costas, JAQUETA)
	var camiseta := PackedVector2Array([
		q + n * 12 + d * 6, o - d * 14 + n * 16, o - d * 4 + n * 13, o + n * 4 - d * 2, q + n * 2 + d * 8,
	])
	poligono(camiseta, CAMISA)
	circulo(o, 9, JAQUETA)
	if _passe == 1 and not eh_reflexo:
		# raio estampado na camiseta
		var c := o - d * 24 + n * 10
		var raio := PackedVector2Array([
			c - d * 6 + n * 1, c + n * 3, c - n * 1 + d * 1, c + d * 6 - n * 1,
		])
		draw_polyline(raio, Color(cor_neon, 0.9), 1.5)
		# friso de neon da jaqueta
		linha_neon(q + n * 4 + d * 4, o - d * 12 + n * 12, 1.2, Color(cor_neon, 0.85))
		contorno_neon(q - n * 13 + d * 2, o - d * 12 - n * 14, 3.0, cor_neon)
		# cinto
		draw_line(q - n * 12 + d * 6, q + n * 12 + d * 6, Color(0.02, 0.02, 0.03), 3.0)


func cabeca(jt: Dictionary) -> void:
	var c: Vector2 = jt["cabeca"]
	var r: float = corpo["cabeca"]
	var up: Vector2 = jt["dir_cabeca"]
	var v := -up
	var u := up.rotated(PI * 0.5)
	segmento(jt["ombro"] + (jt["dir_tronco"] as Vector2) * 2.0, c + v * r * 0.7, 10, 9, paleta["pele"])
	desenhar_rosto(c, u, v, r, paleta["pele"])
	# cabelo espetado para trás, com mecha azul
	var cab := PackedVector2Array([
		c + u * r * 0.75 - v * r * 0.55,
		c + u * r * 0.55 - v * r * 1.05,
		c + u * r * 0.15 - v * r * 1.3,
		c - u * r * 0.2 - v * r * 1.18,
		c - u * r * 0.55 - v * r * 1.42,
		c - u * r * 0.85 - v * r * 0.95,
		c - u * r * 1.45 - v * r * 0.85,
		c - u * r * 1.05 - v * r * 0.35,
		c - u * r * 1.3 + v * r * 0.05,
		c - u * r * 0.9 + v * r * 0.45,
		c - u * r * 0.45 + v * r * 0.2,
		c + u * r * 0.15 - v * r * 0.35,
	])
	poligono(cab, paleta["cabelo"])
	if _passe == 1 and not eh_reflexo:
		draw_line(c + u * r * 0.4 - v * r * 1.1, c - u * r * 0.9 - v * r * 0.9, Color(cor_neon, 0.9), 2.0)


## Guitarra em V, segurada pelo braço na mão de trás.
func guitarra(mao: Vector2, ang: float) -> void:
	var dx := Vector2(cos(ang), sin(ang))
	var dy := dx.rotated(PI * 0.5)
	var cabeca_g := mao - dx * 13.0
	segmento(cabeca_g - dx * 2.0, mao + dx * 30.0, 5, 5, BRACO_GUITARRA)
	var mao_cabeca := PackedVector2Array([
		cabeca_g - dx * 6 - dy * 4, cabeca_g + dx * 4 - dy * 3, cabeca_g + dx * 4 + dy * 3, cabeca_g - dx * 7 + dy * 2,
	])
	poligono(mao_cabeca, GUITARRA)
	var b := mao + dx * 26.0
	var corpo_v := PackedVector2Array([
		b - dy * 6, b + dx * 36 - dy * 19, b + dx * 41 - dy * 13, b + dx * 15, b + dx * 41 + dy * 13,
		b + dx * 36 + dy * 19, b + dy * 6,
	])
	poligono(corpo_v, GUITARRA)
	if _passe == 0 or eh_reflexo:
		return
	# borda de neon e cordas (acendem com a energia)
	var borda := corpo_v.duplicate()
	borda.append(corpo_v[0])
	draw_polyline(borda, Color(cor_neon, 0.75), 1.5)
	var cordas := int(extra.get("cordas", 0))
	for i in 3:
		var off := dy * (float(i) - 1.0) * 1.6
		var acesa := i < cordas
		var c := Color(0.85, 0.97, 1.0, 1.0) if acesa else Color(0.55, 0.55, 0.6, 0.6)
		if acesa:
			draw_line(cabeca_g + off, b + dx * 18 + off, Color(cor_neon, 0.35), 3.0)
		draw_line(cabeca_g + off, b + dx * 18 + off, c, 1.0)
	if cordas > 0 and t % 6 < 3:
		var faisca := b + dx * (8.0 + float(t % 5) * 5.0) + dy * (float(t % 7) - 3.0) * 3.0
		draw_line(faisca, faisca + Vector2(3, -4), Color(0.9, 0.98, 1.0), 1.0)
