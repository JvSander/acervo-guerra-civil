class_name MenuPausa
extends Control
## Menu de pausa (ESC ou Start) e menu do fim da partida.
##
## Pausa: continuar, lista de golpes, controles, dificuldade da CPU,
## P2 humano ou CPU, trocar os personagens de lado, reiniciar e sair.
## Fim da partida: revanche, trocar personagens, dificuldade e sair.
## Os comandos da lista de golpes são desenhados como setas (as fontes do
## jogo não têm o caractere de seta).

enum Tela { FECHADO, PAUSA, GOLPES, CONTROLES, FIM }

const FONTE := preload("res://fontes/BebasNeue-Regular.woff2")
const PIXEL := preload("res://fontes/Silkscreen-Regular.woff2")
const ESQ := HORIZONTAL_ALIGNMENT_LEFT
const COR := Color(0.3, 0.85, 1.0)
const ROSA := Color(1.0, 0.2, 0.55)
const AMARELO := Color(1.0, 0.85, 0.3)

const CONTROLES := [
	["", "P1 TECLADO", "P2 TECLADO", "CONTROLE"],
	["MOVER", "W A S D", "SETAS", "ANALÓGICO / DIRECIONAL"],
	["SOCO FRACO (SF)", "U", "NUM 4", "X"],
	["SOCO FORTE (SR)", "I", "NUM 5", "Y"],
	["CHUTE FRACO (CF)", "J", "NUM 1", "A"],
	["CHUTE FORTE (CR)", "K", "NUM 2", "B"],
	["DEFESA (DEF)", "O", "NUM 6", "RB"],
	["NEON", "L", "NUM 3", "LB"],
	["PAUSA", "ESC", "ESC", "START"],
]
const BASICOS := [
	["66", "", "Dash para frente"],
	["44", "", "Dash para trás (escapa de golpes no começo)"],
	["4", "", "Segurar para trás defende (ou segure DEF)"],
	["1", "", "Defesa baixa: pega rasteira e chute baixo"],
	["6", "SR", "Agarrão, colado no rival (com 4 joga para trás)"],
	["2", "SR", "Antiaéreo"],
]

## Nó da Luta (sem tipo para não criar dependência circular).
var luta: Node
var tela: int = Tela.FECHADO
var sel := 0
var _itens: Array = []
var _frames := 0
var _vencedor := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func abrir_pausa() -> void:
	tela = Tela.PAUSA
	sel = 0
	_frames = 0
	visible = true
	get_tree().paused = true
	Sons.tocar("menu_ok", -6.0)


func fechar() -> void:
	tela = Tela.FECHADO
	visible = false
	get_tree().paused = false


## Chamado pela Luta quando alguém vence a partida.
func abrir_fim(vencedor: int) -> void:
	_vencedor = vencedor
	tela = Tela.FIM
	sel = 0
	_frames = 0
	visible = true


func _process(_delta: float) -> void:
	_frames += 1
	if Input.is_action_just_pressed("tela_cheia"):
		var cheia := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if cheia else DisplayServer.WINDOW_MODE_FULLSCREEN)
	match tela:
		Tela.FECHADO:
			if Input.is_action_just_pressed("pausa") and luta and luta.fase != Luta.F.FIM_PARTIDA:
				abrir_pausa()
		Tela.PAUSA:
			if Input.is_action_just_pressed("pausa") and _frames > 1:
				fechar()
				return
			_navegar()
		Tela.GOLPES, Tela.CONTROLES:
			if Input.is_action_just_pressed("pausa") or Controles.menu_voltar() or Controles.menu_confirmar():
				tela = Tela.PAUSA
				Sons.tocar("menu_mover", -8.0)
		Tela.FIM:
			if _frames > 50:
				_navegar()
	queue_redraw()


func _montar_itens() -> void:
	if tela == Tela.FIM:
		_itens = [
			["REVANCHE", "revanche"],
			["TROCAR PERSONAGENS", "trocar"],
			["DIFICULDADE: " + Config.nome_dificuldade(), "dificuldade"],
			["SAIR DO JOGO", "sair"],
		]
	else:
		_itens = [
			["CONTINUAR", "continuar"],
			["LISTA DE GOLPES", "golpes"],
			["CONTROLES", "controles"],
			["DIFICULDADE: " + Config.nome_dificuldade(), "dificuldade"],
			["P2: " + ("CPU" if Config.p2_cpu else "JOGADOR 2"), "p2"],
			["TROCAR PERSONAGENS", "trocar"],
			["REINICIAR LUTA", "reiniciar"],
			["SAIR DO JOGO", "sair"],
		]


func _navegar() -> void:
	_montar_itens()
	var d := Controles.menu_direcao()
	if d.y != 0:
		sel = posmod(sel + d.y, _itens.size())
		Sons.tocar("menu_mover", -8.0)
	var acao: String = _itens[sel][1]
	if d.x != 0 and acao == "dificuldade":
		luta.mudar_dificuldade(posmod(Config.dificuldade + d.x, Config.NOMES_DIFICULDADE.size()))
		Sons.tocar("menu_mover", -8.0)
	if tela == Tela.PAUSA and Controles.menu_voltar() and not Input.is_action_just_pressed("pausa"):
		fechar()
		return
	if not Controles.menu_confirmar():
		return
	Sons.tocar("menu_ok", -5.0)
	match acao:
		"continuar":
			fechar()
		"golpes":
			tela = Tela.GOLPES
		"controles":
			tela = Tela.CONTROLES
		"dificuldade":
			luta.mudar_dificuldade(posmod(Config.dificuldade + 1, Config.NOMES_DIFICULDADE.size()))
		"p2":
			Config.p2_cpu = not Config.p2_cpu
			luta.configurar_cpu()
		"trocar":
			fechar()
			luta.trocar_personagens()
		"reiniciar", "revanche":
			fechar()
			luta.reiniciar_partida()
		"sair":
			get_tree().quit()


# ------------------------------------------------------------ desenho

func _draw() -> void:
	if tela == Tela.FECHADO:
		return
	var a := 1.0
	if tela == Tela.FIM:
		a = clampf((_frames - 30) / 20.0, 0.0, 1.0)
		if a <= 0.0:
			return
	draw_rect(Rect2(0, 0, 960, 540), Color(0.0, 0.0, 0.03, 0.62 * a))
	match tela:
		Tela.PAUSA, Tela.FIM:
			_menu(a)
		Tela.GOLPES:
			_golpes()
		Tela.CONTROLES:
			_controles()


func _texto(fonte: Font, pos: Vector2, texto: String, tamanho: int, cor: Color, contorno := 0) -> void:
	var p := pos.floor()
	if contorno > 0:
		draw_string_outline(fonte, p, texto, ESQ, -1, tamanho, contorno, Color(0, 0, 0.03, cor.a))
	draw_string(fonte, p, texto, ESQ, -1, tamanho, cor)


func _centro(fonte: Font, y: float, texto: String, tamanho: int, cor: Color, contorno := 0) -> void:
	var w := fonte.get_string_size(texto, ESQ, -1, tamanho).x
	_texto(fonte, Vector2(480 - w * 0.5, y), texto, tamanho, cor, contorno)


func _painel(r: Rect2, cor: Color, a := 1.0) -> void:
	draw_rect(r, Color(0.015, 0.015, 0.04, 0.94 * a))
	draw_rect(r.grow(2), Color(cor, 0.2 * a), false, 4.0)
	draw_rect(r, Color(cor, 0.9 * a), false, 1.5)
	# cantos recortados, estilo do lobby
	for c in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		draw_rect(Rect2(c - Vector2(3, 3), Vector2(6, 6)), Color(cor, a))


func _menu(a: float) -> void:
	_montar_itens()
	var titulo := "PAUSA"
	var cor := COR
	if tela == Tela.FIM:
		if _vencedor == 2:
			titulo = "EMPATE"
		elif _vencedor >= 0:
			var v: Lutador = luta.lutadores[_vencedor]
			titulo = v.p.nome + " VENCEU!"
			cor = v.p.cor_neon
	var altura := 100.0 + _itens.size() * 34.0
	var r := Rect2(480 - 190, 270 - altura * 0.5, 380, altura)
	_painel(r, cor, a)
	var tw := FONTE.get_string_size(titulo, ESQ, -1, 48).x
	draw_string_outline(FONTE, Vector2(480 - tw * 0.5, r.position.y + 54), titulo, ESQ, -1, 48, 10, Color(cor, 0.3 * a))
	_texto(FONTE, Vector2(480 - tw * 0.5, r.position.y + 54), titulo, 48, Color(1, 1, 1, a), 3)
	for i in _itens.size():
		var y := r.position.y + 96.0 + i * 34.0
		var texto: String = _itens[i][0]
		var escolhido := i == sel
		if escolhido:
			draw_rect(Rect2(r.position.x + 14, y - 24, r.size.x - 28, 30), Color(cor, 0.16 * a))
			draw_rect(Rect2(r.position.x + 14, y - 24, 4, 30), Color(cor, a))
			if _itens[i][1] == "dificuldade":
				texto = "<  " + texto + "  >"
		var w := FONTE.get_string_size(texto, ESQ, -1, 28).x
		var c := Color(cor.lerp(Color.WHITE, 0.5), a) if escolhido else Color(0.7, 0.74, 0.86, a)
		_texto(FONTE, Vector2(480 - w * 0.5, y), texto, 28, c, 2)
	_centro(PIXEL, r.end.y + 22, "W/S OU SETAS: ESCOLHER  ·  ENTER OU U: CONFIRMAR  ·  ESC: VOLTAR", 8, Color(0.75, 0.8, 0.95, 0.85 * a), 2)


## Lista de golpes dos dois personagens, com os comandos em setas.
func _golpes() -> void:
	var r := Rect2(40, 28, 880, 484)
	_painel(r, COR)
	_centro(FONTE, 70, "LISTA DE GOLPES", 40, Color.WHITE, 3)
	_centro(PIXEL, 88, "COMANDOS COM O PERSONAGEM OLHANDO PARA A DIREITA (6 = FRENTE)", 8, Color(0.7, 0.75, 0.9), 2)
	for i in 2:
		var l: Lutador = luta.lutadores[i]
		var x := 70.0 + i * 430.0
		var y := 124.0
		draw_string_outline(FONTE, Vector2(x, y), l.p.nome, ESQ, -1, 30, 8, Color(l.p.cor_neon, 0.3))
		_texto(FONTE, Vector2(x, y), l.p.nome, 30, l.p.cor_neon.lerp(Color.WHITE, 0.3), 2)
		_texto(PIXEL, Vector2(x + FONTE.get_string_size(l.p.nome, ESQ, -1, 30).x + 10, y - 4), l.p.titulo, 8, Color(0.7, 0.75, 0.9))
		y += 14.0
		for g in l.p.lista_golpes:
			y += 36.0
			var fim := _comando(Vector2(x, y - 6), g[1], g[2], l.p.cor_neon)
			_texto(FONTE, Vector2(fim + 8, y), g[0], 22, Color(0.95, 0.97, 1.0), 2)
			_texto(PIXEL, Vector2(x, y + 14), g[3], 8, Color(0.68, 0.72, 0.86))
	# golpes que todo mundo tem
	var y0 := 368.0
	draw_line(Vector2(70, y0 - 26), Vector2(890, y0 - 26), Color(COR, 0.35), 1.0)
	_texto(FONTE, Vector2(70, y0 - 4), "BÁSICOS", 24, AMARELO, 2)
	for k in BASICOS.size():
		var b: Array = BASICOS[k]
		var x := 70.0 + (k % 2) * 430.0
		var y := y0 + 26.0 + floori(k / 2.0) * 30.0
		var fim := _comando(Vector2(x, y - 4), b[0], b[1], COR)
		_texto(PIXEL, Vector2(fim + 8, y), b[2], 8, Color(0.85, 0.88, 1.0))
	_centro(PIXEL, 532, "ESC OU ENTER: VOLTAR", 8, Color(0.75, 0.8, 0.95), 2)


## Desenha o comando (setas em notação de teclado numérico) e o botão.
## Devolve o x onde terminou.
func _comando(pos: Vector2, cmd: String, botao: String, cor: Color) -> float:
	var x := pos.x
	for ch in cmd:
		_seta(Vector2(x + 8, pos.y), int(ch), cor)
		x += 18.0
	if botao != "":
		x += 2.0
		var w := PIXEL.get_string_size(botao, ESQ, -1, 8).x + 10.0
		var corb := ROSA if botao == "NEON" else AMARELO
		draw_rect(Rect2(x, pos.y - 7, w, 14), Color(corb, 0.9))
		_texto(PIXEL, Vector2(x + 5, pos.y + 3), botao, 8, Color(0.02, 0.02, 0.05))
		x += w
	return x


## Seta dentro de um círculo. d = direção no teclado numérico (5 = neutro).
func _seta(c: Vector2, d: int, cor: Color) -> void:
	var dx := ((d - 1) % 3) - 1
	var dy := 1 - floori((d - 1) / 3.0)
	var v := Vector2(dx, dy).normalized()
	draw_circle(c, 8.0, Color(0.04, 0.05, 0.1))
	draw_arc(c, 8.0, 0.0, TAU, 20, Color(cor, 0.7), 1.0)
	if v == Vector2.ZERO:
		draw_circle(c, 2.0, Color.WHITE)
		return
	var ponta := c + v * 5.0
	draw_line(c - v * 4.5, ponta, Color.WHITE, 2.0)
	draw_line(ponta, ponta - v.rotated(0.65) * 4.0, Color.WHITE, 2.0)
	draw_line(ponta, ponta - v.rotated(-0.65) * 4.0, Color.WHITE, 2.0)


func _controles() -> void:
	var r := Rect2(70, 50, 820, 440)
	_painel(r, COR)
	_centro(FONTE, 96, "CONTROLES", 40, Color.WHITE, 3)
	var colunas := [100.0, 330.0, 480.0, 630.0]
	for li in CONTROLES.size():
		var linha: Array = CONTROLES[li]
		var y := 140.0 + li * 30.0
		if li > 0 and li % 2 == 0:
			draw_rect(Rect2(90, y - 19, 780, 28), Color(1, 1, 1, 0.03))
		for ci in linha.size():
			var cor := AMARELO if li == 0 else (Color(0.85, 0.88, 1.0) if ci == 0 else COR.lerp(Color.WHITE, 0.4))
			_texto(FONTE, Vector2(colunas[ci], y), linha[ci], 22 if li > 0 else 20, cor, 2)
	_centro(PIXEL, 430, "F1: CAIXAS DE ACERTO  ·  F2: CPU OU 2 JOGADORES  ·  F3: FILTRO CRT  ·  F11: TELA CHEIA", 8, Color(0.85, 0.88, 1.0), 2)
	_centro(PIXEL, 448, "O 1º CONTROLE CONECTADO É DO P1 E O 2º É DO P2.", 8, Color(0.7, 0.75, 0.9), 2)
	_centro(PIXEL, 466, "DÁ PARA TROCAR AS TECLAS NO MAPA DE ENTRADA DO PROJETO (EDITOR DO GODOT).", 8, Color(0.7, 0.75, 0.9), 2)
	_centro(PIXEL, 532, "ESC OU ENTER: VOLTAR", 8, Color(0.75, 0.8, 0.95), 2)
