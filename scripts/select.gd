extends Control
## 전투준비 = 장비창(로드아웃) + 탭 픽커 (2026-06-03 v2 — design.md 토큰/정렬 준수)
##  기본: 장착된 치즈 + 장비 슬롯(직업/동료/스킬/소지품) + 스탯 + [출격]
##  슬롯 탭 → 인벤토리 픽커 오버레이(보유 목록 + 선택 설명 + [장착])
##  ★직업 = '장비'. 등급은 별개 아이템(owned_grades). (시스템밸런스 §5.2 / 홈로드맵 §4)

const FONT := preload("res://assets/fonts/Pretendard-Regular.ttf")
const JOB_ORDER := ["base", "sheriff", "maid", "jazz"]
const IDLE_FPS := 9.0
const ITEM_ICON := {
	"bandage": "res://assets/items/food/medkit.png",
	"anchovy": "res://assets/items/food/fish.png",
	"firecracker": "res://assets/items/gadgets/firecracker.png",
}

var _sf := {}                 # job -> SpriteFrames(idle)
var _t := 0.0
var _frame := 0
var _vp: Vector2
var _center_art: TextureRect
var _power_lbl: Label
var _base: Control            # 기본 장비창 레이어
var _picker: Control          # 픽커 오버레이(없으면 null)
var _pick_cat := ""
var _pick_sel := ""


func _ready() -> void:
	_vp = get_viewport_rect().size
	if has_node("Center"): $Center.visible = false
	if has_node("BG"): $BG.color = Design.CANVAS
	if has_node("Build"):
		$Build.text = GameState.BUILD + " ver."
		$Build.position = Vector2(_vp.x - 120, _vp.y - 28)
	for j in JOB_ORDER:
		var sf: SpriteFrames = load("res://assets/sprites/cheese/%s/cheese_%s.tres" % [j, j])
		if sf: _sf[j] = sf
	_build_base()


# ══════════════ 기본 장비창 ══════════════
func _build_base() -> void:
	if _base: _base.queue_free()
	_base = Control.new()
	_base.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_base)
	var E := float(Design.EDGE); var G := float(Design.GAP); var GL := float(Design.GAP_LG)
	var bar := float(Design.BAR_H)

	# 상단 바: [← 홈] / 전투력
	var home := Design.button("← 홈", "secondary", Design.FS_BODY)
	home.position = Vector2(E, 16); home.custom_minimum_size = Vector2(150, bar); home.size = Vector2(150, bar)
	home.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/home.tscn"))
	_base.add_child(home)
	_power_lbl = Design.label("", "title", Design.CHEESE)
	_power_lbl.position = Vector2(_vp.x - E - 400, 24); _power_lbl.size = Vector2(400, 40)
	_power_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_base.add_child(_power_lbl)

	# 영역 계산(전부 토큰 기반)
	var y0 := 16.0 + bar + G
	var go_h := 64.0
	var go_y := _vp.y - E - go_h
	var ph := go_y - G - y0
	var inner := _vp.x - E * 2.0 - G
	var lw := floorf(inner * 0.5)
	var rw := inner - lw
	var lx := E
	var rx := E + lw + G

	# 좌 패널: 캐릭터 + 이름 + 등급 + 스탯
	var lp := _panel(Vector2(lx, y0), Vector2(lw, ph))
	_base.add_child(lp)
	var lcol := _vbox(lp, GL, G)
	_center_art = TextureRect.new()
	_center_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_center_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_center_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_center_art.custom_minimum_size = Vector2(0, ph * 0.42)
	lcol.add_child(_center_art)
	var name_lbl := Design.label("", "display_s", Design.INK)
	name_lbl.name = "NameLbl"; name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lcol.add_child(name_lbl)
	var pill := Design.label("", "title", Design.INK_CREAM)
	pill.name = "GradePill"; pill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pill.custom_minimum_size = Vector2(0, 40)
	lcol.add_child(pill)
	var stat_box := _vbox_node(GAP_XS())
	stat_box.name = "StatBox"
	lcol.add_child(stat_box)

	# 우 패널: 장비 슬롯 4
	var rp := _panel(Vector2(rx, y0), Vector2(rw, ph))
	_base.add_child(rp)
	var rcol := _vbox(rp, GL, G)
	for cat in [["job", "직업"], ["ally", "동료 호루라기"], ["skill", "스킬"], ["item", "소지품"]]:
		var slot := _slot_button(cat[0], cat[1])
		slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		rcol.add_child(slot)

	# 하단 중앙: 출격
	var go := Design.button("출격 ▶", "primary", Design.FS_DISPLAY_S)
	var gw := 360.0
	go.position = Vector2((_vp.x - gw) * 0.5, go_y); go.custom_minimum_size = Vector2(gw, go_h); go.size = Vector2(gw, go_h)
	go.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	_base.add_child(go)

	_refresh_base()


func GAP_XS() -> int: return Design.GAP_XS


func _refresh_base() -> void:
	var job: String = GameState.selected_job
	var g: int = GameState.equipped_grade
	if _sf.has(job): _center_art.texture = _sf[job].get_frame_texture("idle", 0)
	var nm: Label = _base.find_child("NameLbl", true, false)
	nm.text = GameState.job_title(job, g)
	var pill: Label = _base.find_child("GradePill", true, false)
	if job == "base":
		pill.text = "등급 없음"
		pill.add_theme_stylebox_override("normal", Design.card_box(Design.PAPER_DEEP, 3, Design.RADIUS_CARD))
		pill.add_theme_color_override("font_color", Design.INK)
	else:
		pill.text = "%s   %s" % [_stars(g), GameState.rank_label(g, job)]
		pill.add_theme_stylebox_override("normal", Design.card_box(GameState.rank_color(g, job), 3, Design.RADIUS_CARD))
		pill.add_theme_color_override("font_color", Design.INK_CREAM)
	# 스탯
	var sb: VBoxContainer = _base.find_child("StatBox", true, false)
	for c in sb.get_children(): c.queue_free()
	var st: Dictionary = GameState.JOB_STATS[job]
	var m: float = GameState.LV_MULT[clampi(g - 1, 0, 4)]
	var rows := [
		["체력", "%d" % int(round(st["hp"] * m))],
		["근접 공격력", "%d" % int(round(st["near"] * m))],
		["원거리 공격력", "%d" % int(round(st["ranged"] * m))],
		["공격 속도", "%.2f" % st["atk_spd"]],
		["이동 속도", "%.2f" % st["move"]],
		["치명타 확률", "%d%%" % int(st["crit"] * 100)],
	]
	for r in rows:
		var row := HBoxContainer.new()
		var k := Design.label(r[0], "body", Design.INK)
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := Design.label(r[1], "body", Design.CHEESE_DEEP)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(k); row.add_child(v)
		sb.add_child(row)
	# 슬롯 값 갱신
	_set_slot("job", _job_slot_text())
	_set_slot("ally", "비어 있음" if GameState.equipped_companion == "" else String(GameState.COMPANIONS[GameState.equipped_companion]["name"]))
	_set_slot("skill", _skill_slot_text())
	_set_slot("item", _item_slot_text())
	_power_lbl.text = "전투력  %s" % _commafy(_power())


func _job_slot_text() -> String:
	var job: String = GameState.selected_job
	if job == "base": return "%s · 등급 없음" % GameState.job_title(job)
	return "%s · %s" % [GameState.job_title(job, GameState.equipped_grade), GameState.rank_label(GameState.equipped_grade, job)]

func _skill_slot_text() -> String:
	var ns := GameState.skill_slots(GameState.selected_job)
	if ns == 0: return "직업 장착 시 사용"
	var eq: Array = GameState.equipped_for(GameState.selected_job)
	if eq.is_empty(): return "비어 있음 (%d칸)" % ns
	var names: Array = []
	for sid in eq: names.append(String(GameState.SKILLS[sid]["name"]))
	return "  ·  ".join(names)

func _item_slot_text() -> String:
	var parts: Array = []
	for s in GameState.item_slots:
		parts.append(String(GameState.CONSUMABLES[s]["name"]) if s != "" else "(빈칸)")
	return "  ·  ".join(parts)


# ── 슬롯 버튼(라벨 + 값 + ▶) ──
func _slot_button(cat: String, label: String) -> Button:
	var b := Button.new()
	b.name = "Slot_" + cat
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", Design.FS_TITLE)
	b.add_theme_color_override("font_color", Design.INK)
	b.add_theme_color_override("font_hover_color", Design.INK)
	b.add_theme_color_override("font_pressed_color", Design.INK)
	for stn in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(stn, Design.card_box(Design.PAPER, 3, Design.RADIUS_CARD))
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(_open_picker.bind(cat))
	# 라벨(좌상단 caption) + 값(본문)을 자식 라벨로
	var cap := Design.label(label + "   ▶", "caption", Design.PAPER_DEEP.darkened(0.35))
	cap.name = "Cap"; cap.position = Vector2(Design.GAP, 8)
	b.add_child(cap)
	var val := Design.label("", "body", Design.INK)
	val.name = "Val"; val.position = Vector2(Design.GAP, 34)
	b.add_child(val)
	return b

func _set_slot(cat: String, value: String) -> void:
	var b: Button = _base.find_child("Slot_" + cat, true, false)
	if b == null: return
	var val: Label = b.find_child("Val", true, false)
	if val:
		val.text = value
		val.size = Vector2(b.size.x - Design.GAP * 2, 30)


# ══════════════ 픽커 오버레이 ══════════════
func _open_picker(cat: String) -> void:
	_pick_cat = cat
	_pick_sel = _picker_default(cat)
	if _picker: _picker.queue_free()
	_picker = Control.new()
	_picker.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_picker)
	var dim := ColorRect.new()
	dim.color = Color(Design.INK.r, Design.INK.g, Design.INK.b, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _close_picker())
	_picker.add_child(dim)
	var pw := minf(980.0, _vp.x - Design.EDGE * 2)
	var phh := minf(580.0, _vp.y - Design.EDGE * 2)
	var panel := _panel(Vector2((_vp.x - pw) * 0.5, (_vp.y - phh) * 0.5), Vector2(pw, phh))
	_picker.add_child(panel)
	_build_picker_content(panel, pw, phh)


func _picker_default(cat: String) -> String:
	match cat:
		"job": return "%s:%d" % [GameState.selected_job, GameState.equipped_grade]
		"ally": return GameState.equipped_companion
		"skill":
			var eq: Array = GameState.equipped_for(GameState.selected_job)
			return String(eq[0]) if eq.size() > 0 else ""
		"item":
			for s in GameState.item_slots:
				if s != "": return s
	return ""


func _build_picker_content(panel: Panel, pw: float, phh: float) -> void:
	for c in panel.get_children(): c.queue_free()
	var E := float(Design.GAP_LG)
	var titles := {"job": "직업", "ally": "동료 호루라기", "skill": "스킬", "item": "소지품"}
	var ttl := Design.label("%s 인벤토리" % titles[_pick_cat], "title", Design.INK)
	ttl.position = Vector2(E, E)
	panel.add_child(ttl)
	# 목록(스크롤 그리드)
	var list_h := phh * 0.5
	var sc := ScrollContainer.new()
	sc.position = Vector2(E, E + 44); sc.size = Vector2(pw - E * 2, list_h)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	var grid := GridContainer.new()
	grid.columns = 3 if _pick_cat in ["job", "item"] else 2
	grid.add_theme_constant_override("h_separation", Design.GAP)
	grid.add_theme_constant_override("v_separation", Design.GAP)
	sc.add_child(grid)
	for entry in _picker_entries():
		grid.add_child(_picker_card(entry))
	# 설명 영역
	var desc := Design.label("", "body", Design.INK)
	desc.name = "PickDesc"
	desc.position = Vector2(E, E + 44 + list_h + Design.GAP)
	desc.size = Vector2(pw - E * 2, phh - (E + 44 + list_h + Design.GAP) - 80)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	panel.add_child(desc)
	# 버튼: 장착 / 닫기
	var by := phh - Design.GAP_LG - float(Design.BAR_H)
	var equip := Design.button("장착", "brand", Design.FS_TITLE)
	equip.position = Vector2(pw - E - 340, by); equip.custom_minimum_size = Vector2(160, Design.BAR_H); equip.size = Vector2(160, Design.BAR_H)
	equip.pressed.connect(_do_equip)
	panel.add_child(equip)
	var close := Design.button("닫기", "secondary", Design.FS_TITLE)
	close.position = Vector2(pw - E - 168, by); close.custom_minimum_size = Vector2(160, Design.BAR_H); close.size = Vector2(160, Design.BAR_H)
	close.pressed.connect(_close_picker)
	panel.add_child(close)
	_update_pick_desc(panel)


func _picker_entries() -> Array:
	var out: Array = []   # [key, name, sub, accent]
	match _pick_cat:
		"job":
			for j in JOB_ORDER:
				for g in GameState.owned_grades.get(j, []):
					out.append(["%s:%d" % [j, g], GameState.job_title(j, g),
						("등급 없음" if j == "base" else GameState.rank_label(g, j)),
						(Design.PAPER_DEEP if j == "base" else GameState.rank_color(g, j))])
		"ally":
			out.append(["", "장착 안 함", "", Design.PAPER_DEEP])
			for cid in GameState.owned_companions:
				out.append([cid, String(GameState.COMPANIONS[cid]["name"]), "호루라기", Design.TEAL])
		"skill":
			for sid in GameState.owned_for(GameState.selected_job):
				out.append([sid, String(GameState.SKILLS[sid]["name"]), "스킬", Design.BLUE])
		"item":
			for id in ["bandage", "anchovy", "firecracker"]:
				if int(GameState.inventory.get(id, 0)) > 0:
					out.append([id, String(GameState.CONSUMABLES[id]["name"]), "보유 %d" % int(GameState.inventory.get(id, 0)), Design.CHEESE_DEEP])
	return out


func _picker_card(entry: Array) -> Button:
	var key: String = entry[0]
	var b := Button.new()
	b.custom_minimum_size = Vector2(280, 76)
	b.text = "%s\n%s" % [entry[1], entry[2]]
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", Design.FS_BODY)
	b.add_theme_color_override("font_color", Design.INK)
	var picked := (key == _pick_sel)
	var sb := Design.card_box(Design.CHEESE if picked else Design.PAPER, 4 if picked else 3, Design.RADIUS_CARD)
	sb.border_color = entry[3] if picked else Design.INK
	for stn in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(stn, sb)
	b.pressed.connect(func():
		_pick_sel = key
		var panel := _picker.get_child(1)
		_build_picker_content(panel, panel.size.x, panel.size.y))
	return b


func _update_pick_desc(panel: Panel) -> void:
	var d: Label = panel.find_child("PickDesc", true, false)
	if d == null: return
	match _pick_cat:
		"job":
			if _pick_sel == "": d.text = ""; return
			var parts := _pick_sel.split(":")
			var job: String = parts[0]; var g := int(parts[1])
			var st: Dictionary = GameState.JOB_STATS[job]
			var m: float = GameState.LV_MULT[clampi(g - 1, 0, 4)]
			d.text = "%s\n체력 %d  ·  근접 %d  ·  원거리 %d  ·  치명타 %d%%\n전투 배율 ×%.1f" % [
				GameState.job_title(job, g),
				int(round(st["hp"] * m)), int(round(st["near"] * m)), int(round(st["ranged"] * m)),
				int(st["crit"] * 100), m]
		"ally":
			d.text = ("동료를 장착하지 않습니다." if _pick_sel == "" else String(GameState.COMPANIONS[_pick_sel]["desc"]))
		"skill":
			d.text = (String(GameState.SKILLS[_pick_sel]["desc"]) if _pick_sel != "" else "보유 스킬이 없어요 (맥스 상점에서 구매).")
		"item":
			d.text = (String(GameState.CONSUMABLES[_pick_sel]["desc"]) if _pick_sel != "" else "소지품이 없어요.")


func _do_equip() -> void:
	match _pick_cat:
		"job":
			if _pick_sel != "":
				var parts := _pick_sel.split(":")
				GameState.selected_job = parts[0]
				GameState.equipped_grade = int(parts[1])
		"ally":
			GameState.equip_companion(_pick_sel)
		"skill":
			if _pick_sel != "":
				if GameState.is_equipped(GameState.selected_job, _pick_sel):
					GameState.unequip_skill(GameState.selected_job, _pick_sel)
				elif not GameState.equip_skill(GameState.selected_job, _pick_sel):
					# 슬롯 꽉 참 → 첫 슬롯 교체
					var eq: Array = GameState.equipped_for(GameState.selected_job)
					if eq.size() > 0: GameState.unequip_skill(GameState.selected_job, String(eq[0]))
					GameState.equip_skill(GameState.selected_job, _pick_sel)
		"item":
			if _pick_sel != "":
				if GameState.item_slots.has(_pick_sel):
					GameState.item_slots[GameState.item_slots.find(_pick_sel)] = ""
				else:
					var i := GameState.item_slots.find("")
					if i < 0: i = 0
					GameState.item_slots[i] = _pick_sel
	if GameState.mode != "dev" and GameState.AUTOSAVE: GameState.save_game()
	# 스킬·소지품은 연속 장착이 자연스러우니 픽커 유지하고 갱신, 직업·동료는 닫기
	if _pick_cat in ["skill", "item"]:
		var panel := _picker.get_child(1)
		_build_picker_content(panel, panel.size.x, panel.size.y)
		_refresh_base()
	else:
		_close_picker()


func _close_picker() -> void:
	if _picker: _picker.queue_free(); _picker = null
	_refresh_base()


# ── helpers ──
func _panel(pos: Vector2, sz: Vector2) -> Panel:
	var p := Panel.new()
	p.position = pos; p.size = sz
	p.add_theme_stylebox_override("panel", Design.panel_box())
	return p

func _vbox(parent: Control, margin: float, sep: int) -> VBoxContainer:
	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + s, int(margin))
	parent.add_child(mc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", sep)
	mc.add_child(vb)
	return vb

func _vbox_node(sep: int) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", sep)
	return vb

func _stars(g: int) -> String:
	return "★".repeat(clampi(g, 0, 5))

func _power() -> int:
	var st: Dictionary = GameState.JOB_STATS[GameState.selected_job]
	var m := GameState.level_mult()
	var v := (float(st["hp"]) + (float(st["ranged"]) + float(st["near"])) * 6.0 + float(st["crit"]) * 200.0) * m
	v += GameState.equipped_for(GameState.selected_job).size() * 40.0
	if GameState.equipped_companion != "": v += 100.0
	for s in GameState.item_slots:
		if s != "": v += 20.0
	return int(round(v))

func _commafy(n: int) -> String:
	var s := str(n); var out := ""; var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out; c += 1
		if c % 3 == 0 and i > 0: out = "," + out
	return out


func _process(delta: float) -> void:
	if _center_art == null or _picker != null: return
	var job: String = GameState.selected_job
	if not _sf.has(job): return
	var sf: SpriteFrames = _sf[job]
	var n := sf.get_frame_count("idle")
	if n <= 0: return
	_t += delta
	if _t >= 1.0 / IDLE_FPS:
		_t = 0.0
		_frame = (_frame + 1) % n
		_center_art.texture = sf.get_frame_texture("idle", _frame)
