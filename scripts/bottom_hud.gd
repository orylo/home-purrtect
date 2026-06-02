extends Control
const UI_FONT := preload("res://assets/fonts/Pretendard-Regular.ttf")
## 하단 HUD (단일 행 — 왼→오):
##   아이템1~3(키 1 2 3) / 동료(키 4) / 스킬1~4(키 U I O P) / 근접공격(K) / 원거리공격(L)
##   좌하단: 가상 조이스틱(joystick.gd)
## 근접/원거리만 실제 작동(입력=attack_button.gd / Touch). 나머지는 시스템 생기면 연결.
## 좌표는 Layout.bottom_row()가 그림·입력 공유로 계산.

## 소모품 짧은 이름(아이템칸 표시용)
const SHORT := {"bandage": "붕대", "anchovy": "멸치", "firecracker": "폭죽"}
## 동료 짧은 이름(동료칸 표시용)
const COMP_SHORT := {"dove": "비둘기", "chihuahua": "치와와"}
## 스킬 짧은 이름(스킬칸 표시용)
const SKILL_SHORT := {
	"warn_shot": "경고", "shield": "방패", "support": "지원",
	"sweep": "대청소", "wax": "왁스", "plates": "접시",
	"discord": "불협", "lullaby": "자장", "encore": "앵콜",
}

const FILL := Color(0, 0, 0, 0.40)        # 평소(검정 반투명)
const FILL_ON := Color(1, 1, 1, 0.45)     # 눌림(밝게)
const LINE := Color(1, 1, 1, 0.78)
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

	# 아이템 1~3 (사각, 키 1 2 3) — 배치된 소모품 이름 + 보유 수
	var items: Array = L["items"]
	for i in items.size():
		_square(items[i], Layout.ITEM_SQ, Input.is_action_pressed("item_%d" % (i + 1)))
		var id: String = GameState.item_slots[i] if i < GameState.item_slots.size() else ""
		if id == "":
			_label(font, 17, "비었음", items[i], Color(1, 1, 1, 0.45))
		else:
			var n: int = int(GameState.inventory.get(id, 0))
			var col := TXT if n > 0 else Color(1, 1, 1, 0.4)
			_label(font, 18, SHORT.get(id, "?") + "\n×" + str(n), items[i], col)

	# 동료 (원, 키 4) — 장착 동료 + 쿨타임. 없으면 어둡게.
	var comp: String = GameState.equipped_companion
	if comp == "":
		draw_circle(L["companion"], Layout.ACT_R, Color(0, 0, 0, 0.22))
		draw_arc(L["companion"], Layout.ACT_R, 0.0, TAU, 48, Color(1, 1, 1, 0.22), 2.0, true)
		_label(font, 22, "동료", L["companion"], Color(1, 1, 1, 0.4))
	else:
		var cbtn := get_parent().get_node_or_null("CompanionButton")
		var ccd: float = cbtn.cd_left() if cbtn else 0.0
		_circle(L["companion"], Layout.ACT_R, Input.is_key_pressed(KEY_4))
		if ccd > 0.0:
			draw_circle(L["companion"], Layout.ACT_R, Color(0, 0, 0, 0.5))
			_label(font, 30, str(int(ceil(ccd))), L["companion"])
		else:
			_label(font, 24, COMP_SHORT.get(comp, "동료"), L["companion"])

	# 스킬 1~4 — 장착 슬롯(현재 직업×Lv)대로 표시. 비활성 슬롯은 어둡게, 쿨 중엔 남은 초.
	var skills: Array = L["skills"]
	var sbtn := get_parent().get_node_or_null("SkillButton")
	var equipped: Array = GameState.equipped_for(GameState.selected_job)
	var nslots: int = GameState.skill_slots(GameState.selected_job)
	for k in skills.size():
		var active: bool = k < nslots and k < equipped.size()
		if not active:
			draw_circle(skills[k], Layout.SKILL_BTN_R, Color(0, 0, 0, 0.22))
			draw_arc(skills[k], Layout.SKILL_BTN_R, 0.0, TAU, 48, Color(1, 1, 1, 0.22), 2.0, true)
			continue
		var sid: String = equipped[k]
		var cd: float = sbtn.cd_left(k) if sbtn else 0.0
		_circle(skills[k], Layout.SKILL_BTN_R, Input.is_action_pressed("skill_%d" % (k + 1)))
		if cd > 0.0:
			draw_circle(skills[k], Layout.SKILL_BTN_R, Color(0, 0, 0, 0.5))   # 쿨 중 어둡게
			_label(font, 30, str(int(ceil(cd))), skills[k])
		else:
			_label(font, 20, SKILL_SHORT.get(sid, "?"), skills[k])

	# 근접공격(K) / 원거리공격(L)
	_circle(L["melee"], Layout.ACT_R, Touch.melee_held or Input.is_key_pressed(KEY_K))
	_label(font, 26, "근접\n공격", L["melee"])

	_circle(L["ranged"], Layout.ACT_R, Touch.ranged_held or Input.is_action_pressed("attack"))
	_label(font, 26, "원거리\n공격", L["ranged"])


func _square(center: Vector2, sq: float, active: bool) -> void:
	var r := Rect2(center.x - sq * 0.5, center.y - sq * 0.5, sq, sq)
	draw_rect(r, FILL_ON if active else FILL, true)
	draw_rect(r, LINE, false, 3.0)


func _circle(c: Vector2, r: float, active: bool) -> void:
	draw_circle(c, r, FILL_ON if active else FILL)
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
