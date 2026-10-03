extends Node2D
## Modo treino (F1): desenha hurtbox (verde), hitbox ativa (vermelho),
## caixa de empurrão (azul) e caixa dos projéteis (laranja).

var luta: Node


func _ready() -> void:
	z_index = 20


func _process(_delta: float) -> void:
	visible = Config.mostrar_caixas
	if visible:
		queue_redraw()


func _draw() -> void:
	if luta == null:
		return
	for l in luta.lutadores:
		var lut := l as Lutador
		_caixa(lut.caixa_empurrao(), Color(0.3, 0.5, 1.0))
		for hu in lut.hurtboxes():
			_caixa(hu, Color(0.2, 1.0, 0.3))
		var hb := lut.hitbox_ativa()
		if hb.size != Vector2.ZERO:
			_caixa(hb, Color(1.0, 0.2, 0.2))
		draw_line(lut.position + Vector2(-6, 0), lut.position + Vector2(6, 0), Color.WHITE, 1.0)
		draw_line(lut.position + Vector2(0, -6), lut.position + Vector2(0, 0), Color.WHITE, 1.0)
	for pr in luta.projeteis:
		var p := pr as Projetil
		if not p.morto:
			_caixa(p.caixa_mundo(), Color(1.0, 0.6, 0.1) if p.ativo else Color(0.5, 0.5, 0.5))


func _caixa(r: Rect2, c: Color) -> void:
	draw_rect(r, Color(c, 0.18))
	draw_rect(r, Color(c, 0.9), false, 1.0)
