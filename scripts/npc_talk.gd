extends Control
## NPC 대화 화면(미연시/비주얼노벨) 베이스 ─ 카툰 톤(design.md): 크림 대화창 + 잉크 외곽선 + 빨강/크림.
##   서브클래스가 _start() 오버라이드로 흐름을 짠다. (pearl.gd / maxtalk.gd)
##   API: portrait(색,표정) / say(이름,색,대사) / choices([[라벨,Callable]...]) / go(씬경로)

const BG := preload("res://assets/backgrounds/stage1_wall.jpg")
const FIG := preload("res://scripts/npc_figure.gd")

var _figure: Control
var _name_lbl: Label
var _text_lbl: Label
var _choice_box: VBoxContainer


func _ready() -> void:
	_build()
	_start()


func _start() -> void:
	pass


func _build() -> void:
	var vp := get_viewport().get_visible_rect().size

	var bg := TextureRect.new()
	bg.texture = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.modulate = Color(0.5, 0.46, 0.42)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_figure = FIG.new()
	_figure.size = Vector2(vp.x * 0.5, vp.y * 0.6)
	_figure.position = Vector2(vp.x * 0.5 - _figure.size.x * 0.5, 8)
	_figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_figure)

	# 하단 대화창 ─ 크림 패널 + 잉크 외곽선
	var panel := Panel.new()
	panel.position = Vector2(24, vp.y - 264)
	panel.size = Vector2(vp.x - 48, 248)
	panel.add_theme_stylebox_override("panel", Design.panel_box())
	add_child(panel)

	# 이름 띠 (잉크 박스 + 크림 역상) ─ 레퍼런스 "제목 검정 박스"
	var band := Panel.new()
	band.position = Vector2(24, -22)
	band.size = Vector2(300, 52)
	band.add_theme_stylebox_override("panel", Design.card_box(Design.INK, 3, 10))
	panel.add_child(band)
	_name_lbl = Design.label("", "title", Design.INK_CREAM)
	_name_lbl.position = Vector2(18, 6)
	band.add_child(_name_lbl)

	_text_lbl = Design.label("", "body", Design.INK)
	_text_lbl.position = Vector2(32, 52)
	_text_lbl.size = Vector2(panel.size.x * 0.54, 170)
	_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_text_lbl)

	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 8)
	_choice_box.position = Vector2(panel.size.x * 0.58, 24)
	_choice_box.size = Vector2(panel.size.x * 0.40, panel.size.y - 40)
	panel.add_child(_choice_box)


func portrait(col: Color, mood: String) -> void:
	if _figure:
		_figure.set_fig(col, mood)


func say(speaker: String, col: Color, text: String) -> void:
	_name_lbl.text = speaker
	_text_lbl.text = text


## items: Array of [label:String, fn:Callable]
func choices(items: Array) -> void:
	for c in _choice_box.get_children():
		c.queue_free()
	for it in items:
		# 첫 항목 강조(cheese), 나머지 크림
		var kind := "cheese" if _choice_box.get_child_count() == 0 else "paper"
		var b := Design.button(String(it[0]), kind, Design.FS_BODY)
		b.custom_minimum_size = Vector2(0, 58)
		b.pressed.connect(it[1])
		_choice_box.add_child(b)


func go(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)
