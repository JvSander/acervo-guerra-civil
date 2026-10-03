extends Node
## Testes automáticos do jogo (rodam sem tela e sem som):
##   godot --headless res://testes/testes.tscn
## 1. Leitura de comandos (meia-lua, shoryuken, ↓↓, dash...).
## 2. Partidas inteiras CPU contra CPU nos três níveis, com os personagens
##    dos dois lados: toda partida termina, ninguém trava num estado e
##    todos os especiais saem pelo menos uma vez.
## 3. Determinismo: a mesma semente dá exatamente a mesma partida.
## Sai com código 0 se tudo passar e 1 se algo falhar.

const LUTA := preload("res://cenas/luta.tscn")
const PARTIDAS := 12
## 8 minutos de luta por partida, no máximo.
const LIMITE_FRAMES := 60 * 60 * 8
const ESPECIAIS := ["riff_f", "riff_r", "energizar", "bumerangue", "meia_lua", "au_f", "au_r", "pes_virados", "arremesso"]
const LIVRES := [
	Lutador.E.PARADO, Lutador.E.ANDANDO, Lutador.E.AGACHADO, Lutador.E.DEFENDENDO,
	Lutador.E.INTRO, Lutador.E.VITORIA, Lutador.E.KO,
]

var falhas: Array[String] = []


func _ready() -> void:
	Config.modo_teste = true
	_testar_comandos()
	await _testar_partidas()
	await _testar_determinismo()
	print("")
	if falhas.is_empty():
		print("TUDO CERTO: todos os testes passaram.")
		get_tree().quit(0)
	else:
		print("FALHAS (%d):" % falhas.size())
		for f in falhas:
			print("  - " + f)
		get_tree().quit(1)


func _conferir(ok: bool, descricao: String) -> void:
	if not ok:
		falhas.append(descricao)


# ------------------------------------------------------------ comandos

## Alimenta o buffer com direções em notação numérica (relativas a quem
## olha para a direita) e botões: [[2, 0], [3, 0], [6, SF]].
func _buffer(seq: Array, frente := 1) -> BufferComandos:
	var b := BufferComandos.new()
	for passo in seq:
		var d: int = passo[0]
		var x := ((d - 1) % 3) - 1
		var y := 1 - floori((d - 1) / 3.0)
		b.registrar(x * frente, y, passo[1])
	return b


func _seq(dirs: Array, botao_no_fim := 0) -> Array:
	var r := []
	for i in dirs.size():
		r.append([dirs[i], botao_no_fim if i == dirs.size() - 1 else 0])
	return r


func _testar_comandos() -> void:
	var SF := BufferComandos.SF
	for frente in [1, -1]:
		var lado := " (olhando para %s)" % ("a direita" if frente == 1 else "a esquerda")
		_conferir(_buffer(_seq([5, 2, 3, 6], SF), frente).comando("236", frente), "meia-lua 236" + lado)
		_conferir(_buffer(_seq([5, 2, 6], SF), frente).comando("236", frente), "meia-lua rápida 26" + lado)
		_conferir(_buffer(_seq([5, 2, 1, 4], SF), frente).comando("214", frente), "meia-lua para trás 214" + lado)
		_conferir(not _buffer(_seq([5, 2, 1, 4], SF), frente).comando("236", frente), "214 não pode virar 236" + lado)
		_conferir(_buffer(_seq([5, 6, 2, 3], SF), frente).comando("623", frente), "shoryuken 623" + lado)
		_conferir(_buffer(_seq([5, 6, 3, 2, 3], SF), frente).comando("623", frente), "shoryuken 6323" + lado)
		_conferir(not _buffer(_seq([5, 6, 2, 3], SF), frente).comando("236", frente), "623 não pode virar 236" + lado)
		_conferir(_buffer(_seq([5, 2, 5, 2], SF), frente).comando("22", frente), "↓↓ 22" + lado)
		_conferir(not _buffer(_seq([5, 2, 2, 2], SF), frente).comando("22", frente), "↓ segurado não é 22" + lado)
		_conferir(_buffer(_seq([5, 6, 5, 6]), frente).comando("66", frente), "dash 66" + lado)
		_conferir(not _buffer(_seq([5, 6, 6, 6]), frente).comando("66", frente), "→ segurado não é dash" + lado)
		_conferir(_buffer(_seq([5, 4, 5, 4]), frente).comando("44", frente), "dash para trás 44" + lado)
	# movimento lento demais não vale
	var lento := []
	for d in [6, 2, 3]:
		for i in 12:
			lento.append([d, 0])
	_conferir(not _buffer(lento).comando("623", 1), "623 lento demais não pode sair")
	# aperto e segurar
	var b := _buffer([[5, 0], [5, SF]])
	_conferir(b.apertou(SF) == SF, "aperto de botão")
	b.registrar(0, 0, SF)
	_conferir(b.apertou(SF) == 0, "segurar não conta como novo aperto")
	_conferir(b.apertou(SF, 2) == SF, "janela de aperto de 2 frames")
	print("Comandos: %s" % ("ok" if falhas.is_empty() else "%d falhas" % falhas.size()))


# ------------------------------------------------------------ partidas

func _rodar_partida(semente: int, dificuldade: int, p1: String, p2: String) -> Dictionary:
	Config.semente = semente
	Config.dificuldade = dificuldade
	Config.p1_cpu = true
	Config.p2_cpu = true
	Config.personagem_p1 = p1
	Config.personagem_p2 = p2
	var luta: Luta = LUTA.instantiate()
	add_child(luta)
	luta.set_physics_process(false)
	luta.set_process(false)
	var travado := [0, 0]
	var antes := [-1, -1]
	var frames := 0
	var problemas: Array[String] = []
	while luta.fase != Luta.F.FIM_PARTIDA and frames < LIMITE_FRAMES:
		luta.passo()
		frames += 1
		for i in 2:
			var l: Lutador = luta.lutadores[i]
			if l.estado == antes[i] and not (l.estado in LIVRES):
				travado[i] += 1
			else:
				travado[i] = 0
			antes[i] = l.estado
			if travado[i] == 600:
				problemas.append("%s travou no estado %s (frame %d)" % [l.p.nome, Lutador.E.keys()[l.estado], frames])
			if absf(l.position.x) > Luta.LIMITE or l.position.y > 0.5 or is_nan(l.position.x) or is_nan(l.position.y):
				if problemas.size() < 5:
					problemas.append("%s fora da arena em %s (frame %d)" % [l.p.nome, l.position, frames])
			if l.vida < 0 or l.vida > l.p.vida_max:
				problemas.append("%s com vida inválida %d" % [l.p.nome, l.vida])
	var r := {
		"terminou": luta.fase == Luta.F.FIM_PARTIDA, "frames": frames, "vencedor": luta.vencedor_partida,
		"vitorias": luta.vitorias.duplicate(), "rounds": luta.round_atual, "registro": luta.registro.duplicate(),
		"vida": [luta.lutadores[0].vida, luta.lutadores[1].vida], "problemas": problemas,
		"nomes": [luta.lutadores[0].p.nome, luta.lutadores[1].p.nome],
	}
	luta.queue_free()
	await get_tree().process_frame
	return r


func _testar_partidas() -> void:
	var total := {}
	var vitorias_por_personagem := {}
	var t0 := Time.get_ticks_msec()
	for n in PARTIDAS:
		var p1 := "sander" if n % 2 == 0 else "curupira"
		var p2 := "curupira" if n % 2 == 0 else "sander"
		var r: Dictionary = await _rodar_partida(1000 + n, n % 3, p1, p2)
		var reg: Dictionary = r["registro"]
		for k in reg:
			total[k] = int(total.get(k, 0)) + int(reg[k])
		var venc := "EMPATE"
		if int(r["vencedor"]) in [0, 1]:
			venc = r["nomes"][r["vencedor"]]
			vitorias_por_personagem[venc] = int(vitorias_por_personagem.get(venc, 0)) + 1
		print("Partida %2d  %-9s x %-9s  %-7s  vencedor: %-8s  rounds %d (%d x %d)  %5.1f s de luta  acertos %3d  defesas %3d  KOs %d  tempo %d" % [
			n + 1, r["nomes"][0], r["nomes"][1], Config.NOMES_DIFICULDADE[n % 3], venc, r["rounds"],
			r["vitorias"][0], r["vitorias"][1], r["frames"] / 60.0, reg.get("acertos", 0), reg.get("defesas", 0),
			reg.get("ko", 0), reg.get("tempo_esgotado", 0)])
		_conferir(r["terminou"], "partida %d não terminou em %d frames" % [n + 1, LIMITE_FRAMES])
		for pr in r["problemas"]:
			falhas.append("partida %d: %s" % [n + 1, pr])
	print("")
	print("Golpes usados nas %d partidas:" % PARTIDAS)
	var chaves := total.keys()
	chaves.sort()
	var linha := ""
	for k in chaves:
		linha += "%s=%d  " % [k, total[k]]
		if linha.length() > 100:
			print("  " + linha)
			linha = ""
	if linha != "":
		print("  " + linha)
	print("Vitórias: %s" % vitorias_por_personagem)
	print("Tempo do teste: %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	for e in ESPECIAIS:
		_conferir(int(total.get("golpe_" + e, 0)) > 0, "a CPU nunca usou o golpe %s" % e)
	_conferir(int(total.get("efeito_pegadas", 0)) > 0, "as pegadas (Pés Virados) nunca acertaram")
	_conferir(int(total.get("acertos", 0)) > 0, "ninguém acertou nada")
	_conferir(int(total.get("defesas", 0)) > 0, "ninguém defendeu nada")
	_conferir(int(total.get("ko", 0)) > 0, "nenhum round acabou em KO")


func _testar_determinismo() -> void:
	var a: Dictionary = await _rodar_partida(77, 1, "sander", "curupira")
	var b: Dictionary = await _rodar_partida(77, 1, "sander", "curupira")
	var igual: bool = a["frames"] == b["frames"] and a["vida"] == b["vida"] and a["registro"] == b["registro"]
	print("Determinismo: %s (%d frames, vida final %s)" % ["ok" if igual else "FALHOU", a["frames"], a["vida"]])
	_conferir(igual, "a mesma semente deu partidas diferentes")
