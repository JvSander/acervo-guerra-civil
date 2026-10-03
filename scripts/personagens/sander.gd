extends Personagem
## SANDER · O Guitarrista · ACERVO · neon azul-relâmpago
## Rushdown com projétil bumerangue (GDD, seção 3.2).
##
## Especiais:
##   Riff (↓↘→ + S): acorde que vira onda de choque.
##   Energizar (↓↓ + S): acende uma corda da guitarra (até 3, aparece no HUD).
##   Guitarra Bumerangue (→↓↘ + NEON): gasta 1 corda; a guitarra acerta na
##     ida e na volta. Sem a guitarra na mão o SR vira soco (mais fraco) e o
##     Riff/Energizar ficam indisponíveis até ela voltar.


func configurar() -> void:
	id = "sander"
	nome = "SANDER"
	titulo = "O GUITARRISTA"
	faccao = "ACERVO"
	cor_neon = Color(0.3, 0.78, 1.0)
	cor_faccao = Color(0.25, 0.85, 1.0)
	visual = preload("res://scripts/visual/visual_sander.gd")
	vel_andar = 3.4
	vel_recuar = 2.7
	vel_dash = 9.0
	frames_dash = 16
	_poses()
	_golpes()
	lista_golpes = [
		["Riff", "236", "S", "Acorde que vira onda de choque."],
		["Energizar", "22", "S", "Acende uma corda da guitarra (até 3)."],
		["Guitarra Bumerangue", "623", "NEON", "Gasta 1 corda. Acerta na ida e na volta."],
		["Microfonia (agarrão)", "6", "SR", "Perto do rival. Com ← joga para trás."],
	]


func novo_extra() -> Dictionary:
	return {"guitarra": true, "cordas": 0}


func pode_usar(g: Dictionary, l) -> bool:
	var e: Dictionary = l.extra
	match g["id"]:
		"riff_f", "riff_r":
			return e["guitarra"] and not l.luta.tem_projetil(l, "riff")
		"energizar":
			return e["guitarra"] and int(e["cordas"]) < 3
		"bumerangue":
			return e["guitarra"] and int(e["cordas"]) >= 1
	return true


func golpe_normal(chave: String, l) -> String:
	if not l.extra["guitarra"] and normais.has(chave + "_sem"):
		return normais[chave + "_sem"]
	return normais.get(chave, "")


func ao_iniciar_golpe(g: Dictionary, l) -> void:
	match g["id"]:
		"bumerangue":
			l.extra["cordas"] = int(l.extra["cordas"]) - 1
		"energizar":
			Sons.tocar("energizar", -3.0)


func ao_frame_golpe(g: Dictionary, l, f: int) -> void:
	match g["id"]:
		"riff_f", "riff_r":
			if f == 11:
				Sons.tocar("riff", -1.0)
		"energizar":
			if f >= 6 and f <= 24 and f % 4 == 0:
				l.luta.efeito_raios(l, Vector2(30, -150))
			if f == 22:
				l.extra["cordas"] = mini(3, int(l.extra["cordas"]) + 1)
				l.luta.efeito_anel(l, Vector2(24, -140), cor_neon)
		"bumerangue":
			if f == 12:
				l.extra["guitarra"] = false


func _poses() -> void:
	# Guitarra: "gt" é o ângulo da guitarra saindo da mão de trás
	# (0 = para frente, 90 = para baixo, -90 = para cima).
	pose("tocar1", "parado", {
		"tronco": 2.0, "mao_t": Vector2(32, 4), "gt": 166.0, "gt_frente": 1.0,
		"mao_f": Vector2(4, 30),
	})
	pose("tocar2", "tocar1", {"mao_f": Vector2(8, 40), "quadril": Vector2(0, -88)})
	pose("sf_prep", "parado", {"mao_f": Vector2(8, 0), "tronco": 8.0})
	pose("sf", "parado", {
		"quadril": Vector2(4, -89), "tronco": 12.0, "cabeca": 0.0,
		"mao_f": Vector2(54, -4), "pe_f": Vector2(22, 0),
	})
	pose("sr_prep", "parado", {
		"quadril": Vector2(-4, -90), "tronco": -8.0, "cabeca": -4.0,
		"mao_t": Vector2(-18, -44), "gt": -125.0, "mao_f": Vector2(14, 4),
	})
	pose("sr", "parado", {
		"quadril": Vector2(8, -86), "tronco": 22.0, "cabeca": 6.0,
		"mao_t": Vector2(34, -4), "gt": 20.0, "gt_frente": 1.0,
		"mao_f": Vector2(-4, 22), "pe_f": Vector2(28, 0), "pe_t": Vector2(-22, 0),
	})
	pose("sr_sem_prep", "parado", {"mao_t": Vector2(-6, 6), "tronco": 2.0, "quadril": Vector2(-2, -90)})
	pose("sr_sem", "parado", {
		"quadril": Vector2(8, -88), "tronco": 18.0, "mao_t": Vector2(54, -8),
		"mao_f": Vector2(10, 6), "pe_f": Vector2(26, 0),
	})
	pose("cf_prep", "parado", {
		"quadril": Vector2(0, -92), "tronco": -2.0, "pe_f": Vector2(16, -40), "mao_f": Vector2(14, -6),
	})
	pose("cf", "parado", {
		"quadril": Vector2(4, -92), "tronco": -8.0, "pe_f": Vector2(64, -40),
		"mao_f": Vector2(12, -8), "mao_t": Vector2(-6, 18),
	})
	pose("cr_prep", "parado", {
		"quadril": Vector2(-4, -92), "tronco": -6.0, "pe_f": Vector2(8, -56),
		"mao_f": Vector2(10, -14), "mao_t": Vector2(-12, 6),
	})
	pose("cr", "parado", {
		"quadril": Vector2(2, -94), "tronco": -24.0, "cabeca": 10.0,
		"pe_f": Vector2(80, -118), "pe_t": Vector2(-14, 0),
		"mao_f": Vector2(2, -16), "mao_t": Vector2(-22, 4),
	})
	pose("crsf_prep", "agachado", {"mao_f": Vector2(10, 2)})
	pose("crsf", "agachado", {"mao_f": Vector2(52, -2), "tronco": 20.0})
	pose("crsr_prep", "agachado", {
		"quadril": Vector2(-2, -54), "tronco": 20.0, "mao_t": Vector2(10, 34), "gt": 150.0,
		"mao_f": Vector2(14, -6),
	})
	pose("crsr", "agachado", {
		"quadril": Vector2(6, -72), "tronco": -6.0, "cabeca": -10.0,
		"mao_t": Vector2(18, -40), "gt": -78.0, "gt_frente": 1.0, "mao_f": Vector2(8, 0),
		"pe_f": Vector2(22, 0), "pe_t": Vector2(-24, 0),
	})
	pose("crsr_sem", "agachado", {
		"quadril": Vector2(6, -74), "tronco": -4.0, "cabeca": -12.0,
		"mao_t": Vector2(16, -56), "mao_f": Vector2(8, 0),
	})
	pose("crcf_prep", "agachado", {"quadril": Vector2(-2, -52), "tronco": 10.0, "pe_f": Vector2(18, -10)})
	pose("crcf", "agachado", {
		"quadril": Vector2(-4, -50), "tronco": 4.0, "pe_f": Vector2(66, -8),
		"pe_t": Vector2(-26, 0), "mao_f": Vector2(18, -6),
	})
	pose("crcr_prep", "agachado", {
		"quadril": Vector2(-4, -46), "tronco": 30.0, "mao_f": Vector2(24, 34),
		"pe_f": Vector2(30, 0), "pe_t": Vector2(-20, 0),
	})
	pose("crcr", "agachado", {
		"quadril": Vector2(-8, -38), "tronco": 36.0, "cabeca": -8.0,
		"mao_f": Vector2(24, 40), "mao_t": Vector2(12, 38),
		"pe_f": Vector2(90, -6), "pe_t": Vector2(-24, 0),
	})
	pose("jsf_prep", "pulo_cair", {"mao_f": Vector2(8, 4)})
	pose("jsf", "pulo_cair", {"mao_f": Vector2(50, 16), "tronco": 14.0})
	pose("jsr_prep", "pulo_cair", {"mao_t": Vector2(-14, -44), "gt": -120.0, "tronco": -4.0})
	pose("jsr", "pulo_cair", {
		"mao_t": Vector2(36, 22), "gt": 55.0, "gt_frente": 1.0, "tronco": 22.0, "mao_f": Vector2(0, 10),
	})
	pose("jsr_sem", "pulo_cair", {"mao_t": Vector2(46, 22), "tronco": 18.0, "mao_f": Vector2(4, 8)})
	pose("jcf_prep", "pulo_cair", {"pe_f": Vector2(18, -40)})
	pose("jcf", "pulo_cair", {"pe_f": Vector2(60, -22), "tronco": -4.0, "pe_t": Vector2(-12, -28)})
	pose("jcr_prep", "pulo_cair", {"pe_f": Vector2(10, -50), "tronco": 0.0})
	pose("jcr", "pulo_cair", {
		"pe_f": Vector2(78, -50), "tronco": -18.0, "pe_t": Vector2(-14, -30),
		"mao_f": Vector2(6, -14), "mao_t": Vector2(-24, -6),
	})
	pose("riff_prep", "tocar1", {"mao_f": Vector2(4, 4), "brilho": 1.0})
	pose("riff", "tocar1", {
		"mao_f": Vector2(12, 42), "tronco": 14.0, "quadril": Vector2(6, -88), "brilho": 1.0,
		"pe_f": Vector2(26, 0),
	})
	pose("energizar", "parado", {
		"mao_t": Vector2(14, -42), "gt": -95.0, "gt_frente": 1.0, "mao_f": Vector2(22, -26),
		"tronco": -6.0, "cabeca": -10.0, "brilho": 1.0,
	})
	pose("bum_prep", "parado", {
		"quadril": Vector2(-4, -90), "tronco": -12.0, "mao_t": Vector2(-34, -8), "gt": 185.0,
		"mao_f": Vector2(16, -6), "brilho": 1.0,
	})
	pose("bumerangue", "parado", {
		"quadril": Vector2(6, -88), "tronco": 20.0, "mao_t": Vector2(50, -14), "gt": 0.0,
		"gt_frente": 1.0, "mao_f": Vector2(-4, 18), "pe_f": Vector2(26, 0), "brilho": 1.0,
	})
	pose("vitoria", "parado", {
		"quadril": Vector2(0, -92), "tronco": -4.0, "cabeca": -12.0,
		"mao_t": Vector2(6, -58), "gt": -100.0, "gt_frente": 1.0, "mao_f": Vector2(22, -30),
	})
	pose("vitoria2", "vitoria", {"quadril": Vector2(0, -89), "mao_f": Vector2(26, -22)})
	anim("intro", [[0, "tocar1"], [8, "tocar2"], [16, "tocar1"], [24, "tocar2"], [32, "tocar1"]])


func _golpes() -> void:
	# Normais de pé
	golpe("pe_sf", {
		"nome": "Jab", "inicio": 4, "ativo": 3, "recuperacao": 7, "dano": 30, "atordoa": 13,
		"bloqueio": 9, "empurrao": 4.0, "hitstop": 7, "cancela": ["fraco", "forte", "especial"],
		"pose_prep": "sf_prep", "pose_golpe": "sf", "membro": "mao_f",
	})
	golpe("pe_sr", {
		"nome": "Guitarrada", "forca": "forte", "inicio": 10, "ativo": 4, "recuperacao": 19,
		"dano": 85, "atordoa": 20, "bloqueio": 15, "empurrao": 7.5, "hitstop": 11,
		"cancela": ["especial"], "pose_prep": "sr_prep", "pose_golpe": "sr", "membro": "guitarra",
		"som": "vento_forte", "som_acerto": "acerto_forte",
	})
	golpe("pe_sr_sem", {
		"nome": "Direto", "forca": "forte", "inicio": 7, "ativo": 3, "recuperacao": 15,
		"dano": 55, "atordoa": 18, "bloqueio": 13, "empurrao": 6.0, "hitstop": 9,
		"cancela": ["especial"], "pose_prep": "sr_sem_prep", "pose_golpe": "sr_sem", "membro": "mao_t",
		"som": "vento_forte", "som_acerto": "acerto_forte",
	})
	golpe("pe_cf", {
		"nome": "Chute frontal", "inicio": 5, "ativo": 3, "recuperacao": 9, "dano": 35, "atordoa": 14,
		"bloqueio": 10, "empurrao": 5.0, "hitstop": 7, "cancela": ["forte", "especial"],
		"pose_prep": "cf_prep", "pose_golpe": "cf", "membro": "pe_f",
	})
	golpe("pe_cr", {
		"nome": "Chute alto", "forca": "forte", "inicio": 10, "ativo": 4, "recuperacao": 20,
		"dano": 85, "atordoa": 20, "bloqueio": 16, "empurrao": 8.0, "hitstop": 11,
		"pose_prep": "cr_prep", "pose_golpe": "cr", "membro": "pe_f",
		"som": "vento_forte", "som_acerto": "acerto_forte",
	})
	# Agachado
	golpe("agachado_sf", {
		"nome": "Jab baixo", "postura": "agachado", "inicio": 4, "ativo": 2, "recuperacao": 7,
		"dano": 25, "atordoa": 12, "bloqueio": 8, "empurrao": 4.0, "hitstop": 6,
		"cancela": ["fraco", "forte", "especial"], "pose_prep": "crsf_prep", "pose_golpe": "crsf",
		"membro": "mao_f",
	})
	golpe("agachado_sr", {
		"nome": "Guitarra para cima (antiaéreo)", "postura": "agachado", "forca": "forte",
		"inicio": 7, "ativo": 5, "recuperacao": 20, "dano": 75, "atordoa": 18, "bloqueio": 14,
		"empurrao": 5.0, "hitstop": 10, "lanca": true, "cancela": ["especial"],
		"pose_prep": "crsr_prep", "pose_golpe": "crsr", "membro": "guitarra", "margem": 6.0,
		"som": "vento_forte", "som_acerto": "acerto_forte",
	})
	golpe("agachado_sr_sem", {
		"nome": "Gancho", "postura": "agachado", "forca": "forte",
		"inicio": 6, "ativo": 4, "recuperacao": 18, "dano": 55, "atordoa": 18, "bloqueio": 12,
		"empurrao": 5.0, "hitstop": 9, "lanca": true, "cancela": ["especial"],
		"pose_prep": "crsf_prep", "pose_golpe": "crsr_sem", "membro": "mao_t", "margem": 6.0,
		"som": "vento_forte", "som_acerto": "acerto_forte",
	})
	golpe("agachado_cf", {
		"nome": "Chute baixo", "postura": "agachado", "inicio": 5, "ativo": 3, "recuperacao": 9,
		"dano": 28, "atordoa": 13, "bloqueio": 9, "empurrao": 4.5, "hitstop": 7, "altura": "baixo",
		"cancela": ["fraco", "especial"], "pose_prep": "crcf_prep", "pose_golpe": "crcf", "membro": "pe_f",
	})
	golpe("agachado_cr", {
		"nome": "Rasteira", "postura": "agachado", "forca": "forte", "inicio": 9, "ativo": 4,
		"recuperacao": 22, "dano": 70, "atordoa": 18, "bloqueio": 14, "empurrao": 6.0, "hitstop": 10,
		"altura": "baixo", "derruba": true, "pose_prep": "crcr_prep", "pose_golpe": "crcr",
		"membro": "pe_f", "som": "vento_forte", "som_acerto": "acerto_forte",
	})
	# No ar (todos são "alto": defende em pé)
	golpe("ar_sf", {
		"nome": "Soco aéreo", "postura": "ar", "inicio": 4, "ativo": 6, "recuperacao": 8,
		"dano": 40, "atordoa": 14, "bloqueio": 10, "altura": "alto", "hitstop": 8,
		"pose_prep": "jsf_prep", "pose_golpe": "jsf", "membro": "mao_f",
	})
	golpe("ar_sr", {
		"nome": "Guitarra de cima", "postura": "ar", "forca": "forte", "inicio": 8, "ativo": 5,
		"recuperacao": 10, "dano": 80, "atordoa": 18, "bloqueio": 14, "altura": "alto", "hitstop": 11,
		"pose_prep": "jsr_prep", "pose_golpe": "jsr", "membro": "guitarra",
		"som": "vento_forte", "som_acerto": "acerto_forte",
	})
	golpe("ar_sr_sem", {
		"nome": "Soco forte aéreo", "postura": "ar", "forca": "forte", "inicio": 6, "ativo": 5,
		"recuperacao": 10, "dano": 55, "atordoa": 16, "bloqueio": 12, "altura": "alto", "hitstop": 9,
		"pose_prep": "jsf_prep", "pose_golpe": "jsr_sem", "membro": "mao_t",
		"som": "vento_forte", "som_acerto": "acerto_forte",
	})
	golpe("ar_cf", {
		"nome": "Joelhada aérea", "postura": "ar", "inicio": 5, "ativo": 8, "recuperacao": 8,
		"dano": 45, "atordoa": 15, "bloqueio": 10, "altura": "alto", "hitstop": 8,
		"pose_prep": "jcf_prep", "pose_golpe": "jcf", "membro": "pe_f",
	})
	golpe("ar_cr", {
		"nome": "Voadora", "postura": "ar", "forca": "forte", "inicio": 8, "ativo": 6,
		"recuperacao": 10, "dano": 80, "atordoa": 18, "bloqueio": 14, "altura": "alto", "hitstop": 11,
		"pose_prep": "jcr_prep", "pose_golpe": "jcr", "membro": "pe_f",
		"som": "vento_forte", "som_acerto": "acerto_forte",
	})
	golpe("arremesso", {
		"nome": "Microfonia", "tipo": "arremesso", "forca": "forte", "inicio": 3, "ativo": 19,
		"recuperacao": 14, "dano": 110, "membro": "", "invencivel": [1, 36], "imune_projetil": [1, 36],
		"anim": [[0, "parado"], [3, "agarrar"], [14, "agarrar"], [22, "arremessar"], [36, "parado"]],
	})
	# Especiais
	var riff := {
		"tipo": "especial", "forca": "forte", "inicio": 12, "ativo": 1, "recuperacao": 29,
		"dano": 0, "membro": "", "brilho": true, "som": "vento_fraco",
		"anim": [[0, "parado"], [6, "riff_prep"], [12, "riff"], [22, "riff"], [42, "parado"]],
	}
	var riff_f := riff.duplicate(true)
	riff_f.merge({"nome": "Riff", "projetil": {
		"frame": 12, "tipo": "riff", "vel": 6.0, "pos": Vector2(64, -122),
		"dano": 80, "atordoa": 18, "bloqueio": 14, "chip": 10, "empurrao": 6.0, "hitstop": 10,
	}}, true)
	golpe("riff_f", riff_f)
	var riff_r := riff.duplicate(true)
	riff_r.merge({"nome": "Riff", "recuperacao": 31, "projetil": {
		"frame": 12, "tipo": "riff", "vel": 8.5, "pos": Vector2(64, -122),
		"dano": 80, "atordoa": 18, "bloqueio": 14, "chip": 10, "empurrao": 6.0, "hitstop": 10,
	}}, true)
	golpe("riff_r", riff_r)
	golpe("energizar", {
		"nome": "Energizar", "tipo": "especial", "inicio": 24, "ativo": 0, "recuperacao": 10,
		"dano": 0, "membro": "", "brilho": true,
		"anim": [[0, "parado"], [7, "energizar"], [24, "energizar"], [34, "parado"]],
	})
	golpe("bumerangue", {
		"nome": "Guitarra Bumerangue", "tipo": "especial", "forca": "forte", "inicio": 12, "ativo": 1,
		"recuperacao": 21, "dano": 0, "membro": "", "brilho": true, "som": "vento_forte",
		"anim": [[0, "parado"], [7, "bum_prep"], [12, "bumerangue"], [18, "bumerangue"], [34, "parado"]],
		"projetil": {
			"frame": 12, "tipo": "guitarra", "vel": 10.0, "pos": Vector2(70, -132),
			"dano": 65, "atordoa": 18, "bloqueio": 14, "chip": 8, "empurrao": 5.0, "hitstop": 9,
		},
	})
	for chave in ["pe_sf", "pe_sr", "pe_cf", "pe_cr", "agachado_sf", "agachado_sr", "agachado_cf",
			"agachado_cr", "ar_sf", "ar_sr", "ar_cf", "ar_cr"]:
		normais[chave] = chave
	normais["pe_sr_sem"] = "pe_sr_sem"
	normais["agachado_sr_sem"] = "agachado_sr_sem"
	normais["ar_sr_sem"] = "ar_sr_sem"
	especial("623", NEON, "bumerangue")
	especial("236", SR, "riff_r")
	especial("236", SF, "riff_f")
	especial("22", SF | SR, "energizar")
