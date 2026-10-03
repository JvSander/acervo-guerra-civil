extends Personagem
## CURUPIRA · A Professora de Capoeira · GRUPO B · neon verde-mata
## Capoeira com ginga constante: ela nunca fica parada (GDD, seção 3.1).
##
## Especiais:
##   Meia-Lua de Compasso (↓↘→ + CR): giro baixo com alcance enorme. Derruba.
##   Aú Fantasma (→↓↘ + C): estrela que passa por cima de projéteis e
##     termina com o calcanhar de cima (defende em pé).
##   Pés Virados (↓↙← + NEON): pegadas ao contrário correm pelo chão; quem
##     pisa fica "desorientado" (vira para o lado errado) por 2,5 s.
##     Não dá para defender, só pular.


func configurar() -> void:
	id = "curupira"
	nome = "CURUPIRA"
	titulo = "A PROFESSORA DE CAPOEIRA"
	faccao = "GRUPO B"
	cor_neon = Color(0.22, 1.0, 0.48)
	cor_faccao = Color(1.0, 0.18, 0.5)
	visual = preload("res://scripts/visual/visual_curupira.gd")
	corpo = {
		"coxa": 49.0, "canela": 47.0, "tronco": 54.0, "pescoco": 8.0, "cabeca": 12.0,
		"braco": 30.0, "antebraco": 28.0,
	}
	caixa_pe = Rect2(-22, -178, 44, 178)
	caixa_agachado = Rect2(-26, -108, 52, 108)
	caixa_ar = Rect2(-22, -170, 44, 145)
	vel_andar = 3.2
	vel_recuar = 3.0
	vel_dash = 8.5
	frames_dash = 18
	pulo_vy = -16.0
	pulo_vx = 4.3
	_poses()
	_golpes()
	lista_golpes = [
		["Meia-Lua de Compasso", "236", "CR", "Giro baixo de alcance enorme. Derruba."],
		["Aú Fantasma", "623", "C", "Estrela que passa por cima de projéteis."],
		["Pés Virados", "214", "NEON", "Pegadas ao contrário: o rival vira para o lado errado."],
		["Vingativa (agarrão)", "6", "SR", "Perto do rival. Com ← joga para trás."],
	]


func pode_usar(g: Dictionary, l) -> bool:
	if g["id"] == "pes_virados":
		return not l.luta.tem_projetil(l, "pegadas")
	return true


func ao_frame_golpe(g: Dictionary, l, f: int) -> void:
	match g["id"]:
		"pes_virados":
			if f == 8:
				Sons.tocar("berimbau", -2.0)
		"meia_lua":
			if f == 9:
				Sons.tocar("berimbau", -6.0, 1.25)
		"au_f", "au_r":
			if f == 6 or f == 16:
				Sons.tocar_variado("vento_fraco", -8.0)


func _poses() -> void:
	# A base dela é a ginga: base aberta, um braço protegendo o rosto.
	pose("parado", "parado", {
		"quadril": Vector2(-6, -76), "tronco": 22.0, "cabeca": -12.0,
		"mao_f": Vector2(20, -18), "mao_t": Vector2(-28, 6),
		"pe_f": Vector2(30, 0), "pe_t": Vector2(-36, 0),
	})
	pose("ginga2", "parado", {
		"quadril": Vector2(0, -82), "tronco": 12.0, "cabeca": -6.0,
		"mao_f": Vector2(14, -8), "mao_t": Vector2(-6, 12),
		"pe_f": Vector2(14, 0), "pe_t": Vector2(-14, 0),
	})
	pose("ginga3", "parado", {
		"quadril": Vector2(6, -76), "tronco": 22.0, "cabeca": -12.0,
		"mao_f": Vector2(-26, 6), "mao_t": Vector2(18, -18),
		"pe_f": Vector2(-34, 0), "pe_t": Vector2(30, 0),
	})
	pose("agachado", "parado", {
		"quadril": Vector2(0, -50), "tronco": 30.0, "cabeca": -10.0,
		"mao_f": Vector2(20, -14), "mao_t": Vector2(14, 20),
		"pe_f": Vector2(26, 0), "pe_t": Vector2(-26, 0),
	})
	pose("defesa", "parado", {
		"quadril": Vector2(-4, -82), "tronco": 0.0, "cabeca": 10.0,
		"mao_f": Vector2(10, -20), "mao_t": Vector2(14, -12),
		"pe_f": Vector2(16, 0), "pe_t": Vector2(-24, 0),
	})
	pose("defesa_agachado", "agachado", {
		"quadril": Vector2(-2, -44), "tronco": 26.0, "cabeca": 10.0,
		"mao_f": Vector2(14, -22), "mao_t": Vector2(16, -12),
		"pe_f": Vector2(18, 0), "pe_t": Vector2(-22, 0),
	})
	pose("pre_pulo", "parado", {"quadril": Vector2(0, -64), "tronco": 20.0, "pe_f": Vector2(18, 0), "pe_t": Vector2(-18, 0)})
	pose("pulo", "parado", {
		"quadril": Vector2(0, -92), "tronco": 6.0, "cabeca": -4.0,
		"mao_f": Vector2(20, -24), "mao_t": Vector2(-14, -20),
		"pe_f": Vector2(16, -32), "pe_t": Vector2(-14, -22),
	})
	pose("pulo_cair", "pulo", {
		"tronco": 10.0, "mao_f": Vector2(22, -12), "mao_t": Vector2(-16, -6),
		"pe_f": Vector2(16, -12), "pe_t": Vector2(-16, -6),
	})
	# Mortal para frente e para trás (rot = giro do corpo inteiro).
	var bola := {
		"quadril": Vector2(0, -100), "tronco": 30.0, "cabeca": 10.0,
		"mao_f": Vector2(24, 24), "mao_t": Vector2(18, 30),
		"pe_f": Vector2(18, -58), "pe_t": Vector2(8, -54),
	}
	for i in 4:
		var b := bola.duplicate()
		b["rot"] = 90.0 * (i + 1)
		pose("mortal%d" % (i + 1), "pulo", b)
		var bt := bola.duplicate()
		bt["rot"] = -90.0 * (i + 1)
		pose("mortal_tras%d" % (i + 1), "pulo", bt)
	pose("pulo_cair360", "pulo_cair", {"rot": 360.0})
	# Golpes
	pose("sf_prep", "parado", {"mao_f": Vector2(-4, -34), "tronco": 10.0})
	pose("sf", "parado", {
		"mao_f": Vector2(50, -14), "tronco": 18.0, "quadril": Vector2(4, -80),
		"pe_f": Vector2(30, 0), "pe_t": Vector2(-30, 0),
	})
	pose("sr_prep", "parado", {"mao_f": Vector2(-6, 4), "tronco": 4.0, "quadril": Vector2(-4, -80)})
	pose("sr", "parado", {
		"mao_f": Vector2(6, -22), "tronco": 28.0, "quadril": Vector2(10, -78),
		"pe_f": Vector2(34, 0), "pe_t": Vector2(-26, 0), "mao_t": Vector2(-18, 14),
	})
	pose("cf_prep", "parado", {
		"pe_f": Vector2(20, -52), "tronco": -6.0, "quadril": Vector2(-2, -84),
	})
	pose("cf", "parado", {
		"pe_f": Vector2(72, -72), "tronco": -22.0, "quadril": Vector2(-4, -86), "cabeca": 8.0,
		"mao_f": Vector2(10, -20), "mao_t": Vector2(-24, 0), "pe_t": Vector2(-18, 0),
	})
	pose("cr_prep", "parado", {
		"pe_f": Vector2(0, -64), "tronco": -10.0, "quadril": Vector2(-4, -84), "mao_f": Vector2(14, -20),
	})
	pose("cr", "parado", {
		"pe_f": Vector2(82, -128), "tronco": -34.0, "cabeca": 14.0, "quadril": Vector2(0, -88),
		"pe_t": Vector2(-12, 0), "mao_f": Vector2(-6, -10), "mao_t": Vector2(-30, 10),
	})
	pose("crsf_prep", "agachado", {"mao_f": Vector2(8, -2)})
	pose("crsf", "agachado", {"mao_f": Vector2(48, -6), "tronco": 34.0})
	pose("crsr_prep", "agachado", {"mao_f": Vector2(6, 10), "quadril": Vector2(0, -48)})
	pose("crsr", "agachado", {
		"quadril": Vector2(6, -76), "tronco": -4.0, "cabeca": -14.0,
		"mao_f": Vector2(22, -56), "mao_t": Vector2(-14, 10),
		"pe_f": Vector2(22, 0), "pe_t": Vector2(-22, 0),
	})
	pose("crcf_prep", "agachado", {"pe_f": Vector2(22, -14), "quadril": Vector2(-2, -48), "tronco": 34.0})
	pose("crcf", "agachado", {
		"pe_f": Vector2(70, -10), "tronco": 40.0, "quadril": Vector2(-6, -46),
		"mao_f": Vector2(18, 30), "mao_t": Vector2(4, 34), "pe_t": Vector2(-26, 0),
	})
	pose("crcr_prep", "agachado", {
		"quadril": Vector2(-6, -36), "tronco": 50.0, "mao_f": Vector2(6, 46), "mao_t": Vector2(-6, 46),
		"pe_f": Vector2(28, 0), "pe_t": Vector2(-24, -2),
	})
	pose("crcr", "agachado", {
		"quadril": Vector2(-10, -32), "tronco": 56.0, "cabeca": -10.0,
		"mao_f": Vector2(2, 48), "mao_t": Vector2(-12, 46),
		"pe_f": Vector2(104, -6), "pe_t": Vector2(-26, 0),
	})
	pose("jsf_prep", "pulo_cair", {"mao_f": Vector2(4, -10)})
	pose("jsf", "pulo_cair", {"mao_f": Vector2(46, 18), "tronco": 12.0})
	pose("jsr_prep", "pulo_cair", {"mao_f": Vector2(0, -36), "mao_t": Vector2(-6, -34)})
	pose("jsr", "pulo_cair", {"mao_f": Vector2(44, 30), "mao_t": Vector2(38, 34), "tronco": 24.0})
	pose("jcf_prep", "pulo_cair", {"pe_f": Vector2(18, -44)})
	pose("jcf", "pulo_cair", {"pe_f": Vector2(58, -24)})
	pose("jcr_prep", "pulo_cair", {"pe_f": Vector2(4, -56), "tronco": -4.0})
	pose("jcr", "pulo_cair", {"pe_f": Vector2(80, -60), "tronco": -20.0, "pe_t": Vector2(-10, -30)})
	# Meia-lua de compasso: mãos no chão e a perna varre por baixo.
	pose("ml_prep", "parado", {
		"quadril": Vector2(-4, -50), "tronco": 62.0, "cabeca": -20.0,
		"mao_f": Vector2(14, 50), "mao_t": Vector2(2, 52),
		"pe_f": Vector2(24, 0), "pe_t": Vector2(-28, -6), "brilho": 1.0,
	})
	pose("ml_giro", "ml_prep", {"pe_t": Vector2(-50, -46), "tronco": 70.0})
	pose("ml_golpe", "ml_prep", {
		"quadril": Vector2(8, -46), "tronco": 70.0, "cabeca": -24.0,
		"mao_f": Vector2(6, 52), "mao_t": Vector2(-10, 50),
		"pe_f": Vector2(128, -30), "pe_t": Vector2(-20, 0),
	})
	# Aú (estrela): o corpo gira por cima das mãos.
	pose("au0", "parado", {
		"quadril": Vector2(0, -62), "tronco": 34.0, "cabeca": -8.0,
		"mao_f": Vector2(26, 26), "mao_t": Vector2(14, 30), "pe_f": Vector2(20, 0), "pe_t": Vector2(-24, 0),
		"brilho": 1.0,
	})
	var estrela := {
		"quadril": Vector2(0, -94), "tronco": 0.0, "cabeca": 0.0,
		"mao_f": Vector2(34, -40), "mao_t": Vector2(-34, -40),
		"pe_f": Vector2(38, -6), "pe_t": Vector2(-38, -6), "brilho": 1.0,
	}
	for i in 4:
		var e := estrela.duplicate()
		e["rot"] = 90.0 * (i + 1)
		pose("au%d" % (i + 1), "parado", e)
	pose("au_golpe", "parado", {
		"quadril": Vector2(4, -88), "tronco": -14.0, "cabeca": 6.0, "rot": 360.0,
		"pe_f": Vector2(56, -84), "pe_t": Vector2(-12, 0),
		"mao_f": Vector2(-10, -30), "mao_t": Vector2(-32, -10), "brilho": 1.0,
	})
	pose("au_fim", "parado", {"rot": 360.0})
	# Pés Virados: pisada forte que solta as pegadas.
	pose("pv_prep", "parado", {
		"quadril": Vector2(-10, -78), "tronco": 20.0, "pe_f": Vector2(10, -24),
		"mao_f": Vector2(20, -20), "mao_t": Vector2(-30, 0), "brilho": 1.0,
	})
	pose("pv", "parado", {
		"quadril": Vector2(-8, -72), "tronco": 26.0, "pe_f": Vector2(28, 0),
		"mao_f": Vector2(26, -8), "mao_t": Vector2(-34, -6), "brilho": 1.0,
	})
	pose("vitoria", "parado", {
		"quadril": Vector2(0, -90), "tronco": -6.0, "cabeca": -12.0,
		"mao_f": Vector2(28, -50), "mao_t": Vector2(-26, -48),
		"pe_f": Vector2(14, 0), "pe_t": Vector2(-16, 0),
	})
	pose("vitoria2", "vitoria", {"quadril": Vector2(0, -86), "mao_f": Vector2(30, -40), "mao_t": Vector2(-28, -38)})
	# A ginga também é a animação de andar (só que mais rápida).
	anim("parado", [[0, "parado"], [16, "ginga2"], [32, "ginga3"], [48, "ginga2"], [64, "parado"]])
	anim("intro", [[0, "parado"], [16, "ginga2"], [32, "ginga3"], [48, "ginga2"], [64, "parado"]])
	anim("andar", [[0, "parado"], [10, "ginga2"], [20, "ginga3"], [30, "ginga2"], [40, "parado"]])
	anim("recuar", [[0, "parado"], [10, "ginga2"], [20, "ginga3"], [30, "ginga2"], [40, "parado"]])
	anim("pulo_frente", [
		[0, "pulo"], [5, "mortal1"], [10, "mortal2"], [15, "mortal3"], [20, "mortal4"], [30, "pulo_cair360"],
	], false)
	anim("pulo_tras", [
		[0, "pulo"], [6, "mortal_tras1"], [12, "mortal_tras2"], [18, "mortal_tras3"], [24, "mortal_tras4"],
		[34, "pulo_cair"],
	], false)


func _golpes() -> void:
	golpe("pe_sf", {
		"nome": "Galopante", "inicio": 4, "ativo": 3, "recuperacao": 7, "dano": 28, "atordoa": 13,
		"bloqueio": 9, "empurrao": 4.0, "hitstop": 7, "cancela": ["fraco", "forte", "especial"],
		"pose_prep": "sf_prep", "pose_golpe": "sf", "membro": "mao_f",
	})
	golpe("pe_sr", {
		"nome": "Cotovelada", "forca": "forte", "inicio": 8, "ativo": 4, "recuperacao": 16,
		"dano": 80, "atordoa": 20, "bloqueio": 15, "empurrao": 7.0, "hitstop": 11,
		"cancela": ["especial"], "mover": [[2, 7, 3.5]], "pose_prep": "sr_prep", "pose_golpe": "sr",
		"membro": "cot_f", "som": "vento_forte", "som_acerto": "acerto_forte",
	})
	golpe("pe_cf", {
		"nome": "Benção", "inicio": 6, "ativo": 4, "recuperacao": 10, "dano": 40, "atordoa": 14,
		"bloqueio": 10, "empurrao": 8.0, "hitstop": 8, "cancela": ["forte", "especial"],
		"pose_prep": "cf_prep", "pose_golpe": "cf", "membro": "pe_f",
	})
	golpe("pe_cr", {
		"nome": "Martelo", "forca": "forte", "inicio": 10, "ativo": 4, "recuperacao": 19,
		"dano": 90, "atordoa": 20, "bloqueio": 16, "empurrao": 8.0, "hitstop": 12,
		"pose_prep": "cr_prep", "pose_golpe": "cr", "membro": "pe_f",
		"som": "vento_forte", "som_acerto": "acerto_forte",
	})
	golpe("agachado_sf", {
		"nome": "Galopante baixo", "postura": "agachado", "inicio": 4, "ativo": 2, "recuperacao": 7,
		"dano": 24, "atordoa": 12, "bloqueio": 8, "empurrao": 4.0, "hitstop": 6,
		"cancela": ["fraco", "forte", "especial"], "pose_prep": "crsf_prep", "pose_golpe": "crsf",
		"membro": "mao_f",
	})
	golpe("agachado_sr", {
		"nome": "Palma para cima (antiaéreo)", "postura": "agachado", "forca": "forte",
		"inicio": 7, "ativo": 5, "recuperacao": 18, "dano": 70, "atordoa": 18, "bloqueio": 14,
		"empurrao": 5.0, "hitstop": 10, "lanca": true, "cancela": ["especial"],
		"pose_prep": "crsr_prep", "pose_golpe": "crsr", "membro": "mao_f", "margem": 7.0,
		"som": "vento_forte", "som_acerto": "acerto_forte",
	})
	golpe("agachado_cf", {
		"nome": "Chapa baixa", "postura": "agachado", "inicio": 5, "ativo": 3, "recuperacao": 9,
		"dano": 28, "atordoa": 13, "bloqueio": 9, "empurrao": 4.5, "hitstop": 7, "altura": "baixo",
		"cancela": ["fraco", "especial"], "pose_prep": "crcf_prep", "pose_golpe": "crcf", "membro": "pe_f",
	})
	golpe("agachado_cr", {
		"nome": "Rasteira", "postura": "agachado", "forca": "forte", "inicio": 9, "ativo": 5,
		"recuperacao": 21, "dano": 70, "atordoa": 18, "bloqueio": 14, "empurrao": 6.0, "hitstop": 10,
		"altura": "baixo", "derruba": true, "pose_prep": "crcr_prep", "pose_golpe": "crcr",
		"membro": "pe_f", "margem": 4.0, "som": "vento_forte", "som_acerto": "acerto_forte",
	})
	golpe("ar_sf", {
		"nome": "Tapa aéreo", "postura": "ar", "inicio": 4, "ativo": 6, "recuperacao": 8,
		"dano": 38, "atordoa": 14, "bloqueio": 10, "altura": "alto", "hitstop": 8,
		"pose_prep": "jsf_prep", "pose_golpe": "jsf", "membro": "mao_f",
	})
	golpe("ar_sr", {
		"nome": "Palmas de cima", "postura": "ar", "forca": "forte", "inicio": 7, "ativo": 5,
		"recuperacao": 10, "dano": 75, "atordoa": 18, "bloqueio": 14, "altura": "alto", "hitstop": 11,
		"pose_prep": "jsr_prep", "pose_golpe": "jsr", "membro": "mao_f", "margem": 4.0,
		"som": "vento_forte", "som_acerto": "acerto_forte",
	})
	golpe("ar_cf", {
		"nome": "Chute aéreo", "postura": "ar", "inicio": 5, "ativo": 8, "recuperacao": 8,
		"dano": 45, "atordoa": 15, "bloqueio": 10, "altura": "alto", "hitstop": 8,
		"pose_prep": "jcf_prep", "pose_golpe": "jcf", "membro": "pe_f",
	})
	golpe("ar_cr", {
		"nome": "Martelo voador", "postura": "ar", "forca": "forte", "inicio": 8, "ativo": 6,
		"recuperacao": 10, "dano": 80, "atordoa": 18, "bloqueio": 14, "altura": "alto", "hitstop": 11,
		"pose_prep": "jcr_prep", "pose_golpe": "jcr", "membro": "pe_f",
		"som": "vento_forte", "som_acerto": "acerto_forte",
	})
	golpe("arremesso", {
		"nome": "Vingativa", "tipo": "arremesso", "forca": "forte", "inicio": 3, "ativo": 19,
		"recuperacao": 14, "dano": 110, "membro": "", "invencivel": [1, 36], "imune_projetil": [1, 36],
		"anim": [[0, "parado"], [3, "agarrar"], [14, "agarrar"], [22, "arremessar"], [36, "parado"]],
	})
	golpe("meia_lua", {
		"nome": "Meia-Lua de Compasso", "tipo": "especial", "forca": "forte",
		"inicio": 14, "ativo": 6, "recuperacao": 28, "dano": 90, "atordoa": 20, "bloqueio": 16,
		"chip": 10, "empurrao": 6.0, "hitstop": 12, "altura": "baixo", "derruba": true,
		"mover": [[3, 13, 3.0]], "membro": "pe_f", "pose_golpe": "ml_golpe", "margem": 8.0, "brilho": true,
		"som": "vento_forte", "som_acerto": "acerto_especial",
		"anim": [[0, "parado"], [6, "ml_prep"], [11, "ml_giro"], [15, "ml_golpe"], [20, "ml_golpe"], [48, "parado"]],
	})
	var au := {
		"nome": "Aú Fantasma", "tipo": "especial", "forca": "forte",
		"inicio": 26, "ativo": 5, "recuperacao": 12, "dano": 85, "atordoa": 20, "bloqueio": 15,
		"chip": 8, "empurrao": 6.0, "hitstop": 11, "altura": "alto", "imune_projetil": [1, 26],
		"membro": "pe_f", "pose_golpe": "au_golpe", "margem": 8.0, "brilho": true,
		"som": "vento_forte", "som_acerto": "acerto_especial",
		"anim": [[0, "parado"], [4, "au0"], [9, "au1"], [14, "au2"], [19, "au3"], [24, "au4"],
			[27, "au_golpe"], [31, "au_golpe"], [43, "au_fim"]],
	}
	var au_f := au.duplicate(true)
	au_f["mover"] = [[4, 26, 4.5]]
	golpe("au_f", au_f)
	var au_r := au.duplicate(true)
	au_r["mover"] = [[4, 26, 6.2]]
	golpe("au_r", au_r)
	golpe("pes_virados", {
		"nome": "Pés Virados", "tipo": "especial", "inicio": 13, "ativo": 0, "recuperacao": 27,
		"dano": 0, "membro": "", "brilho": true,
		"anim": [[0, "parado"], [6, "pv_prep"], [12, "pv"], [22, "pv"], [40, "parado"]],
		"projetil": {
			"frame": 12, "tipo": "pegadas", "vel": 5.0, "pos": Vector2(40, 0), "dano": 0,
			"atordoa": 0, "bloqueio": 0, "chip": 0, "empurrao": 0.0, "hitstop": 0, "desorienta": 150,
		},
	})
	for chave in ["pe_sf", "pe_sr", "pe_cf", "pe_cr", "agachado_sf", "agachado_sr", "agachado_cf",
			"agachado_cr", "ar_sf", "ar_sr", "ar_cf", "ar_cr"]:
		normais[chave] = chave
	especial("623", CR, "au_r")
	especial("623", CF, "au_f")
	especial("236", CR, "meia_lua")
	especial("214", NEON, "pes_virados")
