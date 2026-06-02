extends Control
## 전투준비 = 장비 장착(로드아웃) 화면 (2026-06-03 개편 — 시스템밸런스 §5.2 / 홈로드맵 §4)
## 좌: 인벤토리 탭(직업/동료/스킬/소지품) + 보유 목록  →  중앙: 선택 항목 상세 + [장착]  →  우: 내 장비 + [출격]
## ★직업 = '장비'. 등급은 별개 아이템(owned_grades). 보유 (직업×등급) 중 택1 장착.

const FONT := preload("res://assets/fonts/Pretendard-Regular.ttf")
const JOB_ORDER := ["base", "sheriff", "maid", "jazz"]
const CATS := [["job", "직업"], ["ally", "동료"], ["skill", "스킬"], ["item", "소지품"]]
const IDLE_FPS := 9.0
const ITEM_ICON := {
	"bandage": "res://assets/items/food/medkit.png",
	"anchovy": "res://assets/items/food/fish.png",
	"firecracker": "res://assets/items/gadgets/firecracker.png",
}

var _cat := "job"
var _sel := ""                # 선택 키: 직업="job:grade" / 그외=id
var _sf := {}                 # job -> SpriteFrames(idle)
var _t := 0.0
var _frame := 0
var _tab_btns := {}
var _list_box: VBoxContainer
var _detail: Control
var _loadout: Control
var _power_lbl: Label
var _center_art: TextureRect
var _vp: Vector2


func _ready() -> void:
	_vp = get_viewport_rect().size
	if has_node("Center"): $Center.visible = false
	if has_node("BG"): $BG.color = Design.CANVAS
	if has_node("Build"):
		$Build.text = GameState.BUILD + " ver."
		$Build.position = Vector2(_vp.x - 120, _vp.y - 30)
	for j in JOB_ORDER:
		var sf: SpriteFrames = load("res://assets/sprites/cheese/%s/cheese_%s.tres" % [j, j])
		if sf: _sf[j] = sf
	_build_skeleton()
	_select_cat("job")


func _build_skeleton() -> void:
	var home := Design.button("← 홈", "secondary", Design.FS_BODY)
	home.position = Vector2(24, 16); home.custom_minimum_size = Vector2(140, 48); home.size = Vector2(140, 48)
	home.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/home.tscn"))
	add_child(home)
	_power_lbl = Design.label("", "title", Design.CHEESE)
	_power_lbl.position = Vector2(_vp.x - 380, 24); _power_lbl.size = Vector2(340, 40)
	_power_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_power_lbl)

	var top := 84.0
	var h := _vp.y - top - 24.0
	var lx := 24.0; var lw := 392.0
	var tabrow := HBoxContainer.new()
	tabrow.add_theme_constant_override("separation", 6)
	tabrow.position = Vector2(lx, top); tabrow.size = Vector2(lw, 48)
	add_child(tabrow)
	for c in CATS:
		var b := Design.button(c[1], "paper", Design.FS_BODY)
		b.custom_minimum_size = Vector2(92, 48)
		b.pressed.connect(_select_cat.bind(c[0]))
		_tab_btns[c[0]] = b
		tabrow.add_child(b)
	var lpanel := Panel.new()
	lpanel.position = Vector2(lx, top + 56); lpanel.size = Vector2(lw, h - 56)
	lpanel.add_theme_stylebox_override("panel", Design.panel_box())
	add_child(lpanel)
	var sc := ScrollContainer.new()
	sc.position = Vector2(12, 12); sc.size = lpanel.size - Vector2(24, 24)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lpanel.add_child(sc)
	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 8)
	_list_box.custom_minimum_size = Vector2(sc.size.x, 0)
	sc.add_child(_list_box)

	var cx := lx + lw + 20.0; var cw := 612.0
	var cpanel := Panel.new()
	cpanel.position = Vector2(cx, top); cpanel.size = Vector2(cw, h)
	cpanel.add_theme_stylebox_override("panel", Design.panel_box())
	add_child(cpanel)
	_detail = Control.new()
	_detail.set_anchors_preset(Control.PRESET_FULL_RECT)
	cpanel.add_child(_detail)

	var rx := cx + cw + 20.0; var rw := _vp.x - rx - 24.0
	var rpanel := Panel.new()
	rpanel.position = Vector2(rx, top); rpanel.size = Vector2(rw, h)
	rpanel.add_theme_stylebox_override("panel", Design.panel_box())
	add_child(rpanel)
	_loadout = Control.new()
	_loadout.set_anchors_preset(Control.PRESET_FULL_RECT)
	rpanel.add_child(_loadout)


func _select_cat(cat: String) -> void:
	_cat = cat
	for id in _tab_btns:
		Design.style_button(_tab_btns[id], "cheese" if id == cat else "paper", Design.FS_BODY)
	_sel = _default_sel(cat)
	_refresh_list()
	_refresh_detail()
	_refresh_loadout()


func _default_sel(cat: String) -> String:
	match cat:
		"job": return "%s:%d" % [GameState.selected_job, GameState.display_grade(GameState.selected_job)]
		"ally": return String(GameState.owned_companions[0]) if GameState.owned_companions.size() > 0 else ""
		"skill":
			var ow: Array = GameState.owned_for(GameState.selected_job)
			return String(ow[0]) if ow.size() > 0 else ""
		"item":
			for id in ["bandage", "anchovy", "firecracker"]:
				if int(GameState.inventory.get(id, 0)) > 0: return id
	return ""


func _refresh_list() -> void:
	for c in _list_box.get_children(): c.queue_free()
	match _cat:
		"job":
			for j in JOB_ORDER:
				for g in GameState.owned_grades.get(j, []):
					_add_list_row("%s:%d" % [j, g], GameState.job_title(j, g),
						(GameState.rank_label(g, j) if j != "base" else "맨몸"),
						GameState.rank_color(g, j) if j != "base" else Design.PAPER_DEEP)
		"ally":
			if GameState.owned_companions.is_empty(): _add_empty("동료 없음 — 펄/상점에서 호루라기 입수")
			for cid in GameState.owned_companions:
				_add_list_row(cid, String(GameState.COMPANIONS[cid]["name"]), "동료 호루라기", Design.TEAL)
		"skill":
			if GameState.selected_job == "base":
				_add_empty("맨몸은 스킬 없음 — 직업을 장착하세요")
			else:
				var ow: Array = GameState.owned_for(GameState.selected_job)
				if ow.is_empty(): _add_empty("보유 스킬 없음 — 맥스 상점에서 구매")
				for sid in ow:
					_add_list_row(sid, String(GameState.SKILLS[sid]["name"]), "스킬", Design.BLUE)
		"item":
			var any := false
			for id in ["bandage", "anchovy", "firecracker"]:
				var n := int(GameState.inventory.get(id, 0))
				if n > 0:
					any = true
					_add_list_row(id, String(GameState.CONSUMABLES[id]["name"]), "보유 %d" % n, Design.CHEESE_DEEP)
			if not any: _add_empty("소지품 없음 — 맥스 상점에서 구매")


func _add_list_row(key: String, name: String, sub: String, accent: Color) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 64)
	b.text = "%s\n%s" % [name, sub]
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", Design.FS_BODY)
	b.add_theme_color_override("font_color", Design.INK)
	var picked := (key == _sel)
	var sb := Design.card_box(Design.CHEESE if picked else Design.PAPER, 4 if picked else 3, 12)
	sb.border_color = accent if picked else Design.INK
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(_select_item.bind(key))
	_list_box.add_child(b)


func _add_empty(msg: String) -> void:
	_list_box.add_child(Design.label("  " + msg, "caption", Design.PAPER_DEEP.darkened(0.25)))


func _select_item(key: String) -> void:
	_sel = key
	_refresh_list()
	_refresh_detail()


func _refresh_detail() -> void:
	for c in _detail.get_children(): c.queue_free()
	_center_art = null
	if _sel == "":
		_detail.add_child(_dlabel("좌측에서 선택하세요", "body", Design.PAPER_DEEP.darkened(0.2), _detail_h() * 0.5))
		return
	match _cat:
		"job": _detail_job()
		"ally": _detail_simple(String(GameState.COMPANIONS[_sel]["name"]), String(GameState.COMPANIONS[_sel]["desc"]), Design.TEAL, GameState.equipped_companion == _sel, "동료")
		"skill": _detail_simple(String(GameState.SKILLS[_sel]["name"]), String(GameState.SKILLS[_sel]["desc"]), Design.BLUE, GameState.is_equipped(GameState.selected_job, _sel), "스킬")
		"item": _detail_item()


func _detail_job() -> void:
	var parts := _sel.split(":")
	var job: String = parts[0]
	var g := int(parts[1])
	_center_art = TextureRect.new()
	_center_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_center_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_center_art.position = Vector2(40, 36); _center_art.size = Vector2(_detail_w() - 80, 230)
	if _sf.has(job): _center_art.texture = _sf[job].get_frame_texture("idle", 0)
	_detail.add_child(_center_art)
	var y := 278.0
	_detail.add_child(_dlabel(GameState.job_title(job, g), "display_s", Design.INK, y)); y += 58
	if job != "base":
		var pill := Design.label("  %s   %s  " % [_stars(g), GameState.rank_label(g, job)], "title", Design.INK_CREAM)
		pill.add_theme_stylebox_override("normal", Design.card_box(GameState.rank_color(g, job), 3, 99))
		pill.position = Vector2(120, y); pill.size = Vector2(_detail_w() - 240, 40)
		pill.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; pill.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_detail.add_child(pill); y += 54
	var st: Dictionary = GameState.JOB_STATS[job]
	var m: float = GameState.LV_MULT[clampi(g - 1, 0, 4)]
	for ln in [
		"♥ 체력  %d" % int(round(st["hp"] * m)),
		"근접  %d      원거리  %d" % [int(round(st["near"] * m)), int(round(st["ranged"] * m))],
		"공속  %.2f      이속  %.2f" % [st["atk_spd"], st["move"]],
		"◆ 크리  %d%%" % int(st["crit"] * 100),
	]:
		_detail.add_child(_dlabel(ln, "body", Design.INK, y)); y += 30
	var equipped := (GameState.selected_job == job and GameState.equipped_grade == g)
	_add_equip_btn("장착됨" if equipped else "장착", equipped, func():
		GameState.selected_job = job
		GameState.equipped_grade = g
		if GameState.mode != "dev" and GameState.AUTOSAVE: GameState.save_game()
		_refresh_list(); _refresh_detail(); _refresh_loadout())


func _detail_simple(name: String, desc: String, accent: Color, equipped: bool, kind: String) -> void:
	var badge := Panel.new()
	badge.position = Vector2(_detail_w() * 0.5 - 70, 50); badge.size = Vector2(140, 140)
	badge.add_theme_stylebox_override("panel", Design.card_box(accent, 4, 99))
	_detail.add_child(badge)
	var bl := Design.label(name.substr(0, 2), "display_s", Design.INK_CREAM)
	bl.set_anchors_preset(Control.PRESET_FULL_RECT)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(bl)
	var y := 210.0
	_detail.add_child(_dlabel(name, "display_s", Design.INK, y)); y += 60
	_detail.add_child(_dlabel("[%s]" % kind, "caption", accent, y)); y += 34
	var d := Design.label(desc, "body", Design.INK)
	d.position = Vector2(48, y); d.size = Vector2(_detail_w() - 96, 130)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(d)
	_add_equip_btn("해제" if equipped else "장착", false, func():
		if _cat == "ally":
			GameState.equip_companion("" if equipped else _sel)
		else:
			if equipped: GameState.unequip_skill(GameState.selected_job, _sel)
			elif not GameState.equip_skill(GameState.selected_job, _sel):
				_toast("스킬 슬롯이 꽉 찼어요 (다른 스킬 해제 후)")
		_refresh_list(); _refresh_detail(); _refresh_loadout())


func _detail_item() -> void:
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(_detail_w() * 0.5 - 80, 36); icon.size = Vector2(160, 160)
	if ITEM_ICON.has(_sel): icon.texture = load(ITEM_ICON[_sel])
	_detail.add_child(icon)
	var y := 210.0
	_detail.add_child(_dlabel(String(GameState.CONSUMABLES[_sel]["name"]), "display_s", Design.INK, y)); y += 60
	_detail.add_child(_dlabel("보유 %d개" % int(GameState.inventory.get(_sel, 0)), "caption", Design.CHEESE_DEEP, y)); y += 34
	var d := Design.label(String(GameState.CONSUMABLES[_sel]["desc"]), "body", Design.INK)
	d.position = Vector2(48, y); d.size = Vector2(_detail_w() - 96, 80)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(d)
	var slotted := GameState.item_slots.has(_sel)
	_add_equip_btn("슬롯에서 빼기" if slotted else "소지품 슬롯에 넣기", false, func():
		if slotted:
			GameState.item_slots[GameState.item_slots.find(_sel)] = ""
		else:
			var i := GameState.item_slots.find("")
			if i < 0: _toast("소지품 슬롯 3칸이 꽉 찼어요")
			else: GameState.item_slots[i] = _sel
		_refresh_detail(); _refresh_loadout())


func _add_equip_btn(text: String, disabled: bool, fn: Callable) -> void:
	var b := Design.button(text, "brand", Design.FS_TITLE)
	b.custom_minimum_size = Vector2(240, 60); b.size = Vector2(240, 60)
	b.position = Vector2(_detail_w() * 0.5 - 120, _detail_h() - 84)
	b.disabled = disabled
	if not disabled: b.pressed.connect(fn)
	_detail.add_child(b)


func _refresh_loadout() -> void:
	for c in _loadout.get_children(): c.queue_free()
	var y := 18.0
	var hdr := Design.label("내 장비", "title", Design.INK); hdr.position = Vector2(16, y); _loadout.add_child(hdr); y += 46
	var jt := GameState.job_title(GameState.selected_job, GameState.equipped_grade)
	var jr := (GameState.rank_label(GameState.equipped_grade, GameState.selected_job) if GameState.selected_job != "base" else "맨몸")
	y = _equip_slot("직업", "%s · %s" % [jt, jr], GameState.rank_color(GameState.equipped_grade, GameState.selected_job), y)
	var comp: String = GameState.equipped_companion
	y = _equip_slot("동료 호루라기", (String(GameState.COMPANIONS[comp]["name"]) if comp != "" else "(빈 슬롯)"), Design.TEAL, y)
	var eq: Array = GameState.equipped_for(GameState.selected_job)
	var ns := GameState.skill_slots(GameState.selected_job)
	var stxt := ""
	if ns == 0:
		stxt = "(직업 없음)"
	else:
		for i in ns:
			stxt += ("• %s\n" % String(GameState.SKILLS[eq[i]]["name"])) if i < eq.size() else "• (빈 슬롯)\n"
	y = _equip_slot("스킬 %d칸" % ns, stxt.strip_edges(), Design.BLUE, y, 90)
	var itxt := ""
	for s in GameState.item_slots:
		itxt += ("[%s] " % String(GameState.CONSUMABLES[s]["name"])) if s != "" else "[빈] "
	y = _equip_slot("소지품 3", itxt.strip_edges(), Design.CHEESE_DEEP, y)
	var w := _loadout_w()
	var go := Design.button("출격 ▶", "primary", Design.FS_DISPLAY_S)
	go.custom_minimum_size = Vector2(w - 32, 72); go.size = Vector2(w - 32, 72)
	go.position = Vector2(16, _loadout_h() - 88)
	go.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	_loadout.add_child(go)
	_power_lbl.text = "전투력  %s" % _commafy(_power())


func _equip_slot(label: String, value: String, accent: Color, y: float, hh: float = 70.0) -> float:
	var w := _loadout_w()
	var p := Panel.new()
	p.position = Vector2(16, y); p.size = Vector2(w - 32, hh)
	var sb := Design.card_box(Design.PAPER, 3, 12); sb.border_color = accent
	p.add_theme_stylebox_override("panel", sb)
	_loadout.add_child(p)
	var lab := Design.label(label, "caption", accent.darkened(0.12)); lab.position = Vector2(12, 6); p.add_child(lab)
	var v := Design.label(value, "body", Design.INK); v.position = Vector2(12, 28); v.size = Vector2(w - 56, hh - 30); p.add_child(v)
	return y + hh + 10.0


func _power() -> int:
	var st: Dictionary = GameState.JOB_STATS[GameState.selected_job]
	var m := GameState.level_mult()
	var v := (float(st["hp"]) + (float(st["ranged"]) + float(st["near"])) * 6.0 + float(st["crit"]) * 200.0) * m
	v += GameState.equipped_for(GameState.selected_job).size() * 40.0
	if GameState.equipped_companion != "": v += 100.0
	for s in GameState.item_slots:
		if s != "": v += 20.0
	return int(round(v))


func _detail_w() -> float: return 612.0
func _detail_h() -> float: return _vp.y - 84.0 - 24.0
func _loadout_w() -> float: return _vp.x - (24.0 + 392.0 + 20.0 + 612.0 + 20.0) - 24.0
func _loadout_h() -> float: return _vp.y - 84.0 - 24.0

func _stars(g: int) -> String:
	return "★".repeat(clampi(g, 0, 5))

func _dlabel(text: String, kind: String, col: Color, y: float) -> Label:
	var l := Design.label(text, kind, col)
	l.position = Vector2(40, y); l.size = Vector2(_detail_w() - 80, 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _commafy(n: int) -> String:
	var s := str(n); var out := ""; var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out; c += 1
		if c % 3 == 0 and i > 0: out = "," + out
	return out

var _toast_lbl: Label
func _toast(msg: String) -> void:
	if _toast_lbl == null:
		_toast_lbl = Design.label("", "title", Design.INK_CREAM)
		_toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_toast_lbl.size = Vector2(_vp.x * 0.6, 48); _toast_lbl.position = Vector2(_vp.x * 0.2, _vp.y * 0.42)
		_toast_lbl.add_theme_stylebox_override("normal", Design.card_box(Design.RED, 3, 10))
		add_child(_toast_lbl)
	_toast_lbl.text = msg
	_toast_lbl.visible = true
	_toast_lbl.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(_toast_lbl, "modulate:a", 0.0, 0.4)


func _process(delta: float) -> void:
	if _center_art == null or _cat != "job" or _sel == "": return
	var job: String = _sel.split(":")[0]
	if not _sf.has(job): return
	var sf: SpriteFrames = _sf[job]
	var n := sf.get_frame_count("idle")
	if n <= 0: return
	_t += delta
	if _t >= 1.0 / IDLE_FPS:
		_t = 0.0
		_frame = (_frame + 1) % n
		_center_art.texture = sf.get_frame_texture("idle", _frame)
