extends CanvasLayer
## DEV 전용 인게임 디버그 오버레이 — 좌상단 🐞 버튼으로 패널 토글.
## 게임 진행 중에 스테이지 점프 / 직업 변경 / 특정 적 스폰 / 치트.

const FONT := preload("res://assets/fonts/Pretendard-Regular.ttf")
const ENEMY_SCENE := preload("res://scenes/enemy_mouse.tscn")
## 스폰 버튼 순서(적 10종)
const SPAWN_ORDER := [
	"gray", "gray_roller", "gray_thrower",
	"black", "black_roller", "black_thrower",
	"bat", "sparrow", "bee", "spider",
]

var _panel: PanelContainer


func _ready() -> void:
	if not GameState.is_dev() or GameState.mode != "dev":
		queue_free()      # 개발자 모드(dev)에서만 표시 — 플레이어 모드/출시 빌드엔 안 뜸
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

	# 2칼럼: 세로로 덜 길게(아래 HUD까지 안 내려오게)
	_panel = PanelContainer.new()
	_panel.position = Vector2(10, 150)
	_panel.visible = false
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	_panel.add_child(cols)
	add_child(_panel)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 5)
	left.custom_minimum_size = Vector2(210, 0)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 5)
	right.custom_minimum_size = Vector2(210, 0)
	cols.add_child(left)
	cols.add_child(right)

	# === 왼쪽 칼럼: 치트 + 스테이지 이동 ===
	_sec(left, "치트")
	_btn(left, "코인 +1000", func(): GameState.coins += 1000)
	_btn(left, "무적 토글", func(): GameState.cheats["godmode"] = not GameState.cheats.get("godmode", false))
	_btn(left, "적 즉사 토글", func(): GameState.cheats["enemy_oneshot"] = not GameState.cheats.get("enemy_oneshot", false))
	_btn(left, "적 전멸", _kill_all)

	_sec(left, "스테이지 이동")
	var srow := HBoxContainer.new()
	var spin := SpinBox.new()
	spin.min_value = 1
	spin.max_value = 20
	spin.value = GameState.stage_minor
	spin.custom_minimum_size = Vector2(90, 0)
	srow.add_child(spin)
	var go := Button.new()
	go.text = "이동"
	_font(go, 18)
	go.pressed.connect(func():
		GameState.sandbox = false
		GameState.stage_minor = int(spin.value)
		get_tree().reload_current_scene())
	srow.add_child(go)
	left.add_child(srow)
	_btn(left, "다음 스테이지 ▶", func():
		GameState.sandbox = false
		GameState.advance_stage()
		get_tree().reload_current_scene())

	# === 오른쪽 칼럼: 직업 변경 + 적 스폰 ===
	_sec(right, "직업 변경(재시작)")
	var jgrid := GridContainer.new()
	jgrid.columns = 2
	for j in [["base", "맨몸"], ["sheriff", "보안관"], ["maid", "메이드"], ["jazz", "음악가"]]:
		var jb := Button.new()
		jb.text = j[1]
		_font(jb, 18)
		var jid: String = j[0]
		jb.pressed.connect(func():
			GameState.selected_job = jid
			get_tree().reload_current_scene())
		jgrid.add_child(jb)
	right.add_child(jgrid)

	_sec(right, "적 스폰")
	var egrid := GridContainer.new()
	egrid.columns = 2
	for id in SPAWN_ORDER:
		var eb := Button.new()
		eb.text = String(Enemies.def_of(id).get("name", id))
		_font(eb, 16)
		var eid: String = id
		eb.pressed.connect(func(): _spawn(eid))
		egrid.add_child(eb)
	right.add_child(egrid)


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
	l.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
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
