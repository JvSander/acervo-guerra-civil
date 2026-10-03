extends Node
## Grava capturas de tela de uma luta CPU x CPU, para conferir o visual sem
## abrir o editor (e para as imagens do README). Uso:
##   godot --fixed-fps 60 res://ferramentas/capturas.tscn -- <pasta> [semente]
## Salva um PNG a cada 20 frames no começo e nos momentos de KO e de vitória.
## No fim abre o menu de pausa, a lista de golpes e os controles.

const LUTA := preload("res://cenas/luta.tscn")

var luta: Luta
var pasta := "user://capturas"
var frame := 0
var _fase_antes := -1
var _marcos := {}
var _fim := -1


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		pasta = args[0]
	Config.semente = int(args[1]) if args.size() > 1 else 3
	Config.p1_cpu = true
	Config.p2_cpu = true
	Config.dificuldade = 2
	DirAccess.make_dir_recursive_absolute(pasta)
	luta = LUTA.instantiate()
	add_child(luta)


func _physics_process(_delta: float) -> void:
	frame += 1
	if luta.fase != _fase_antes:
		_fase_antes = luta.fase
		var nome: String = Luta.F.keys()[luta.fase].to_lower()
		for atraso in [6, 30, 90]:
			_marcos[frame + atraso] = "%s_%d" % [nome, atraso]
		if luta.fase == Luta.F.FIM_PARTIDA:
			_fim = frame
	var nome_cap := ""
	if frame <= 1600 and frame % 20 == 0:
		nome_cap = "f%05d" % frame
	if _marcos.has(frame):
		nome_cap = "f%05d_%s" % [frame, _marcos[frame]]
	if _fim > 0:
		var depois := frame - _fim
		if depois == 110:
			nome_cap = "menu_fim"
		elif depois == 120:
			luta.menu.abrir_pausa()
		elif depois == 126:
			nome_cap = "menu_pausa"
		elif depois == 130:
			luta.menu.tela = MenuPausa.Tela.GOLPES
		elif depois == 136:
			nome_cap = "menu_golpes"
		elif depois == 140:
			luta.menu.tela = MenuPausa.Tela.CONTROLES
		elif depois == 146:
			nome_cap = "menu_controles"
		elif depois > 150:
			get_tree().quit()
	if frame > 20000:
		get_tree().quit()
	if nome_cap != "":
		_capturar(nome_cap)


func _capturar(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(pasta.path_join(nome + ".png"))
