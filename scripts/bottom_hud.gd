extends Control
## 하단 HUD 레이아웃 (빈 슬롯 placeholder)
##   왼손: 이동·점프 터치 영역(힌트) / 가운데: 소모품 4칸(정사각형)
##   오른손: 스킬 4(작은 원) + 동료 호출 1(큰 원, 우측 하단)
##
## ※ 지금은 "자리"만 그린다. 실제 기능(소모품·스킬·동료)은 해당 시스템이 생기면 연결.

const MARGIN: float = 40.0

# 가운데 — 소모품(정사각형) 4칸
const CONSUMABLE_COUNT: int = 4
const SQ: float = 80.0
const SQ_GAP: float = 16.0

# 오른손 — 스킬/동료(원)
const R_BIG: float = 64.0     # 동료 호출(큰 원)
const R_SMALL: float = 40.0   # 스킬(작은 원) 4개
const ARC_GAP: float = 14.0   # 큰 원과 작은 원 사이 여백

# 왼손 — 이동/점프 터치 영역(힌트)
const LEFT_W: float = 360.0
const LEFT_H: float = 200.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # 그림만 — 입력은 막지 않음
	resized.connect(queue_redraw)
	get_viewport().size_changed.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var font := get_theme_default_font()

	# --- 왼손: 이동/점프 터치 영역 힌트 ---
	var lz := Rect2(MARGIN, h - MARGIN - LEFT_H, LEFT_W, LEFT_H)
	draw_rect(lz, Color(1, 1, 1, 0.06), true)
	draw_rect(lz, Color(1, 1, 1, 0.18), false, 2.0)
	_caption(font, 18, "←→ 드래그 = 이동   /   탭 = 점프", lz.get_center())

	# --- 가운데: 소모품 4칸(정사각형) ---
	var total_w := CONSUMABLE_COUNT * SQ + (CONSUMABLE_COUNT - 1) * SQ_GAP
	var start_x := w * 0.5 - total_w * 0.5
	var sy := h - MARGIN - SQ
	for i in CONSUMABLE_COUNT:
		var x := start_x + i * (SQ + SQ_GAP)
		_slot_rect(Rect2(x, sy, SQ, SQ))
	_caption(font, 18, "소모품", Vector2(w * 0.5, sy - 16.0))

	# --- 오른손: 동료(큰 원) + 스킬 4(작은 원) ---
	var big := Vector2(w - MARGIN - R_BIG, h - MARGIN - R_BIG)
	_slot_circle(big, R_BIG)
	_caption(font, 16, "동료", big)

	var d := R_BIG + R_SMALL + ARC_GAP
	var angles := [90.0, 120.0, 150.0, 180.0]  # 정상단 → 사이 2 → 정좌측
	for k in angles.size():
		var a := deg_to_rad(angles[k])
		var c := big + Vector2(d * cos(a), -d * sin(a))
		_slot_circle(c, R_SMALL)
		_caption(font, 16, str(k + 1), c)


func _slot_rect(r: Rect2) -> void:
	draw_rect(r, Color(0, 0, 0, 0.38), true)
	draw_rect(r, Color(1, 1, 1, 0.7), false, 3.0)


func _slot_circle(c: Vector2, r: float) -> void:
	draw_circle(c, r, Color(0, 0, 0, 0.38))
	draw_arc(c, r, 0.0, TAU, 48, Color(1, 1, 1, 0.7), 3.0, true)


func _caption(font: Font, fs: int, text: String, center: Vector2) -> void:
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, center + Vector2(-tw * 0.5, fs * 0.35), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.9))
