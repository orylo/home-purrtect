extends Control
const UI_FONT := preload("res://assets/fonts/DoHyeon-Regular.ttf")
## 하단 HUD 레이아웃
##   공격: 우하단 코너 1/4 원 (실제 작동 — 입력은 attack_button.gd / 키보드 L)
##   스킬1~4: 공격을 둘러싸는 원 (키 U I O P) / 동료: 독립 버튼 / 아이템1~3: 정사각형 (키 1 2 3)
##   (왼손 이동/점프는 가상 조이스틱 — joystick.gd)
##
## 버튼을 누르면(터치/키보드) 해당 버튼이 반짝인다. 실제 기능은 해당 시스템 생기면 연결.

# 아이템(소모품) 3칸
const ITEM_COUNT: int = 3
const SQ: float = 76.0
const SQ_GAP: float = 18.0
const ITEM_CENTER_RATIO: float = 0.62

# 동료(원) — 아이템과 공격·스킬 무리 사이의 독립 버튼
const COMP_R: float = 50.0
const COMP_CENTER_RATIO: float = 0.78

# 스킬(원) 4개 — 공격(코너)을 둘러싸는 부채꼴
const SKILL_R: float = 32.0
const SKILL_RING: float = 189.0

const FILL_NORMAL := Color(0, 0, 0, 0.38)
const FILL_ACTIVE := Color(0.25, 0.55, 1, 0.7)
const LINE_NORMAL := Color(1, 1, 1, 0.7)
const LINE_ACTIVE := Color(1, 1, 1, 0.98)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	get_viewport().size_changed.connect(queue_redraw)


func _process(_delta: float) -> void:
	queue_redraw()   # 버튼 눌림(반짝) 상태를 매 프레임 반영


func _draw() -> void:
	var w := size.x
	var h := size.y
	var m := Layout.CONTROL_EDGE_MARGIN   # 가장자리 공통 마진
	var font := UI_FONT

	# (조작 띠 블랙 딤 제거 — 배경이 그대로 보이게)

	# --- 공격: 코너에서 아래/오른쪽 마진만큼 띄운 1/4 원 ---
	var corner := Vector2(w - m, h - m)
	var atk_r := Layout.ATTACK_BUTTON_RADIUS
	var atk_active := Touch.attack_held or Input.is_action_pressed("attack")
	_slot_quarter(corner, atk_r, atk_active)
	_caption(font, 22, "공격", corner + Vector2(-atk_r * 0.5, -atk_r * 0.42))
	_caption(font, 26, "L", corner + Vector2(-atk_r * 0.5, -atk_r * 0.42 + 30.0))   # 키보드 힌트

	# --- 스킬 1~4: 공격을 둘러싸는 부채꼴 ---
	var angles := [192.0, 214.0, 236.0, 258.0]
	for k in angles.size():
		var a := deg_to_rad(angles[k])
		var c := corner + Vector2(SKILL_RING * cos(a), SKILL_RING * sin(a))
		_slot_circle(c, SKILL_R, Input.is_action_pressed("skill_%d" % (k + 1)))
		_caption(font, 13, "스킬" + str(k + 1), c)

	# --- 동료: 독립 버튼 (바닥에서 마진만큼 위) ---
	var comp := Vector2(w * COMP_CENTER_RATIO, h - m - COMP_R)
	_slot_circle(comp, COMP_R, false)
	_caption(font, 16, "동료", comp)

	# --- 아이템 1~3 (바닥에서 마진만큼 위) ---
	var total_w := ITEM_COUNT * SQ + (ITEM_COUNT - 1) * SQ_GAP
	var start_x := w * ITEM_CENTER_RATIO - total_w * 0.5
	var sy := h - SQ - m
	for i in ITEM_COUNT:
		var r := Rect2(start_x + i * (SQ + SQ_GAP), sy, SQ, SQ)
		_slot_rect(r, Input.is_action_pressed("item_%d" % (i + 1)))
		_caption(font, 14, "아이템" + str(i + 1), r.get_center())


func _slot_rect(r: Rect2, active: bool) -> void:
	draw_rect(r, FILL_ACTIVE if active else FILL_NORMAL, true)
	draw_rect(r, LINE_ACTIVE if active else LINE_NORMAL, false, 3.0)


func _slot_circle(c: Vector2, r: float, active: bool) -> void:
	draw_circle(c, r, FILL_ACTIVE if active else FILL_NORMAL)
	draw_arc(c, r, 0.0, TAU, 48, LINE_ACTIVE if active else LINE_NORMAL, 3.0, true)


## 코너에 붙는 1/4 원(부채꼴) — corner는 화면 우하단 꼭짓점
func _slot_quarter(corner: Vector2, r: float, active: bool) -> void:
	var pts := PackedVector2Array()
	pts.append(corner)
	var steps := 28
	for i in range(steps + 1):
		var a := deg_to_rad(180.0 + 90.0 * float(i) / float(steps))  # 좌 → 상
		pts.append(corner + Vector2(cos(a), sin(a)) * r)
	var fill := Color(0.2, 0.5, 1.0, 0.7) if active else Color(0.1, 0.25, 0.6, 0.55)
	draw_colored_polygon(pts, fill)
	draw_arc(corner, r, deg_to_rad(180.0), deg_to_rad(270.0), 40, LINE_ACTIVE if active else Color(1, 1, 1, 0.85), 3.0)
	draw_line(corner, corner + Vector2(-r, 0.0), Color(1, 1, 1, 0.85), 3.0)
	draw_line(corner, corner + Vector2(0.0, -r), Color(1, 1, 1, 0.85), 3.0)


func _caption(font: Font, fs: int, text: String, center: Vector2) -> void:
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, center + Vector2(-tw * 0.5, fs * 0.35), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.92))
