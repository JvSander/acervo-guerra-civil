class_name ControleCPU
extends RefCounted
## CPU simples: aperta os mesmos botões que um jogador (inclusive os comandos
## de especial), então usa exatamente as mesmas regras de luta.
##
## Ela planeja alguns frames de entrada por vez numa fila. A cada decisão
## olha a distância, o que o rival está fazendo e os projéteis na tela.
## A dificuldade muda o tempo de reação, a chance de defender, de usar
## antiaéreo e de completar combos.

const SF := BufferComandos.SF
const SR := BufferComandos.SR
const CF := BufferComandos.CF
const CR := BufferComandos.CR
const DEF := BufferComandos.DEF
const NEON := BufferComandos.NEON

const NIVEIS := [
	{"reacao": 22, "defesa": 0.3, "anti_aereo": 0.2, "combo": 0.3, "pausa": [16, 40]},
	{"reacao": 13, "defesa": 0.58, "anti_aereo": 0.5, "combo": 0.65, "pausa": [8, 26]},
	{"reacao": 8, "defesa": 0.85, "anti_aereo": 0.85, "combo": 0.92, "pausa": [3, 14]},
]

var eu: Lutador
var nivel := 1
var rng := RandomNumberGenerator.new()
## Frames planejados: [x relativo à frente, y, botões segurados].
var fila: Array = []
var espera := 0


func _init(lutador: Lutador, dificuldade: int, semente := -1) -> void:
	eu = lutador
	nivel = clampi(dificuldade, 0, NIVEIS.size() - 1)
	if semente >= 0:
		rng.seed = semente
	else:
		rng.randomize()


func reiniciar() -> void:
	fila.clear()
	espera = 20


## Entrada bruta deste frame (mesmo formato de Controles.ler()).
func ler() -> Dictionary:
	if fila.is_empty():
		_decidir()
	var f: Array = [0, 0, 0]
	if not fila.is_empty():
		f = fila.pop_front()
	return {"x": int(f[0]) * eu.frente, "y": int(f[1]), "seg": int(f[2]), "apt": 0}


func _cfg() -> Dictionary:
	return NIVEIS[nivel]


func _pode_agir() -> bool:
	return eu.estado in [Lutador.E.PARADO, Lutador.E.ANDANDO, Lutador.E.AGACHADO, Lutador.E.DEFENDENDO]


func _decidir() -> void:
	var cfg := _cfg()
	if eu.estado == Lutador.E.BLOQUEANDO:
		_defender(eu.agachado, 1)
		return
	if not _pode_agir():
		fila.append([0, 0, 0])
		return
	if _reagir(cfg):
		return
	if espera > 0:
		espera -= 1
		fila.append([0, 0, 0])
		return
	_escolher_acao(cfg)
	var pausa: Array = cfg["pausa"]
	espera = rng.randi_range(int(pausa[0]), int(pausa[1]))


## Reações a ameaças. Devolve true se já planejou algo. Cada ameaça (um
## projétil, um golpe, um pulo) só é avaliada uma vez, como um humano que
## decide na hora e não fica tentando de novo a cada frame.
func _reagir(cfg: Dictionary) -> bool:
	var op := eu.oponente
	var dist := absf(op.position.x - eu.position.x)
	var defesa: float = cfg["defesa"]
	var agora: int = eu.luta.frame_total
	# projétil vindo
	var pr: Projetil = eu.luta.projetil_mais_proximo(eu)
	if pr != null:
		var d := absf(pr.position.x - eu.position.x)
		if d < 190.0 and pr.frame >= int(cfg["reacao"]) and _primeira_vez("p%d" % pr.get_instance_id()):
			if rng.randf() < defesa:
				if not pr.bloqueavel:
					_pular(rng.randi_range(0, 1))
				elif eu.p.id == "curupira" and rng.randf() < 0.45:
					_comando("623", CF)
				elif rng.randf() < 0.25:
					_pular(1)
				else:
					_defender(false, 16)
				return true
	# golpe do rival
	if op.estado == Lutador.E.GOLPE and not op.golpe.is_empty() and dist < 230.0:
		var g: Dictionary = op.golpe
		var ini := int(g["inicio"])
		var chave := "g%s_%d" % [g["id"], agora - op.frame_golpe]
		if op.frame_golpe <= ini + int(g["ativo"]) and _primeira_vez(chave):
			var da_tempo := ini >= int(cfg["reacao"]) or rng.randf() < defesa * 0.35
			if da_tempo and rng.randf() < defesa:
				var baixo: bool = g["altura"] == "baixo"
				if rng.randf() > 0.55 + defesa * 0.45:
					baixo = not baixo
				_defender(baixo, ini + int(g["ativo"]) + 4)
				return true
	# rival pulando em cima: antiaéreo
	if op.estado == Lutador.E.NO_AR and dist < 160.0 and dist > 25.0 and op.position.y > -150.0:
		var vindo := signf(op.vel.x) == signf(eu.position.x - op.position.x)
		if vindo and _primeira_vez("j%d" % (agora - op.frames_estado)):
			if rng.randf() < float(cfg["anti_aereo"]):
				_golpe(0, 1, SR)
				return true
	# rival se recuperando de um golpe que errou ou foi defendido: punir
	if op.estado == Lutador.E.GOLPE and not op.golpe.is_empty() and dist < 115.0:
		var g: Dictionary = op.golpe
		var falta: int = op.p.total_frames(g) - op.frame_golpe
		if op.frame_golpe > int(g["inicio"]) + int(g["ativo"]) and falta >= 10:
			if _primeira_vez("c%s_%d" % [g["id"], agora - op.frame_golpe]) and rng.randf() < float(cfg["combo"]):
				_punir()
				return true
	return false


func _punir() -> void:
	if eu.p.id == "sander":
		_combo([[0, 0, SF], 7, [0, 0, SR], 9, "236", SR])
	else:
		_combo([[0, 0, SF], 7, [0, 0, SR], 10, "236", CR])


var _visto := {}


func _primeira_vez(chave: String) -> bool:
	if _visto.has(chave):
		return false
	if _visto.size() > 64:
		_visto.clear()
	_visto[chave] = true
	return true


func _escolher_acao(cfg: Dictionary) -> void:
	var op := eu.oponente
	var dist := absf(op.position.x - eu.position.x)
	var opcoes: Array = []
	if eu.p.id == "sander":
		_opcoes_sander(dist, cfg, opcoes)
	else:
		_opcoes_curupira(dist, cfg, opcoes)
	var total := 0.0
	for o in opcoes:
		total += float(o[0])
	if total <= 0.0:
		_andar(8, 1)
		return
	var sorteio := rng.randf() * total
	for o in opcoes:
		sorteio -= float(o[0])
		if sorteio <= 0.0:
			(o[1] as Callable).call()
			return


func _opcoes_sander(dist: float, cfg: Dictionary, opcoes: Array) -> void:
	var e: Dictionary = eu.extra
	var com_guitarra: bool = e["guitarra"]
	var cordas := int(e["cordas"])
	var riff_livre: bool = com_guitarra and not eu.luta.tem_projetil(eu, "riff")
	var combo: float = cfg["combo"]
	# a guitarra bumerangue gasta uma corda: a CPU acende e depois arremessa
	var bumerangue: bool = com_guitarra and cordas >= 1
	var op := eu.oponente
	if com_guitarra and cordas < 3 and dist > 150.0 and op.estado in [Lutador.E.CAIDO, Lutador.E.LEVANTANDO]:
		# rival no chão: hora de acender uma corda
		opcoes.append([6.0, _comando.bind("22", SF)])
	if dist > 320.0:
		if riff_livre:
			opcoes.append([4.0, _comando.bind("236", SF if rng.randf() < 0.5 else SR)])
		if com_guitarra and cordas < 3 and dist > 340.0:
			opcoes.append([2.5, _comando.bind("22", SF)])
		if bumerangue:
			opcoes.append([2.5, _comando.bind("623", NEON)])
		opcoes.append([2.0, _andar.bind(12, 1)])
		opcoes.append([1.5, _dash])
		opcoes.append([0.6, _pular_atacando.bind(1, CR, 14)])
	elif dist > 140.0:
		opcoes.append([3.0, _andar.bind(8, 1)])
		if dist < 175.0:
			opcoes.append([2.5, _golpe.bind(0, 0, SR)])
		opcoes.append([2.0, _pular_atacando.bind(1, SR if com_guitarra else CR, 12)])
		if riff_livre:
			opcoes.append([1.5, _comando.bind("236", SF)])
		if bumerangue and dist > 200.0:
			opcoes.append([1.5, _comando.bind("623", NEON)])
		opcoes.append([1.0, _andar.bind(8, -1)])
		opcoes.append([1.0, _dash])
	else:
		opcoes.append([3.0 * combo, _combo.bind([[0, 0, SF], 7, [0, 0, SR], 9, "236", SR])])
		opcoes.append([2.0 * combo, _combo.bind([[0, 1, CF], 7, [0, 1, SF], 7, "236", SF])])
		if dist < 70.0:
			opcoes.append([1.5, _golpe.bind(1, 0, SR)])
		opcoes.append([1.5, _golpe.bind(0, 0, CF)])
		opcoes.append([2.0, _golpe.bind(0, 1, CR)])
		opcoes.append([1.0, _golpe.bind(0, 0, CR)])
		opcoes.append([1.0, _andar.bind(10, -1)])
		opcoes.append([1.0, _defender.bind(false, 14)])


func _opcoes_curupira(dist: float, cfg: Dictionary, opcoes: Array) -> void:
	var op := eu.oponente
	var combo: float = cfg["combo"]
	var pegadas_livre: bool = not eu.luta.tem_projetil(eu, "pegadas")
	if dist > 300.0:
		if pegadas_livre and op.no_chao and op.desorientado == 0:
			opcoes.append([2.0, _comando.bind("214", NEON)])
		opcoes.append([4.0, _andar.bind(12, 1)])
		opcoes.append([3.0, _dash])
		opcoes.append([1.0, _pular_atacando.bind(1, CR, 14)])
	elif dist > 120.0:
		if dist < 200.0:
			opcoes.append([3.0, _comando.bind("236", CR)])
		opcoes.append([3.0, _andar.bind(8, 1)])
		opcoes.append([2.0, _pular_atacando.bind(1, CR, 12)])
		opcoes.append([1.0, _comando.bind("623", CR if rng.randf() < 0.5 else CF)])
		opcoes.append([1.0, _dash])
		if pegadas_livre and op.no_chao and op.desorientado == 0:
			opcoes.append([0.8, _comando.bind("214", NEON)])
	else:
		opcoes.append([3.0 * combo, _combo.bind([[0, 0, SF], 7, [0, 0, SR], 10, "236", CR])])
		opcoes.append([2.0 * combo, _combo.bind([[0, 1, CF], 8, [0, 1, CR]])])
		if dist < 70.0:
			opcoes.append([1.5, _golpe.bind(1, 0, SR)])
		opcoes.append([1.5, _golpe.bind(0, 0, CF)])
		opcoes.append([1.5, _golpe.bind(0, 0, CR)])
		opcoes.append([1.5, _golpe.bind(0, 1, CR)])
		opcoes.append([1.0, _andar.bind(10, -1)])
		opcoes.append([1.0, _defender.bind(true, 14)])


# ------------------------------------------------------------ ações

func _vazio(n: int) -> void:
	for i in n:
		fila.append([0, 0, 0])


func _andar(frames: int, sentido: int) -> void:
	for i in frames:
		fila.append([sentido, 0, 0])


func _dash() -> void:
	fila.append([1, 0, 0])
	fila.append([0, 0, 0])
	for i in 10:
		fila.append([1, 0, 0])


func _pular(sentido: int) -> void:
	for i in 3:
		fila.append([sentido, -1, 0])
	_vazio(6)


func _pular_atacando(sentido: int, botao: int, atraso: int) -> void:
	for i in 3:
		fila.append([sentido, -1, 0])
	_vazio(atraso)
	fila.append([0, 0, botao])
	_vazio(2)


func _golpe(x: int, y: int, botao: int) -> void:
	fila.append([x, y, botao])
	fila.append([x, y, 0])
	fila.append([x, y, 0])


func _defender(baixo: bool, frames: int) -> void:
	for i in frames:
		fila.append([-1, 1 if baixo else 0, 0])


func _comando(cmd: String, botao: int) -> void:
	match cmd:
		"236":
			fila.append_array([[0, 1, 0], [1, 1, 0], [1, 0, botao], [0, 0, 0]])
		"214":
			fila.append_array([[0, 1, 0], [-1, 1, 0], [-1, 0, botao], [0, 0, 0]])
		"623":
			fila.append_array([[1, 0, 0], [0, 1, 0], [1, 1, botao], [0, 0, 0]])
		"22":
			fila.append_array([[0, 1, 0], [0, 0, 0], [0, 1, botao], [0, 0, 0]])


## Sequência de golpes: arrays [x, y, botão], números (frames de espera) e
## comandos de especial ("236" seguido do botão).
func _combo(passos: Array) -> void:
	var i := 0
	while i < passos.size():
		var passo = passos[i]
		if passo is Array:
			fila.append(passo)
		elif passo is int:
			_vazio(passo)
		elif passo is String:
			i += 1
			_comando(passo, int(passos[i]))
		i += 1
	_vazio(4)
