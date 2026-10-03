class_name Lutador
extends Node2D
## Um lutador: estado, física, leitura de comandos e golpes.
##
## A lógica roda em passo fixo de 60 frames por segundo e só avança quando
## a Luta chama tick(). Assim a luta inteira fica determinística (requisito
## para replay e netcode com rollback no futuro).
## Coordenadas: y = 0 é o chão, y negativo é para cima. 'frente' é 1 quando
## o lutador olha para a direita e -1 para a esquerda.

enum E {
	PARADO, ANDANDO, AGACHADO, DEFENDENDO, PRE_PULO, NO_AR, ATERRISSANDO, GOLPE,
	ATORDOADO, BLOQUEANDO, VOANDO, CAIDO, LEVANTANDO, DASH, BACKDASH, AGARRADO,
	KO, VITORIA, INTRO,
}

const SF := BufferComandos.SF
const SR := BufferComandos.SR
const CF := BufferComandos.CF
const CR := BufferComandos.CR
const DEF := BufferComandos.DEF
const NEON := BufferComandos.NEON

const FRAMES_CAIDO := 38
const FRAMES_LEVANTAR := 22

var p: Personagem
var jogador := 1
var oponente: Lutador
## Nó da Luta (sem tipo para não criar dependência circular entre scripts).
var luta: Node

var vel := Vector2.ZERO
## Empurrão recebido (golpes e bloqueios), some aos poucos.
var empurrao := 0.0
var frente := 1
var estado: int = E.INTRO
var frames_estado := 0
var vida := 1000
var no_chao := true
var agachado := false

var golpe: Dictionary = {}
var frame_golpe := 0
var golpe_acertou := false
var golpe_conectou := false
var ataque_aereo_usado := false
var pulo_dir := 0
var atordoamento := 0
var acerto_alto := false
var desorientado := 0
var tremor := 0
var flash := 0.0
var quicou := false
var arremesso_para_tras := false
var agarrado_por: Lutador = null
## Estado próprio do personagem (ex.: cordas da guitarra do Sander).
var extra: Dictionary = {}

var buffer := BufferComandos.new()
## ControleCPU quando o lutador é da CPU, ou null para jogador humano.
var cpu: ControleCPU = null
var _botao_pendente := 0
var _pendente_frames := 0

var visual: Esqueleto
var reflexo: Esqueleto
var sombra: Sombra
var anim := ""
var pose_atual: Dictionary = {}
var _pose_antes: Dictionary = {}
var _mistura := 0
var _mistura_total := 1


class Sombra extends Node2D:
	var altura := 0.0

	func _draw() -> void:
		var esc := clampf(1.0 - altura / 320.0, 0.35, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.2))
		draw_circle(Vector2.ZERO, 40.0 * esc, Color(0.0, 0.0, 0.02, 0.5 * esc))
		draw_circle(Vector2.ZERO, 26.0 * esc, Color(0.0, 0.0, 0.02, 0.35 * esc))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func configurar(personagem: Personagem, numero: int) -> void:
	p = personagem
	jogador = numero
	name = "Lutador%d_%s" % [numero, p.id]
	vida = p.vida_max
	extra = p.novo_extra()
	sombra = Sombra.new()
	sombra.z_index = -2
	add_child(sombra)
	reflexo = p.visual.new()
	reflexo.eh_reflexo = true
	reflexo.z_index = -1
	reflexo.modulate = Color(1, 1, 1, 0.22)
	add_child(reflexo)
	visual = p.visual.new()
	add_child(visual)
	for v in [visual, reflexo]:
		var esq := v as Esqueleto
		esq.corpo = p.corpo
		esq.cor_neon = p.cor_neon


# ------------------------------------------------------------ round

func iniciar_round(x: float, lado: int) -> void:
	position = Vector2(x, 0)
	vel = Vector2.ZERO
	empurrao = 0.0
	frente = lado
	vida = p.vida_max
	no_chao = true
	agachado = false
	golpe = {}
	frame_golpe = 0
	golpe_acertou = false
	golpe_conectou = false
	atordoamento = 0
	desorientado = 0
	tremor = 0
	flash = 0.0
	quicou = false
	agarrado_por = null
	extra = p.novo_extra()
	p.ao_iniciar_round(self)
	buffer.limpar()
	_botao_pendente = 0
	_pendente_frames = 0
	visual.rastros.clear()
	anim = ""
	pose_atual = {}
	_mudar(E.INTRO)
	if cpu:
		cpu.reiniciar()
	_atualizar_visual()


func liberar() -> void:
	_mudar(E.PARADO)


func comemorar() -> void:
	if estado in [E.KO, E.CAIDO, E.VOANDO]:
		return
	golpe = {}
	vel = Vector2(0.0, vel.y)
	if no_chao:
		_mudar(E.VITORIA)


# ------------------------------------------------------------ entrada

## Registra a entrada deste frame. Durante a pausa de impacto (hitstop) os
## apertos continuam guardados para os cancelamentos funcionarem.
func registrar_entrada(e: Dictionary, congelado := false) -> void:
	buffer.registrar(e["x"], e["y"], e["seg"], e.get("apt", 0))
	var apt := buffer.apertou(BufferComandos.ATAQUES | NEON)
	if apt != 0:
		_botao_pendente = apt
		_pendente_frames = 6
	elif not congelado and _pendente_frames > 0:
		_pendente_frames -= 1
		if _pendente_frames == 0:
			_botao_pendente = 0


func _consumir_botao() -> void:
	_botao_pendente = 0
	_pendente_frames = 0


## Direção atual em notação numérica relativa ao lado do lutador.
func _dir() -> int:
	return buffer.dir(0, frente)


# ------------------------------------------------------------ passo

func tick() -> void:
	frames_estado += 1
	if desorientado > 0:
		desorientado -= 1
	if flash > 0.0:
		flash = maxf(0.0, flash - 0.25)
	if tremor > 0:
		tremor -= 1
	match estado:
		E.INTRO, E.VITORIA:
			vel.x = 0.0
		E.PARADO, E.ANDANDO, E.AGACHADO, E.DEFENDENDO:
			_livre_no_chao()
		E.PRE_PULO:
			vel.x = 0.0
			if frames_estado >= 4:
				_pular()
		E.NO_AR:
			if not ataque_aereo_usado:
				_tentar_atacar()
		E.ATERRISSANDO:
			vel.x = 0.0
			if frames_estado >= 4:
				_voltar_neutro()
		E.GOLPE:
			_golpe()
		E.ATORDOADO, E.BLOQUEANDO:
			atordoamento -= 1
			if atordoamento <= 0:
				_voltar_neutro()
		E.CAIDO:
			if frames_estado >= FRAMES_CAIDO:
				_mudar(E.LEVANTANDO)
		E.LEVANTANDO:
			if frames_estado >= FRAMES_LEVANTAR:
				_voltar_neutro()
		E.DASH:
			_dash()
		E.BACKDASH:
			_backdash()
		E.AGARRADO:
			vel = Vector2.ZERO
			var a := agarrado_por
			if a == null or a.estado != E.GOLPE or a.golpe.is_empty() or a.golpe["tipo"] != "arremesso":
				agarrado_por = null
				_voltar_neutro()
	_fisica()
	_atualizar_visual()


## Durante o hitstop só o tremor e o desenho andam.
func tick_congelado() -> void:
	if tremor > 0:
		tremor -= 1
	if flash > 0.0:
		flash = maxf(0.0, flash - 0.12)
	_atualizar_visual()


func _livre_no_chao() -> void:
	no_chao = true
	ataque_aereo_usado = false
	_virar_para_oponente()
	if _tentar_atacar():
		return
	var d := _dir()
	if d >= 7:
		pulo_dir = d - 8
		vel.x = 0.0
		_mudar(E.PRE_PULO)
		return
	if buffer.comando("66", frente):
		_mudar(E.DASH)
		return
	if buffer.comando("44", frente):
		_mudar(E.BACKDASH)
		Sons.tocar_variado("vento_fraco", -8.0)
		return
	agachado = d <= 3
	var tras := d == 1 or d == 4
	if buffer.segurando(DEF) or (tras and _ameacado()):
		_mudar_se(E.DEFENDENDO)
		vel.x = 0.0
	elif agachado:
		_mudar_se(E.AGACHADO)
		vel.x = 0.0
	elif d == 6:
		_mudar_se(E.ANDANDO)
		vel.x = p.vel_andar * frente
	elif d == 4:
		_mudar_se(E.ANDANDO)
		vel.x = -p.vel_recuar * frente
	else:
		_mudar_se(E.PARADO)
		vel.x = 0.0


## Há um golpe ou projétil vindo? (mostra a pose de defesa ao segurar trás)
func _ameacado() -> bool:
	var dist := absf(oponente.position.x - position.x)
	if oponente.estado == E.GOLPE and not oponente.golpe.is_empty() and dist < 260.0:
		var ini := int(oponente.golpe["inicio"])
		if oponente.frame_golpe <= ini + int(oponente.golpe["ativo"]):
			return true
	return luta.projetil_vindo(self, 300.0)


func _virar_para_oponente() -> void:
	var dx := oponente.position.x - position.x
	if absf(dx) < 1.0:
		return
	var lado := 1 if dx > 0.0 else -1
	if desorientado > 0:
		lado = -lado
	frente = lado


func _pular() -> void:
	no_chao = false
	vel = Vector2(pulo_dir * p.pulo_vx * frente, p.pulo_vy)
	_mudar(E.NO_AR)
	Sons.tocar_variado("pulo", -8.0)


func _dash() -> void:
	var fim := p.frames_dash
	vel.x = p.vel_dash * frente * (1.0 if frames_estado < fim - 5 else 0.45)
	if frames_estado > 5 and _tentar_atacar():
		return
	if frames_estado >= fim:
		_voltar_neutro()


func _backdash() -> void:
	var fim := p.frames_backdash
	var t := float(frames_estado) / float(fim)
	vel.x = -p.vel_backdash * frente * (1.0 - t * 0.8)
	if frames_estado >= fim:
		_voltar_neutro()


func _voltar_neutro() -> void:
	golpe = {}
	if not no_chao:
		_mudar(E.NO_AR)
		frames_estado = 30
		return
	vel.x = 0.0
	agachado = _dir() <= 3
	_mudar(E.AGACHADO if agachado else E.PARADO)


func _mudar(e: int) -> void:
	estado = e
	frames_estado = 0


func _mudar_se(e: int) -> void:
	if estado != e:
		_mudar(e)


# ------------------------------------------------------------ golpes

func _tentar_atacar() -> bool:
	if _botao_pendente == 0:
		return false
	var g := _escolher_golpe(_botao_pendente)
	if g.is_empty():
		return false
	_consumir_botao()
	iniciar_golpe(g)
	return true


func _escolher_golpe(botoes: int) -> Dictionary:
	for esp in p.especiais:
		if (botoes & int(esp["botoes"])) == 0:
			continue
		if no_chao == bool(esp["ar"]):
			continue
		if not buffer.comando(esp["comando"], frente):
			continue
		var ge: Dictionary = p.golpes[esp["golpe"]]
		if p.pode_usar(ge, self):
			return ge
	if no_chao and (botoes & SR) != 0 and _pode_arremessar():
		return p.golpes["arremesso"]
	var postura := "ar" if not no_chao else ("agachado" if _dir() <= 3 else "pe")
	for par in [[SR, "sr"], [CR, "cr"], [SF, "sf"], [CF, "cf"]]:
		if (botoes & int(par[0])) != 0:
			var id_golpe := p.golpe_normal(postura + "_" + str(par[1]), self)
			if id_golpe != "" and p.golpes.has(id_golpe):
				return p.golpes[id_golpe]
	return {}


func iniciar_golpe(g: Dictionary) -> void:
	golpe = g
	frame_golpe = 0
	golpe_acertou = false
	golpe_conectou = false
	if g["postura"] == "ar":
		ataque_aereo_usado = true
	else:
		vel.x = 0.0
	if g["tipo"] == "arremesso":
		arremesso_para_tras = _dir() == 4
	_mudar(E.GOLPE)
	p.ao_iniciar_golpe(g, self)
	luta.ao_iniciar_golpe(self, g)
	_golpe()


func _golpe() -> void:
	frame_golpe += 1
	var g := golpe
	var ini := int(g["inicio"])
	var atv := int(g["ativo"])
	if g["postura"] != "ar":
		vel.x = 0.0
		for m in g["mover"]:
			if frame_golpe >= int(m[0]) and frame_golpe <= int(m[1]):
				vel.x = float(m[2]) * frente
	if frame_golpe == ini + 1 and g["tipo"] != "arremesso":
		Sons.tocar_variado(g["som"], -4.0)
	var proj: Dictionary = g["projetil"]
	if not proj.is_empty() and frame_golpe == int(proj["frame"]):
		luta.criar_projetil(self, proj)
	if g["tipo"] == "arremesso":
		_passo_arremesso(g)
		if estado != E.GOLPE:
			return
	p.ao_frame_golpe(g, self, frame_golpe)
	if estado != E.GOLPE or not is_same(golpe, g):
		return
	if golpe_acertou and _botao_pendente != 0 and frame_golpe > ini and frame_golpe <= ini + atv + 10:
		var novo := _escolher_golpe(_botao_pendente)
		if not novo.is_empty() and _pode_cancelar(g, novo):
			_consumir_botao()
			iniciar_golpe(novo)
			return
	if frame_golpe >= p.total_frames(g):
		if g["postura"] == "ar" and not no_chao:
			golpe = {}
			_mudar(E.NO_AR)
			frames_estado = 30
		else:
			_voltar_neutro()


func _pode_cancelar(atual: Dictionary, novo: Dictionary) -> bool:
	var regras: Array = atual["cancela"]
	if novo["tipo"] == "especial":
		return "especial" in regras
	if novo["tipo"] != "normal" or novo["postura"] == "ar":
		return false
	if novo["forca"] == "forte":
		return "forte" in regras
	return "fraco" in regras


func _pode_arremessar() -> bool:
	if not p.golpes.has("arremesso"):
		return false
	var d := _dir()
	if d != 4 and d != 6:
		return false
	if not oponente.pode_ser_agarrado():
		return false
	return absf(oponente.position.x - position.x) <= p.alcance_arremesso


func pode_ser_agarrado() -> bool:
	if not no_chao or agarrado_por != null or tremor > 0:
		return false
	if estado in [E.PARADO, E.ANDANDO, E.AGACHADO, E.DEFENDENDO, E.DASH, E.ATERRISSANDO]:
		return true
	if estado == E.GOLPE and not golpe.is_empty() and golpe["tipo"] != "arremesso":
		return frame_golpe > int(golpe["inicio"]) + int(golpe["ativo"])
	return false


func _passo_arremesso(g: Dictionary) -> void:
	var agarra := 3
	var solta := int(g["inicio"]) + int(g["ativo"])
	if frame_golpe == agarra:
		if oponente.pode_ser_agarrado() and absf(oponente.position.x - position.x) <= p.alcance_arremesso + 12.0:
			oponente.ser_agarrado(self)
			golpe_acertou = true
			golpe_conectou = true
			Sons.tocar("agarrar", -2.0)
		return
	if oponente.agarrado_por != self:
		return
	if frame_golpe < solta:
		var lado := -frente if (arremesso_para_tras and frame_golpe > agarra + 8) else frente
		oponente.position = Vector2(position.x + lado * 42.0, -18.0 if frame_golpe > agarra + 6 else 0.0)
		oponente.frente = -lado
	elif frame_golpe == solta:
		var direcao := -frente if arremesso_para_tras else frente
		luta.aplicar_arremesso(self, oponente, g, direcao)


func ser_agarrado(por: Lutador) -> void:
	agarrado_por = por
	golpe = {}
	vel = Vector2.ZERO
	empurrao = 0.0
	_mudar(E.AGARRADO)


# ------------------------------------------------------------ acertos

## Pode levar golpe agora? (caído, levantando e já voando não levam)
func pode_ser_atingido() -> bool:
	if estado in [E.CAIDO, E.LEVANTANDO, E.KO, E.INTRO, E.VITORIA, E.VOANDO, E.AGARRADO]:
		return false
	if estado == E.BACKDASH and frames_estado <= 8:
		return false
	if estado == E.GOLPE and _no_intervalo(golpe["invencivel"]):
		return false
	return true


func imune_a_projetil() -> bool:
	return estado == E.GOLPE and _no_intervalo(golpe["imune_projetil"])


func _no_intervalo(intervalo: Array) -> bool:
	return intervalo.size() == 2 and frame_golpe >= int(intervalo[0]) and frame_golpe <= int(intervalo[1])


func esta_agachado() -> bool:
	if estado == E.GOLPE and not golpe.is_empty():
		return golpe["postura"] == "agachado"
	return no_chao and agachado and estado in [E.AGACHADO, E.DEFENDENDO, E.BLOQUEANDO, E.ATORDOADO]


func em_atordoamento() -> bool:
	return estado in [E.ATORDOADO, E.VOANDO, E.AGARRADO] or (estado == E.KO and not no_chao)


## Caixa local (olhando para a direita) convertida para o mundo.
func para_mundo(r: Rect2) -> Rect2:
	if frente == 1:
		return Rect2(position + r.position, r.size)
	return Rect2(Vector2(position.x - r.position.x - r.size.x, position.y + r.position.y), r.size)


func hurtboxes() -> Array:
	var r := p.caixa_pe
	if not no_chao or estado == E.VOANDO:
		r = p.caixa_ar
	elif estado == E.CAIDO or (estado == E.KO and no_chao):
		r = p.caixa_caido
	elif esta_agachado():
		r = p.caixa_agachado
	var lista := [para_mundo(r)]
	if estado == E.GOLPE and not golpe.is_empty() and golpe["tipo"] != "arremesso":
		var hb: Rect2 = golpe["hitbox"]
		var ini := int(golpe["inicio"])
		var fim_vuln := ini + int(golpe["ativo"]) + int(int(golpe["recuperacao"]) * 0.5)
		if hb.size != Vector2.ZERO and frame_golpe >= ini - 1 and frame_golpe <= fim_vuln:
			lista.append(para_mundo(hb.grow(-5.0)))
	return lista


func hitbox_ativa() -> Rect2:
	if estado != E.GOLPE or golpe.is_empty() or golpe_acertou or golpe["tipo"] == "arremesso":
		return Rect2()
	var ini := int(golpe["inicio"])
	if frame_golpe <= ini or frame_golpe > ini + int(golpe["ativo"]):
		return Rect2()
	var hb: Rect2 = golpe["hitbox"]
	if hb.size == Vector2.ZERO:
		return Rect2()
	return para_mundo(hb)


func caixa_empurrao() -> Rect2:
	var w := p.largura_empurrao
	if not no_chao:
		return Rect2(position.x - w, position.y - 130.0, w * 2.0, 110.0)
	if estado in [E.CAIDO, E.KO, E.LEVANTANDO]:
		return Rect2(position.x - w, position.y - 40.0, w * 2.0, 40.0)
	var h := 110.0 if esta_agachado() else 160.0
	return Rect2(position.x - w, position.y - h, w * 2.0, h)


## Defende o golpe vindo de x_origem? (segurando trás ou DEF, na altura certa)
func defende(g: Dictionary, x_origem: float) -> bool:
	if not no_chao:
		return false
	if not (estado in [E.PARADO, E.ANDANDO, E.AGACHADO, E.DEFENDENDO, E.BLOQUEANDO, E.ATERRISSANDO]):
		return false
	var lado_atacante := 1 if x_origem > position.x else -1
	var tras := buffer.x_bruto() == -lado_atacante
	if estado != E.BLOQUEANDO and not (tras or buffer.segurando(DEF)):
		return false
	var agachando := buffer.y_bruto() > 0
	match g["altura"]:
		"baixo":
			return agachando
		"alto":
			return not agachando
	return true


func sofrer_bloqueio(g: Dictionary, direcao: int) -> void:
	golpe = {}
	agachado = buffer.y_bruto() > 0
	atordoamento = int(g["bloqueio"])
	empurrao = direcao * float(g["empurrao"]) * 0.9
	vel.x = 0.0
	_mudar(E.BLOQUEANDO)


func sofrer_acerto(g: Dictionary, direcao: int, dano: int, ponto_y: float) -> void:
	var estava_agachado := esta_agachado()
	var no_ar := not no_chao or estado == E.VOANDO
	vida = maxi(0, vida - dano)
	golpe = {}
	flash = 1.0
	agarrado_por = null
	if vida <= 0:
		no_chao = false
		quicou = false
		vel = Vector2(direcao * 4.5, -9.5)
		empurrao = 0.0
		_mudar(E.KO)
		return
	if no_ar or bool(g["derruba"]) or bool(g["lanca"]):
		no_chao = false
		quicou = false
		if bool(g["lanca"]):
			vel = Vector2(direcao * 2.5, -11.5)
		elif no_ar:
			vel = Vector2(direcao * 3.5, -6.5)
		else:
			vel = Vector2(direcao * 3.0, -5.5)
		empurrao = 0.0
		_mudar(E.VOANDO)
		return
	agachado = estava_agachado
	acerto_alto = ponto_y < position.y - 130.0
	atordoamento = int(g["atordoa"])
	empurrao = direcao * float(g["empurrao"])
	vel.x = 0.0
	_mudar(E.ATORDOADO)


## Arremessado: voa na direção indicada e cai.
func ser_arremessado(direcao: int, dano: int) -> void:
	agarrado_por = null
	vida = maxi(0, vida - dano)
	flash = 1.0
	no_chao = false
	quicou = false
	position.y = -20.0
	vel = Vector2(direcao * 5.0, -8.0)
	_mudar(E.KO if vida <= 0 else E.VOANDO)


func desorientar(frames: int) -> void:
	desorientado = frames
	if no_chao and estado in [E.PARADO, E.ANDANDO, E.AGACHADO, E.DEFENDENDO]:
		_virar_para_oponente()


# ------------------------------------------------------------ física

func _fisica() -> void:
	if estado == E.AGARRADO:
		return
	if not no_chao:
		vel.y += p.gravidade
	position.x += vel.x + empurrao
	position.y += vel.y
	if absf(empurrao) > 0.05:
		empurrao *= 0.82
	else:
		empurrao = 0.0
	if not no_chao and position.y >= 0.0 and vel.y > 0.0:
		position.y = 0.0
		_aterrissar()
	if no_chao:
		position.y = 0.0


func _aterrissar() -> void:
	var impacto := vel.y
	if estado in [E.VOANDO, E.KO] and not quicou and impacto > 7.0:
		quicou = true
		vel.y = -impacto * 0.32
		vel.x *= 0.6
		luta.ao_cair(self, impacto)
		return
	no_chao = true
	vel.y = 0.0
	match estado:
		E.NO_AR:
			vel.x = 0.0
			_mudar(E.ATERRISSANDO)
			Sons.tocar_variado("aterrissar", -10.0)
		E.GOLPE:
			vel.x = 0.0
			golpe = {}
			_mudar(E.ATERRISSANDO)
			Sons.tocar_variado("aterrissar", -10.0)
		E.VOANDO:
			vel.x = 0.0
			_mudar(E.CAIDO)
			luta.ao_cair(self, impacto)
		E.KO:
			vel.x = 0.0
			frames_estado = 0
			luta.ao_cair(self, impacto)
		_:
			vel.x = 0.0


# ------------------------------------------------------------ visual

func _nome_anim() -> String:
	match estado:
		E.INTRO:
			return "intro"
		E.ANDANDO:
			return "andar" if vel.x * frente > 0.0 else "recuar"
		E.AGACHADO:
			return "agachado"
		E.DEFENDENDO, E.BLOQUEANDO:
			return "defesa_agachado" if agachado else "defesa"
		E.PRE_PULO:
			return "pre_pulo"
		E.NO_AR:
			if pulo_dir == 0:
				return "pulo"
			return "pulo_frente" if pulo_dir > 0 else "pulo_tras"
		E.ATERRISSANDO:
			return "aterrissar"
		E.ATORDOADO:
			if agachado:
				return "dor_agachado"
			return "dor_alto" if acerto_alto else "dor_medio"
		E.VOANDO:
			return "voando"
		E.KO:
			return "caido" if no_chao else "voando"
		E.CAIDO:
			return "caido"
		E.LEVANTANDO:
			return "levantar"
		E.DASH:
			return "dash"
		E.BACKDASH:
			return "backdash"
		E.AGARRADO:
			return "agarrado"
		E.VITORIA:
			return "vitoria"
	return "parado"


func _atualizar_visual() -> void:
	var nome := ""
	var nova: Dictionary
	if estado == E.GOLPE and not golpe.is_empty():
		nome = "golpe:" + str(golpe["id"])
		nova = p.avaliar_golpe(golpe, frame_golpe)
	else:
		nome = _nome_anim()
		nova = p.avaliar_anim(nome, frames_estado)
	if nome != anim:
		if not pose_atual.is_empty():
			_pose_antes = pose_atual
			var rapido := estado in [E.GOLPE, E.ATORDOADO, E.BLOQUEANDO, E.VOANDO, E.KO, E.AGARRADO]
			_mistura_total = 2 if rapido else 5
			_mistura = _mistura_total
		anim = nome
	if _mistura > 0:
		var t := 1.0 - float(_mistura) / float(_mistura_total + 1)
		nova = Personagem.interpolar(_pose_antes, nova, t)
		_mistura -= 1
	pose_atual = nova

	if float(nova.get("brilho", 0.0)) > 0.5:
		if Engine.get_physics_frames() % 2 == 0:
			visual.rastros.append(Esqueleto.calcular_juntas(nova, p.corpo))
			if visual.rastros.size() > 5:
				visual.rastros.pop_front()
	elif not visual.rastros.is_empty():
		visual.rastros.pop_front()

	var desloc := Vector2.ZERO
	if tremor > 0:
		desloc.x = 2.0 if tremor % 2 == 0 else -2.0
	for v in [visual, reflexo]:
		var esq := v as Esqueleto
		esq.pose = nova
		esq.extra = extra
		esq.flash = flash
		esq.t += 1
		esq.queue_redraw()
	visual.position = desloc
	visual.scale = Vector2(frente, 1)
	reflexo.position = Vector2(desloc.x, -2.0 * position.y)
	reflexo.scale = Vector2(frente, -1)
	sombra.position = Vector2(0, -position.y)
	sombra.altura = -position.y
	sombra.queue_redraw()
	queue_redraw()


func _draw() -> void:
	if desorientado > 0:
		var t := float(Engine.get_physics_frames())
		var topo := Vector2(0, -218)
		for i in 3:
			var a := t * 0.12 + i * TAU / 3.0
			var c := topo + Vector2(cos(a) * 18.0, sin(a) * 5.0)
			draw_circle(c, 3.0, Color(0.25, 1.0, 0.5, 0.9))
			draw_circle(c + Vector2(0, 5), 2.0, Color(0.25, 1.0, 0.5, 0.6))
