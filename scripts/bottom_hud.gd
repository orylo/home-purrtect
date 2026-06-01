extends Control
const UI_FONT := preload("res://assets/fonts/DoHyeon-Regular.ttf")
## 하단 HUD (목업 기준)
##   우하단 클러스터:
##     · 스킬 행(위): 스킬1~4 원 (키 U I O P) — placeholder
##     · 액션 행(아래): 동료 / 근접공격(키 K) / 원거리공격(키 L)
##   가운데 아래: 소모품 4칸(빈 슬롯) + 아이템1~3 (키 1 2 3) — placeholder
##   좌하단: 가상 조이스틱(joystick.gd)
## 근접/원거리만 실제 작동(입력=attack_button.gd / Touch). 나머지는 시스템 생기면 연결.

const BTN := Color(0.27, 0.29, 0.78)          # 인디고(목업 파랑)
const BTN_ON := Color(0.46, 0.53, 1.0)        # 눌림(밝게)
const SLOT_FILL := Color(0, 0, 0, 0.22)       # 소모품 빈칸
const SLOT_LINE := Color(1, 1, 1, 0.7)
const LINE := Color(1, 1, 1, 0.92)
const TXT := Color(1, 1, 1, 0.96)

# 소모품 4칸 / 아이템 3칸
const CONSUM_N := 4
const CONSUM_SQ := 64.0
const CONSUM_GAP := 14.0
const CONSUM_CX := 0.36          # 화면폭 대비 중심 x
const ITEM_N := 3
const ITEM_SQ := 72.0
const ITEM_GAP := 16.0
const ITEM_CX := 0.55


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	get_viewport().size_changed.connect(queue_redraw)


func _process(_delta: float) -> void:
	queue_redraw()   # 버튼 눌림(반짝) 반영


func _draw() -> void:
	var s := size
	var font := UI_FONT
	var m := Layout.CONTROL_EDGE_MARGIN

	# === 우하단 클러스터: 스킬 행(위) ===
	for k in 4:
		var c := Layout.skill_btn_center(s, k)
		_circle(c, Layout.SKILL_BTN_R, BTN, Input.is_action_pressed("skill_%d" % (k + 1)))
		_label(font, 18, "스킬" + str(k + 1), c)

	# === 액션 행(아래): 동료 / 근접공격 / 원거리공격 ===
	var comp := Layout.companion_btn_center(s)
	_circle(comp, Layout.ACT_R, BTN, false)
	_label(font, 26, "동료", comp)

	var mc := Layout.melee_btn_center(s)
	var melee_on := Touch.melee_held or Input.is_key_pressed(KEY_K)
	_circle(mc, Layout.ACT_R, BTN, melee_on)
	_label(font, 26, "근접\n공격", mc)
	_label(font, 16, "K", mc + Vector2(0, Layout.ACT_R - 16.0), Color(1, 1, 1, 0.55))

	var rc := Layout.ranged_btn_center(s)
	var ranged_on := Touch.ranged_held or Input.is_action_pressed("attack")
	_circle(rc, Layout.ACT_R, BTN, ranged_on)
	_label(font, 26, "원거리\n공격", rc)
	_label(font, 16, "L", rc + Vector2(0, Layout.ACT_R - 16.0), Color(1, 1, 1, 0.55))

	# === 가운데 아래: 소모품 4칸(빈 슬롯) ===
	var cons_w := CONSUM_N * CONSUM_SQ + (CONSUM_N - 1) * CONSUM_GAP
	var cons_x := s.x * CONSUM_CX - cons_w * 0.5
	var cons_y := s.y - m - CONSUM_SQ
	_label(font, 18, "소모품", Vector2(s.x * CONSUM_CX, cons_y - 16.0), TXT)
	for i in CONSUM_N:
		var r := Rect2(cons_x + i * (CONSUM_SQ + CONSUM_GAP), cons_y, CONSUM_SQ, CONSUM_SQ)
		draw_rect(r, SLOT_FILL, true)
		draw_rect(r, SLOT_LINE, false, 3.0)

	# === 아이템 1~3 ===
	var item_w := ITEM_N * ITEM_SQ + (ITEM_N - 1) * ITEM_GAP
	var item_x := s.x * ITEM_CX - item_w * 0.5
	var item_y := s.y - m - ITEM_SQ
	for i in ITEM_N:
		var r := Rect2(item_x + i * (ITEM_SQ + ITEM_GAP), item_y, ITEM_SQ, ITEM_SQ)
		var on := Input.is_action_pressed("item_%d" % (i + 1))
		draw_rect(r, BTN_ON if on else BTN, true)
		draw_rect(r, LINE, false, 3.0)
		_label(font, 18, "아이템\n" + str(i + 1), r.get_center())


## 채워진 원형 버튼(파랑) + 테두리
func _circle(c: Vector2, r: float, base: Color, active: bool) -> void:
	draw_circle(c, r, BTN_ON if active else base)
	draw_arc(c, r, 0.0, TAU, 48, LINE, 3.0, true)


## 가운데 정렬 텍스트(여러 줄 \n 지원)
func _label(font: Font, fs: int, text: String, center: Vector2, col: Color = TXT) -> void:
	var lines := text.split("\n")
	var line_h := float(fs) + 4.0
	var total_h := line_h * lines.size()
	var y0 := center.y - total_h * 0.5 + float(fs) * 0.78
	for li in lines.size():
		var line: String = lines[li]
		var tw := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(center.x - tw * 0.5, y0 + li * line_h), line,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
