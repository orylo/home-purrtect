extends Control
## 해금 이벤트 씬 (placeholder) — 이벤트 스테이지 클리어 후 랜딩.
##  GameState.pending_event_stage 에 담긴 스테이지의 clear_event_for() 내용을 보여주고 [계속]→홈.
##  나중에 진짜 컷신/대화로 교체(지금은 카드형 알림).

func _ready() -> void:
	var stage: int = GameState.pending_event_stage
	GameState.pending_event_stage = 0
	var txt: String = GameState.clear_event_for(stage)
	if txt == "":
		_continue()
		return
	var vp := get_viewport_rect().size

	var bg := ColorRect.new()
	bg.color = Design.CANVAS
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 상단 "새 소식" 배지
	var badge := Design.label("새 소식", "title", Design.INK_CREAM)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_stylebox_override("normal", Design.card_box(Design.RED, 4, Design.RADIUS_CARD))
	badge.custom_minimum_size = Vector2(220, 48)
	badge.size = Vector2(220, 48)
	badge.position = Vector2((vp.x - 220) * 0.5, vp.y * 0.5 - 250)
	add_child(badge)

	# 중앙 카드
	var pw := minf(900.0, vp.x - 80.0)
	var phh := 360.0
	var panel := Panel.new()
	panel.size = Vector2(pw, phh)
	panel.position = Vector2((vp.x - pw) * 0.5, (vp.y - phh) * 0.5)
	panel.add_theme_stylebox_override("panel", Design.panel_box())
	add_child(panel)

	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + s, Design.GAP_XL)
	panel.add_child(mc)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", Design.GAP_LG)
	mc.add_child(vb)

	var lines := txt.split("\n", false)
	var head := lines[0] if lines.size() > 0 else txt
	var body := "\n".join(Array(lines).slice(1)) if lines.size() > 1 else ""
	var h := Design.label(head, "display_s", Design.RED_DEEP)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(h)
	if body != "":
		var b := Design.label(body, "body", Design.INK)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(b)

	# [계속]
	var cont := Design.button("계속 ▶", "primary", Design.FS_DISPLAY_S)
	cont.custom_minimum_size = Vector2(320, 68)
	cont.size = Vector2(320, 68)
	cont.position = Vector2((vp.x - 320) * 0.5, panel.position.y + phh + Design.GAP_LG)
	cont.pressed.connect(_continue)
	add_child(cont)


func _continue() -> void:
	if GameState.mode == "dev":
		get_tree().change_scene_to_file("res://scenes/dev_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/home.tscn")
