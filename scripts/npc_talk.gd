extends Control
## NPC 대화 화면(미연시/비주얼노벨 풍) 베이스 — 캐릭터 placeholder + 하단 대화창 + 선택지.
##   서브클래스가 _start()를 오버라이드해 대화 흐름을 짠다. (pearl.gd / maxtalk.gd)
##   API: portrait(색,표정) / say(이름,색,대사) / choices([[라벨,Callable]...]) / go(씬경로)

const FONT := preload("res://assets/fonts/Pretendard-Regular.ttf")
const BG := preload("res://assets/backgrounds/stage1_wall.jpg")
const FIG := preload("res://scripts/npc_figure.gd")

var _figure: Control
var _name_lbl: Label
var _text_lbl: Label
var _choice_box: VBoxContainer


func _ready() -> void:
	_build()
	_start()


## 서브클래스에서 오버라이드
func _start() -> void:
	pass


func _build() -> void:
	var vp := get_viewport().get_visible_rect().size

	var bg := TextureRect.new()
	bg.texture = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.modulate = Color(0.45, 0.42, 0.5)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 캐릭터 placeholder (가운데 위)
	_figure = FIG.new()
	_figure.size = Vector2(vp.x * 0.5, vp.y * 0.62)
	_figure.position = Vector2(vp.x * 0.5 - _figure.size.x * 0.5, 10)
	_figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_figure)

	# 하단 대화창
	var panel := Panel.new()
	panel.position = Vector2(24, vp.y - 268)
	panel.size = Vector2(vp.x - 48, 252)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.09, 0.92)
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(3)
	sb.border_color = Color(1, 1, 1, 0.3)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	_name_lbl = _mk_label(28, Color(1, 1, 1))
	_name_lbl.position = Vector2(30, 14)
	_name_lbl.size = Vector2(panel.size.x * 0.5, 36)
	panel.add_child(_name_lbl)

	_text_lbl = _mk_label(26, Color(1, 1, 1))
	_text_lbl.position = Vector2(30, 62)
	_text_lbl.size = Vector2(panel.size.x * 0.52, 170)
	_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	panel.add_child(_text_lbl)

	# 선택지(대화창 오른쪽 절반에 세로로)
	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 10)
	_choice_box.position = Vector2(panel.size.x * 0.56, 16)
	_choice_box.size = Vector2(panel.size.x * 0.42, panel.size.y - 32)
	panel.add_child(_choice_box)


func portrait(col: Color, mood: String) -> void:
	if _figure:
		_figure.set_fig(col, mood)


func say(speaker: String, col: Color, text: String) -> void:
	_name_lbl.text = speaker
	_name_lbl.add_theme_color_override("font_color", col)
	_text_lbl.text = text


## items: Array of [label:String, fn:Callable]
func choices(items: Array) -> void:
	for c in _choice_box.get_children():
		c.queue_free()
	for it in items:
		var b := Button.new()
		b.text = String(it[0])
		b.custom_minimum_size = Vector2(0, 56)
		b.add_theme_font_override("font", FONT)
		b.add_theme_font_size_override("font_size", 24)
		b.add_theme_color_override("font_color", Color(1, 1, 1))
		b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.9882, 0.3137, 0.0)
		s.set_corner_radius_all(12)
		s.content_margin_left = 18.0
		var sh := StyleBoxFlat.new()
		sh.bg_color = Color(0.86, 0.27, 0.0)
		sh.set_corner_radius_all(12)
		sh.content_margin_left = 18.0
		b.add_theme_stylebox_override("normal", s)
		b.add_theme_stylebox_override("hover", sh)
		b.add_theme_stylebox_override("pressed", sh)
		b.add_theme_stylebox_override("focus", s)
		b.pressed.connect(it[1])
		_choice_box.add_child(b)


func go(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)


func _mk_label(fs: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("outline_size", 4)
	return l
