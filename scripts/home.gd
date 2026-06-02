extends Control
## 홈 화면 (메인 허브) — 카툰 톤(design.md): 크림 패널·잉크 외곽선·빨강 CTA·골든 강조.
##   상단: 코인(골든)·스테이지 / 가방·설정 / 중앙: 치즈·펄·맥스 진입 / 하단: 전투준비·맵·출격(CTA)

const BG := preload("res://assets/backgrounds/stage1_wall.jpg")

var _toast: Label
var _toast_t := 0.0


func _ready() -> void:
	GameState.mode = "player"
	_build()


func _build() -> void:
	var vp := get_viewport().get_visible_rect().size

	var bg := TextureRect.new()
	bg.texture = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)

	# 치즈(대기) — 선택 직업 idle
	var frames := load(GameState.job_frames_path())
	if frames:
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = frames
		if (frames as SpriteFrames).has_animation("idle"):
			spr.play("idle")
		spr.position = Vector2(vp.x * 0.52, vp.y * 0.78)
		add_child(spr)

	# 상단 바 — 코인(골든)·스테이지(크림), 잉크 외곽선으로 배경 위 가독
	var coin := Design.label("코인 " + _commafy(GameState.coins), "num", Design.CHEESE)
	coin.position = Vector2(32, 24)
	add_child(coin)
	var stage := Design.label("1막   ·   " + GameState.stage_label(), "num", Design.INK_CREAM)
	stage.position = Vector2(vp.x * 0.5 - 96, 24)
	add_child(stage)
	_btn("가방", Vector2(vp.x - 296, 24), Vector2(120, 48), "paper", Design.FS_BODY, _show_bag)
	_btn("설정", Vector2(vp.x - 160, 24), Vector2(120, 48), "paper", Design.FS_BODY,
			func(): _toast_msg("설정 — 준비중"))

	# NPC 진입점 (테스트 위해 상시 노출)
	_btn("펄", Vector2(vp.x * 0.20, vp.y * 0.40), Vector2(128, 64), "cheese", Design.FS_TITLE,
			func(): get_tree().change_scene_to_file("res://scenes/pearl.tscn"))
	_btn("맥스 상점", Vector2(vp.x * 0.12, vp.y * 0.62), Vector2(208, 64), "paper", Design.FS_TITLE,
			func(): get_tree().change_scene_to_file("res://scenes/maxtalk.tscn"))

	# 하단: 전투 준비(보조) / 맵(보조) / 출격(CTA=빨강, 화면당 1개)
	_btn("전투 준비", Vector2(40, vp.y - 120), Vector2(240, 80), "paper", Design.FS_TITLE,
			func(): get_tree().change_scene_to_file("res://scenes/select.tscn"))
	_btn("맵", Vector2(vp.x - 416, vp.y - 120), Vector2(120, 80), "paper", Design.FS_TITLE,
			func(): _toast_msg("스테이지 맵(파밍) — 준비중"))
	_btn("출격 ▶", Vector2(vp.x - 272, vp.y - 120), Vector2(232, 80), "cta", Design.FS_DISPLAY_S,
			func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))

	# 토스트
	_toast = Design.label("", "title", Design.INK_CREAM)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.size = Vector2(vp.x, 50)
	_toast.position = Vector2(0, vp.y * 0.5)
	_toast.visible = false
	add_child(_toast)


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0 and _toast:
			_toast.visible = false


## 가방(인벤토리) 오버레이 — 크림 패널 + 잉크 외곽선(design.md 패널 규칙)
func _show_bag() -> void:
	var vp := get_viewport().get_visible_rect().size
	var ov := ColorRect.new()
	ov.color = Color(Design.INK.r, Design.INK.g, Design.INK.b, 0.6)
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ov)
	var panel := Panel.new()
	panel.size = Vector2(minf(840, vp.x - 80), vp.y - 120)
	panel.position = Vector2((vp.x - panel.size.x) * 0.5, 60)
	ov.add_child(panel)
	Design.frame_signboard(panel)   # 빈티지 간판 패널 텍스처(물건화)
	var sc := ScrollContainer.new()
	sc.position = Vector2(72, 104)                 # 간판 테두리 안쪽으로 들임
	sc.size = panel.size - Vector2(144, 230)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.custom_minimum_size = Vector2(sc.size.x, 0)
	sc.add_child(vb)
	vb.add_child(Design.label("가방 — 보유 현황", "title", Design.INK))
	_bag_section(vb, "◆ 전리품")
	var any_mat := false
	for id in GameState.MAT_ORDER:
		var n: int = GameState.mat_count(id)
		if n > 0:
			any_mat = true
			vb.add_child(Design.label("   %s  ×%d" % [String(GameState.MATERIALS[id]["name"]), n], "body"))
	if not any_mat:
		vb.add_child(Design.label("   (없음 — 전투에서 적 처치 시 드랍)", "caption", Design.PAPER_DEEP.darkened(0.2)))
	_bag_section(vb, "◆ 소모품")
	var any_item := false
	for id in ["bandage", "anchovy", "firecracker"]:
		var n: int = int(GameState.inventory.get(id, 0))
		if n > 0:
			any_item = true
			vb.add_child(Design.label("   %s  ×%d" % [String(GameState.CONSUMABLES[id]["name"]), n], "body"))
	if not any_item:
		vb.add_child(Design.label("   (없음 — 맥스 상점에서 구매)", "caption", Design.PAPER_DEEP.darkened(0.2)))
	_bag_section(vb, "◆ 보유 스킬")
	if GameState.owned_skills.is_empty():
		vb.add_child(Design.label("   (없음 — 맥스 상점 [스킬]에서 구매)", "caption", Design.PAPER_DEEP.darkened(0.2)))
	else:
		var jk := {"sheriff": "보안관", "maid": "메이드", "jazz": "음악가"}
		for sid in GameState.owned_skills:
			var s: Dictionary = GameState.SKILLS[sid]
			vb.add_child(Design.label("   %s  (%s)" % [String(s["name"]), jk.get(s["job"], s["job"])], "body"))
	var close := Design.button("닫기", "cta", Design.FS_TITLE)
	close.custom_minimum_size = Vector2(180, 60)
	close.size = Vector2(180, 60)
	close.position = Vector2(panel.size.x * 0.5 - 90, panel.size.y - 110)
	close.pressed.connect(ov.queue_free)
	panel.add_child(close)


func _bag_section(vb: VBoxContainer, t: String) -> void:
	var l := Design.label(t, "title", Design.RED)
	vb.add_child(l)


func _toast_msg(msg: String) -> void:
	if _toast == null:
		return
	_toast.text = msg
	_toast.visible = true
	_toast_t = 1.6


# --- helpers ---
func _btn(label: String, pos: Vector2, sz: Vector2, kind: String, fs: int, fn: Callable) -> void:
	var b := Design.button(label, kind, fs)
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
