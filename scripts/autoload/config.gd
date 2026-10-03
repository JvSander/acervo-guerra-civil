extends Node
## Configurações globais enquanto o jogo está aberto (autoload "Config").

const NOMES_DIFICULDADE := ["FÁCIL", "NORMAL", "DIFÍCIL"]

## Personagens da luta (id do arquivo em res://scripts/personagens/).
var personagem_p1 := "sander"
var personagem_p2 := "curupira"

## Rounds para vencer a partida (2 = melhor de 3).
var rounds_para_vencer := 2
## Duração do round, em segundos de luta.
var tempo_round := 99

## Quem é controlado pela CPU. O P1 só vira CPU nos testes automáticos.
var p1_cpu := false
var p2_cpu := true
## 0 = fácil, 1 = normal, 2 = difícil.
var dificuldade := 1

## Efeito de tela: scanlines, aberração cromática leve e grão (F3).
var efeito_crt := true
## Desenha hitbox (vermelho) e hurtbox (verde) dos lutadores (F1).
var mostrar_caixas := false

## Semente da CPU. -1 sorteia uma nova a cada partida.
var semente := -1
## Desliga voz do anunciador e trava a câmera lenta (usado pelos testes).
var modo_teste := false


func nome_dificuldade() -> String:
	return NOMES_DIFICULDADE[clampi(dificuldade, 0, 2)]
