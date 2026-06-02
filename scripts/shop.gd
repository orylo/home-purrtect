extends Control
## 맥스의 상점 (로드맵 4단계) — 코인을 쓰는 곳. 탭 구조.
##   [레벨업] 직업 Lv↑ / [소모품] 붕대·멸치·폭죽 / [전리품 매입] 재료 팔기 / [제작] 메이드·음악가
##   진입: 홈 [맥스 상점]. 나가기: [← 홈].

const FONT := preload("res://assets/fonts/Pretendard-Regular.ttf")
const BG := preload("res://assets/backgrounds/stage1_wall.jpg")
const ORANGE := Color(0.9882, 0.3137, 0.0)
const DARK := Color(0.12, 0.12, 0.16)
const GOLD := Color(1.0, 0.82, 0.2)
const ITEM_ORDER := ["bandage", "anchovy", "firecracker"]
const TABS := [
	{"id": "level", "name": "레벨업"},
	{"id": "skill", "name": "스킬"},
	{"id": "companion", "name": "동료"},
	{"id": "item", "name": "소모품"},
	{"id": "sell", "name": "전리품 매입"},
	{"id": "craft", "name": "직업 제작"},
]

var _coin_lbl: Label
var _tab := "level"
var _tab_btns := {}
var _panes := {}        # tab id -> 콘텐츠 Control
# 레벨업 탭
var _job_lbl: Label
var _lv_lbl: Label
var _buy_btn: Button
# 소모품 탭
var _inv_lbls := {}
var _item_btns := {}
# 동적 탭 컨테이너
var _sell_box: VBoxContainer
var _craft_box: VBoxContainer
var _skill_box: VBoxContainer
var _comp_box: VBoxContainer
var _toast: Label
var _toast_t := 0.0
var _content_rect: Rect2


func _ready() -> void:
	_build()
	_set_tab("level")


func _build() -> void:
	var vp := get_viewport().get_visible_rect().size
	_content_rect = Rect2(Vector2(vp.x * 0.5 - 420, 180), Vector2(840, vp.y - 320))

	var bg := TextureRect.new()
	bg.texture = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.modulate = Color(0.5, 0.5, 0.55)
	add_child(bg)

	var title := _text("맥스의 상점", 40, Color(1, 1, 1))
	title.position = Vector2(40, 24)
	add_child(title)
	_coin_lbl = _text("", 30, GOLD)
	_coin_lbl.position = Vector2(vp.x - 340, 30)
	_coin_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_coin_lbl.size = Vector2(300, 40)
	add_child(_coin_lbl)

	_build_tabbar(vp)

	# 콘텐츠 패널(공통 배경) + 각 탭 컨테이너
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", Style.panel_box(Style.PAPER, 5, 16))
	frame.position = _content_rect.position - Vector2(20, 20)
	frame.size = _content_rect.size + Vector2(40, 40)
	add_child(frame)

	_build_level_pane()
	_build_skill_pane()
	_build_companion_pane()
	_build_item_pane()
	_build_sell_pane()
	_build_craft_pane()

	_solid_btn("← 홈", Vector2(40, vp.y - 112), Vector2(200, 80), Style.PAPER, 30,
			func(): get_tree().change_scene_to_file("res://scenes/home.tscn"))

	_toast = _text("", 30, Style.INK)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.size = Vector2(vp.x, 50)
	_toast.position = Vector2(0, vp.y - 170)
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_toast.add_theme_constant_override("outline_size", 5)
	_toast.visible = false
	add_child(_toast)


func _build_tabbar(vp: Vector2) -> void:
	var n := TABS.size()
	var sep := 8
	var bw := 138
	var total := n * bw + (n - 1) * sep
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", sep)
	bar.position = Vector2(vp.x * 0.5 - total * 0.5, 100)
	add_child(bar)
	for t in TABS:
		var b := Style.button(t["name"], "paper", Style.FS_BODY)
		b.custom_minimum_size = Vector2(bw, 56)
		b.pressed.connect(_set_tab.bind(t["id"]))
		bar.add_child(b)
		_tab_btns[t["id"]] = b


func _new_pane(id: String) -> Control:
	var p := Control.new()
	p.position = _content_rect.position
	p.size = _content_rect.size
	p.visible = false
	add_child(p)
	_panes[id] = p
	return p


# --- 레벨업 탭 ---
func _build_level_pane() -> void:
	var p := _new_pane("level")
	var head := _text("직업 레벨업", 32, ORANGE)
	head.position = Vector2(20, 16)
	p.add_child(head)
	_job_lbl = _text("", 30, Color(1, 1, 1))
	_job_lbl.position = Vector2(20, 78)
	p.add_child(_job_lbl)
	_lv_lbl = _text("", 26, Color(0.85, 0.85, 0.9))
	_lv_lbl.position = Vector2(20, 128)
	p.add_child(_lv_lbl)
	_buy_btn = Button.new()
	_buy_btn.position = Vector2(20, 196)
	_buy_btn.custom_minimum_size = Vector2(800, 72)
	_font(_buy_btn, 32)
	_btn_colors(_buy_btn, ORANGE)
	_buy_btn.pressed.connect(_on_buy_levelup)
	p.add_child(_buy_btn)


# --- 소모품 탭 ---
func _build_item_pane() -> void:
	var p := _new_pane("item")
	for i in range(ITEM_ORDER.size()):
		_item_card(p, ITEM_ORDER[i], Vector2(20 + i * 270, 20))


func _item_card(parent: Control, id: String, pos: Vector2) -> void:
	var def: Dictionary = GameState.CONSUMABLES.get(id, {})
	var card := Panel.new()
	card.add_theme_stylebox_override("panel", _card_sb())
	card.position = pos
	card.size = Vector2(250, 200)
	parent.add_child(card)
	var nm := _text(String(def.get("name", id)), 28, Color(1, 1, 1))
	nm.position = Vector2(16, 14)
	card.add_child(nm)
	var ds := _text(String(def.get("desc", "")), 20, Color(0.8, 0.85, 0.9))
	ds.position = Vector2(16, 54)
	card.add_child(ds)
	var inv := _text("", 22, GOLD)
	inv.position = Vector2(16, 92)
	card.add_child(inv)
	_inv_lbls[id] = inv
	var b := Button.new()
	b.position = Vector2(16, 130)
	b.custom_minimum_size = Vector2(218, 54)
	_font(b, 26)
	_btn_colors(b, ORANGE)
	b.pressed.connect(_on_buy_consumable.bind(id))
	card.add_child(b)
	_item_btns[id] = b


# --- 전리품 매입 탭(동적) ---
func _build_sell_pane() -> void:
	var p := _new_pane("sell")
	var head := _text("전리품 매입 (팔아서 코인)", 30, ORANGE)
	head.position = Vector2(20, 12)
	p.add_child(head)
	var sc := ScrollContainer.new()
	sc.position = Vector2(20, 64)
	sc.size = Vector2(800, _content_rect.size.y - 80)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	_sell_box = VBoxContainer.new()
	_sell_box.add_theme_constant_override("separation", 8)
	_sell_box.custom_minimum_size = Vector2(780, 0)
	sc.add_child(_sell_box)


func _rebuild_sell() -> void:
	for c in _sell_box.get_children():
		c.queue_free()
	var any := false
	for id in GameState.MAT_ORDER:
		var n: int = GameState.mat_count(id)
		if n <= 0:
			continue
		any = true
		var def: Dictionary = GameState.MATERIALS[id]
		var row := Panel.new()
		row.add_theme_stylebox_override("panel", _card_sb())
		row.custom_minimum_size = Vector2(770, 64)
		_sell_box.add_child(row)
		var lbl := _text("%s  ×%d   (개당 %d코인)" % [String(def["name"]), n, int(def["sell"])], 24, Color(1, 1, 1))
		lbl.position = Vector2(16, 16)
		row.add_child(lbl)
		var b1 := Button.new()
		b1.position = Vector2(530, 8)
		b1.custom_minimum_size = Vector2(110, 48)
		_font(b1, 22); _btn_colors(b1, ORANGE)
		b1.text = "팔기"
		b1.pressed.connect(_on_sell.bind(id, 1))
		row.add_child(b1)
		var b2 := Button.new()
		b2.position = Vector2(648, 8)
		b2.custom_minimum_size = Vector2(110, 48)
		_font(b2, 22); _btn_colors(b2, Color(0.35, 0.3, 0.2))
		b2.text = "전량"
		b2.pressed.connect(_on_sell.bind(id, -1))
		row.add_child(b2)
	if not any:
		var empty := _text("팔 전리품이 없어요. 전투에서 적을 처치하면 모입니다.", 24, Color(1, 1, 1, 0.7))
		_sell_box.add_child(empty)


# --- 스킬 탭(동적, 현재 선택 직업 기준) ---
func _build_skill_pane() -> void:
	var p := _new_pane("skill")
	var head := _text("스킬 구매 (현재 직업 전용 · §4.2)", 30, ORANGE)
	head.position = Vector2(20, 12)
	p.add_child(head)
	_skill_box = VBoxContainer.new()
	_skill_box.add_theme_constant_override("separation", 12)
	_skill_box.position = Vector2(20, 60)
	_skill_box.custom_minimum_size = Vector2(800, 0)
	p.add_child(_skill_box)


func _rebuild_skill() -> void:
	for c in _skill_box.get_children():
		c.queue_free()
	var job: String = GameState.selected_job
	if job == "base":
		var none := _text("맨몸(길냥이)은 구매 스킬이 없어요. 고유기 '냥냥펀치'만 (§4.1)\n전투 준비에서 직업을 골라 보세요.", 24, Color(1, 1, 1, 0.8))
		_skill_box.add_child(none)
		return
	# 해당 직업 스킬 3개를 order 순으로
	var ids: Array = []
	for sid in GameState.SKILLS:
		if GameState.SKILLS[sid]["job"] == job:
			ids.append(sid)
	ids.sort_custom(func(a, b): return int(GameState.SKILLS[a]["order"]) < int(GameState.SKILLS[b]["order"]))
	for sid in ids:
		var s: Dictionary = GameState.SKILLS[sid]
		var card := Panel.new()
		card.add_theme_stylebox_override("panel", _card_sb())
		card.custom_minimum_size = Vector2(800, 116)
		_skill_box.add_child(card)
		var nm := _text("%d번째  %s   (CD %ds)" % [int(s["order"]), String(s["name"]), int(s["cd"])], 26, Color(1, 1, 1))
		nm.position = Vector2(16, 10)
		card.add_child(nm)
		var ds := _text(String(s["desc"]), 21, Color(0.82, 0.88, 0.95))
		ds.position = Vector2(16, 50)
		card.add_child(ds)
		var b := Button.new()
		b.position = Vector2(560, 30)
		b.custom_minimum_size = Vector2(224, 56)
		_font(b, 24)
		if GameState.owns_skill(sid):
			_btn_colors(b, Color(0.3, 0.4, 0.3)); b.text = "보유 완료"; b.disabled = true
		elif int(s["order"]) >= 3:
			_btn_colors(b, Color(0.35, 0.3, 0.45)); b.text = "2막 라쿤"; b.disabled = true
		else:
			_btn_colors(b, ORANGE); b.text = "구매 (%d)" % int(s["price"])
			b.disabled = not GameState.can_buy_skill(sid)
			b.pressed.connect(_on_buy_skill.bind(sid))
		card.add_child(b)


# --- 동료 탭(동적, §5.5-B) ---
func _build_companion_pane() -> void:
	var p := _new_pane("companion")
	var head := _text("동료 호루라기 구매 (슬롯 1 · 매 판 택1)", 30, ORANGE)
	head.position = Vector2(20, 12)
	p.add_child(head)
	_comp_box = VBoxContainer.new()
	_comp_box.add_theme_constant_override("separation", 14)
	_comp_box.position = Vector2(20, 64)
	_comp_box.custom_minimum_size = Vector2(800, 0)
	p.add_child(_comp_box)


func _rebuild_companion() -> void:
	for c in _comp_box.get_children():
		c.queue_free()
	for cid in GameState.COMPANION_ORDER:
		var cdef: Dictionary = GameState.COMPANIONS[cid]
		var card := Panel.new()
		card.add_theme_stylebox_override("panel", _card_sb())
		card.custom_minimum_size = Vector2(800, 116)
		_comp_box.add_child(card)
		var nm := _text("%s   (CD %ds · 만남 1-%d)" % [String(cdef["name"]), int(cdef["cd"]), int(cdef["meet"])], 26, Color(1, 1, 1))
		nm.position = Vector2(16, 10)
		card.add_child(nm)
		var ds := _text(String(cdef["desc"]), 21, Color(0.82, 0.88, 0.95))
		ds.position = Vector2(16, 50)
		card.add_child(ds)
		var b := Button.new()
		b.position = Vector2(560, 30)
		b.custom_minimum_size = Vector2(224, 56)
		_font(b, 24)
		if GameState.owns_companion(cid):
			_btn_colors(b, Color(0.3, 0.4, 0.3)); b.text = "보유 완료"; b.disabled = true
		else:
			_btn_colors(b, ORANGE); b.text = "구매 (%d)" % int(cdef["price"])
			b.disabled = not GameState.can_buy_companion(cid)
			b.pressed.connect(_on_buy_companion.bind(cid))
		card.add_child(b)


func _on_buy_companion(cid: String) -> void:
	if GameState.buy_companion(cid):
		_toast_msg("%s 호루라기 구매! 전투 준비 [동료]에서 장착" % String(GameState.COMPANIONS[cid]["name"]))
		_rebuild_companion()
		_refresh()
	else:
		_toast_msg("코인이 부족해요 (%d)" % int(GameState.COMPANIONS[cid]["price"]))


# --- 직업 제작 탭(동적) ---
func _build_craft_pane() -> void:
	var p := _new_pane("craft")
	var head := _text("직업 제작 (재료 + 코인)", 30, ORANGE)
	head.position = Vector2(20, 12)
	p.add_child(head)
	_craft_box = VBoxContainer.new()
	_craft_box.add_theme_constant_override("separation", 16)
	_craft_box.position = Vector2(20, 64)
	_craft_box.custom_minimum_size = Vector2(800, 0)
	p.add_child(_craft_box)


func _rebuild_craft() -> void:
	for c in _craft_box.get_children():
		c.queue_free()
	for job in GameState.CRAFT_RECIPES:
		var r: Dictionary = GameState.CRAFT_RECIPES[job]
		var card := Panel.new()
		card.add_theme_stylebox_override("panel", _card_sb())
		card.custom_minimum_size = Vector2(800, 150)
		_craft_box.add_child(card)
		var nm := _text(String(r["name"]), 28, Color(1, 1, 1))
		nm.position = Vector2(16, 12)
		card.add_child(nm)
		# 재료 요구 + 보유
		var parts: Array = []
		for mid in r["mats"]:
			var need: int = int(r["mats"][mid])
			var have: int = GameState.mat_count(mid)
			parts.append("%s %d/%d" % [String(GameState.MATERIALS[mid]["name"]), have, need])
		parts.append("코인 %d/%d" % [GameState.coins, int(r["coin"])])
		var req := _text("  ·  ".join(parts), 22, Color(0.85, 0.88, 0.95))
		req.position = Vector2(16, 56)
		card.add_child(req)
		var b := Button.new()
		b.position = Vector2(16, 92)
		b.custom_minimum_size = Vector2(768, 48)
		_font(b, 26)
		if GameState.is_job_unlocked(job):
			_btn_colors(b, Color(0.3, 0.4, 0.3))
			b.text = "이미 보유한 직업"
			b.disabled = true
		else:
			_btn_colors(b, ORANGE)
			b.text = "제작"
			b.disabled = not GameState.can_craft_job(job)
			b.pressed.connect(_on_craft.bind(job))
		card.add_child(b)


# --- 탭 전환 ---
func _set_tab(tab: String) -> void:
	_tab = tab
	for id in _tab_btns:
		Style.style_button(_tab_btns[id], "cheese" if id == tab else "paper", Style.FS_BODY)
	for id in _panes:
		_panes[id].visible = (id == tab)
	if tab == "sell":
		_rebuild_sell()
	elif tab == "craft":
		_rebuild_craft()
	elif tab == "skill":
		_rebuild_skill()
	elif tab == "companion":
		_rebuild_companion()
	_refresh()


# --- 갱신(정적 탭) ---
func _refresh() -> void:
	_coin_lbl.text = "코인 " + _commafy(GameState.coins)
	var job: String = GameState.selected_job
	var lv := int(GameState.job_level.get(job, 1))
	_job_lbl.text = "%s   ·   %s" % [GameState.job_title(job), GameState.rank_label(job)]
	var cost := GameState.levelup_cost(job)
	if cost <= 0:
		_lv_lbl.text = "Lv %d — 최고 레벨 (전투력 배율 ×%.1f)" % [lv, GameState.level_mult(job)]
		_buy_btn.text = "최고 레벨 도달"
		_buy_btn.disabled = true
	else:
		var next_mult: float = GameState.LV_MULT[clampi(lv, 0, 4)]
		_lv_lbl.text = "Lv %d → Lv %d   (전투력 배율 ×%.1f → ×%.1f)" % [lv, lv + 1, GameState.level_mult(job), next_mult]
		_buy_btn.text = "레벨업  —  %s 코인" % _commafy(cost)
		_buy_btn.disabled = not GameState.can_levelup(job)
	for id in _inv_lbls.keys():
		_inv_lbls[id].text = "보유 %d" % int(GameState.inventory.get(id, 0))
		_item_btns[id].text = "구매 (%d)" % GameState.consumable_price(id)
		_item_btns[id].disabled = not GameState.can_buy_consumable(id)


# --- 버튼 핸들러 ---
func _on_buy_levelup() -> void:
	var job: String = GameState.selected_job
	if GameState.do_levelup(job):
		_toast_msg("레벨업! %s" % GameState.job_title(job))
		_refresh()
	else:
		_toast_msg("코인이 부족해요 (%s 필요)" % _commafy(GameState.levelup_cost(job)))

func _on_buy_consumable(id: String) -> void:
	if GameState.buy_consumable(id):
		_toast_msg("%s 구매!" % String(GameState.CONSUMABLES[id]["name"]))
		_refresh()
	else:
		_toast_msg("코인 부족 (%s 코인)" % _commafy(GameState.consumable_price(id)))

func _on_sell(id: String, n: int) -> void:
	var gain := GameState.sell_material(id, n)
	if gain > 0:
		_toast_msg("+%s 코인" % _commafy(gain))
		_rebuild_sell()
		_refresh()

func _on_buy_skill(sid: String) -> void:
	if GameState.buy_skill(sid):
		_toast_msg("%s 구매! 전투 준비에서 장착" % String(GameState.SKILLS[sid]["name"]))
		_rebuild_skill()
		_refresh()
	else:
		_toast_msg("코인이 부족해요 (%d)" % int(GameState.SKILLS[sid]["price"]))


func _on_craft(job: String) -> void:
	if GameState.craft_job(job):
		_toast_msg("%s 제작 완료! 전투 준비에서 선택 가능" % String(GameState.CRAFT_RECIPES[job]["name"]))
		_rebuild_craft()
		_refresh()
	else:
		_toast_msg("재료나 코인이 부족해요")


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0 and _toast:
			_toast.visible = false

func _toast_msg(msg: String) -> void:
	if _toast == null:
		return
	_toast.text = msg
	_toast.visible = true
	_toast_t = 1.8


# --- helpers (design.md 토큰 라우팅) ---
## 크림 패널 위라 밝은색(흰계열)→잉크, ORANGE→빨강, GOLD→머스타드로 리맵
func _ink(col: Color) -> Color:
	if col == ORANGE:
		return Style.RED
	if col == GOLD:
		return Style.CHEESE_DEEP
	if col.v > 0.78 and col.s < 0.25:
		return Style.INK
	return col

func _text(s: String, fs: int, col: Color) -> Label:
	var kind := "title" if fs >= 30 else ("caption" if fs <= 18 else "body")
	return Style.label(s, kind, _ink(col))

## 버튼 폰트/기본 스타일(크림) — 호출부 호환용 래퍼
func _font(b: Button, fs: int) -> void:
	Style.style_button(b, "paper", fs)

## bg로 버튼 종류 추론 후 Style 재적용
func _btn_colors(b: Button, bg: Color) -> void:
	var fs := int(b.get_theme_font_size("font_size"))
	Style.style_button(b, "cta" if bg == ORANGE else "paper", fs if fs > 0 else Style.FS_BODY)

func _card_sb() -> StyleBoxFlat:
	return Style.card_box(Style.PAPER, 3, 10)

func _solid_btn(label: String, pos: Vector2, sz: Vector2, bg: Color, fs: int, fn: Callable) -> void:
	var b := Style.button(label, "cta" if bg == ORANGE else "paper", fs)
	b.position = pos
	b.custom_minimum_size = sz
	b.size = sz
	b.pressed.connect(fn)
	add_child(b)

func _commafy(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out
