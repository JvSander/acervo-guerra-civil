extends Projetil
## Riff do Sander: o acorde vira uma onda de choque azul.


func ao_iniciar() -> void:
	caixa = Rect2(-20, -30, 40, 60)
	duracao = 200
	scale.x = frente


func _draw() -> void:
	var f := float(frame)
	var pulso := 1.0 + sin(f * 0.6) * 0.08
	for i in 3:
		var raio := (26.0 - i * 7.0) * pulso
		var alfa := 0.25 + i * 0.25
		draw_arc(Vector2(-6 + i * 4, 0), raio, -1.15, 1.15, 14, Color(cor, alfa), 5.0 - i)
	draw_arc(Vector2(4, 0), 20.0 * pulso, -1.0, 1.0, 12, Color(0.9, 0.98, 1.0), 2.0)
	# rastro e faíscas elétricas
	for k in 4:
		var x := -14.0 - k * 9.0
		draw_line(Vector2(x, -10 + k * 6), Vector2(x - 8, -7 + k * 6), Color(cor, 0.5 - k * 0.1), 2.0)
	var semente := frame * 7
	var p := Vector2(6, -24)
	for k in 4:
		var q := p + Vector2(float((semente + k * 13) % 9) - 4.0, 12.0)
		draw_line(p, q, Color(0.85, 0.97, 1.0, 0.9), 1.0)
		p = q
