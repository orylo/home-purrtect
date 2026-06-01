extends CanvasLayer
## DEV 전용 인게임 디버그 오버레이 — 좌상단 🐞 버튼으로 패널 토글.
## 게임 진행 중에 스테이지 점프 / 직업 변경 / 특정 적 스폰 / 치트.

const FONT := preload("res://assets/fonts/DoHyeon-Regular.ttf")
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
	# 좌측 절반은 조이스틱(점프) 영역이라, 패널을 화면 오른쪽 절반으로 띄움(터치 충돌 방지)
	var px := get_viewport().get_visible_rect().size.x * 0.5 + 30.0

	var btn := Button.new()
	btn.text = "🐞"
	btn.position = Vector2(px, 96)
	_font(btn, 24)
	btn.pressed.connect(func(): _panel.visible = not _panel.visible)
	add_child(btn)

	_panel = PanelContainer.new()
	_panel.position = Vector2(px, 146)
	_panel.visible = false
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(250, 560)
	_panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	scroll.add_child(box)
	add_child(_panel)

	# --- 치트 ---
	_sec(box, "치트")
	_btn(box, "코인 +1000", func(): GameState.coins += 1000)
	_btn(box, "무적 토글", func(): GameState.cheats["godmode"] = not GameState.cheats.get("godmode", false))
	_btn(box, "적 즉사 토글", func(): GameState.cheats["enemy_oneshot"] = not GameState.cheats.get("enemy_oneshot", false))
	_btn(box, "적 전멸", _kill_all)

	# --- 스테이지 이동(진행 중에도) ---
	_sec(box, "스테이지 이동")
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
	box.add_child(srow)
	_btn(box, "다음 스테이지 ▶", func():
		GameState.sandbox = false
		GameState.advance_stage()
		get_tree().reload_current_scene())

	# --- 직업 변경(현재 판 재시작) ---
	_sec(box, "직업 변경(재시작)")
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
	box.add_child(jgrid)

	# --- 적 스폰(현재 판에 바로) ---
	_sec(box, "적 스폰")
	var egrid := GridContainer.new()
	egrid.columns = 2
	for id in SPAWN_ORDER:
		var eb := Button.new()
		eb.text = String(Enemies.def_of(id).get("name", id))
		_font(eb, 16)
		var eid: String = id
		eb.pressed.connect(func(): _spawn(eid))
		egrid.add_child(eb)
	box.add_child(egrid)


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
