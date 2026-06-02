extends Node
## Style (오토로드) — design.md UI 디자인 시스템의 단일 토큰/헬퍼 소스.
## 색·폰트크기·버튼·라벨·패널을 여기서만 정의. 화면들은 이 함수만 호출(직접 색 입력 금지).
## 톤: 고전 카툰 — 두꺼운 잉크 외곽선 + 단색 면 + 단색(블러0) 오프셋 그림자 + 8px 그리드.

const FONT := preload("res://assets/fonts/Pretendard-Regular.ttf")

# --- 컬러 토큰 (design.md §1) ---
const INK := Color("241f1b")          # 외곽선·본문 (따뜻한 먹색)
const PAPER := Color("f3e3be")        # 크림 바탕(패널·카드)
const PAPER_DEEP := Color("e4cb95")   # 진한 크림(음영·비활성)
const CANVAS := Color("2a211c")       # 최하단 배경(어두운 우드)
const CHEESE := Color("f2b33d")       # ★메인 골든(치즈·강조·동전·별)
const CHEESE_DEEP := Color("d4912a")
const RED := Color("d6402e")          # ★CTA·HP·위험
const RED_DEEP := Color("a82b1e")
const INK_CREAM := Color("f3e3be")    # 잉크/빨강 위 역상 글자
const TEAL := Color("2e8b8b")
const BLUE := Color("3e6fb0")
const GREEN := Color("5e8c4e")
const PINK := Color("e8729c")
const RANK := [Color("9a8c7a"), Color("5e8c4e"), Color("3e6fb0"), Color("8a5ba6"), Color("f2b33d")]

# --- 타입 스케일 (design.md §2.1, 1560×720 좌표 px) ---
const FS_DISPLAY_L := 64
const FS_DISPLAY_S := 48
const FS_TITLE := 32
const FS_BODY := 22
const FS_CAPTION := 18
const FS_NUM := 30

# 글자 외곽선 두께 (design.md §2.2 위계표)
const OUTLINE := {"display": 8, "display_s": 5, "title": 3, "body": 0, "caption": 0, "num": 3}
const FS := {"display": FS_DISPLAY_L, "display_s": FS_DISPLAY_S, "title": FS_TITLE, "body": FS_BODY, "caption": FS_CAPTION, "num": FS_NUM}


## 라벨 생성 — kind: display/display_s/title/body/caption/num
func label(text: String, kind: String = "body", color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	apply_label(l, kind, color)
	return l

func apply_label(l: Label, kind: String = "body", color: Color = INK) -> void:
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", int(FS.get(kind, FS_BODY)))
	l.add_theme_color_override("font_color", color)
	var ow: int = int(OUTLINE.get(kind, 0))
	if ow > 0:
		l.add_theme_color_override("font_outline_color", INK)
		l.add_theme_constant_override("outline_size", ow)


## 버튼 스타일박스 — 잉크 외곽선 + 단색 오프셋 그림자(블러0). 카툰 입체.
func _btn_box(bg: Color, border := 4, radius := 18, shadow := true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border)
	sb.border_color = INK
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	if shadow:
		sb.shadow_color = INK         # 단색
		sb.shadow_size = 0            # 블러 없음
		sb.shadow_offset = Vector2(0, 6)   # 아래 한 방향
	return sb

## 눌림 박스 — 그림자 빠지고 글자가 그림자 자리로 쑥(쑥 들어가는 카툰 누름)
func _btn_box_pressed(bg: Color, border := 4, radius := 18) -> StyleBoxFlat:
	var sb := _btn_box(bg.darkened(0.08), border, radius, false)
	sb.content_margin_top = 18.0
	sb.content_margin_bottom = 6.0
	return sb


## 버튼에 스타일 적용 — kind: cta(빨강)/paper(크림)/cheese(골든)/ghost(테두리만)/dark
func style_button(b: Button, kind: String = "paper", fs: int = FS_TITLE) -> void:
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", fs)
	var bg: Color
	var fg: Color
	match kind:
		"cta":    bg = RED;        fg = INK_CREAM
		"cheese": bg = CHEESE;     fg = INK
		"paper":  bg = PAPER;      fg = INK
		"dark":   bg = Color("3a3330"); fg = INK_CREAM
		"ghost":  bg = Color(0, 0, 0, 0); fg = INK
		_:        bg = PAPER;      fg = INK
	for st in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(st, _btn_box(bg, 4, 18, kind != "ghost"))
	b.add_theme_stylebox_override("hover", _btn_box(bg.lightened(0.06), 4, 18, kind != "ghost"))
	b.add_theme_stylebox_override("pressed", _btn_box_pressed(bg, 4, 18))
	b.add_theme_stylebox_override("disabled", _btn_box(PAPER_DEEP, 4, 18, false))
	for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(cn, fg)
	b.add_theme_color_override("font_disabled_color", INK.lerp(PAPER_DEEP, 0.5))

func button(text: String, kind: String = "paper", fs: int = FS_TITLE) -> Button:
	var b := Button.new()
	b.text = text
	style_button(b, kind, fs)
	return b


## 패널 스타일박스 — 크림 + 잉크 외곽선 + 단색 그림자
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

## 칸/카드 스타일박스 (얇은 잉크 테두리)
func card_box(bg: Color = PAPER, border := 3, radius := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border)
	sb.border_color = INK
	return sb
