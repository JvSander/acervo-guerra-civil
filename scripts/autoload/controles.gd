extends Node
## Mapa de controles padrão, registrado ao abrir o jogo (autoload "Controles").
##
## Teclado (teclas físicas, funciona em ABNT2 e US):
##   P1: W A S D para mover · U = SF · I = SR · O = DEF · J = CF · K = CR · L = NEON
##   P2: setas para mover · numpad 4 = SF · 5 = SR · 6 = DEF · 1 = CF · 2 = CR · 3 = NEON
## Controle: o 1º conectado é do P1 e o 2º do P2.
##   X = SF · Y = SR · A = CF · B = CR · RB = DEF · LB = NEON · Start = pausa
##
## Se uma ação já existir no Mapa de Entrada do projeto, ela é respeitada
## (dá para remapear pelo editor sem mexer aqui).

const BOTOES := ["sf", "sr", "cf", "cr", "def", "neon"]
const DIRECOES := ["cima", "baixo", "esquerda", "direita"]

const TECLAS := {
	1: {
		"cima": KEY_W, "baixo": KEY_S, "esquerda": KEY_A, "direita": KEY_D,
		"sf": KEY_U, "sr": KEY_I, "def": KEY_O,
		"cf": KEY_J, "cr": KEY_K, "neon": KEY_L,
	},
	2: {
		"cima": KEY_UP, "baixo": KEY_DOWN, "esquerda": KEY_LEFT, "direita": KEY_RIGHT,
		"sf": KEY_KP_4, "sr": KEY_KP_5, "def": KEY_KP_6,
		"cf": KEY_KP_1, "cr": KEY_KP_2, "neon": KEY_KP_3,
	},
}

const BOTOES_CONTROLE := {
	"sf": JOY_BUTTON_X, "sr": JOY_BUTTON_Y, "cf": JOY_BUTTON_A, "cr": JOY_BUTTON_B,
	"def": JOY_BUTTON_RIGHT_SHOULDER, "neon": JOY_BUTTON_LEFT_SHOULDER,
	"cima": JOY_BUTTON_DPAD_UP, "baixo": JOY_BUTTON_DPAD_DOWN,
	"esquerda": JOY_BUTTON_DPAD_LEFT, "direita": JOY_BUTTON_DPAD_RIGHT,
}

const EIXOS := {
	"cima": [JOY_AXIS_LEFT_Y, -1.0], "baixo": [JOY_AXIS_LEFT_Y, 1.0],
	"esquerda": [JOY_AXIS_LEFT_X, -1.0], "direita": [JOY_AXIS_LEFT_X, 1.0],
}


func _ready() -> void:
	for jogador in [1, 2]:
		for acao in DIRECOES + BOTOES:
			_registrar_acao_jogador(jogador, acao)
	_registrar_global("pausa", [KEY_ESCAPE], [JOY_BUTTON_START])
	_registrar_global("confirmar", [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE], [JOY_BUTTON_A, JOY_BUTTON_START])
	_registrar_global("debug_caixas", [KEY_F1], [])
	_registrar_global("alternar_cpu", [KEY_F2], [])
	_registrar_global("alternar_crt", [KEY_F3], [])
	_registrar_global("tela_cheia", [KEY_F11], [])


func _registrar_acao_jogador(jogador: int, acao: String) -> void:
	var nome := "p%d_%s" % [jogador, acao]
	if InputMap.has_action(nome):
		return
	InputMap.add_action(nome, 0.45)
	var tecla := InputEventKey.new()
	tecla.device = -1
	tecla.physical_keycode = TECLAS[jogador][acao]
	InputMap.action_add_event(nome, tecla)
	var botao := InputEventJoypadButton.new()
	botao.device = jogador - 1
	botao.button_index = BOTOES_CONTROLE[acao]
	InputMap.action_add_event(nome, botao)
	if EIXOS.has(acao):
		var eixo := InputEventJoypadMotion.new()
		eixo.device = jogador - 1
		eixo.axis = EIXOS[acao][0]
		eixo.axis_value = EIXOS[acao][1]
		InputMap.action_add_event(nome, eixo)


func _registrar_global(nome: String, teclas: Array, botoes: Array) -> void:
	if InputMap.has_action(nome):
		return
	InputMap.add_action(nome, 0.5)
	for t in teclas:
		var ev := InputEventKey.new()
		ev.device = -1
		ev.physical_keycode = t
		InputMap.action_add_event(nome, ev)
	for b in botoes:
		var bt := InputEventJoypadButton.new()
		bt.device = -1
		bt.button_index = b
		InputMap.action_add_event(nome, bt)


## Lê o estado bruto do jogador neste frame.
## x: -1 esquerda, 1 direita. y: -1 cima, 1 baixo. seg/apt: máscara de botões
## (bit 0 = SF ... bit 5 = NEON) segurados e recém-apertados.
func ler(jogador: int) -> Dictionary:
	var pre := "p%d_" % jogador
	var x := int(Input.is_action_pressed(pre + "direita")) - int(Input.is_action_pressed(pre + "esquerda"))
	var y := int(Input.is_action_pressed(pre + "baixo")) - int(Input.is_action_pressed(pre + "cima"))
	var seg := 0
	var apt := 0
	for i in BOTOES.size():
		var acao: String = pre + BOTOES[i]
		if Input.is_action_pressed(acao):
			seg |= 1 << i
		if Input.is_action_just_pressed(acao):
			apt |= 1 << i
	return {"x": x, "y": y, "seg": seg, "apt": apt}


## Navegação de menu vinda de qualquer jogador (teclado ou controle).
func menu_direcao() -> Vector2i:
	var d := Vector2i.ZERO
	for j in [1, 2]:
		var pre := "p%d_" % j
		if Input.is_action_just_pressed(pre + "cima"):
			d.y = -1
		elif Input.is_action_just_pressed(pre + "baixo"):
			d.y = 1
		if Input.is_action_just_pressed(pre + "esquerda"):
			d.x = -1
		elif Input.is_action_just_pressed(pre + "direita"):
			d.x = 1
	if d == Vector2i.ZERO:
		if Input.is_action_just_pressed("ui_up"):
			d.y = -1
		elif Input.is_action_just_pressed("ui_down"):
			d.y = 1
		if Input.is_action_just_pressed("ui_left"):
			d.x = -1
		elif Input.is_action_just_pressed("ui_right"):
			d.x = 1
	return d


func menu_confirmar() -> bool:
	return Input.is_action_just_pressed("confirmar") or Input.is_action_just_pressed("p1_sf") \
		or Input.is_action_just_pressed("p2_sf")


func menu_voltar() -> bool:
	return Input.is_action_just_pressed("p1_def") or Input.is_action_just_pressed("p2_def") \
		or Input.is_action_just_pressed("ui_cancel")
