class_name Luta
extends Node2D
## A luta 1x1: rounds, cronômetro, colisões, câmera e efeitos.
##
## Toda a lógica anda em passo fixo (60 por segundo) dentro de passo().
## Ordem de cada frame:
##   1. lê os controles (ou a CPU)
##   2. cada lutador anda um frame (estado, golpe, física)
##   3. os projéteis andam
##   4. separa os corpos e aplica os limites da arena e da tela
##   5. resolve os acertos de golpes e de projéteis (trocas valem)
##   6. avança o round (KO, tempo, vitória)
## Um acerto congela a luta por alguns frames (hitstop) para dar peso.

signal partida_terminou(vencedor: int)

enum F { INTRO, LUTA, KO, FIM_ROUND, FIM_PARTIDA }

## Meia largura da arena, em pixels.
const LIMITE := 620.0
## Distância mínima do lutador até a parede.
const MARGEM := 28.0
## Distância máxima entre os dois (sempre cabem na tela de 960).
const DIST_MAX := 860.0
## Altura da câmera: o chão fica a 50 pixels da borda de baixo.
const CAM_Y := -220.0
const META_TELA := 480.0
## Redução de dano a cada acerto do combo.
const ESCALA_COMBO := [1.0, 1.0, 0.8, 0.7, 0.6, 0.5, 0.45, 0.4]
const NEUTRO := {"x": 0, "y": 0, "seg": 0, "apt": 0}

const PERSONAGENS := {
	"sander": preload("res://scripts/personagens/sander.gd"),
	"curupira": preload("res://scripts/personagens/curupira.gd"),
}
const PROJETEIS := {
	"riff": preload("res://scripts/projeteis/riff.gd"),
	"guitarra": preload("res://scripts/projeteis/guitarra.gd"),
	"pegadas": preload("res://scripts/projeteis/pegadas.gd"),
}
const EFEITOS := preload("res://scripts/visual/efeitos.gd")
const CAIXAS := preload("res://scripts/luta/caixas.gd")

@onready var arena: ArenaSelaron = $Arena
@onready var mundo: Node2D = $Mundo
@onready var camera: Camera2D = $Camera
@onready var hud: HudLuta = $CamadaHUD/HUD
@onready var menu: MenuPausa = $CamadaPausa/Pausa
@onready var crt: ColorRect = $CamadaCRT/CRT

var lutadores: Array[Lutador] = []
var projeteis: Array[Projetil] = []
var efeitos: Node2D
var caixas: Node2D
var escurecer: Escurecer
var frente_arena: Node2D

var fase: int = F.INTRO
var frames_fase := 0
## Frames de luta desde o começo da partida (não conta hitstop).
var frame_total := 0
var round_atual := 1
var vitorias := [0, 0]
var tempo := 99
var _frames_segundo := 0
## Frames restantes de pausa de impacto (hitstop).
var congelar := 0
## Câmera lenta do KO: frames restantes.
var lento := 0
var _contador_lento := 0
## Vencedor do round: 0 ou 1 (índice do lutador), 2 = empate, -1 = ainda não.
var vencedor_round := -1
var vencedor_partida := -1
var motivo_fim := ""
## Combo em andamento de cada jogador (acertos e dano).
var combo := [0, 0]
var dano_combo := [0, 0]
## Contagem de golpes, acertos e defesas da partida (usada nos testes).
var registro := {}
var _x_antes := [0.0, 0.0]
var _tremor_camera := 0.0
var _foco_ko := Vector2.ZERO
var _rng := RandomNumberGenerator.new()


## Escurece o cenário atrás dos lutadores nos especiais e no KO.
class Escurecer extends Node2D:
	var alfa := 0.0

	func tick() -> void:
		if alfa > 0.0:
			alfa = maxf(0.0, alfa - 0.025)
			queue_redraw()

	func _draw() -> void:
		if alfa > 0.0:
			draw_rect(Rect2(-3000, -2000, 6000, 4000), Color(0.0, 0.0, 0.03, alfa))


func _ready() -> void:
	_rng.randomize()
	escurecer = Escurecer.new()
	escurecer.z_index = -5
	mundo.add_child(escurecer)
	efeitos = EFEITOS.new()
	mundo.add_child(efeitos)
	caixas = CAIXAS.new()
	caixas.luta = self
	mundo.add_child(caixas)
	frente_arena = arena.criar_frente()
	add_child(frente_arena)
	_criar_lutadores()
	hud.luta = self
	menu.luta = self
	crt.visible = Config.efeito_crt
	if not Config.modo_teste:
		Sons.iniciar_ambiente()
	iniciar_partida()


func _criar_lutadores() -> void:
	for l in lutadores:
		l.queue_free()
	lutadores.clear()
	var ids := [Config.personagem_p1, Config.personagem_p2]
	for i in 2:
		var p: Personagem = PERSONAGENS[ids[i]].new()
		if i == 1 and ids[1] == ids[0]:
			# mesmo personagem dos dois lados: o P2 ganha outra cor de neon
			p.cor_neon = Color.from_hsv(fposmod(p.cor_neon.h + 0.45, 1.0), p.cor_neon.s, p.cor_neon.v)
		var l := Lutador.new()
		l.luta = self
		l.configurar(p, i + 1)
		mundo.add_child(l)
		lutadores.append(l)
	lutadores[0].oponente = lutadores[1]
	lutadores[1].oponente = lutadores[0]
	configurar_cpu()


## Liga a CPU em quem estiver marcado no Config (F2 troca o P2).
func configurar_cpu() -> void:
	for i in 2:
		var eh_cpu: bool = Config.p1_cpu if i == 0 else Config.p2_cpu
		if eh_cpu:
			var semente := -1
			if Config.semente >= 0:
				semente = Config.semente * 2 + i
			lutadores[i].cpu = ControleCPU.new(lutadores[i], Config.dificuldade, semente)
			lutadores[i].cpu.reiniciar()
		else:
			lutadores[i].cpu = null


# ------------------------------------------------------------ partida

func iniciar_partida() -> void:
	vitorias = [0, 0]
	round_atual = 1
	vencedor_partida = -1
	frame_total = 0
	registro = {}
	_iniciar_round()


## Recomeça a partida do zero (menu de pausa e revanche).
func reiniciar_partida() -> void:
	iniciar_partida()


## Troca os personagens de lado (assim dá para jogar com a Curupira).
func trocar_personagens() -> void:
	var p1 := Config.personagem_p1
	Config.personagem_p1 = Config.personagem_p2
	Config.personagem_p2 = p1
	_criar_lutadores()
	iniciar_partida()


func mudar_dificuldade(nivel: int) -> void:
	Config.dificuldade = clampi(nivel, 0, ControleCPU.NIVEIS.size() - 1)
	configurar_cpu()


func _iniciar_round() -> void:
	for pr in projeteis:
		pr.queue_free()
	projeteis.clear()
	efeitos.limpar()
	lutadores[0].iniciar_round(-170.0, 1)
	lutadores[1].iniciar_round(170.0, -1)
	for l in lutadores:
		l.z_index = 0
	tempo = Config.tempo_round
	_frames_segundo = 0
	congelar = 0
	lento = 0
	combo = [0, 0]
	dano_combo = [0, 0]
	vencedor_round = -1
	motivo_fim = ""
	escurecer.alfa = 0.0
	_tremor_camera = 0.0
	_mudar_fase(F.INTRO)
	camera.position = Vector2(0.0, CAM_Y)
	camera.zoom = Vector2.ONE
	hud.novo_round()


func _mudar_fase(f: int) -> void:
	fase = f
	frames_fase = 0


# ------------------------------------------------------------ passo

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("debug_caixas"):
		Config.mostrar_caixas = not Config.mostrar_caixas
		hud.aviso("CAIXAS: LIGADAS" if Config.mostrar_caixas else "CAIXAS: DESLIGADAS")
	if Input.is_action_just_pressed("alternar_cpu"):
		Config.p2_cpu = not Config.p2_cpu
		configurar_cpu()
		hud.aviso("P2: CPU " + Config.nome_dificuldade() if Config.p2_cpu else "P2: JOGADOR 2")
	if Input.is_action_just_pressed("alternar_crt"):
		Config.efeito_crt = not Config.efeito_crt
		crt.visible = Config.efeito_crt


func _physics_process(_delta: float) -> void:
	var anda := true
	if lento > 0:
		# câmera lenta do KO: a luta anda um frame a cada três
		lento -= 1
		_contador_lento += 1
		anda = _contador_lento % 3 == 0
	if anda:
		passo()
	hud.tick()
	_atualizar_camera()


## Um frame de luta. Os testes chamam direto, sem esperar o relógio.
func passo() -> void:
	if congelar > 0:
		congelar -= 1
		for l in lutadores:
			if l.cpu == null:
				l.registrar_entrada(_entrada(l), true)
			l.tick_congelado()
		efeitos.tick()
		return
	frame_total += 1
	frames_fase += 1
	for l in lutadores:
		l.registrar_entrada(_entrada(l))
	_x_antes = [lutadores[0].position.x, lutadores[1].position.x]
	for l in lutadores:
		l.tick()
	for pr in projeteis:
		pr.tick()
	_separar()
	if fase == F.LUTA:
		_resolver_golpes()
		_resolver_projeteis()
	_limpar_projeteis()
	for l in lutadores:
		# quem está atacando aparece na frente
		l.z_index = 1 if l.estado == Lutador.E.GOLPE else 0
	efeitos.tick()
	escurecer.tick()
	_avancar_fase()


func _entrada(l: Lutador) -> Dictionary:
	if fase != F.LUTA:
		return NEUTRO
	if l.cpu != null:
		return l.cpu.ler()
	return Controles.ler(l.jogador)


# ------------------------------------------------------------ espaço

func _separar() -> void:
	var a := lutadores[0]
	var b := lutadores[1]
	_prender_na_arena(a)
	_prender_na_arena(b)
	# os dois sempre cabem na tela: quem se afastou neste frame volta
	var esq := a if a.position.x <= b.position.x else b
	var dir := b if esq == a else a
	var excesso := (dir.position.x - esq.position.x) - DIST_MAX
	if excesso > 0.0:
		var i_esq := lutadores.find(esq)
		var saiu_esq: float = _x_antes[i_esq] - esq.position.x
		var saiu_dir: float = dir.position.x - _x_antes[1 - i_esq]
		if saiu_esq >= saiu_dir:
			esq.position.x += excesso
		else:
			dir.position.x -= excesso
	if a.estado == Lutador.E.AGARRADO or b.estado == Lutador.E.AGARRADO:
		return
	# caixas de empurrão: um corpo não atravessa o outro
	var ra := a.caixa_empurrao()
	var rb := b.caixa_empurrao()
	if not ra.intersects(rb):
		return
	var sobra := minf(ra.end.x, rb.end.x) - maxf(ra.position.x, rb.position.x)
	if sobra <= 0.0:
		return
	var lado := signf(b.position.x - a.position.x)
	if lado == 0.0:
		lado = float(a.frente)
	var parte_a := sobra * 0.5
	var parte_b := sobra * 0.5
	if _na_parede(a, int(-lado)):
		parte_a = 0.0
		parte_b = sobra
	elif _na_parede(b, int(lado)):
		parte_a = sobra
		parte_b = 0.0
	a.position.x -= lado * parte_a
	b.position.x += lado * parte_b
	_prender_na_arena(a)
	_prender_na_arena(b)


func _prender_na_arena(l: Lutador) -> void:
	l.position.x = clampf(l.position.x, -LIMITE + MARGEM, LIMITE - MARGEM)


func _na_parede(l: Lutador, lado: int) -> bool:
	if lado > 0:
		return l.position.x >= LIMITE - MARGEM - 0.5
	return l.position.x <= -LIMITE + MARGEM + 0.5


# ------------------------------------------------------------ acertos

func _resolver_golpes() -> void:
	# primeiro descobre todos os acertos e só depois aplica: assim, se os
	# dois acertarem no mesmo frame, vale a troca
	var acertos := []
	for i in 2:
		var atk := lutadores[i]
		var def := lutadores[1 - i]
		var hb := atk.hitbox_ativa()
		if hb.size == Vector2.ZERO or not def.pode_ser_atingido():
			continue
		for hu in def.hurtboxes():
			var r: Rect2 = hu
			if hb.intersects(r):
				acertos.append([atk, def, atk.golpe, hb.intersection(r).get_center()])
				break
	for ac in acertos:
		var atk: Lutador = ac[0]
		atk.golpe_acertou = true
		atk.golpe_conectou = true
		_aplicar_golpe(atk, ac[1], ac[2], atk.position.x, ac[3], true)


## Aplica um golpe (ou projétil) em 'def'. Devolve true se acertou e false
## se foi defendido.
func _aplicar_golpe(atk: Lutador, def: Lutador, g: Dictionary, x_origem: float, ponto: Vector2,
		corpo_a_corpo: bool, bloqueavel := true) -> bool:
	var i := lutadores.find(atk)
	var direcao := 1 if def.position.x > x_origem else -1
	if absf(def.position.x - x_origem) < 0.5:
		direcao = atk.frente
	var hitstop := int(g["hitstop"])
	if bloqueavel and def.defende(g, x_origem):
		var chip := int(g["chip"])
		if def.vida - chip > 0:
			def.vida -= chip
			def.sofrer_bloqueio(g, direcao)
			congelar = maxi(congelar, int(round(hitstop * 0.75)))
			def.tremor = congelar
			efeitos.bloqueio(ponto, direcao)
			Sons.tocar_variado("bloqueio", -4.0)
			if corpo_a_corpo:
				_recuo_na_parede(atk, def, g, direcao, 0.9)
			_contar("defesas")
			return false
		# o dano de raspão termina o round: vira acerto
		g = g.duplicate()
		g["dano"] = chip
	if def.em_atordoamento():
		combo[i] += 1
	else:
		combo[i] = 1
		dano_combo[i] = 0
	var escala: float = ESCALA_COMBO[mini(combo[i] - 1, ESCALA_COMBO.size() - 1)]
	var dano := maxi(1, int(round(int(g["dano"]) * escala)))
	dano_combo[i] += mini(dano, def.vida)
	def.sofrer_acerto(g, direcao, dano, ponto.y)
	congelar = maxi(congelar, hitstop)
	def.tremor = congelar + 2
	var forte: bool = g.get("forca", "fraco") == "forte" or g["tipo"] != "normal"
	efeitos.faisca(ponto, atk.p.cor_neon, forte, direcao)
	Sons.tocar_variado(g["som_acerto"], -1.0 if forte else -3.0)
	if forte:
		_tremor_camera = maxf(_tremor_camera, 3.5 if g["tipo"] == "normal" else 5.5)
	if corpo_a_corpo:
		_recuo_na_parede(atk, def, g, direcao, 1.0)
	_contar("acertos")
	if combo[i] >= 2:
		_contar("combos_%d_hits" % combo[i])
	return true


## Encostado na parede quem recua é o atacante (senão o combo é infinito).
func _recuo_na_parede(atk: Lutador, def: Lutador, g: Dictionary, direcao: int, fator: float) -> void:
	if _na_parede(def, direcao) and atk.no_chao:
		atk.empurrao = -direcao * float(g["empurrao"]) * fator


func _resolver_projeteis() -> void:
	# projétil contra projétil: os dois somem
	for a in projeteis:
		for b in projeteis:
			if a.get_instance_id() >= b.get_instance_id() or a.morto or b.morto:
				continue
			if a.dono == b.dono or not (a.ativo and b.ativo):
				continue
			if not (a.colide_com_projetil and b.colide_com_projetil):
				continue
			var ra := a.caixa_mundo()
			var rb := b.caixa_mundo()
			if ra.intersects(rb):
				a.ao_colidir()
				b.ao_colidir()
				efeitos.faisca(ra.intersection(rb).get_center(), Color(0.9, 0.95, 1.0), true, 1)
				Sons.tocar("choque", -4.0)
				_contar("projeteis_anulados")
	# projétil contra lutador
	for pr in projeteis:
		if pr.morto:
			continue
		var alvo := pr.dono.oponente
		if not pr.pode_acertar(alvo) or not alvo.pode_ser_atingido() or alvo.imune_a_projetil():
			continue
		var cx := pr.caixa_mundo()
		for hu in alvo.hurtboxes():
			var r: Rect2 = hu
			if not cx.intersects(r):
				continue
			var g := pr.como_golpe()
			if int(g["dano"]) <= 0 and int(g["atordoa"]) <= 0:
				# projétil de efeito, sem dano (ex.: Pés Virados)
				pr.ao_acertar(alvo, false)
				efeitos.anel(alvo.position + Vector2(0, -100), pr.cor)
				Sons.tocar("choque", -8.0, 0.7)
				_contar("efeito_" + pr.tipo)
			else:
				var acertou := _aplicar_golpe(pr.dono, alvo, g, pr.position.x, cx.intersection(r).get_center(),
					false, pr.bloqueavel)
				pr.ao_acertar(alvo, not acertou)
			break


func _limpar_projeteis() -> void:
	var vivos: Array[Projetil] = []
	for pr in projeteis:
		if pr.morto:
			pr.queue_free()
		else:
			vivos.append(pr)
	projeteis = vivos


## No KO os projéteis na tela se desfazem.
func _dissipar_projeteis() -> void:
	for pr in projeteis:
		if not pr.morto:
			efeitos.anel(pr.position, pr.cor)
			pr.morto = true
			if pr.tipo == "guitarra":
				pr.dono.extra["guitarra"] = true


func _contar(chave: String) -> void:
	registro[chave] = int(registro.get(chave, 0)) + 1


# ------------------------------------------------------------ chamadas do Lutador

func ao_iniciar_golpe(l: Lutador, g: Dictionary) -> void:
	_contar("golpe_" + str(g["id"]))
	if g["tipo"] == "especial":
		escurecer.alfa = maxf(escurecer.alfa, 0.3)
		escurecer.queue_redraw()
		efeitos.anel(l.position + Vector2(0, -100), l.p.cor_neon)


func criar_projetil(l: Lutador, cfg: Dictionary) -> void:
	if not PROJETEIS.has(cfg["tipo"]):
		push_error("Projétil desconhecido: %s" % cfg["tipo"])
		return
	var pr: Projetil = PROJETEIS[cfg["tipo"]].new()
	mundo.add_child(pr)
	pr.iniciar(l, cfg)
	projeteis.append(pr)


func aplicar_arremesso(atk: Lutador, def: Lutador, g: Dictionary, direcao: int) -> void:
	var i := lutadores.find(atk)
	combo[i] = 1
	dano_combo[i] = mini(int(g["dano"]), def.vida)
	def.ser_arremessado(direcao, int(g["dano"]))
	efeitos.faisca(def.position + Vector2(0, -90), atk.p.cor_neon, true, direcao)
	Sons.tocar("acerto_forte", -1.0, 0.85)
	congelar = maxi(congelar, 9)
	_tremor_camera = maxf(_tremor_camera, 6.0)
	_contar("arremessos")


func ao_cair(l: Lutador, impacto: float) -> void:
	efeitos.poeira(l.position, clampf(impacto / 9.0, 0.6, 1.5))
	Sons.tocar_variado("queda", -3.0 if impacto > 9.0 else -7.0)
	_tremor_camera = maxf(_tremor_camera, clampf(impacto * 0.35, 1.0, 5.0))


## Há projétil do rival vindo na direção de 'l' a menos de 'dist' pixels?
func projetil_vindo(l: Lutador, dist: float) -> bool:
	for pr in projeteis:
		if pr.morto or not pr.ativo or pr.dono == l:
			continue
		var dx := l.position.x - pr.position.x
		if absf(dx) < dist and signf(dx) == signf(pr.vel.x):
			return true
	return false


func projetil_mais_proximo(l: Lutador) -> Projetil:
	var melhor: Projetil = null
	var menor := INF
	for pr in projeteis:
		if pr.morto or not pr.ativo or pr.dono == l:
			continue
		var d := absf(pr.position.x - l.position.x)
		if d < menor:
			menor = d
			melhor = pr
	return melhor


func tem_projetil(l: Lutador, tipo: String) -> bool:
	for pr in projeteis:
		if pr.dono == l and pr.tipo == tipo and not pr.morto:
			return true
	return false


func efeito_raios(l: Lutador, offset: Vector2) -> void:
	efeitos.raios(l.position + Vector2(offset.x * l.frente, offset.y), l.p.cor_neon)


func efeito_anel(l: Lutador, offset: Vector2, cor: Color) -> void:
	efeitos.anel(l.position + Vector2(offset.x * l.frente, offset.y), cor)


# ------------------------------------------------------------ round

func _avancar_fase() -> void:
	match fase:
		F.INTRO:
			if frames_fase == 20:
				_anunciar_round()
			elif frames_fase == 95:
				hud.anunciar("LUTEM!", Color(1.0, 0.22, 0.38), HudLuta.GRANDE, 48)
				Sons.tocar("lutem", -2.0)
				Sons.anunciar("Lutem!")
			elif frames_fase >= 112:
				for l in lutadores:
					l.liberar()
				_mudar_fase(F.LUTA)
		F.LUTA:
			if lutadores[0].vida <= 0 or lutadores[1].vida <= 0:
				_fim_por_ko()
				return
			_frames_segundo += 1
			if _frames_segundo >= 60:
				_frames_segundo = 0
				tempo -= 1
				if tempo <= 10 and tempo > 0:
					Sons.tocar("tique", -6.0)
				if tempo <= 0:
					_fim_por_tempo()
		F.KO:
			_passo_ko()
		F.FIM_ROUND:
			_passo_fim_round()
		F.FIM_PARTIDA:
			_comemorar_vencedor()


func _anunciar_round() -> void:
	var penultimo := Config.rounds_para_vencer - 1
	var final: bool = vitorias[0] == penultimo and vitorias[1] == penultimo and round_atual > 1
	var texto := "ROUND FINAL" if final else "ROUND %d" % round_atual
	hud.anunciar(texto, Color(0.92, 0.96, 1.0), HudLuta.MEDIO, 70)
	Sons.tocar("round", -2.0)
	Sons.anunciar("Round final" if final else "Round %d" % round_atual)


func _fim_por_ko() -> void:
	var caiu1 := lutadores[0].vida <= 0
	var caiu2 := lutadores[1].vida <= 0
	if caiu1 and caiu2:
		vencedor_round = 2
	else:
		vencedor_round = 1 if caiu1 else 0
	motivo_fim = "ko"
	_mudar_fase(F.KO)
	_dissipar_projeteis()
	if not Config.modo_teste:
		lento = 84
	_tremor_camera = 9.0
	escurecer.alfa = 0.55
	var perdedor := lutadores[0] if caiu1 else lutadores[1]
	_foco_ko = perdedor.position + Vector2(0, -100)
	hud.anunciar("K.O.", Color(1.0, 0.12, 0.22), HudLuta.ENORME, 120)
	hud.piscar(0.85)
	Sons.tocar("ko", 0.0)
	Sons.anunciar("Nocaute!")
	_contar("ko")


func _fim_por_tempo() -> void:
	var v1 := float(lutadores[0].vida) / float(lutadores[0].p.vida_max)
	var v2 := float(lutadores[1].vida) / float(lutadores[1].p.vida_max)
	if is_equal_approx(v1, v2):
		vencedor_round = 2
	else:
		vencedor_round = 0 if v1 > v2 else 1
	motivo_fim = "tempo"
	_mudar_fase(F.KO)
	_dissipar_projeteis()
	hud.anunciar("TEMPO!", Color(1.0, 0.78, 0.2), HudLuta.GRANDE, 90)
	Sons.tocar("round", -2.0, 0.8)
	Sons.anunciar("Tempo!")
	_contar("tempo_esgotado")


func _passo_ko() -> void:
	if frames_fase < 70:
		return
	if motivo_fim == "ko" and frames_fase < 260:
		# espera quem perdeu terminar de cair
		for l in lutadores:
			if l.vida <= 0 and not (l.estado == Lutador.E.KO and l.no_chao):
				return
	_encerrar_round()


func _encerrar_round() -> void:
	_mudar_fase(F.FIM_ROUND)
	if vencedor_round == 2:
		vitorias[0] += 1
		vitorias[1] += 1
		hud.anunciar("EMPATE", Color(0.8, 0.86, 1.0), HudLuta.GRANDE, 150)
		Sons.anunciar("Empate!")
		return
	vitorias[vencedor_round] += 1
	var v := lutadores[vencedor_round]
	var perfeito := v.vida >= v.p.vida_max
	hud.anunciar("%s VENCE" % v.p.nome, v.p.cor_neon, HudLuta.MEDIO, 160, "PERFEITO!" if perfeito else "")
	Sons.anunciar(v.p.nome.capitalize() + " vence!" + (" Perfeito!" if perfeito else ""))
	if perfeito:
		_contar("perfeito")


func _passo_fim_round() -> void:
	_comemorar_vencedor()
	if frames_fase < 170:
		return
	var alvo := Config.rounds_para_vencer
	var p1_venceu: bool = vitorias[0] >= alvo
	var p2_venceu: bool = vitorias[1] >= alvo
	if not (p1_venceu or p2_venceu):
		round_atual += 1
		_iniciar_round()
		return
	if p1_venceu and p2_venceu:
		vencedor_partida = 2
	else:
		vencedor_partida = 0 if p1_venceu else 1
	_mudar_fase(F.FIM_PARTIDA)
	hud.fim_partida(vencedor_partida)
	if not Config.modo_teste:
		menu.abrir_fim(vencedor_partida)
	partida_terminou.emit(vencedor_partida)


func _comemorar_vencedor() -> void:
	if vencedor_round < 0 or vencedor_round > 1:
		return
	var v := lutadores[vencedor_round]
	if v.estado in [Lutador.E.PARADO, Lutador.E.AGACHADO, Lutador.E.ANDANDO, Lutador.E.DEFENDENDO]:
		v.comemorar()


# ------------------------------------------------------------ câmera

func _atualizar_camera() -> void:
	var a := lutadores[0].position
	var b := lutadores[1].position
	var zoom := 1.0
	var meia := META_TELA
	var alvo := Vector2((a.x + b.x) * 0.5, CAM_Y + minf(0.0, (minf(a.y, b.y) + 170.0) * 0.4))
	if fase == F.KO and motivo_fim == "ko" and lento > 0:
		# zoom no KO, puxando a câmera para quem caiu
		zoom = 1.14
		meia = META_TELA / zoom
		alvo = alvo.lerp(_foco_ko, 0.4)
		alvo.y = minf(alvo.y, CAM_Y + 270.0 * (1.0 - 1.0 / zoom))
	alvo.x = clampf(alvo.x, -LIMITE + meia, LIMITE - meia)
	camera.position = camera.position.lerp(alvo, 0.35)
	camera.zoom = camera.zoom.lerp(Vector2(zoom, zoom), 0.1)
	if _tremor_camera > 0.15:
		camera.offset = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * _tremor_camera
		_tremor_camera *= 0.84
	else:
		_tremor_camera = 0.0
		camera.offset = Vector2.ZERO
	arena.atualizar(camera.position)
