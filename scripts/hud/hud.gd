class_name HudLuta
extends Control
## HUD da luta, desenhado por código: barras de vida inclinadas com a vida
## fantasma (o pedaço vermelho que desce devagar depois do combo),
## cronômetro, marcadores de round, contador de combo, cordas da guitarra
## do Sander e os anúncios no meio da tela (ROUND 1, LUTEM!, K.O....).

## Tamanhos de anúncio.
const ENORME := 0
const GRANDE := 1
const MEDIO := 2
const TAMANHOS := [128, 88, 64]

const FONTE := preload("res://fontes/BebasNeue-Regular.woff2")
const PIXEL := preload("res://fontes/Silkscreen-Regular.woff2")
const PIXEL_NEGRITO := preload("res://fontes/Silkscreen-Bold.woff2")
const ESQ := HORIZONTAL_ALIGNMENT_LEFT

const LARGURA := 960.0
const ALTURA := 540.0
const BARRA_Y := 18.0
const BARRA_H := 20.0
## Ponta de fora e ponta de dentro da barra do P1 (a do P2 é espelhada).
const BARRA_FORA := 24.0
const BARRA_DENTRO := 418.0
const INCLINACAO := 10.0
const AMARELO := Color(1.0, 0.85, 0.3)

## Nó da Luta (sem tipo para não criar dependência circular).
var luta: Node
var _fantasma := [1.0, 1.0]
var _espera_fantasma := [0, 0]
var _vida_antes := [1.0, 1.0]
var _anuncio := {}
var _flash := 0.0
var _aviso := ""
var _aviso_frames := 0
var _dicas_frames := 0
var _combo_visto := [0, 0]
var _combo_valor := [0, 0]
var _combo_dano := [0, 0]
var _combo_tempo := [999, 999]
var _combo_pop := [0, 0]
var _frame := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


# ------------------------------------------------------------ chamadas da Luta

func novo_round() -> void:
	_fantasma = [1.0, 1.0]
	_vida_antes = [1.0, 1.0]
	_espera_fantasma = [0, 0]
	_combo_tempo = [999, 999]
	_combo_visto = [0, 0]
	_anuncio = {}
	if luta and luta.round_atual == 1:
		_dicas_frames = 660
	queue_redraw()


func anunciar(texto: String, cor: Color, estilo: int, frames: int, sub := "") -> void:
	_anuncio = {"texto": texto, "cor": cor, "estilo": estilo, "frames": frames, "f": 0, "sub": sub}


## Clarão branco na tela inteira (KO).
func piscar(forca: float) -> void:
	_flash = maxf(_flash, forca)


## Aviso pequeno embaixo (F1, F2...).
func aviso(texto: String) -> void:
	_aviso = texto
	_aviso_frames = 110


func fim_partida(_vencedor: int) -> void:
	_dicas_frames = 0


func tick() -> void:
	_frame += 1
	if luta == null or luta.lutadores.is_empty():
		return
	for i in 2:
		var l: Lutador = luta.lutadores[i]
		var v := float(l.vida) / float(l.p.vida_max)
		if v < _vida_antes[i]:
			_espera_fantasma[i] = 30
		_vida_antes[i] = v
		if _espera_fantasma[i] > 0:
			# a vida fantasma espera o combo acabar para descer
			if not l.em_atordoamento():
				_espera_fantasma[i] -= 1
		elif _fantasma[i] > v:
			_fantasma[i] = maxf(v, _fantasma[i] - 0.006)
		if _fantasma[i] < v:
			_fantasma[i] = v
		var c: int = luta.combo[i]
		if c != _combo_visto[i]:
			if c >= 2:
				_combo_valor[i] = c
				_combo_dano[i] = luta.dano_combo[i]
				_combo_pop[i] = 7
				_combo_tempo[i] = 0
			_combo_visto[i] = c
		if c >= 2 and luta.lutadores[1 - i].em_atordoamento():
			_combo_tempo[i] = 0
			_combo_dano[i] = luta.dano_combo[i]
		else:
			_combo_tempo[i] += 1
		_combo_pop[i] = maxi(0, _combo_pop[i] - 1)
	if not _anuncio.is_empty():
		_anuncio["f"] = int(_anuncio["f"]) + 1
		if int(_anuncio["f"]) >= int(_anuncio["frames"]):
			_anuncio = {}
	_flash = maxf(0.0, _flash - 0.05)
	_aviso_frames = maxi(0, _aviso_frames - 1)
	_dicas_frames = maxi(0, _dicas_frames - 1)
	queue_redraw()


# ------------------------------------------------------------ desenho

func _draw() -> void:
	if luta == null or luta.lutadores.is_empty():
		return
	for i in 2:
		_barra(i)
		_placa(i)
		_marcadores(i)
		_cordas(i)
		_combo(i)
	_cronometro()
	_anuncio_centro()
	_rodape()
	if _flash > 0.0:
		draw_rect(Rect2(0, 0, LARGURA, ALTURA), Color(1, 1, 1, _flash * 0.75))


## Espelha x para o lado do P2.
func _x(i: int, x: float) -> float:
	return x if i == 0 else LARGURA - x


## Posição x de um bloco de largura 'w' encostado na margem do lado do jogador.
func _alinhar(i: int, margem: float, w: float) -> float:
	return margem if i == 0 else LARGURA - margem - w


func _texto(fonte: Font, pos: Vector2, texto: String, tamanho: int, cor: Color, contorno := 0,
		cor_contorno := Color(0, 0, 0.02, 0.9)) -> void:
	var p := pos.floor()
	if contorno > 0:
		draw_string_outline(fonte, p, texto, ESQ, -1, tamanho, contorno, cor_contorno)
	draw_string(fonte, p, texto, ESQ, -1, tamanho, cor)


func _largura(fonte: Font, texto: String, tamanho: int) -> float:
	return fonte.get_string_size(texto, ESQ, -1, tamanho).x


## Forma da barra entre duas frações (0 = ponta de fora, 1 = ponta de dentro).
func _forma(i: int, de: float, ate: float, cresce := 0.0) -> PackedVector2Array:
	var comp := BARRA_DENTRO - BARRA_FORA
	var y0 := BARRA_Y - cresce
	var y1 := BARRA_Y + BARRA_H + cresce
	var xa := BARRA_FORA + de * comp - cresce
	var xb := BARRA_FORA + ate * comp + cresce
	return PackedVector2Array([
		Vector2(_x(i, xa + INCLINACAO), y0), Vector2(_x(i, xb + INCLINACAO), y0),
		Vector2(_x(i, xb), y1), Vector2(_x(i, xa), y1),
	])


func _fechado(pts: PackedVector2Array) -> PackedVector2Array:
	var r := pts.duplicate()
	r.append(pts[0])
	return r


func _barra(i: int) -> void:
	var l: Lutador = luta.lutadores[i]
	var cor := l.p.cor_neon
	var v := clampf(float(l.vida) / float(l.p.vida_max), 0.0, 1.0)
	draw_colored_polygon(_forma(i, 0.0, 1.0, 4.0), Color(0.0, 0.0, 0.02, 0.88))
	draw_colored_polygon(_forma(i, 0.0, 1.0), Color(0.07, 0.055, 0.1))
	# listras diagonais no fundo vazio
	for k in 40:
		var f := k / 40.0
		var a := _forma(i, f, f)
		draw_line(a[0] + Vector2(_x(i, 6.0) - _x(i, 0.0), 0), a[3], Color(0.12, 0.1, 0.16), 2.0)
	if _fantasma[i] > v:
		draw_colored_polygon(_forma(i, v, _fantasma[i]), Color(1.0, 0.24, 0.3))
	if v > 0.0:
		var c1 := cor.lerp(Color.WHITE, 0.35)
		var c2 := cor.darkened(0.35)
		if v < 0.25:
			# pouca vida: a barra pulsa em vermelho
			var p := 0.5 + 0.5 * sin(_frame * 0.25)
			c1 = c1.lerp(Color(1.0, 0.35, 0.35), p * 0.6)
			c2 = c2.lerp(Color(0.8, 0.05, 0.1), p * 0.6)
		var pts := _forma(i, 0.0, v)
		draw_polygon(pts, PackedColorArray([c1, c1, c2, c2]))
		draw_line(pts[0] + Vector2(0, 2.5), pts[1] + Vector2(0, 2.5), Color(1, 1, 1, 0.5), 2.0)
	for k in range(1, 10):
		var a := _forma(i, k / 10.0, k / 10.0)
		draw_line(a[0], a[3], Color(0, 0, 0.03, 0.35), 1.0)
	var borda := _fechado(_forma(i, 0.0, 1.0, 1.5))
	draw_polyline(borda, Color(cor, 0.25), 4.0)
	draw_polyline(borda, Color(cor, 0.95), 1.5)


func _placa(i: int) -> void:
	var l: Lutador = luta.lutadores[i]
	var p := l.p
	var y := 72.0
	var w := _largura(FONTE, p.nome, 30)
	var x := _alinhar(i, 26.0, w)
	draw_string_outline(FONTE, Vector2(x, y), p.nome, ESQ, -1, 30, 8, Color(p.cor_neon, 0.22))
	_texto(FONTE, Vector2(x, y), p.nome, 30, Color(0.97, 0.98, 1.0), 3)
	# facção
	var fw := _largura(PIXEL, p.faccao, 8) + 10.0
	var fx := x + w + 8.0 if i == 0 else x - 8.0 - fw
	draw_rect(Rect2(fx, y - 18.0, fw, 12.0), p.cor_faccao)
	_texto(PIXEL, Vector2(fx + 5.0, y - 9.0), p.faccao, 8, Color(0.02, 0.02, 0.05))
	# título do personagem
	var tw := _largura(PIXEL, p.titulo, 8)
	_texto(PIXEL, Vector2(_alinhar(i, 27.0, tw), y + 12.0), p.titulo, 8, Color(0.72, 0.76, 0.9, 0.9), 2)
	# quem controla, em cima da ponta da barra
	var quem := "P%d" % l.jogador
	if l.cpu != null:
		quem = "CPU · " + Config.nome_dificuldade()
	var qw := _largura(PIXEL, quem, 8)
	_texto(PIXEL, Vector2(_alinhar(i, 30.0, qw), 12.0), quem, 8, Color(p.cor_neon.lerp(Color.WHITE, 0.4), 0.9), 2)


func _marcadores(i: int) -> void:
	var cor: Color = luta.lutadores[i].p.cor_neon
	for k in Config.rounds_para_vencer:
		var c := Vector2(_x(i, BARRA_DENTRO - 2.0 - k * 18.0), 50.0)
		var losango := PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, 0), c + Vector2(0, 6), c + Vector2(-6, 0)])
		if luta.vitorias[i] > k:
			draw_circle(c, 10.0, Color(cor, 0.22))
			draw_colored_polygon(losango, cor.lerp(Color.WHITE, 0.35))
		else:
			draw_colored_polygon(losango, Color(0, 0, 0.03, 0.85))
			draw_polyline(_fechado(losango), Color(cor, 0.55), 1.0)


## Cordas acesas da guitarra do Sander (GDD: indicador de 3 cordas no HUD).
func _cordas(i: int) -> void:
	var l: Lutador = luta.lutadores[i]
	if not l.extra.has("cordas"):
		return
	var cordas := int(l.extra["cordas"])
	var com_guitarra: bool = l.extra.get("guitarra", true)
	var cor := l.p.cor_neon
	var rotulo := "CORDAS"
	var rw := _largura(PIXEL, rotulo, 8)
	var bloco := rw + 6.0 + 3.0 * 16.0
	var x0 := _alinhar(i, 27.0, bloco)
	var y := 92.0
	_texto(PIXEL, Vector2(x0, y + 7.0), rotulo, 8, Color(0.72, 0.76, 0.9, 0.9), 2)
	for k in 3:
		var r := Rect2(x0 + rw + 6.0 + k * 16.0, y, 12.0, 6.0)
		if k < cordas:
			draw_rect(r.grow(2.0), Color(cor, 0.3))
			draw_rect(r, cor.lerp(Color.WHITE, 0.45))
		else:
			draw_rect(r, Color(0.06, 0.06, 0.1, 0.9))
			draw_rect(r, Color(cor, 0.4), false, 1.0)
	if not com_guitarra and floori(_frame / 12.0) % 2 == 0:
		var txt := "SEM GUITARRA"
		var tw := _largura(PIXEL, txt, 8)
		var tx := x0 + bloco + 8.0 if i == 0 else x0 - 8.0 - tw
		_texto(PIXEL, Vector2(tx, y + 7.0), txt, 8, Color(1.0, 0.45, 0.45), 2)


func _combo(i: int) -> void:
	var t: int = _combo_tempo[i]
	if _combo_valor[i] < 2 or t > 60:
		return
	var alfa := 1.0 if t < 40 else 1.0 - (t - 40) / 20.0
	var cor: Color = luta.lutadores[i].p.cor_neon
	var num := str(_combo_valor[i])
	var nw := _largura(FONTE, num, 64)
	var hw := _largura(FONTE, "HITS", 28)
	var total := nw + 6.0 + hw
	var ancora := Vector2(_x(i, 30.0), 196.0)
	var esc: float = 1.0 + _combo_pop[i] * 0.05
	draw_set_transform(ancora, 0.0, Vector2(esc, esc))
	var x := 0.0 if i == 0 else -total
	draw_string_outline(FONTE, Vector2(x, 0), num, ESQ, -1, 64, 10, Color(cor, 0.3 * alfa))
	draw_string_outline(FONTE, Vector2(x, 0), num, ESQ, -1, 64, 4, Color(0, 0, 0.03, alfa))
	draw_string(FONTE, Vector2(x, 0), num, ESQ, -1, 64, Color(cor.lerp(Color.WHITE, 0.3), alfa))
	draw_string_outline(FONTE, Vector2(x + nw + 6.0, 0), "HITS", ESQ, -1, 28, 4, Color(0, 0, 0.03, alfa))
	draw_string(FONTE, Vector2(x + nw + 6.0, 0), "HITS", ESQ, -1, 28, Color(1, 1, 1, alfa))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var dano := "%d DE DANO" % _combo_dano[i]
	var dw := _largura(PIXEL, dano, 8)
	_texto(PIXEL, Vector2(_alinhar(i, 31.0, dw), 212.0), dano, 8, Color(AMARELO, alfa), 2, Color(0, 0, 0.03, alfa))


func _cronometro() -> void:
	var c := Vector2(480, 36)
	var hex := PackedVector2Array([
		c + Vector2(-34, -28), c + Vector2(34, -28), c + Vector2(46, 0),
		c + Vector2(34, 28), c + Vector2(-34, 28), c + Vector2(-46, 0),
	])
	draw_colored_polygon(hex, Color(0.0, 0.0, 0.03, 0.9))
	var borda := _fechado(hex)
	draw_polyline(borda, Color(0.5, 0.8, 1.0, 0.22), 5.0)
	draw_polyline(borda, Color(0.78, 0.92, 1.0, 0.9), 1.5)
	var t: int = maxi(luta.tempo, 0)
	var txt := "%02d" % t
	var cor := Color(0.96, 0.98, 1.0)
	if t <= 10 and luta.fase == Luta.F.LUTA:
		var p := 0.5 + 0.5 * sin(_frame * 0.3)
		cor = cor.lerp(Color(1.0, 0.25, 0.3), 0.5 + 0.5 * p)
	var w := _largura(FONTE, txt, 52)
	draw_string_outline(FONTE, Vector2(480 - w * 0.5, 55), txt, ESQ, -1, 52, 8, Color(0.4, 0.7, 1.0, 0.22))
	draw_string(FONTE, Vector2(480 - w * 0.5, 55), txt, ESQ, -1, 52, cor)
	var r := "ROUND %d" % luta.round_atual
	_texto(PIXEL, Vector2(480 - _largura(PIXEL, r, 8) * 0.5, 77), r, 8, Color(0.75, 0.8, 0.95, 0.9), 2)


func _anuncio_centro() -> void:
	if _anuncio.is_empty():
		return
	var f := int(_anuncio["f"])
	var total := int(_anuncio["frames"])
	var texto: String = _anuncio["texto"]
	var cor: Color = _anuncio["cor"]
	var estilo: int = _anuncio["estilo"]
	var tam: int = TAMANHOS[estilo]
	var entra := clampf(f / 9.0, 0.0, 1.0)
	var sai := clampf((total - f) / 12.0, 0.0, 1.0)
	var alfa := minf(entra * 1.4, 1.0) * sai
	var esc := lerpf(1.7, 1.0, 1.0 - pow(1.0 - entra, 3.0)) * lerpf(1.08, 1.0, sai)
	var centro := Vector2(480, 250)
	# faixa escura atrás do texto, com fios de neon
	var h := tam * 0.86 * minf(1.0, entra * 2.0)
	draw_rect(Rect2(0, centro.y - h * 0.5, LARGURA, h), Color(0, 0, 0.02, 0.55 * alfa))
	draw_line(Vector2(0, centro.y - h * 0.5), Vector2(LARGURA, centro.y - h * 0.5), Color(cor, 0.85 * alfa), 1.5)
	draw_line(Vector2(0, centro.y + h * 0.5), Vector2(LARGURA, centro.y + h * 0.5), Color(cor, 0.85 * alfa), 1.5)
	var w := _largura(FONTE, texto, tam)
	var pos := Vector2(-w * 0.5, tam * 0.36)
	var sep := 2.0 + 7.0 * (1.0 - entra)
	if estilo == ENORME:
		sep += 3.0 * absf(sin(f * 0.9))
	draw_set_transform(centro, 0.0, Vector2(esc, esc))
	# separação de cor (vermelho e azul), o "glitch" do vírus CASCATA
	draw_string(FONTE, pos + Vector2(-sep, 0), texto, ESQ, -1, tam, Color(1.0, 0.1, 0.25, 0.75 * alfa))
	draw_string(FONTE, pos + Vector2(sep, 0), texto, ESQ, -1, tam, Color(0.1, 0.85, 1.0, 0.75 * alfa))
	draw_string_outline(FONTE, pos, texto, ESQ, -1, tam, 14, Color(cor, 0.3 * alfa))
	draw_string_outline(FONTE, pos, texto, ESQ, -1, tam, 5, Color(0, 0, 0.03, alfa))
	draw_string(FONTE, pos, texto, ESQ, -1, tam, Color(cor.lerp(Color.WHITE, 0.6), alfa))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var sub: String = _anuncio["sub"]
	if sub != "" and f > 20:
		var sw := _largura(PIXEL_NEGRITO, sub, 16)
		var a2 := alfa * clampf((f - 20) / 8.0, 0.0, 1.0)
		_texto(PIXEL_NEGRITO, Vector2(480 - sw * 0.5, centro.y + tam * 0.5 + 26), sub, 16, Color(AMARELO, a2), 4,
			Color(0, 0, 0.03, a2))


func _rodape() -> void:
	if _dicas_frames > 0:
		var a := minf(1.0, _dicas_frames / 60.0)
		_pilula("ESC PAUSA  ·  F1 CAIXAS  ·  F2 CPU OU 2 JOGADORES  ·  F3 FILTRO", 524.0, Color(0.8, 0.85, 1.0, 0.85 * a), a)
	if _aviso_frames > 0:
		var a := minf(1.0, _aviso_frames / 20.0)
		_pilula(_aviso, 498.0, Color(AMARELO, a), a)
	if Config.mostrar_caixas:
		var x := 16.0
		var y := 524.0
		for item in [["ACERTA", Color(1.0, 0.25, 0.25)], ["APANHA", Color(0.25, 1.0, 0.35)], ["EMPURRA", Color(0.35, 0.55, 1.0)], ["PROJÉTIL", Color(1.0, 0.6, 0.1)]]:
			draw_rect(Rect2(x, y - 7, 8, 8), item[1])
			_texto(PIXEL, Vector2(x + 12, y), item[0], 8, Color(0.9, 0.92, 1.0), 2)
			x += 20.0 + _largura(PIXEL, item[0], 8) + 10.0


func _pilula(texto: String, y: float, cor: Color, alfa: float) -> void:
	var w := _largura(PIXEL, texto, 8)
	var r := Rect2(480 - w * 0.5 - 10, y - 11, w + 20, 15)
	draw_rect(r, Color(0, 0, 0.03, 0.7 * alfa))
	draw_rect(r, Color(cor, 0.4 * alfa), false, 1.0)
	_texto(PIXEL, Vector2(480 - w * 0.5, y), texto, 8, cor)
