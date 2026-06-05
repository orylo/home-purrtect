extends CanvasLayer
## DEV 전용 인게임 디버그 오버레이 - 좌상단 🐞 버튼으로 패널 토글.
## 게임 진행 중에 스테이지 점프 / 직업 변경 / 특정 적 스폰 / 치트.

const FONT := preload("res://assets/fonts/SBAggro-Medium.ttf")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
# 가독성 토큰 - 어두운 패널 + 밝은 크림 버튼 + 진한 잉크 글씨(밝은 게임화면 위에서도 또렷).
const BG_PANEL := Color("17140F")    # 어두운 패널
const PAPER := Color("F3E3BE")       # 크림 버튼 바탕
const PAPER_HI := Color("FBEFCF")    # 버튼 호버
const INK := Color("241F1B")         # 진한 글씨
const GOLD := Color("E0A53B")        # 헤더·강조
const REDC := Color("E45A45")        # ON 상태 강조
## 스폰 버튼 순서(적 10종)
const SPAWN_ORDER := [
	"gray", "gray_roller", "gray_thrower",
	"black", "black_roller", "black_thrower",
	"bat", "sparrow", "bee", "spider",
]

var _panel: PanelContainer


func _ready() -> void:
	if not GameState.is_dev() or GameState.mode != "dev":
		queue_free()      # 개발자 모드(dev)에서만 표시 - 플레이어 모드/출시 빌드엔 안 뜸
		return
	layer = 100
	_build_ui()


func _build_ui() -> void:
	var btn := Button.new()
	btn.text = "버그"   # (이모지는 폰트에 없어 텍스트로)
	btn.position = Vector2(10, 100)      # 원위치(좌상단)
	_font(btn, 24)
	btn.pressed.connect(func(): _panel.visible = not _panel.visible)
	add_child(btn)

	# 가로로 넓고 낮게(상단 띠) - 하단 게임영역(치즈·조작)이 안 가려지게. 반투명(게임 비침).
	_panel = PanelContainer.new()
	_panel.position = Vector2(10, 58)
	_panel.visible = false
	_panel.add_theme_stylebox_override("panel", _box(Color(BG_PANEL.r, BG_PANEL.g, BG_PANEL.b, 0.42), GOLD, 8))
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 12)
	_panel.add_child(cols)
	add_child(_panel)
	# 디버그 버튼/패널 위 터치는 게임(조이스틱 점프 등)으로 새지 않게 차단 등록
	Touch.register_block(btn)
	Touch.register_block(_panel)

	# 4칼럼(가로로 길게): 치트 / 전투·스킬 / 스테이지·직업 / 스폰
	var c1 := _col(cols)
	var c2 := _col(cols)
	var c3 := _col(cols)
	var c4 := _col(cols)

	# === c1: 치트 ===
	_sec(c1, "치트")
	_btn(c1, "코인 +1000", func(): GameState.coins += 1000)
	_btn(c1, "무적 토글", func(): GameState.cheats["godmode"] = not GameState.cheats.get("godmode", false))
	_btn(c1, "침입자 즉사 토글", func(): GameState.cheats["enemy_oneshot"] = not GameState.cheats.get("enemy_oneshot", false))
	_btn(c1, "침입자 전멸", _kill_all)

	# === c2: 전투 진행 + 스킬/동료 ===
	_sec(c2, "전투 진행")
	# 이벤트 스킵(전투만) - 토글. ON이면 인트로/클리어·게임오버 컷씬 전부 생략(인트로는 다음 스테이지 진입부터 적용).
	var ev := Button.new()
	var ev_upd := func():
		var on: bool = GameState.cheats.get("skip_events", false)
		ev.text = "이벤트 스킵(전투만): " + ("ON" if on else "OFF")
		ev.add_theme_color_override("font_color", REDC if on else INK)
	ev_upd.call()
	_font(ev, 16)
	ev.pressed.connect(func():
		GameState.cheats["skip_events"] = not GameState.cheats.get("skip_events", false)
		ev_upd.call())
	c2.add_child(ev)
	# 웨이브 건너뛰기 - 현재 웨이브 즉시 종료 → 다음 웨이브(또는 클리어).
	_btn(c2, "웨이브 건너뛰기 ⏭", func():
		var sp: Node = get_parent().get_node_or_null("Spawner")
		if sp != null and sp.has_method("dev_skip_wave"):
			sp.dev_skip_wave())
	_sec(c2, "스킬/동료(전투 중)")
	_btn(c2, "스킬 지급+장착", func(): GameState.dev_grant_skills())
	_btn(c2, "동료 지급+장착", func(): GameState.dev_grant_companions())

	# === c3: 스테이지 이동 + 직업 변경 ===
	_sec(c3, "스테이지 이동")
	var srow := HBoxContainer.new()
	var spin := SpinBox.new()
	spin.min_value = 1
	spin.max_value = 20
	spin.value = GameState.stage_minor
	spin.custom_minimum_size = Vector2(84, 0)
	_font(spin, 16)   # 값 글자 INK(안 그러면 흰 글씨로 안 보임)
	srow.add_child(spin)
	var go := Button.new()
	go.text = "이동"
	_font(go, 16)
	go.pressed.connect(func():
		GameState.sandbox = false
		GameState.stage_minor = int(spin.value)
		get_tree().reload_current_scene())
	srow.add_child(go)
	c3.add_child(srow)
	_btn(c3, "다음 스테이지 ▶", func():
		GameState.sandbox = false
		GameState.advance_stage()
		get_tree().reload_current_scene())
	_sec(c3, "직업 변경(재시작)")
	var jgrid := GridContainer.new()
	jgrid.columns = 2
	for j in [["base", "맨몸"], ["sheriff", "보안관"], ["maid", "메이드"], ["jazz", "음악가"]]:
		var jb := Button.new()
		jb.text = j[1]
		_font(jb, 16)
		var jid: String = j[0]
		jb.pressed.connect(func():
			GameState.dev_set_job(jid, maxi(1, GameState.equipped_grade))   # 현재 등급 유지하며 직업 교체
			get_tree().reload_current_scene())
		jgrid.add_child(jb)
	c3.add_child(jgrid)

	# === c4: 침입자 스폰(5열 × 2행, 가로로) ===
	_sec(c4, "침입자 스폰")
	var egrid := GridContainer.new()
	egrid.columns = 5
	for id in SPAWN_ORDER:
		var eb := Button.new()
		eb.text = String(Enemies.def_of(id).get("name", id))
		_font(eb, 14)
		var eid: String = id
		eb.pressed.connect(func(): _spawn(eid))
		egrid.add_child(eb)
	c4.add_child(egrid)


## 적 한 마리를 화면 오른쪽 밖에서 등장(스포너와 동일 위치)
func _spawn(id: String) -> void:
	var e := ENEMY_SCENE.instantiate()
	e.def = Enemies.def_of(id)
	e.position = Vector2(get_viewport().get_visible_rect().size.x + 140.0, Layout.ground_y())
	get_parent().add_child(e)


func _kill_all() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("take_damage"):
			e.take_damage(999999.0)


# --- helpers ---
func _sec(box: VBoxContainer, text: String) -> void:
	box.add_child(HSeparator.new())
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", 16)
	# 섹션 헤더 = 골드(어두운 패널 위 또렷).
	l.add_theme_color_override("font_color", GOLD)
	box.add_child(l)


func _btn(box: VBoxContainer, label: String, fn: Callable) -> void:
	var b := Button.new()
	b.text = label
	_font(b, 18)
	b.pressed.connect(fn)
	box.add_child(b)


func _font(c: Control, fs: int) -> void:
	c.add_theme_font_override("font", FONT)
	c.add_theme_font_size_override("font_size", fs)
	c.add_theme_color_override("font_color", INK)
	if c is Button:
		# 버튼 = 크림 바탕 + 잉크 글씨(모든 상태) → 밝은 게임화면 위에서도 또렷.
		c.add_theme_color_override("font_color", INK)
		c.add_theme_color_override("font_hover_color", INK)
		c.add_theme_color_override("font_pressed_color", INK)
		c.add_theme_color_override("font_focus_color", INK)
		c.add_theme_stylebox_override("normal", _box(PAPER, INK, 6))
		c.add_theme_stylebox_override("hover", _box(PAPER_HI, INK, 6))
		c.add_theme_stylebox_override("pressed", _box(GOLD, INK, 6))
		c.add_theme_stylebox_override("focus", _box(PAPER, INK, 6))
	elif c is SpinBox:
		var le := (c as SpinBox).get_line_edit()
		le.add_theme_font_override("font", FONT)
		le.add_theme_font_size_override("font_size", fs)
		le.add_theme_color_override("font_color", INK)
		le.add_theme_stylebox_override("normal", _box(PAPER, INK, 6))
		le.add_theme_stylebox_override("focus", _box(PAPER_HI, INK, 6))


## 가로 배치용 세로 칼럼.
func _col(parent: Node) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.custom_minimum_size = Vector2(166, 0)
	parent.add_child(v)
	return v


## 디버그 UI용 스타일박스(바탕+테두리). 작은 패딩.
func _box(bg: Color, border: Color, radius: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(2)
	s.border_color = border
	s.set_corner_radius_all(radius)
	s.content_margin_left = 8.0
	s.content_margin_right = 8.0
	s.content_margin_top = 4.0
	s.content_margin_bottom = 4.0
	return s
