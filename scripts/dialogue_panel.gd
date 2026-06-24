class_name DialoguePanel
extends RefCounted
## 공용 NPC 대화창 - "인게임 이벤트 펑거스 대화창" 스타일(크림 패널 + 잉크 외곽 + 초상화 + 이름띠 + 본문).
##   게임 내 모든 대화(펑거스 이벤트 / 펄·맥스 컷씬 등)가 동일하게 쓰도록 한 곳에서 빌드 → 통일.
##   build()가 parent에 하단 박스를 붙이고 노드 참조 dict 반환. 타이핑/탭/보이스는 호출부가 담당.

const FONT := preload("res://assets/fonts/SBAggro-Medium.ttf")
const FONT_DIALOGUE := preload("res://assets/fonts/SBAggro-Medium.ttf")   # 대사 본문 = 서울알림체 Bold(700) (= FONT와 동일, 본문 통일)
const INK := Color("241F1B")
const PAPER := Color("F3E3BE")
const PAPER_DEEP := Color("E4CB95")
const CHEESE_DEEP := Color("D4912A")
const BOX_H := 272.0   # 36px 본문 3줄 + 세로 가운데 여유(쿠키런식 큰 글씨 대응)
## 커스텀 대화창 프레임 이미지(빈티지 테두리). 박스 크기로 늘려 깔고, 본문은 그 위에.
const FRAME := preload("res://assets/ui/ui_dialogue.png")


static func _sb(bg: Color, radius: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(4)
	s.border_color = INK
	s.set_corner_radius_all(radius)
	s.content_margin_left = 18.0
	s.content_margin_right = 18.0
	s.content_margin_top = 10.0
	s.content_margin_bottom = 10.0
	return s


static func _mk_label(fsize: int, col: Color, pos: Vector2) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## 단색 초상화 플레이스홀더(스프라이트 없는 NPC용) - 그 색으로 채운 텍스처.
static func solid_portrait(col: Color) -> ImageTexture:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(col)
	return ImageTexture.create_from_image(img)


## parent(CanvasLayer/Control)에 하단 대화 박스 빌드 → {box, face, name_lbl, text_lbl, hint_lbl, choices}.
##   portrait=초상화 텍스처(null이면 초상화 칸 없이 본문이 왼쪽부터).
static func build(parent: Node, vp: Vector2, portrait: Texture2D = null) -> Dictionary:
	var box := Control.new()
	box.position = Vector2(24, vp.y - BOX_H - 24)
	box.size = Vector2(vp.x - 48, BOX_H)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	# 커스텀 프레임 이미지(배경) - 나인패치: 코너 장식은 고정, 가운데 양피지만 늘어남(화면비 무관 왜곡 0).
	var frame := NinePatchRect.new()
	frame.texture = FRAME
	frame.patch_margin_left = 150     # 코너 플로리시 크기(텍스처 px). 측정값.
	frame.patch_margin_right = 150
	frame.patch_margin_top = 100
	frame.patch_margin_bottom = 100
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(frame)

	var face: TextureRect = null
	var tx := 32.0
	if portrait != null:
		var port_sz := BOX_H - 32.0
		var port := Panel.new()
		port.add_theme_stylebox_override("panel", _sb(PAPER_DEEP, 8))
		port.position = Vector2(16, 16)
		port.size = Vector2(port_sz, port_sz)
		port.clip_contents = true
		port.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(port)
		face = TextureRect.new()
		face.texture = portrait
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.set_anchors_preset(Control.PRESET_FULL_RECT)
		face.offset_left = 8; face.offset_top = 8; face.offset_right = -8; face.offset_bottom = -8
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		port.add_child(face)
		tx = 16.0 + port_sz + 24.0

	# 이름 = 크림 상단(테두리선 ~24px 아래). 본문과 한 묶음으로 위쪽 헤더.
	var name_lbl := _mk_label(30, CHEESE_DEEP, Vector2(tx, 34))
	box.add_child(name_lbl)
	# 본문 칸 = 이름 아래(72) ~ 하단 테두리 위 사이 body. 그 안에서 세로 가운데.
	var text_top := 72.0
	var text_h := BOX_H - text_top - 36.0
	var text_lbl := _mk_label(36, INK, Vector2(tx, text_top))   # 본문 36(쿠키런급 큰 글씨)
	text_lbl.add_theme_font_override("font", FONT_DIALOGUE)     # 대사 본문 = 서울알림체 Bold(700)
	text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER     # body 정중앙(1~3줄)
	text_lbl.size = Vector2(minf(box.size.x - tx - 24.0, 880.0), text_h)   # 폭 최대 880(한 줄 글자수↓)
	box.add_child(text_lbl)
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 16)
	choices.position = Vector2(tx, 170)
	choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(choices)
	# 힌트 = 우하단. 코너 플로리시(NinePatch 코너 150px)·하단 테두리선 피해 안쪽으로 우측정렬.
	var hint_txt := "▶ 탭하여 계속"
	var hint_w: float = FONT.get_string_size(hint_txt, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18).x
	var hint := _mk_label(18, CHEESE_DEEP, Vector2(box.size.x - 162.0 - hint_w, BOX_H - 46.0))
	hint.text = hint_txt
	box.add_child(hint)
	return {"box": box, "face": face, "name_lbl": name_lbl, "text_lbl": text_lbl, "hint_lbl": hint, "choices": choices}
