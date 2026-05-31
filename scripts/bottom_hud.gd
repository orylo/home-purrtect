extends Control
## 하단 HUD 레이아웃
##   공격: 우하단 코너 1/4 원 (실제 작동 — 입력은 attack_button.gd)
##   동료: 공격 왼쪽의 원 / 스킬1~4: 동료 위로 부채꼴 원 / 아이템1~3: 왼쪽 정사각형
##   (왼손 이동/점프는 가상 조이스틱 — joystick.gd)
##
## ※ 공격만 실제 동작. 동료·스킬·아이템은 자리(placeholder) — 해당 시스템 생기면 연결.

# 아이템(소모품) 3칸
const ITEM_COUNT: int = 3
const SQ: float = 76.0
const SQ_GAP: float = 18.0
const ITEM_CENTER_RATIO: float = 0.62   # 가로 위치(화면 너비 비율)
const ITEM_BOTTOM_MARGIN: float = 34.0

# 동료(원) — 아이템과 공격·스킬 무리 사이의 독립 버튼
const COMP_R: float = 50.0
const COMP_CENTER_RATIO: float = 0.78   # 가로 위치(화면 너비 비율)
const COMP_BOTTOM_MARGIN: float = 30.0

# 스킬(원) 4개 — 공격(코너)을 둘러싸는 부채꼴
const SKILL_R: float = 32.0
const SKILL_RING: float = 189.0         # 코너에서 스킬 원 중심까지(공격 1/4원 바깥)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	get_viewport().size_changed.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var band_top := Layout.band_top()
	var font := get_theme_default_font()

	# --- 조작 띠 배경: 50% 블랙 딤 (+ 윗변 얇은 라인) ---
	draw_rect(Rect2(0.0, band_top, w, h - band_top), Color(0, 0, 0, 0.5), true)
	draw_line(Vector2(0.0, band_top), Vector2(w, band_top), Color(1, 1, 1, 0.18), 2.0)

	# --- 공격: 우하단 코너 1/4 원 ---
	var corner := Vector2(w, h)
	var atk_r := Layout.ATTACK_BUTTON_RADIUS
	_slot_quarter(corner, atk_r)
	_caption(font, 22, "공격", corner + Vector2(-atk_r * 0.5, -atk_r * 0.42))

	# --- 스킬 1~4: 공격(코너)을 둘러싸는 부채꼴 (스킬1 좌하 → 스킬4 상단) ---
	var angles := [192.0, 214.0, 236.0, 258.0]
	for k in angles.size():
		var a := deg_to_rad(angles[k])
		var c := corner + Vector2(SKILL_RING * cos(a), SKILL_RING * sin(a))
		_slot_circle(c, SKILL_R)
		_caption(font, 13, "스킬" + str(k + 1), c)

	# --- 동료: 아이템 슬롯과 공격·스킬 무리 사이의 독립 버튼 ---
	var comp := Vector2(w * COMP_CENTER_RATIO, h - COMP_BOTTOM_MARGIN - COMP_R)
	_slot_circle(comp, COMP_R)
	_caption(font, 16, "동료", comp)

	# --- 아이템 1~3: 왼쪽 정사각형 ---
	var total_w := ITEM_COUNT * SQ + (ITEM_COUNT - 1) * SQ_GAP
	var start_x := w * ITEM_CENTER_RATIO - total_w * 0.5
	var sy := h - SQ - ITEM_BOTTOM_MARGIN
	for i in ITEM_COUNT:
		var r := Rect2(start_x + i * (SQ + SQ_GAP), sy, SQ, SQ)
		_slot_rect(r)
		_caption(font, 14, "아이템" + str(i + 1), r.get_center())


func _slot_rect(r: Rect2) -> void:
	draw_rect(r, Color(0, 0, 0, 0.38), true)
	draw_rect(r, Color(1, 1, 1, 0.7), false, 3.0)


func _slot_circle(c: Vector2, r: float) -> void:
	draw_circle(c, r, Color(0, 0, 0, 0.38))
	draw_arc(c, r, 0.0, TAU, 48, Color(1, 1, 1, 0.7), 3.0, true)


## 코너에 붙는 1/4 원(부채꼴) — corner는 화면 우하단 꼭짓점
func _slot_quarter(corner: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	pts.append(corner)
	var steps := 28
	for i in range(steps + 1):
		var a := deg_to_rad(180.0 + 90.0 * float(i) / float(steps))  # 좌 → 상
		pts.append(corner + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, Color(0.1, 0.25, 0.6, 0.55))
	draw_arc(corner, r, deg_to_rad(180.0), deg_to_rad(270.0), 40, Color(1, 1, 1, 0.85), 3.0)
	draw_line(corner, corner + Vector2(-r, 0.0), Color(1, 1, 1, 0.85), 3.0)
	draw_line(corner, corner + Vector2(0.0, -r), Color(1, 1, 1, 0.85), 3.0)


func _caption(font: Font, fs: int, text: String, center: Vector2) -> void:
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, center + Vector2(-tw * 0.5, fs * 0.35), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.92))
