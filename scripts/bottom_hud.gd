extends Control
## 하단 HUD 레이아웃 (빈 슬롯 placeholder)
##   가운데: 소모품 4칸(정사각형) / 오른손: 스킬 4(작은 원) + 동료 호출 1(큰 원)
##   (왼손 이동/점프는 가상 조이스틱이 따로 담당 — joystick.gd)
##
## 버튼들은 "조작 띠"(바닥선 아래 영역)의 세로 중앙에 정렬해 위아래 여백을 고르게 둔다.
## ※ 지금은 "자리"만 그린다. 실제 기능은 소모품·스킬·동료 시스템이 생기면 연결.

const SIDE_MARGIN: float = 50.0   # 좌우 가장자리 여백

# 가운데 — 소모품(정사각형) 4칸
const CONSUMABLE_COUNT: int = 4
const SQ: float = 72.0
const SQ_GAP: float = 16.0

# 오른손 — 스킬/동료(원)
const R_BIG: float = 50.0     # 동료 호출(큰 원)
const R_SMALL: float = 26.0   # 스킬(작은 원) 4개
const RING_D: float = 112.0   # 큰 원 중심에서 작은 원 중심까지 거리


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # 그림만 — 입력은 막지 않음
	resized.connect(queue_redraw)
	get_viewport().size_changed.connect(queue_redraw)


func _draw() -> void:
	var w := size.x
	var h := size.y
	var band_top := Layout.ground_y()       # 조작 띠 = 바닥선 ~ 화면 아래
	var band_cy := (band_top + h) * 0.5      # 띠의 세로 중앙
	var font := get_theme_default_font()

	# --- 가운데: 소모품 4칸(정사각형) — 띠 세로 중앙 ---
	var total_w := CONSUMABLE_COUNT * SQ + (CONSUMABLE_COUNT - 1) * SQ_GAP
	var start_x := w * 0.5 - total_w * 0.5
	var sy := band_cy - SQ * 0.5
	for i in CONSUMABLE_COUNT:
		var x := start_x + i * (SQ + SQ_GAP)
		_slot_rect(Rect2(x, sy, SQ, SQ))
	_caption(font, 18, "소모품", Vector2(w * 0.5, sy - 14.0))

	# --- 오른손: 동료(큰 원) + 스킬 4(작은 원) — 클러스터를 띠 세로 중앙에 ---
	var big_y := band_cy + (RING_D + R_SMALL - R_BIG) * 0.5
	var big := Vector2(w - SIDE_MARGIN - R_BIG, big_y)
	_slot_circle(big, R_BIG)
	_caption(font, 15, "동료", big)

	var angles := [90.0, 120.0, 150.0, 180.0]  # 정상단 → 사이 2 → 정좌측
	for k in angles.size():
		var a := deg_to_rad(angles[k])
		var c := big + Vector2(RING_D * cos(a), -RING_D * sin(a))
		_slot_circle(c, R_SMALL)
		_caption(font, 14, str(k + 1), c)


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
