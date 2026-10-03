class_name Personagem
extends RefCounted
## Definição de um personagem: atributos, golpes, comandos e poses.
##
## Cada lutador do elenco estende esta classe (ver sander.gd e curupira.gd)
## e preenche os dados em configurar(). Os números de golpe seguem a
## convenção de jogo de luta, em frames de 1/60 s:
##   inicio      = frames até o golpe ficar ativo (startup)
##   ativo       = frames em que a hitbox pode acertar
##   recuperacao = frames até poder agir de novo
## A hitbox é calculada sozinha a partir da pose do golpe ("membro" que
## acerta), então mudar a pose já ajusta o alcance. Dá para forçar uma
## hitbox manual com "hitbox": Rect2(...).

const SF := BufferComandos.SF
const SR := BufferComandos.SR
const CF := BufferComandos.CF
const CR := BufferComandos.CR
const DEF := BufferComandos.DEF
const NEON := BufferComandos.NEON

var id := ""
var nome := ""
var titulo := ""
var faccao := ""
var cor_neon := Color.WHITE
var cor_faccao := Color.WHITE
var vida_max := 1000
## Script do desenho (Esqueleto) deste personagem.
var visual: Script = null

# Movimento, em pixels por frame.
var vel_andar := 3.2
var vel_recuar := 2.6
var vel_dash := 8.5
var frames_dash := 16
var vel_backdash := 7.5
var frames_backdash := 18
var pulo_vy := -15.5
var pulo_vx := 4.0
var gravidade := 0.75

# Corpo, em pixels.
var corpo := {
	"coxa": 50.0, "canela": 48.0, "tronco": 60.0, "pescoco": 8.0, "cabeca": 13.0,
	"braco": 32.0, "antebraco": 30.0,
}
var caixa_pe := Rect2(-24, -188, 48, 188)
var caixa_agachado := Rect2(-26, -120, 52, 120)
var caixa_ar := Rect2(-22, -178, 44, 150)
var caixa_caido := Rect2(-80, -30, 160, 30)
var largura_empurrao := 22.0
var alcance_arremesso := 70.0

## id do golpe -> dados do golpe.
var golpes := {}
## "pe_sf", "agachado_cr", "ar_sr"... -> id do golpe normal.
var normais := {}
## Especiais em ordem de prioridade: {"comando", "botoes", "golpe", "ar"}.
var especiais: Array = []
## Lista de golpes para o menu de pausa: [nome, comando, botão, descrição].
var lista_golpes: Array = []
var poses := {}
var anims := {}


func _init() -> void:
	_poses_base()
	_anims_base()
	configurar()
	_finalizar()


## Sobrescreva para preencher atributos, poses e golpes.
func configurar() -> void:
	pass


# ------------------------------------------------------------ ganchos

## Estado próprio do personagem guardado no Lutador (ex.: guitarra na mão).
func novo_extra() -> Dictionary:
	return {}


func pode_usar(_g: Dictionary, _l) -> bool:
	return true


## Pode trocar o golpe normal conforme o estado (ex.: Sander sem guitarra).
func golpe_normal(chave: String, _l) -> String:
	return normais.get(chave, "")


func ao_iniciar_golpe(_g: Dictionary, _l) -> void:
	pass


func ao_frame_golpe(_g: Dictionary, _l, _f: int) -> void:
	pass


func ao_iniciar_round(_l) -> void:
	pass


# ------------------------------------------------------------ cadastro

func pose(nome_pose: String, base: String, valores: Dictionary) -> void:
	var p: Dictionary = (poses[base] as Dictionary).duplicate() if poses.has(base) else {}
	p.merge(valores, true)
	poses[nome_pose] = p


func anim(nome_anim: String, chaves: Array, loop := true) -> void:
	anims[nome_anim] = {"chaves": chaves, "loop": loop}


func golpe(id_golpe: String, dados: Dictionary) -> void:
	var g := {
		"id": id_golpe, "nome": id_golpe, "tipo": "normal", "forca": "fraco", "postura": "pe",
		"inicio": 5, "ativo": 3, "recuperacao": 10,
		"dano": 30, "atordoa": 14, "bloqueio": 10, "empurrao": 5.0, "chip": 0,
		"altura": "medio", "hitstop": 8, "derruba": false, "lanca": false,
		"cancela": [], "membro": "mao_f", "hitbox": Rect2(), "margem": 0.0,
		"pose_prep": "", "pose_golpe": "", "anim": [],
		"som": "vento_fraco", "som_acerto": "acerto_fraco",
		"mover": [], "invencivel": [], "imune_projetil": [],
		"projetil": {}, "brilho": false,
	}
	g.merge(dados, true)
	golpes[id_golpe] = g


func especial(comando: String, botoes: int, id_golpe: String, no_ar := false) -> void:
	especiais.append({"comando": comando, "botoes": botoes, "golpe": id_golpe, "ar": no_ar})


func total_frames(g: Dictionary) -> int:
	return int(g["inicio"]) + int(g["ativo"]) + int(g["recuperacao"])


# ------------------------------------------------------------ animação

static func suavizar(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


static func interpolar(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var r := {}
	for k in a:
		var va = a[k]
		var vb = b.get(k, va)
		if va is Vector2:
			r[k] = (va as Vector2).lerp(vb, t)
		elif k == "rot":
			# giro pelo caminho mais curto (360 e 0 são o mesmo ângulo)
			r[k] = rad_to_deg(lerp_angle(deg_to_rad(float(va)), deg_to_rad(float(vb)), t))
		elif va is float or va is int:
			r[k] = lerpf(float(va), float(vb), t)
		else:
			r[k] = va if t < 0.5 else vb
	return r


func avaliar_anim(nome_anim: String, f: int) -> Dictionary:
	if not anims.has(nome_anim):
		return poses.get(nome_anim, poses["parado"])
	var a: Dictionary = anims[nome_anim]
	return _avaliar_chaves(a["chaves"], f, a["loop"])


func avaliar_golpe(g: Dictionary, f: int) -> Dictionary:
	return _avaliar_chaves(g["_chaves"], f, false)


func _avaliar_chaves(chaves: Array, f: int, loop: bool) -> Dictionary:
	var n := chaves.size()
	if n == 1:
		return poses[chaves[0][1]]
	var dur: int = chaves[n - 1][0]
	var ff := f
	if loop and dur > 0:
		ff = posmod(f, dur)
	ff = clampi(ff, 0, dur)
	for i in n - 1:
		var a: Array = chaves[i]
		var b: Array = chaves[i + 1]
		if ff >= int(a[0]) and ff <= int(b[0]):
			var span := maxi(1, int(b[0]) - int(a[0]))
			var tt := suavizar(float(ff - int(a[0])) / float(span))
			return interpolar(poses[a[1]], poses[b[1]], tt)
	return poses[chaves[n - 1][1]]


# ------------------------------------------------------------ finalização

func _finalizar() -> void:
	for k in poses:
		var completa: Dictionary = (poses["parado"] as Dictionary).duplicate()
		completa.merge(poses[k], true)
		poses[k] = completa
	for k in anims:
		for chave in anims[k]["chaves"]:
			if not poses.has(chave[1]):
				push_error("%s: animação %s usa pose inexistente %s" % [id, k, chave[1]])
	for id_golpe in golpes:
		var g: Dictionary = golpes[id_golpe]
		var base := "parado"
		if g["postura"] == "agachado":
			base = "agachado"
		elif g["postura"] == "ar":
			base = "pulo_cair"
		g["_base"] = base
		var chaves: Array = g["anim"]
		if chaves.is_empty():
			var ini := int(g["inicio"])
			var atv := int(g["ativo"])
			var prep: String = g["pose_prep"] if g["pose_prep"] != "" else base
			var acerto: String = g["pose_golpe"] if g["pose_golpe"] != "" else base
			chaves = [
				[0, base], [maxi(1, int(round(ini * 0.6))), prep], [ini + 1, acerto],
				[ini + atv, acerto], [total_frames(g), base],
			]
		for chave in chaves:
			if not poses.has(chave[1]):
				push_error("%s: golpe %s usa pose inexistente %s" % [id, id_golpe, chave[1]])
		g["_chaves"] = chaves
		var hb: Rect2 = g["hitbox"]
		if hb.size == Vector2.ZERO and g["pose_golpe"] != "" and g["membro"] != "":
			hb = caixa_do_membro(poses[g["pose_golpe"]], g["membro"])
		g["hitbox"] = hb.grow(float(g["margem"]))


## Caixa em volta da parte do corpo que acerta, na pose dada.
func caixa_do_membro(p: Dictionary, membro: String) -> Rect2:
	var jt := Esqueleto.calcular_juntas(p, corpo)
	var a := Vector2.ZERO
	var b := Vector2.ZERO
	var raio := 8.0
	match membro:
		"mao_f":
			a = (jt["cot_f"] as Vector2).lerp(jt["mao_f"], 0.45)
			b = jt["mao_f"]
			raio = 8.0
		"mao_t":
			a = (jt["cot_t"] as Vector2).lerp(jt["mao_t"], 0.45)
			b = jt["mao_t"]
			raio = 8.0
		"cot_f":
			a = (jt["ombro"] as Vector2).lerp(jt["cot_f"], 0.5)
			b = jt["cot_f"]
			raio = 10.0
		"pe_f", "pe_t":
			var lado: String = membro.substr(3)
			var joelho: Vector2 = jt["joe_" + lado]
			var pe: Vector2 = jt["pe_" + lado]
			a = joelho.lerp(pe, 0.35)
			b = pe + (pe - joelho).normalized() * 6.0
			raio = 10.0
		"joe_f":
			a = (jt["quadril"] as Vector2).lerp(jt["joe_f"], 0.6)
			b = jt["joe_f"]
			raio = 11.0
		"guitarra":
			var mao: Vector2 = jt["mao_t"]
			var ang: float = jt["gt"]
			a = Esqueleto.ponta(mao, ang, 18.0)
			b = Esqueleto.ponta(mao, ang, 58.0)
			raio = 13.0
		_:
			return Rect2()
	var r := Rect2(a, Vector2.ZERO).expand(b)
	return r.grow(raio)


# ------------------------------------------------------------ poses base

func _poses_base() -> void:
	poses["parado"] = {
		"quadril": Vector2(0, -90), "tronco": 6.0, "cabeca": 4.0,
		"mao_f": Vector2(16, -2), "mao_t": Vector2(4, 22),
		"pe_f": Vector2(18, 0), "pe_t": Vector2(-20, 0),
		"rot": 0.0, "cot_f": 1.0, "cot_t": 1.0, "joe_f": -1.0, "joe_t": -1.0,
		"gt": 95.0, "gt_frente": 0.0, "brilho": 0.0, "olhos": 0.0,
	}
	pose("parado2", "parado", {"quadril": Vector2(0, -87), "mao_f": Vector2(16, 1), "mao_t": Vector2(4, 24)})
	pose("andar1", "parado", {"quadril": Vector2(0, -89), "pe_f": Vector2(20, 0), "pe_t": Vector2(-22, 0)})
	pose("andar2", "parado", {"quadril": Vector2(2, -92), "pe_f": Vector2(28, -8), "pe_t": Vector2(-20, 0)})
	pose("andar3", "parado", {"quadril": Vector2(2, -88), "pe_f": Vector2(24, 0), "pe_t": Vector2(-14, 0)})
	pose("andar4", "parado", {"quadril": Vector2(0, -91), "pe_f": Vector2(22, 0), "pe_t": Vector2(-8, -8)})
	pose("agachado", "parado", {
		"quadril": Vector2(0, -56), "tronco": 16.0, "cabeca": 4.0,
		"mao_f": Vector2(18, -4), "mao_t": Vector2(6, 16),
		"pe_f": Vector2(22, 0), "pe_t": Vector2(-24, 0), "gt": 50.0,
	})
	pose("defesa", "parado", {
		"quadril": Vector2(-3, -88), "tronco": -2.0, "cabeca": 8.0,
		"mao_f": Vector2(12, -18), "mao_t": Vector2(16, -10),
		"pe_f": Vector2(16, 0), "pe_t": Vector2(-24, 0),
	})
	pose("defesa_agachado", "agachado", {
		"quadril": Vector2(-3, -54), "tronco": 10.0, "cabeca": 8.0,
		"mao_f": Vector2(14, -16), "mao_t": Vector2(18, -8),
		"pe_f": Vector2(20, 0), "pe_t": Vector2(-26, 0),
	})
	pose("pre_pulo", "parado", {
		"quadril": Vector2(0, -70), "tronco": 14.0, "cabeca": 0.0,
		"mao_f": Vector2(14, 6), "mao_t": Vector2(0, 22),
		"pe_f": Vector2(18, 0), "pe_t": Vector2(-18, 0),
	})
	pose("pulo", "parado", {
		"quadril": Vector2(0, -96), "tronco": 4.0, "cabeca": -2.0,
		"mao_f": Vector2(18, -22), "mao_t": Vector2(-4, -12),
		"pe_f": Vector2(14, -30), "pe_t": Vector2(-14, -20),
	})
	pose("pulo_cair", "pulo", {
		"tronco": 8.0, "mao_f": Vector2(20, -10), "mao_t": Vector2(-6, 0),
		"pe_f": Vector2(16, -12), "pe_t": Vector2(-14, -4),
	})
	pose("pulo_frente", "pulo", {
		"tronco": 16.0, "mao_f": Vector2(20, -14), "mao_t": Vector2(-4, -4),
		"pe_f": Vector2(22, -42), "pe_t": Vector2(-4, -34),
	})
	pose("dash", "parado", {
		"quadril": Vector2(6, -80), "tronco": 28.0, "cabeca": -10.0,
		"mao_f": Vector2(14, 10), "mao_t": Vector2(-12, 26),
		"pe_f": Vector2(30, -8), "pe_t": Vector2(-30, 0),
	})
	pose("backdash", "parado", {
		"quadril": Vector2(-6, -92), "tronco": -12.0, "cabeca": 6.0,
		"mao_f": Vector2(14, -10), "mao_t": Vector2(-6, 14),
		"pe_f": Vector2(12, -14), "pe_t": Vector2(-24, -8),
	})
	pose("dor_alto", "parado", {
		"quadril": Vector2(-8, -88), "tronco": -20.0, "cabeca": -22.0,
		"mao_f": Vector2(-2, 6), "mao_t": Vector2(-12, 14),
		"pe_f": Vector2(14, 0), "pe_t": Vector2(-22, 0), "olhos": 1.0,
	})
	pose("dor_medio", "parado", {
		"quadril": Vector2(-6, -82), "tronco": 30.0, "cabeca": 22.0,
		"mao_f": Vector2(10, 28), "mao_t": Vector2(-4, 30),
		"pe_f": Vector2(16, 0), "pe_t": Vector2(-22, 0), "olhos": 1.0,
	})
	pose("dor_agachado", "agachado", {
		"quadril": Vector2(-6, -52), "tronco": -6.0, "cabeca": -16.0,
		"mao_f": Vector2(6, 10), "mao_t": Vector2(-6, 16),
		"pe_f": Vector2(20, 0), "pe_t": Vector2(-26, 0), "olhos": 1.0,
	})
	pose("voando", "parado", {
		"quadril": Vector2(0, -84), "tronco": -40.0, "cabeca": -20.0,
		"mao_f": Vector2(14, -36), "mao_t": Vector2(-6, -30),
		"pe_f": Vector2(26, -16), "pe_t": Vector2(12, -6), "olhos": 1.0,
	})
	pose("caido", "parado", {
		"quadril": Vector2(0, -14), "tronco": -90.0, "cabeca": -6.0,
		"mao_f": Vector2(-14, 8), "mao_t": Vector2(12, 10),
		"pe_f": Vector2(84, -6), "pe_t": Vector2(76, -2), "olhos": 1.0, "gt": 0.0,
	})
	pose("levantar", "agachado", {
		"quadril": Vector2(-4, -48), "tronco": 32.0, "cabeca": -4.0,
		"mao_f": Vector2(26, 42), "mao_t": Vector2(12, 42),
		"pe_f": Vector2(24, 0), "pe_t": Vector2(-20, 0),
	})
	pose("vitoria", "parado", {
		"quadril": Vector2(0, -92), "tronco": -4.0, "cabeca": -12.0,
		"mao_f": Vector2(10, -56), "mao_t": Vector2(-10, 24),
		"pe_f": Vector2(14, 0), "pe_t": Vector2(-18, 0),
	})
	pose("vitoria2", "vitoria", {"quadril": Vector2(0, -89), "mao_f": Vector2(14, -50)})
	pose("agarrar", "parado", {
		"quadril": Vector2(4, -88), "tronco": 18.0,
		"mao_f": Vector2(38, -6), "mao_t": Vector2(32, 0),
		"pe_f": Vector2(24, 0), "pe_t": Vector2(-20, 0),
	})
	pose("arremessar", "parado", {
		"quadril": Vector2(-4, -88), "tronco": -24.0, "cabeca": -10.0,
		"mao_f": Vector2(-30, -36), "mao_t": Vector2(-24, -30),
		"pe_f": Vector2(20, 0), "pe_t": Vector2(-26, 0),
	})
	pose("agarrado", "dor_medio", {"tronco": 10.0, "mao_f": Vector2(20, -10), "mao_t": Vector2(16, -2)})


func _anims_base() -> void:
	anim("parado", [[0, "parado"], [26, "parado2"], [52, "parado"]])
	anim("intro", [[0, "parado"], [26, "parado2"], [52, "parado"]])
	anim("andar", [[0, "andar1"], [8, "andar2"], [16, "andar3"], [24, "andar4"], [32, "andar1"]])
	anim("recuar", [[0, "andar1"], [8, "andar4"], [16, "andar3"], [24, "andar2"], [32, "andar1"]])
	anim("agachado", [[0, "agachado"]])
	anim("defesa", [[0, "defesa"]])
	anim("defesa_agachado", [[0, "defesa_agachado"]])
	anim("pre_pulo", [[0, "pre_pulo"]])
	anim("pulo", [[0, "pulo"], [16, "pulo"], [34, "pulo_cair"]], false)
	anim("pulo_frente", [[0, "pulo"], [8, "pulo_frente"], [26, "pulo_frente"], [36, "pulo_cair"]], false)
	anim("pulo_tras", [[0, "pulo"], [8, "pulo_frente"], [26, "pulo_frente"], [36, "pulo_cair"]], false)
	anim("aterrissar", [[0, "pre_pulo"], [4, "parado"]], false)
	anim("dash", [[0, "dash"]])
	anim("backdash", [[0, "backdash"]])
	anim("dor_alto", [[0, "dor_alto"], [12, "dor_alto"], [20, "parado"]], false)
	anim("dor_medio", [[0, "dor_medio"], [12, "dor_medio"], [20, "parado"]], false)
	anim("dor_agachado", [[0, "dor_agachado"], [12, "dor_agachado"], [20, "agachado"]], false)
	anim("voando", [[0, "voando"]])
	anim("caido", [[0, "caido"]])
	anim("levantar", [[0, "caido"], [10, "levantar"], [22, "parado"]], false)
	anim("vitoria", [[0, "vitoria"], [20, "vitoria2"], [40, "vitoria"]])
	anim("agarrado", [[0, "agarrado"]])
