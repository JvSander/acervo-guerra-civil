class_name BufferComandos
extends RefCounted
## Histórico das entradas de um jogador (64 frames) e leitura de comandos
## como meia-lua (↓↘→), meia-lua para trás (↓↙←), "shoryuken" (→↓↘),
## ↓↓ e dash (→→).
##
## Guarda a direção bruta (x, y) e converte para a notação de teclado
## numérico relativa ao lado em que o lutador olha na hora da leitura:
##   7 8 9
##   4 5 6     (6 = frente, 4 = trás, 2 = baixo, 3 = baixo-frente...)
##   1 2 3

const TAM := 64

const SF := 1
const SR := 2
const CF := 4
const CR := 8
const DEF := 16
const NEON := 32
const SOCOS := SF | SR
const CHUTES := CF | CR
const ATAQUES := SF | SR | CF | CR

const BAIXO := [1, 2, 3]
const NAO_BAIXO := [4, 5, 6, 7, 8, 9]
const NAO_FRENTE := [1, 2, 4, 5, 7, 8]
const NAO_TRAS := [2, 3, 5, 6, 8, 9]

var _x := PackedInt32Array()
var _y := PackedInt32Array()
var _seg := PackedInt32Array()
var _apt := PackedInt32Array()
var _i := 0


func _init() -> void:
	_x.resize(TAM)
	_y.resize(TAM)
	_seg.resize(TAM)
	_apt.resize(TAM)
	limpar()


func limpar() -> void:
	_x.fill(0)
	_y.fill(0)
	_seg.fill(0)
	_apt.fill(0)


## Registra um frame. apt_extra soma apertos rápidos que começaram e
## terminaram entre dois frames de física (o Input do Godot avisa).
func registrar(x: int, y: int, seg: int, apt_extra := 0) -> void:
	var anterior := _seg[_i]
	_i = (_i + 1) % TAM
	_x[_i] = clampi(x, -1, 1)
	_y[_i] = clampi(y, -1, 1)
	_seg[_i] = seg
	_apt[_i] = (seg & ~anterior) | apt_extra


func _k(n: int) -> int:
	return (_i - n + TAM * 2) % TAM


## Direção numpad de n frames atrás, relativa a 'frente' (1 = direita).
func dir(n: int, frente: int) -> int:
	var k := _k(n)
	return 5 + _x[k] * frente - _y[k] * 3


func x_bruto() -> int:
	return _x[_i]


func y_bruto() -> int:
	return _y[_i]


func segurando(mascara: int) -> bool:
	return (_seg[_i] & mascara) != 0


## Botões da máscara apertados nos últimos 'janela' frames.
func apertou(mascara: int, janela := 1) -> int:
	var r := 0
	for n in janela:
		r |= _apt[_k(n)] & mascara
	return r


## Procura a sequência de direções de trás para frente no histórico.
## seq é uma lista de conjuntos aceitos, ex.: [[2], [3], [6]].
## O último passo precisa ter acontecido até 'atraso_max' frames atrás e a
## sequência inteira dentro de 'janela' frames.
func sequencia(seq: Array, frente: int, janela := 20, atraso_max := 8) -> bool:
	var idx := seq.size() - 1
	for n in mini(janela, TAM):
		if idx == seq.size() - 1 and n > atraso_max:
			return false
		var conjunto: Array = seq[idx]
		if dir(n, frente) in conjunto:
			idx -= 1
			if idx < 0:
				return true
	return false


## Lê um comando de especial pela notação numérica.
func comando(cmd: String, frente: int) -> bool:
	match cmd:
		"236":  # meia-lua para frente ↓↘→ (aceita ↓→ rápido, comum no teclado)
			return sequencia([[2], [3], [6]], frente, 20, 8) \
				or sequencia([[2], [6]], frente, 10, 6)
		"214":  # meia-lua para trás ↓↙←
			return sequencia([[2], [1], [4]], frente, 20, 8) \
				or sequencia([[2], [4]], frente, 10, 6)
		"623":  # →↓↘ (termina segurando ↘ ou ↓, para não confundir com a meia-lua)
			return dir(0, frente) in [2, 3] and sequencia([[6], [1, 2], [3]], frente, 18, 6)
		"22":  # ↓↓
			return sequencia([BAIXO, NAO_BAIXO, BAIXO], frente, 16, 3)
		"66":  # →→ (dash), o segundo toque é agora
			return dir(0, frente) == 6 and not (dir(1, frente) in [3, 6, 9]) \
				and sequencia([[6], NAO_FRENTE, [6]], frente, 14, 0)
		"44":  # ←← (dash para trás)
			return dir(0, frente) == 4 and not (dir(1, frente) in [1, 4, 7]) \
				and sequencia([[4], NAO_TRAS, [4]], frente, 14, 0)
	return false
