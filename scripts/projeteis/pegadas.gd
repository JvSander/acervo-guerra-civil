extends Projetil
## Pés Virados da Curupira: pegadas ao contrário (calcanhar para frente)
## correm pelo chão. Quem pisa fica desorientado. Não dá para defender,
## só pular por cima.

var marcas: Array = []  # [distância do início, lado, frame em que apareceu]
var passos := 0


func ao_iniciar() -> void:
	caixa = Rect2(-22, -26, 44, 26)
	duracao = 72
	bloqueavel = false
	colide_com_projetil = false
	position.y = 0.0
	scale.x = frente


func tick() -> void:
	frame += 1
	position += vel
	if frame % 7 == 0:
		passos += 1
		marcas.append([float(frame) * absf(vel.x), 1 if passos % 2 == 0 else -1, frame])
		if passos % 2 == 0:
			Sons.tocar_variado("pegadas", -12.0)
	if frame > duracao:
		morto = true
	queue_redraw()


func pode_acertar(alvo: Lutador) -> bool:
	return ativo and not morto and alvo.no_chao


func ao_acertar(alvo: Lutador, _bloqueado: bool) -> void:
	alvo.desorientar(int(dados.get("desorienta", 150)))
	morto = true


func _draw() -> void:
	var andado := float(frame) * absf(vel.x)
	for m in marcas:
		var idade := frame - int(m[2])
		var alfa := clampf(1.0 - idade / 50.0, 0.0, 1.0)
		if alfa <= 0.0:
			continue
		_pegada(Vector2(float(m[0]) - andado, -4.0 + float(m[1]) * 3.0), alfa)
	# névoa verde na frente das pegadas
	draw_circle(Vector2(0, -6), 14.0, Color(cor, 0.12))
	draw_circle(Vector2(0, -6), 7.0, Color(cor, 0.25))


## Pegada virada: o calcanhar aponta para onde ela anda.
func _pegada(p: Vector2, alfa: float) -> void:
	var c := Color(cor, 0.85 * alfa)
	draw_set_transform(p, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2(5, 0), 5.0, Color(cor, 0.25 * alfa))
	draw_circle(Vector2(5, 0), 3.5, c)           # calcanhar (na frente)
	draw_circle(Vector2(-4, 0), 4.5, c)          # planta
	for k in 4:
		draw_circle(Vector2(-10.5, -4.0 + k * 2.6), 1.3, c)  # dedos (atrás)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
