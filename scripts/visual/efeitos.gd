extends Node2D
## Efeitos da luta desenhados com mistura aditiva (brilho de neon):
## faísca de acerto, faísca de defesa, poeira, anel de energia e raios.

var efeitos: Array = []
## Partículas: [posição, velocidade, idade, duração, cor, largura]
var particulas: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	z_index = 5


func faisca(pos: Vector2, cor: Color, forte: bool, direcao: int) -> void:
	efeitos.append({"tipo": "faisca", "pos": pos, "f": 0, "dur": 11 if forte else 8, "cor": cor,
		"forte": forte, "ang": _rng.randf() * TAU})
	var n := 16 if forte else 9
	for i in n:
		var a := _rng.randf_range(-1.3, 1.3) + (0.0 if direcao > 0 else PI)
		var v := Vector2(cos(a), sin(a)) * _rng.randf_range(3.0, 10.0 if forte else 6.5)
		var c := cor if i % 3 != 0 else Color(1, 1, 1)
		particulas.append([pos, v, 0, _rng.randi_range(8, 18), c, 2.0 if forte else 1.5])


func bloqueio(pos: Vector2, direcao: int) -> void:
	efeitos.append({"tipo": "bloqueio", "pos": pos, "f": 0, "dur": 9, "cor": Color(0.55, 0.8, 1.0),
		"dir": direcao})
	for i in 5:
		var a := _rng.randf_range(-0.9, 0.9) + (PI if direcao > 0 else 0.0)
		particulas.append([pos, Vector2(cos(a), sin(a)) * _rng.randf_range(2.0, 5.0), 0, 10,
			Color(0.7, 0.9, 1.0), 1.5])


func poeira(pos: Vector2, tamanho := 1.0) -> void:
	for i in 6:
		var v := Vector2(_rng.randf_range(-2.5, 2.5), _rng.randf_range(-1.2, -0.2)) * tamanho
		particulas.append([pos + Vector2(_rng.randf_range(-14, 14), -2), v, 0, _rng.randi_range(14, 24),
			Color(0.35, 0.42, 0.55, 0.5), 5.0 * tamanho])


func anel(pos: Vector2, cor: Color) -> void:
	efeitos.append({"tipo": "anel", "pos": pos, "f": 0, "dur": 14, "cor": cor})


func raios(pos: Vector2, cor: Color) -> void:
	efeitos.append({"tipo": "raios", "pos": pos, "f": 0, "dur": 5, "cor": cor, "semente": _rng.randi()})


func limpar() -> void:
	efeitos.clear()
	particulas.clear()
	queue_redraw()


func tick() -> void:
	for e in efeitos:
		e["f"] = int(e["f"]) + 1
	efeitos = efeitos.filter(func(e): return int(e["f"]) < int(e["dur"]))
	for p in particulas:
		p[0] = (p[0] as Vector2) + (p[1] as Vector2)
		p[1] = (p[1] as Vector2) * 0.88 + Vector2(0, 0.12)
		p[2] = int(p[2]) + 1
	particulas = particulas.filter(func(p): return int(p[2]) < int(p[3]))
	queue_redraw()


func _draw() -> void:
	for e in efeitos:
		var t := float(e["f"]) / float(e["dur"])
		var pos: Vector2 = e["pos"]
		var cor: Color = e["cor"]
		match e["tipo"]:
			"faisca":
				var forte: bool = e["forte"]
				var r := (22.0 if forte else 14.0) * (1.0 - t * 0.6)
				if int(e["f"]) < 3:
					draw_circle(pos, r * 1.15, Color(1, 1, 1, 0.9))
				draw_circle(pos, r * 0.75, Color(cor, 0.6 * (1.0 - t)))
				var raios_n := 8 if forte else 6
				for i in raios_n:
					var a := float(e["ang"]) + TAU * i / raios_n
					var ini := pos + Vector2(cos(a), sin(a)) * r * 0.5
					var fim := pos + Vector2(cos(a), sin(a)) * r * (1.6 + t * 1.4) * (1.3 if i % 2 == 0 else 0.9)
					draw_line(ini, fim, Color(cor, 1.0 - t), 3.0 if forte else 2.0)
				draw_arc(pos, r * (1.2 + t * 1.6), 0.0, TAU, 20, Color(cor, 0.7 * (1.0 - t)), 2.0)
			"bloqueio":
				var lado := PI if int(e["dir"]) > 0 else 0.0
				draw_arc(pos, 18.0 + t * 10.0, lado - 1.1, lado + 1.1, 12, Color(cor, 1.0 - t), 3.0)
				draw_arc(pos, 12.0 + t * 8.0, lado - 0.9, lado + 0.9, 10, Color(1, 1, 1, 0.8 * (1.0 - t)), 1.5)
			"anel":
				draw_arc(pos, 10.0 + t * 46.0, 0.0, TAU, 28, Color(cor, 0.8 * (1.0 - t)), 3.0 * (1.0 - t) + 1.0)
			"raios":
				var r := RandomNumberGenerator.new()
				r.seed = int(e["semente"])
				for k in 3:
					var p := pos + Vector2(r.randf_range(-26, 26), r.randf_range(-30, 10))
					var pts := PackedVector2Array([p])
					for s in 4:
						p += Vector2(r.randf_range(-9, 9), r.randf_range(4, 10))
						pts.append(p)
					draw_polyline(pts, Color(cor, 0.5), 3.0)
					draw_polyline(pts, Color(0.92, 0.98, 1.0, 0.95), 1.0)
	for p in particulas:
		var t := float(p[2]) / float(p[3])
		var c: Color = p[4]
		var pos: Vector2 = p[0]
		var v: Vector2 = p[1]
		var largura: float = p[5]
		if largura >= 4.0:
			draw_circle(pos, largura * (0.6 + t), Color(c, c.a * (1.0 - t)))
		else:
			draw_line(pos, pos - v * 1.6, Color(c, 1.0 - t), largura)
