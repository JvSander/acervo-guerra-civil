class_name Projetil
extends Node2D
## Base dos projéteis. A Luta chama tick() a cada frame e cuida das colisões.
## A caixa é local, como se o projétil fosse para a direita.

var dono: Lutador
var tipo := ""
## Dados do golpe: dano, atordoa, bloqueio, chip, empurrao, hitstop...
var dados: Dictionary = {}
var vel := Vector2.ZERO
var frente := 1
var frame := 0
var duracao := 240
## Pode acertar agora.
var ativo := true
## Marcado para ser removido.
var morto := false
var caixa := Rect2(-16, -16, 32, 32)
var cor := Color.WHITE
var bloqueavel := true
var colide_com_projetil := true


func iniciar(quem: Lutador, cfg: Dictionary) -> void:
	dono = quem
	frente = quem.frente
	tipo = cfg["tipo"]
	dados = cfg
	cor = quem.p.cor_neon
	var pos: Vector2 = cfg.get("pos", Vector2(60, -120))
	position = quem.position + Vector2(pos.x * frente, pos.y)
	vel = Vector2(float(cfg.get("vel", 6.0)) * frente, 0.0)
	z_index = 2
	ao_iniciar()


func ao_iniciar() -> void:
	pass


func tick() -> void:
	frame += 1
	position += vel
	if frame > duracao or absf(position.x) > 1100.0:
		morto = true
	queue_redraw()


func caixa_mundo() -> Rect2:
	if frente == 1:
		return Rect2(position + caixa.position, caixa.size)
	return Rect2(Vector2(position.x - caixa.position.x - caixa.size.x, position.y + caixa.position.y), caixa.size)


## Dados no formato de golpe, para a Luta aplicar o acerto.
func como_golpe() -> Dictionary:
	return {
		"id": tipo, "tipo": "projetil", "dano": int(dados.get("dano", 60)),
		"atordoa": int(dados.get("atordoa", 16)), "bloqueio": int(dados.get("bloqueio", 12)),
		"chip": int(dados.get("chip", 0)), "empurrao": float(dados.get("empurrao", 5.0)),
		"hitstop": int(dados.get("hitstop", 8)), "altura": dados.get("altura", "medio"),
		"derruba": bool(dados.get("derruba", false)), "lanca": false,
		"som_acerto": dados.get("som_acerto", "choque"),
	}


func pode_acertar(alvo: Lutador) -> bool:
	return ativo and not morto and alvo != dono


func ao_acertar(_alvo: Lutador, _bloqueado: bool) -> void:
	morto = true


func ao_colidir() -> void:
	morto = true
