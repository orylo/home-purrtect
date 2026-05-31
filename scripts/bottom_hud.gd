extends Control
## 하단 HUD 레이아웃 (빈 슬롯 placeholder)
##   소모품 3칸(오른쪽 엄지 존 근처, 바닥 쪽) / 스킬 4(원) / 동료 1(코너 1/4 원)
##   (왼손 이동/점프는 가상 조이스틱 — joystick.gd)
##
## ※ 지금은 "자리"만 그린다. 실제 기능은 소모품·스킬·동료 시스템이 생기면 연결.

# 소모품(정사각형) 3칸 — 오른쪽 엄지 존 근처, 바닥 쪽
const CONSUMABLE_COUNT: int = 3
const SQ: float = 76.0
const SQ_GAP: float = 18.0
const CONSUMABLE_CENTER_RATIO: float = 0.66   # 가로 위치(화면 너비 비율)
const CONSUMABLE_BOTTOM_MARGIN: float = 38.0

# 동료 — 우하단 코너 1/4 원
const PIE_RADIUS: float = 160.0

# 스킬 — 원 4개(부채꼴)
const SKILL_R: float = 34.0
const SKILL_RING: float = 142.0        # 호 반경
const SKILL_CENTER_X_OFF: float = 80.0 # 오른쪽 끝에서 호 중심까지
const SKILL_CENTER_Y_OFF: float = 50.0 # 아래 끝에서 호 중심까지


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

	# --- 소모품 3칸 (오른쪽 엄지 존 근처, 바닥 쪽) ---
	var total_w := CONSUMABLE_COUNT * SQ + (CONSUMABLE_COUNT - 1) * SQ_GAP
	var start_x := w * CONSUMABLE_CENTER_RATIO - total_w * 0.5
	var sy := h - SQ - CONSUMABLE_BOTTOM_MARGIN
	for i in CONSUMABLE_COUNT:
		_slot_rect(Rect2(start_x + i * (SQ + SQ_GAP), sy, SQ, SQ))
	_caption(font, 18, "소모품", Vector2(start_x + total_w * 0.5, sy - 14.0))

	# --- 동료: 우하단 코너 1/4 원 ---
	var corner := Vector2(w, h)
	_slot_quarter(corner, PIE_RADIUS)
	_caption(font, 15, "동료", corner + Vector2(-PIE_RADIUS * 0.5, -PIE_RADIUS * 0.42))

	# --- 스킬 4개: 호(정상단 → 사이 2 → 정좌측) ---
	var p := Vector2(w - SKILL_CENTER_X_OFF, h - SKILL_CENTER_Y_OFF)
	var angles := [270.0, 240.0, 210.0, 180.0]
	for k in angles.size():
		var a := deg_to_rad(angles[k])
		var c := p + Vector2(SKILL_RING * cos(a), SKILL_RING * sin(a))
		_slot_circle(c, SKILL_R)
		_caption(font, 15, str(k + 1), c)


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
	draw_colored_polygon(pts, Color(0, 0, 0, 0.38))
	draw_arc(corner, r, deg_to_rad(180.0), deg_to_rad(270.0), 40, Color(1, 1, 1, 0.7), 3.0)
	draw_line(corner, corner + Vector2(-r, 0.0), Color(1, 1, 1, 0.7), 3.0)
	draw_line(corner, corner + Vector2(0.0, -r), Color(1, 1, 1, 0.7), 3.0)


func _caption(font: Font, fs: int, text: String, center: Vector2) -> void:
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, center + Vector2(-tw * 0.5, fs * 0.35), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.9))
