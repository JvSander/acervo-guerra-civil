extends Node
## Efeitos sonoros, ambiente e voz do anunciador (autoload "Sons").
##
## Os .wav em res://audio/sfx/ são gerados por ferramentas/gerar_sons.py
## (sons provisórios, sintetizados). Para trocar por sons de verdade basta
## salvar um arquivo com o mesmo nome.
## O anunciador usa a voz do sistema (text-to-speech) quando existe uma voz
## em português instalada. No Windows a voz "Maria" já resolve. No Linux a
## voz fica desligada (sem o speech-dispatcher o Godot só enche o log de erros).

const PASTA := "res://audio/sfx/"
const NOMES := [
	"vento_fraco", "vento_forte", "acerto_fraco", "acerto_forte", "acerto_especial",
	"bloqueio", "pulo", "aterrissar", "queda", "ko", "riff", "energizar", "guitarra_gira",
	"choque", "berimbau", "pegadas", "agarrar", "round", "lutem", "tique",
	"menu_mover", "menu_ok", "chuva", "musica",
]

var _sons := {}
var _canais: Array[AudioStreamPlayer] = []
var _proximo := 0
var _ambiente: AudioStreamPlayer
var _musica: AudioStreamPlayer
var _voz := ""
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 14:
		var canal := AudioStreamPlayer.new()
		add_child(canal)
		_canais.append(canal)
	_ambiente = AudioStreamPlayer.new()
	add_child(_ambiente)
	_musica = AudioStreamPlayer.new()
	add_child(_musica)
	for nome in NOMES:
		var caminho: String = PASTA + nome + ".wav"
		if ResourceLoader.exists(caminho):
			_sons[nome] = load(caminho)
	_escolher_voz()


func tocar(nome: String, volume_db := 0.0, tom := 1.0) -> void:
	if not _sons.has(nome):
		return
	var canal := _canais[_proximo]
	_proximo = (_proximo + 1) % _canais.size()
	canal.stream = _sons[nome]
	canal.volume_db = volume_db
	canal.pitch_scale = tom
	canal.play()


## Toca com uma leve variação de tom para não cansar o ouvido.
func tocar_variado(nome: String, volume_db := 0.0, variacao := 0.06) -> void:
	tocar(nome, volume_db, 1.0 + _rng.randf_range(-variacao, variacao))


func iniciar_ambiente(volume_chuva := -14.0, volume_musica := -12.0) -> void:
	_tocar_em_loop(_ambiente, "chuva", volume_chuva)
	_tocar_em_loop(_musica, "musica", volume_musica)


func parar_ambiente() -> void:
	_ambiente.stop()
	_musica.stop()


func _tocar_em_loop(canal: AudioStreamPlayer, nome: String, volume_db: float) -> void:
	if not _sons.has(nome) or canal.playing:
		return
	var stream: AudioStream = _sons[nome]
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	canal.stream = stream
	canal.volume_db = volume_db
	canal.play()


func _escolher_voz() -> void:
	if Config.modo_teste or OS.get_name() not in ["Windows", "macOS"]:
		return
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return
	var vozes := DisplayServer.tts_get_voices_for_language("pt")
	if vozes.size() > 0:
		_voz = vozes[0]


## Fala o texto com voz grave (se houver voz em português no sistema).
func anunciar(texto: String) -> void:
	if _voz == "" or Config.modo_teste:
		return
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(texto, _voz, 100, 0.55, 0.92)
