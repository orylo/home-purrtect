extends Control
const UI_FONT := preload("res://assets/fonts/SeoulAlrim-Bold.ttf")
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

# design.md 토큰(크림 칩 + 잉크 외곽 + 골든 눌림). const라 Style 직접참조 불가 → 동일 hex 리터럴.
const FILL := Color(0.953, 0.890, 0.745, 0.82)   # 크림 칩(paper)
const FILL_ON := Color(0.949, 0.702, 0.239, 0.95) # 눌림 = 골든(cheese)
const LINE := Color(0.141, 0.122, 0.106, 0.95)    # 잉크 외곽
const TXT := Color(0.141, 0.122, 0.106, 1.0)      # 잉크 글자

# 나노바나나 에셋 — 슬롯/손 텍스처
const TEX_SLOT_SQ := preload("res://assets/ui/slots/slot2_sq.png")
const TEX_RND_SKILL := preload("res://assets/ui/slots/slot2_skill.png")
const TEX_RND_COMP := preload("res://assets/ui/slots/slot2_comp.png")
const TEX_RND_ACT := preload("res://assets/ui/slots/slot2_act.png")
const TEX_MELEE := preload("res://assets/ui/hands/action_melee_v1.png")
const TEX_RANGED := preload("res://assets/ui/hands/action_ranged_v1.png")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	get_viewport().size_changed.connect(queue_redraw)


func _process(_delta: float) -> void:
	queue_redraw()   # 버튼 눌림(반짝) 반영


func _draw() -> void:
	var font := UI_FONT
	var L := Layout.bottom_row(size)

	# 아이템 1~3 (사각 슬롯 텍스처) — 배치된 소모품 이름 + 보유 수
	var items: Array = L["items"]
	var sqd := Layout.ITEM_SQ * 1.18
	for i in items.size():
		_tex(TEX_SLOT_SQ, items[i], sqd, sqd, _mod(Input.is_action_pressed("item_%d" % (i + 1))))
		var id: String = GameState.item_slots[i] if i < GameState.item_slots.size() else ""
		if id == "":
			_label(font, 17, "비었음", items[i], Color(TXT, 0.45))
		else:
			var n: int = int(GameState.inventory.get(id, 0))
			var col := TXT if n > 0 else Color(TXT, 0.4)
			_label(font, 18, SHORT.get(id, "?") + "\n×" + str(n), items[i], col)

	var d := Layout.ACT_R * 2.2   # 원형 슬롯 지름(텍스처 자체 여백 포함)

	# 동료 (원, 키 4) — 동료 안 껴도 슬롯은 항상 풀 오퍼시티(빈 슬롯 표시).
	var comp: String = GameState.equipped_companion
	if comp == "":
		_tex(TEX_RND_COMP, L["companion"], d, d)
		_label(font, 22, "동료", L["companion"], Color(TXT, 0.45))
	else:
		var cbtn := get_parent().get_node_or_null("CompanionButton")
		var ccd: float = cbtn.cd_left() if cbtn else 0.0
		_tex(TEX_RND_COMP, L["companion"], d, d, _mod(Input.is_key_pressed(KEY_4)))
		if ccd > 0.0:
			draw_circle(L["companion"], Layout.ACT_R, Color(0, 0, 0, 0.5))
			_label(font, 30, str(int(ceil(ccd))), L["companion"])
		else:
			_label(font, 24, COMP_SHORT.get(comp, "동료"), L["companion"])

	# 스킬 슬롯 — 활성 칸 = 공격버튼에 가까운 "오른쪽 nslots개"만 풀 오퍼시티, 나머지는 opacity 0(숨김).
	#   길냥이(base)=0칸 → 전부 숨김 / 등급1·2=2칸 / 3·4=3칸 / 5=4칸. 빈 슬롯도 풀 표시(스킬 끼면 그 칸에 아이콘=추후).
	var skills: Array = L["skills"]                 # 왼→오 (skills[마지막]=공격버튼에 가장 가까움)
	var sbtn := get_parent().get_node_or_null("SkillButton")
	var equipped: Array = GameState.equipped_for(GameState.selected_job)
	var nslots: int = GameState.skill_slots(GameState.selected_job)
	var ds := Layout.SKILL_BTN_R * 2.2
	var first_active: int = skills.size() - nslots  # 이 인덱스부터 오른쪽이 활성
	for k in skills.size():
		if k < first_active:
			continue                                # 비활성 = opacity 0 (아예 안 그림)
		var i := k - first_active                   # 논리 스킬 인덱스(0..nslots-1)
		var sid: String = equipped[i] if i < equipped.size() else ""
		_tex(TEX_RND_SKILL, skills[k], ds, ds, _mod(Input.is_action_pressed("skill_%d" % (i + 1))))
		if sid == "":
			continue                                # 빈 활성 슬롯 = 풀 오퍼시티 프레임만(아이콘 없음)
		var cd: float = sbtn.cd_left(i) if sbtn else 0.0
		if cd > 0.0:
			draw_circle(skills[k], Layout.SKILL_BTN_R, Color(0, 0, 0, 0.5))   # 쿨 중 어둡게
			_label(font, 30, str(int(ceil(cd))), skills[k])
		else:
			_label(font, 20, SKILL_SHORT.get(sid, "?"), skills[k])

	# 근접공격(K) / 원거리공격(L) = 빨간 원형 버튼 + 글러브 손(나노바나나)
	var am: bool = Touch.melee_held or Input.is_physical_key_pressed(KEY_K)   # 물리 K(IME 무관)
	_tex(TEX_RND_ACT, L["melee"], d, d, _mod(am))
	_tex(TEX_MELEE, L["melee"], d * 0.64, d * 0.64)
	var ar: bool = Touch.ranged_held or Input.is_action_pressed("attack")
	_tex(TEX_RND_ACT, L["ranged"], d, d, _mod(ar))
	_tex(TEX_RANGED, L["ranged"], d * 0.68, d * 0.62)


## 활성(눌림) 시 살짝 밝게
func _mod(active: bool) -> Color:
	return Color(1.18, 1.18, 1.18) if active else Color.WHITE

## 텍스처를 center에 box(w,h) 안에 비율유지로 그림
func _tex(tex: Texture2D, center: Vector2, w: float, h: float, mod := Color.WHITE) -> void:
	var s := minf(w / float(tex.get_width()), h / float(tex.get_height()))
	var sz := Vector2(tex.get_width() * s, tex.get_height() * s)
	draw_texture_rect(tex, Rect2(center - sz * 0.5, sz), false, mod)


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
