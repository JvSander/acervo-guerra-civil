extends Projetil
## Guitarra Bumerangue do Sander: vai girando, freia, volta para a mão
## dele e acerta uma vez na ida e outra na volta.

const DESACELERACAO := 0.14
var voltando := false
var giro := 0.0


func ao_iniciar() -> void:
	caixa = Rect2(-28, -24, 56, 48)
	duracao = 400
	bloqueavel = true
	colide_com_projetil = false


func tick() -> void:
	frame += 1
	giro += 0.42
	if not voltando:
		var v := maxf(0.0, absf(vel.x) - DESACELERACAO)
		vel.x = v * frente
		if v <= 0.01:
			voltando = true
			ativo = true
	else:
		var alvo := dono.position + Vector2(24.0 * dono.frente, -140.0)
		var para := alvo - position
		var rapidez := minf(13.0, vel.length() + 0.35)
		vel = para.normalized() * rapidez
		if para.length() < 26.0:
			dono.extra["guitarra"] = true
			morto = true
			Sons.tocar("menu_ok", -10.0, 0.8)
	position += vel
	if frame > duracao:
		dono.extra["guitarra"] = true
		morto = true
	if frame % 10 == 0:
		Sons.tocar("guitarra_gira", -16.0, 1.0 + (0.2 if voltando else 0.0))
	queue_redraw()


func ao_acertar(_alvo: Lutador, _bloqueado: bool) -> void:
	# acerta uma vez na ida e uma na volta
	ativo = false
	if not voltando:
		vel.x *= 0.4


func _draw() -> void:
	var c := cor
	for i in 3:
		var a := giro - i * 0.35
		var dx := Vector2(cos(a), sin(a))
		draw_line(-dx * 30.0, dx * 30.0, Color(c, 0.12 + 0.08 * (2 - i)), 10.0)
	var dx := Vector2(cos(giro), sin(giro))
	var dy := dx.orthogonal()
	var b := dx * 2.0
	var corpo_v := PackedVector2Array([
		b - dy * 5, b + dx * 26 - dy * 15, b + dx * 30 - dy * 10, b + dx * 11, b + dx * 30 + dy * 10,
		b + dx * 26 + dy * 15, b + dy * 5,
	])
	draw_line(-dx * 30.0, b, Color(0.28, 0.17, 0.1), 4.0)
	draw_colored_polygon(corpo_v, Color(0.05, 0.05, 0.07))
	var borda := corpo_v.duplicate()
	borda.append(corpo_v[0])
	draw_polyline(borda, c, 1.5)
	draw_line(-dx * 30.0, b + dx * 14.0, Color(0.85, 0.97, 1.0, 0.9), 1.0)
