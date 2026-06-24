extends Node
## Design (오토로드) - design.md UI 디자인 시스템의 단일 토큰/헬퍼 소스(SSOT).
## 색·폰트크기·간격·버튼·라벨·패널을 여기서만 정의. 화면들은 이 함수/상수만 호출(직접 색·매직넘버 금지).
## 톤: 고전 카툰 - 두꺼운 잉크 외곽선 + 단색 면 + 단색(블러0) 오프셋 그림자 + 베벨 입체 + 물건화 패널 + 8px 그리드.
## 버튼=Design.style_button(b, kind) / 패널=Design.make_panel(panel, ...).

const FONT := preload("res://assets/fonts/SBAggro-Medium.ttf")        # 본문·숫자·캡션 = 서울알림체 Bold(700)
const FONT_TITLE := preload("res://assets/fonts/SBAggro-Bold.ttf")  # 타이틀·버튼 = 서울알림체 Heavy(900)
const TITLE_KINDS := ["display", "display_s", "title"]

# --- 컬러 토큰 (design.md §1) ---
const INK := Color("241f1b")          # 외곽선·본문 (따뜻한 먹색)
const PAPER := Color("f3e3be")        # 크림 바탕(패널·카드)
const PAPER_DEEP := Color("e4cb95")   # 진한 크림(음영·비활성·칸구분)
const CANVAS := Color("2a211c")       # 최하단 배경(어두운 우드)
const CHEESE := Color("f2b33d")       # ★메인 골든(치즈·긍정CTA·동전·별·Lv5)
const CHEESE_DEEP := Color("d4912a")
const RED := Color("d6402e")          # ★전투CTA·HP·위험
const RED_DEEP := Color("a82b1e")
const INK_CREAM := Color("f3e3be")    # 잉크/빨강 위 역상 글자
const TEAL := Color("2e8b8b")
const BLUE := Color("3e6fb0")
const GREEN := Color("5e8c4e")
const PINK := Color("e8729c")
# 등급색 - 인덱스 1~5 ([0]=INK, 미사용/대체) (design.md §1)
const RANK := [INK, Color("9a8c7a"), Color("5e8c4e"), Color("3e6fb0"), Color("8a5ba6"), Color("f2b33d")]

# --- 간격 토큰 (design.md §3.5, 8px 그리드) ---
const GAP_XS := 8
const GAP := 16
const GAP_LG := 24
const GAP_XL := 32
const EDGE := 24

# --- 크기 토큰 (design.md §3.5, 720 좌표 px) ---
const BAR_H := 52          # 버튼·재화캡슐·탭 공통 높이
const BTN_MIN_H := 60      # 터치 최소
const TILE := 104          # 보상/인벤 정사각 타일
const CARD_H := 88         # 목록 카드 행
const ICON_IN_BAR := 36    # 캡슐 내 아이콘
const RADIUS_CARD := 20    # 사각(카드/타일/패널)
const OUTLINE_W := 4       # 잉크 외곽선 기본 두께
const SHADOW_OFF := 6      # 단색 잉크 그림자 offset(블러 0)

# --- 타입 스케일 (design.md §2.1, 1560×720 좌표 px) ---
const FS_DISPLAY_L := 64
const FS_DISPLAY_S := 48
const FS_TITLE := 32
const FS_BODY := 22
const FS_CAPTION := 18
const FS_NUM := 30

# 글자 외곽선 두께 (design.md §2.2 위계표) - STROKE는 갱신본 명칭, OUTLINE은 하위호환 별칭
const STROKE := {"display": 12, "display_s": 8, "title": 5, "body": 2, "caption": 0, "num": 5}
const OUTLINE := {"display": 12, "display_s": 8, "title": 5, "body": 0, "caption": 0, "num": 5}
const FS := {"display": FS_DISPLAY_L, "display_s": FS_DISPLAY_S, "title": FS_TITLE, "body": FS_BODY, "caption": FS_CAPTION, "num": FS_NUM}

# --- 모션 토큰 (design.md §5, 지속 초) ---
const MOTION := {
	"btn_in": 0.18, "btn_press": 0.07, "panel_in": 0.22, "panel_out": 0.15,
	"count": 0.40, "dmg_pop": 0.50, "iris": 0.35, "bob": 1.6, "rare_pop": 0.30,
}


## 라벨 생성 - kind: display/display_s/title/body/caption/num
func label(text: String, kind: String = "body", color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	apply_label(l, kind, color)
	return l

func apply_label(l: Label, kind: String = "body", color: Color = INK) -> void:
	l.add_theme_font_override("font", FONT_TITLE if kind in TITLE_KINDS else FONT)
	l.add_theme_font_size_override("font_size", int(FS.get(kind, FS_BODY)))
	l.add_theme_color_override("font_color", color)
	var ow: int = int(OUTLINE.get(kind, 0))
	if ow > 0:
		l.add_theme_color_override("font_outline_color", INK)
		l.add_theme_constant_override("outline_size", ow)


# ----------------------------------------------------------
#  버튼 - 베벨 입체 (design.md §0-8 / §3 버튼 시스템)
# ----------------------------------------------------------

# 4색 알약 버튼 텍스처(나노바나나 에셋). 베벨·외곽선·질감이 그림에 구워져 있음. 색=의미(§1).
const TEX_PILL := {
	"gold": preload("res://assets/ui/buttons/pill2_gold.png"),
	"red": preload("res://assets/ui/buttons/pill2_red.png"),
	"cream": preload("res://assets/ui/buttons/pill2_cream.png"),
	"blue": preload("res://assets/ui/buttons/pill2_blue.png"),
	"gray": preload("res://assets/ui/buttons/pill2_gray.png"),
}

# 빈티지 명판 버튼(좌우 리벳 캡 고정·가운데 신축, 9-slice). 좌우 캡 ≈54px.
const SIGN_TEX := {
	"red": preload("res://assets/ui/buttons/sign_red.png"),
	"cream": preload("res://assets/ui/buttons/sign_cream.png"),
	"green": preload("res://assets/ui/buttons/sign_green.png"),
}
const SIGN_CAP := 54.0   # 좌우 장식(코너+리벳) 폭 — 9-slice texture_margin


## 명판 버튼 — ★코인 명판과 같은 드로우 규칙: 세로=이미지 전체 균일 스케일,
##   가로=9-slice(좌우 리벳 캡 고정, 가운데만 가로 신축). 버튼 배경은 투명(StyleBoxEmpty)이고
##   뒤에 깔린 _SignPlate(show_behind_parent)가 텍스처를 직접 그린다. → 버튼 높이가 텍스처와 달라도 리벳 안 늘어남.
##   color: "red"/"green"=크림 글자+잉크 스트로크 / "cream"=잉크 글자(스트로크 없음).
func signboard_button(b: Button, color: String = "green", fs: int = FS_TITLE) -> void:
	var tex: Texture2D = SIGN_TEX.get(color, SIGN_TEX["green"])
	b.clip_contents = false
	# 세로중앙 보정: SB어그로 잉크가 라인박스 안에서 fs의 ~11.5%만큼 위로 앉음 → top↑/bot↓로 끌어내림.
	var vshift: float = fs * 0.115
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxEmpty.new()   # 배경은 _SignPlate가 그림 → 버튼 자체는 투명(글자만)
		sb.content_margin_left = SIGN_CAP + 12.0     # 글자가 리벳 위로 안 가게
		sb.content_margin_right = SIGN_CAP + 12.0
		sb.content_margin_top = 16.0 + vshift
		sb.content_margin_bottom = maxf(4.0, 16.0 - vshift)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_font_override("font", FONT_TITLE)
	b.add_theme_font_size_override("font_size", fs)
	var fg := INK if color == "cream" else INK_CREAM
	for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(cn, fg)
	if color != "cream":
		b.add_theme_color_override("font_outline_color", INK)
		b.add_theme_constant_override("outline_size", maxi(8, int(fs * 0.18)))   # fs 비례 두꺼운 외곽선
	# 명판 배경(텍스트 뒤). 재호출 시 텍스처만 갱신.
	var plate: Node = b.get_node_or_null("_SignPlate")
	if plate == null:
		var p := _SignPlate.new()
		p.name = "_SignPlate"
		b.add_child(p)
		plate = p
	plate.tex = tex
	plate.cap_px = SIGN_CAP
	plate.queue_redraw()
	if not b.has_meta("_sfx"):
		b.set_meta("_sfx", true)
		b.pressed.connect(func(): Sfx.play("click"))


## 명판 버튼 배경 — 버튼 뒤(show_behind_parent)에서 텍스처를 세로 균일 스케일 + 가로 9-slice로 그림.
class _SignPlate extends Control:
	var tex: Texture2D
	var cap_px := 54.0
	func _ready() -> void:
		show_behind_parent = true   # 부모(버튼) 글자 뒤에 그림
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(_d: float) -> void:
		var p := get_parent() as Control
		if p == null:
			return
		# 부모는 컨테이너가 아니라 앵커로 자식 크기를 못 맞춤 → 매 프레임 부모 크기로 직접 동기화.
		if size != p.size or position != Vector2.ZERO:
			position = Vector2.ZERO
			size = p.size
			queue_redraw()
		# 버튼이면 눌림/호버/비활성 밝기 반영(라벨 등 일반 Control은 그대로).
		var b := p as Button
		if b != null:
			var m := b.get_draw_mode()
			var c := Color.WHITE
			if m == BaseButton.DRAW_PRESSED or m == BaseButton.DRAW_HOVER_PRESSED:
				c = Color(0.9, 0.9, 0.9)
			elif m == BaseButton.DRAW_DISABLED:
				c = Color(0.75, 0.75, 0.75)
			if c != modulate:
				modulate = c
	func _draw() -> void:
		if tex == null:
			return
		var th: float = tex.get_height()
		var tw: float = tex.get_width()
		var s: float = size.y / th        # 세로 = 전체 균일 스케일
		var capw: float = cap_px * s
		var W := size.x
		var H := size.y
		draw_texture_rect_region(tex, Rect2(0, 0, capw, H), Rect2(0, 0, cap_px, th))
		draw_texture_rect_region(tex, Rect2(W - capw, 0, capw, H), Rect2(tw - cap_px, 0, cap_px, th))
		var midw: float = maxf(0.0, W - 2.0 * capw)
		draw_texture_rect_region(tex, Rect2(capw, 0, midw, H), Rect2(cap_px, 0, tw - 2.0 * cap_px, th))


## 명판 "라벨"(버튼 아님) - 게임시작 버튼과 같은 _SignPlate 방식으로 텍스트 뒤에 명판을 깐
##   Control 반환(글자수에 맞춰 자동폭). HUD 스테이지 표시 등 비버튼 명판에 사용.
func signboard_plate(text: String, color: String = "cream", fs: int = FS_TITLE, plate_h: float = 0.0) -> Control:
	var tex: Texture2D = SIGN_TEX.get(color, SIGN_TEX["cream"])
	var ph: float = plate_h if plate_h > 0.0 else float(fs) * 2.1
	var s: float = ph / float(tex.get_height())
	var capw: float = SIGN_CAP * s
	var tw: float = FONT_TITLE.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(tw + 2.0 * capw + 20.0, ph)
	holder.size = holder.custom_minimum_size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate := _SignPlate.new()
	plate.tex = tex
	plate.cap_px = SIGN_CAP
	holder.add_child(plate)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", FONT_TITLE)
	lbl.add_theme_font_size_override("font_size", fs)
	lbl.add_theme_color_override("font_color", INK if color == "cream" else INK_CREAM)
	if color != "cream":
		lbl.add_theme_color_override("font_outline_color", INK)
		lbl.add_theme_constant_override("outline_size", maxi(6, int(fs * 0.16)))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.offset_top = fs * 0.23   # SB어그로 잉크 위쏠림 보정(시각 중앙)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(lbl)
	holder.set_meta("label", lbl)   # 텍스트 갱신용
	return holder


## 명판 버튼 생성 헬퍼.
func sign_button(text: String, color: String = "green", fs: int = FS_TITLE) -> Button:
	var b := Button.new()
	b.text = text
	signboard_button(b, color, fs)
	return b

## (폴백) 코드 알약 박스 - 텍스처 못 쓰는 icon kind 등에서 사용
func _btn_box(bg: Color, shadow := true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(999)        # 알약(design.md §3.5)
	sb.set_border_width_all(OUTLINE_W)
	sb.border_color = INK
	sb.content_margin_left = float(GAP_LG)
	sb.content_margin_right = float(GAP_LG)
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	if shadow:
		sb.shadow_color = INK
		sb.shadow_size = 0
		sb.shadow_offset = Vector2(0, SHADOW_OFF)
	return sb

func _btn_box_pressed(bg: Color) -> StyleBoxFlat:
	var sb := _btn_box(bg.darkened(0.08), false)
	sb.content_margin_top = 12.0 + float(SHADOW_OFF)
	sb.content_margin_bottom = 12.0 - float(SHADOW_OFF) * 0.5
	return sb

## 알약 텍스처 9-slice 스타일박스 (좌우 끝=둥근 캡 보존, 세로=버튼 높이에 맞춰 스트레치)
func _pill_tex(key: String, modulate := Color.WHITE, ctop := 14.0, cbot := 18.0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = TEX_PILL.get(key, TEX_PILL["cream"])
	sb.texture_margin_left = 100.0     # ≈ 둥근 끝 폭 → 캡 보존, 가운데만 가로 스트레치
	sb.texture_margin_right = 100.0
	sb.texture_margin_top = 0.0         # 세로는 통째 스트레치(버튼 높이 다양 대응)
	sb.texture_margin_bottom = 0.0
	sb.content_margin_left = 40.0
	sb.content_margin_right = 40.0
	sb.content_margin_top = ctop
	sb.content_margin_bottom = cbot
	sb.modulate_color = modulate
	return sb

## kind → 알약 색 키 (브랜드=골드 / 전투=빨강 / 어두움=회 / 그 외=크림)
func _pill_key(kind: String) -> String:
	match kind:
		"brand", "cheese": return "gold"
		"primary", "cta": return "red"
		"dark": return "gray"
		_: return "cream"


## 버튼에 스타일 적용.
## kind: brand/cheese(골드=성장·획득) / primary/cta(빨강=전투·돌입)
##       secondary/paper/ghost(크림=뒤로·중립) / danger(크림+빨강글자) / dark / icon
func style_button(b: Button, kind: String = "secondary", fs: int = FS_TITLE) -> void:
	b.add_theme_font_override("font", FONT_TITLE)   # 버튼 글자 = 서울알림체 Heavy(900)
	b.add_theme_font_size_override("font_size", fs)
	b.clip_contents = false
	var fg := INK
	match kind:
		"primary", "cta", "dark": fg = INK_CREAM
		"danger": fg = RED
		_: fg = INK
	# 채움색(kind별). ※알약 텍스처(TEX_PILL)는 세로로 뚱뚱한 로젠지라 버튼에서 찌부러짐
	#   → 벡터 코드 알약 사용(어떤 크기에도 안 찌부러짐, design.md §3.5 알약).
	var bg := PAPER
	match kind:
		"brand", "cheese": bg = CHEESE
		"primary", "cta": bg = RED
		"dark": bg = Color("3a3330")
		_: bg = PAPER
	for st in ["normal", "focus"]:
		b.add_theme_stylebox_override(st, _btn_box(bg))
	b.add_theme_stylebox_override("hover", _btn_box(bg.lightened(0.06)))
	b.add_theme_stylebox_override("pressed", _btn_box_pressed(bg))
	b.add_theme_stylebox_override("disabled", _btn_box(PAPER_DEEP, false))
	for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(cn, fg)
	b.add_theme_color_override("font_disabled_color", INK.lerp(PAPER_DEEP, 0.5))
	if not b.has_meta("_sfx"):
		b.set_meta("_sfx", true)
		b.pressed.connect(func(): Sfx.play("click"))

func button(text: String, kind: String = "secondary", fs: int = FS_TITLE) -> Button:
	var b := Button.new()
	b.text = text
	style_button(b, kind, fs)
	return b


# ----------------------------------------------------------
#  패널 - 물건화 (design.md §0-7 / §3 패널)
# ----------------------------------------------------------

## 패널 스타일박스 - 크림 + 잉크 외곽선 + 단색 그림자
func panel_box(bg: Color = PAPER, border := 5, radius := 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border)
	sb.border_color = INK
	sb.shadow_color = Color(INK.r, INK.g, INK.b, 0.5)
	sb.shadow_size = 0
	sb.shadow_offset = Vector2(0, 8)
	return sb


## 툴팁 - 크림 바탕 + 얇은 본문 폰트(FONT) + 가는 잉크 테두리. 자동 줄바꿈(max_w 폭). PanelContainer라 내용맞춤.
func tooltip(text: String, max_w: float = 340.0, fs: int = 20) -> PanelContainer:
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(2)
	sb.border_color = INK
	sb.content_margin_left = 16.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	sb.shadow_color = Color(INK.r, INK.g, INK.b, 0.35)
	sb.shadow_size = 0
	sb.shadow_offset = Vector2(0, 4)
	box.add_theme_stylebox_override("panel", sb)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = sentence_breaks(text)
	lbl.add_theme_font_override("font", FONT)              # 얇은 본문 폰트(어그로체 Medium)
	lbl.add_theme_font_size_override("font_size", fs)
	lbl.add_theme_color_override("font_color", INK)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(max_w, 0.0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lbl)
	return box


## 문장 단위 줄바꿈 - 문장끝(. ! ?) 뒤 공백을 줄바꿈으로(대체로 한 줄에 한 문장, 한글 기준).
##   …(여운)는 제외해 과분할 방지. 기존 줄바꿈 유지. 긴 문장은 라벨 autowrap이 추가로 감쌈.
func sentence_breaks(text: String) -> String:
	var enders := [".", "!", "?"]
	var out := ""
	var i := 0
	var n := text.length()
	while i < n:
		var ch := text[i]
		out += ch
		i += 1
		if enders.has(ch):
			if i < n and (text[i] == " " or text[i] == "\t"):
				while i < n and (text[i] == " " or text[i] == "\t"):
					i += 1
				if i < n and text[i] != "\n":
					out += "\n"
	return out

# 빈티지 간판 패널 텍스처(나노바나나) - 장식 코너 크림 패널(불투명, 9-slice 가능)
const TEX_SIGNBOARD := preload("res://assets/ui/panels/panel_signboard.png")

## 패널 배경을 빈티지 간판 텍스처로 (9-slice). panel은 stylebox를 비우고 이 NinePatch를 맨 뒤에 깖.
## 콘텐츠는 호출부에서 테두리 두께만큼 안쪽으로 들여야 함(좌우 ~90, 상하 ~150).
func frame_signboard(p: Control) -> NinePatchRect:
	p.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var np := NinePatchRect.new()
	np.name = "_signboard"
	np.texture = TEX_SIGNBOARD
	np.mouse_filter = Control.MOUSE_FILTER_IGNORE
	np.set_anchors_preset(Control.PRESET_FULL_RECT)
	np.patch_margin_left = 90
	np.patch_margin_right = 90
	np.patch_margin_top = 150
	np.patch_margin_bottom = 150
	p.add_child(np)
	p.move_child(np, 0)
	return np


## 칸/카드 스타일박스 (얇은 잉크 테두리)
func card_box(bg: Color = PAPER, border := 3, radius := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border)
	sb.border_color = INK
	return sb


## 작은 볼트(나사머리) 도형 - 모서리 하드웨어
func bolt(diam: float = 12.0, col: Color = CHEESE_DEEP) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.custom_minimum_size = Vector2(diam, diam)
	p.size = Vector2(diam, diam)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(diam * 0.5))
	sb.set_border_width_all(2)
	sb.border_color = INK
	p.add_theme_stylebox_override("panel", sb)
	return p


## 패널을 "물건"으로 (design.md §0-7): 크림 바탕 + 잉크 외곽선 + 이중 테두리 + 모서리 볼트 4개
##  + (선택) 상단 중앙 리본 헤더. panel은 Panel 노드(또는 panel 스타일박스를 받는 Control).
##  bolt_col 기본 = 골든 음영. ribbon != "" 이면 빨간 리본 + 크림 제목(잘난체 대용 title).
func make_panel(panel: Control, with_bolts := true, ribbon := "", ribbon_color := RED) -> void:
	if panel.has_method("add_theme_stylebox_override"):
		panel.add_theme_stylebox_override("panel", panel_box())
	# 이중 테두리(안쪽 1겹 더)
	var inner := Panel.new()
	inner.name = "_frameInner"
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 6.0; inner.offset_top = 6.0; inner.offset_right = -6.0; inner.offset_bottom = -6.0
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color(0, 0, 0, 0)
	isb.draw_center = false
	isb.set_corner_radius_all(8)
	isb.set_border_width_all(2)
	isb.border_color = Color(INK.r, INK.g, INK.b, 0.45)
	inner.add_theme_stylebox_override("panel", isb)
	panel.add_child(inner)
	# 모서리 볼트 4개
	if with_bolts:
		var corners := [[0.0, 0.0, 14.0, 14.0], [1.0, 0.0, -26.0, 14.0],
						[0.0, 1.0, 14.0, -26.0], [1.0, 1.0, -26.0, -26.0]]
		for cdef in corners:
			var bt := bolt(12.0, CHEESE_DEEP)
			bt.name = "_frameBolt"
			bt.anchor_left = cdef[0]; bt.anchor_right = cdef[0]
			bt.anchor_top = cdef[1]; bt.anchor_bottom = cdef[1]
			bt.offset_left = cdef[2]; bt.offset_top = cdef[3]
			bt.offset_right = cdef[2] + 12.0; bt.offset_bottom = cdef[3] + 12.0
			panel.add_child(bt)
	# 리본 헤더(중요 패널만)
	if ribbon != "":
		var rib := Panel.new()
		rib.name = "_frameRibbon"
		rib.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rib.anchor_left = 0.5; rib.anchor_right = 0.5; rib.anchor_top = 0.0; rib.anchor_bottom = 0.0
		var rw := 280.0
		rib.offset_left = -rw * 0.5; rib.offset_right = rw * 0.5
		rib.offset_top = -22.0; rib.offset_bottom = 32.0
		var rsb := StyleBoxFlat.new()
		rsb.bg_color = ribbon_color
		rsb.set_corner_radius_all(10)
		rsb.set_border_width_all(OUTLINE_W)
		rsb.border_color = INK
		rsb.shadow_color = Color(INK.r, INK.g, INK.b, 0.5)
		rsb.shadow_size = 0
		rsb.shadow_offset = Vector2(0, 4)
		rib.add_theme_stylebox_override("panel", rsb)
		var rl := label(ribbon, "title", INK_CREAM)
		rl.set_anchors_preset(Control.PRESET_FULL_RECT)
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rib.add_child(rl)
		panel.add_child(rib)


## 작은 명판(framed plate) 한 줄 - 텍스트 한 줄 + 잉크 외곽선 + 볼트 2개(물건화 데모)
func framed_plate(text: String, kind := "caption", fill := PAPER_DEEP) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(OUTLINE_W)
	sb.border_color = INK
	sb.shadow_color = Color(INK.r, INK.g, INK.b, 0.45)
	sb.shadow_size = 0
	sb.shadow_offset = Vector2(0, 4)
	p.add_theme_stylebox_override("panel", sb)
	var l := label(text, kind, INK)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	for side in [0.0, 1.0]:
		var bt := bolt(9.0, CHEESE_DEEP)
		bt.anchor_left = side; bt.anchor_right = side
		var ox := 8.0 if side == 0.0 else -17.0
		bt.offset_left = ox; bt.offset_right = ox + 9.0
		bt.offset_top = 8.0; bt.offset_bottom = 17.0
		p.add_child(bt)
	return p
