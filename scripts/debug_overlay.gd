extends CanvasLayer
## DEV 전용 인게임 디버그 오버레이 — 🐞 버튼으로 패널 토글.
## 시스템(상점·NPC·스킬·아이템)이 생기면 여기에 버튼만 추가하면 됨.

const FONT := preload("res://assets/fonts/DoHyeon-Regular.ttf")
var _panel: PanelContainer


func _ready() -> void:
	if not GameState.is_dev():
		queue_free()      # 출시 빌드: 아예 없음
		return
	layer = 100
	_build_ui()


func _build_ui() -> void:
	var btn := Button.new()
	btn.text = "🐞"
	btn.position = Vector2(10, 100)
	btn.add_theme_font_override("font", FONT)
	btn.add_theme_font_size_override("font_size", 24)
	btn.pressed.connect(func(): _panel.visible = not _panel.visible)
	add_child(btn)

	_panel = PanelContainer.new()
	_panel.position = Vector2(10, 150)
	_panel.visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)
	add_child(_panel)

	_add(box, "코인 +1000", func(): GameState.coins += 1000)
	_add(box, "무적 토글", func(): GameState.cheats["godmode"] = not GameState.cheats.get("godmode", false))
	_add(box, "적 즉사 토글", func(): GameState.cheats["enemy_oneshot"] = not GameState.cheats.get("enemy_oneshot", false))
	_add(box, "적 전멸", _kill_all)
	_add(box, "다음 스테이지", func():
		GameState.advance_stage()
		get_tree().reload_current_scene())


func _add(box: VBoxContainer, label: String, fn: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(fn)
	box.add_child(b)


func _kill_all() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("take_damage"):
			e.take_damage(999999.0)
