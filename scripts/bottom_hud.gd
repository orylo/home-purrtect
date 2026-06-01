extends Control
const UI_FONT := preload("res://assets/fonts/DoHyeon-Regular.ttf")
## 하단 HUD (단일 행 — 왼→오):
##   아이템1~3(키 1 2 3) / 동료 / 소모품 4칸 / 스킬1~4(키 U I O P) / 근접공격(K) / 원거리공격(L)
##   좌하단: 가상 조이스틱(joystick.gd)
## 근접/원거리만 실제 작동(입력=attack_button.gd / Touch). 나머지는 시스템 생기면 연결.
## 좌표는 Layout.bottom_row()가 그림·입력 공유로 계산.

const BTN := Color(0.27, 0.29, 0.78)          # 인디고(목업 파랑)
const BTN_ON := Color(0.46, 0.53, 1.0)        # 눌림(밝게)
const SLOT_FILL := Color(0, 0, 0, 0.22)       # 소모품 빈칸
const SLOT_LINE := Color(1, 1, 1, 0.7)
const LINE := Color(1, 1, 1, 0.92)
const TXT := Color(1, 1, 1, 0.96)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	get_viewport().size_changed.connect(queue_redraw)


func _process(_delta: float) -> void:
	queue_redraw()   # 버튼 눌림(반짝) 반영


func _draw() -> void:
	var font := UI_FONT
	var L := Layout.bottom_row(size)

	# 아이템 1~3 (사각, 파랑)
	var items: Array = L["items"]
	for i in items.size():
		_square(items[i], Layout.ITEM_SQ, BTN, Input.is_action_pressed("item_%d" % (i + 1)))
		_label(font, 18, "아이템\n" + str(i + 1), items[i])

	# 동료 (원)
	_circle(L["companion"], Layout.ACT_R, BTN, false)
	_label(font, 28, "동료", L["companion"])

	# 소모품 4칸 (빈 슬롯) + 라벨
	var consum: Array = L["consum"]
	if consum.size() > 0:
		var label_c := Vector2((consum[0].x + consum[consum.size() - 1].x) * 0.5,
				consum[0].y - Layout.CONSUM_SQ * 0.5 - 14.0)
		_label(font, 18, "소모품", label_c)
	for c in consum:
		var r := Rect2(c.x - Layout.CONSUM_SQ * 0.5, c.y - Layout.CONSUM_SQ * 0.5, Layout.CONSUM_SQ, Layout.CONSUM_SQ)
		draw_rect(r, SLOT_FILL, true)
		draw_rect(r, SLOT_LINE, false, 3.0)

	# 스킬 1~4 (원)
	var skills: Array = L["skills"]
	for k in skills.size():
		_circle(skills[k], Layout.SKILL_BTN_R, BTN, Input.is_action_pressed("skill_%d" % (k + 1)))
		_label(font, 20, "스킬" + str(k + 1), skills[k])

	# 근접공격(K) / 원거리공격(L)
	var melee_on := Touch.melee_held or Input.is_key_pressed(KEY_K)
	_circle(L["melee"], Layout.ACT_R, BTN, melee_on)
	_label(font, 26, "근접\n공격", L["melee"])

	var ranged_on := Touch.ranged_held or Input.is_action_pressed("attack")
	_circle(L["ranged"], Layout.ACT_R, BTN, ranged_on)
	_label(font, 26, "원거리\n공격", L["ranged"])


func _square(center: Vector2, sq: float, base: Color, active: bool) -> void:
	var r := Rect2(center.x - sq * 0.5, center.y - sq * 0.5, sq, sq)
	draw_rect(r, BTN_ON if active else base, true)
	draw_rect(r, LINE, false, 3.0)


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
