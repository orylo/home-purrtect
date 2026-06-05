extends Control
## 홈 화면 (메인 허브) ─ 카툰 톤(design.md): 크림 패널·잉크 외곽선·빨강 CTA·골든 강조.
##   상단: 코인(골든)·스테이지 / 가방·설정 / 중앙: 치즈·펄·맥스 진입 / 하단: 전투준비·맵·출격(CTA)

var _toast: Label
var _toast_t := 0.0
var _coin_lbl: Label   # 개발 도구에서 코인 즉시 갱신용


func _ready() -> void:
	if GameState.mode != "dev":     # 개발 모드면 유지(홈에서 DEV 도구 사용)
		GameState.mode = "player"
	GameState.replaying = false     # 홈 복귀 = 파밍 세션 종료(안전망)
	_build()


func _build() -> void:
	var vp := get_viewport().get_visible_rect().size
	var E := float(Design.EDGE)   # 24

	# ── 배경(실내 플레이스홀더) ─ 벽(위)/바닥(아래) 2톤 + 중앙 받침 + 라벨 ──
	_room_placeholder(vp)

	# ── 중앙: 치즈(대기) ─ 레퍼런스만큼 크게 ──
	var frames := load(GameState.job_frames_path())
	if frames:
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = frames
		if (frames as SpriteFrames).has_animation("idle"):
			spr.play("idle")
		spr.scale = Vector2(2.1, 2.1)                       # ★확대(기존보다 크게)
		spr.position = Vector2(vp.x * 0.5, vp.y * 0.66)     # 받침 위 중앙
		add_child(spr)

	# ── 좌상단: "N막 N스테이지"(옛 게이지 위치) ──
	var stage := Design.framed_plate("%d막 %d스테이지" % [GameState.stage_major, GameState.stage_minor], "title")
	stage.position = Vector2(E, E)
	add_child(stage)
	# 1막 별 진행도 → 스테이지 맵 진입 버튼(별점 허브). 내비게이션이라 Secondary(크림), 강조는 출격(빨강) 하나만.
	var ap := GameState.allstar_progress()
	_btn("지도  ★ %d/%d" % [ap.x, ap.y], Vector2(E, E + 60.0), Vector2(220, float(Design.BAR_H)),
			"paper", Design.FS_BODY,
			func(): get_tree().change_scene_to_file("res://scenes/stagemap.tscn"))

	# ── 우상단: 종/편지/친구/설정/메뉴 5버튼(우→좌) + 그 왼쪽에 보유 코인 ──
	var ic_w := 84.0     # 버튼 텍스트(2글자)가 넘치지 않게 고정폭 → 균일·비겹침
	var ic_h := 56.0
	var istep := ic_w + 10.0
	var top_specs := [   # 오른쪽부터: 메뉴, 설정, 친구, 편지, 종
		["메뉴", func(): _show_bag()],
		["설정", func(): _toast_msg("배경음악 " + ("켜짐" if Music.toggle() else "꺼짐"))],
		["친구", func(): _toast_msg("친구 ─ 준비중")],
		["편지", func(): _toast_msg("메시지 ─ 준비중")],
		["종",   func(): _toast_msg("알림 ─ 준비중")],
	]
	var leftmost := vp.x
	for i in top_specs.size():
		var x := vp.x - E - ic_w - i * istep
		leftmost = x
		_btn(String(top_specs[i][0]), Vector2(x, E), Vector2(ic_w, ic_h), "paper", Design.FS_CAPTION, top_specs[i][1])
	# 보유 코인 ─ 5버튼 왼쪽에(우측정렬)
	var coin := Design.label("코인 " + _commafy(GameState.coins), "num", Design.CHEESE)
	coin.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	coin.size = Vector2(240, ic_h)
	coin.position = Vector2(leftmost - 240 - 16, E)
	coin.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(coin)
	_coin_lbl = coin

	# DEV 도구 ─ "개발자 루트"로 들어온 홈에서만 노출. 일반 [게임 시작]→홈(mode=player)에선 숨김.
	#   (시작화면 우하단 개발자 버튼 → 개발자 메뉴 → [홈 화면으로]로 들어와야 mode=dev → 노출)
	if GameState.is_dev() and GameState.mode == "dev":
		_btn("DEV 도구", Vector2(E, E + 118.0), Vector2(132, 44), "cheese", Design.FS_BODY, _show_dev_panel)

	# ── 좌측 중앙: 펄·맥스 세로 스택(해금 게이팅) ──
	var npc_sz := Vector2(160, 64)
	var pearl_pos := Vector2(E, vp.y * 0.40)
	var max_pos := Vector2(E, vp.y * 0.40 + npc_sz.y + 14.0)
	# ── 좌하단: 전투 준비("내 쿠키들" 위치, 해금 게이팅) ──
	var prep_pos := Vector2(E, vp.y - E - 84.0)
	var prep_sz := Vector2(240, 84)

	var coach := []
	if GameState.cleared_stages.has(5):
		_btn("펄", pearl_pos, npc_sz, "paper", Design.FS_TITLE,
				func(): get_tree().change_scene_to_file("res://scenes/pearl.tscn"))
		coach.append({"id": "pearl", "rect": Rect2(pearl_pos, npc_sz),
				"text": "펄에게 가면, 출격 전 축복을 하나 받을 수 있어요."})
	if GameState.cleared_stages.has(7):
		_btn("맥스", max_pos, npc_sz, "paper", Design.FS_TITLE,
				func(): get_tree().change_scene_to_file("res://scenes/maxtalk.tscn"))
		coach.append({"id": "max", "rect": Rect2(max_pos, npc_sz),
				"text": "맥스의 상점에서 물건을 사고 장비를 만들 수 있어요."})
		# 1-9: 맥스가 스킬도 팔기 시작(D+ 코치마크 ─ 맥스 버튼 재강조)
		if GameState.cleared_stages.has(9):
			coach.append({"id": "skill", "rect": Rect2(max_pos, npc_sz),
					"text": "이제 맥스가 '스킬'도 팔아요. 사서 장착하면 전투 중 쓸 수 있어요."})
	if GameState.cleared_stages.has(3):
		_btn("전투 준비", prep_pos, prep_sz, "secondary", Design.FS_TITLE,
				func(): get_tree().change_scene_to_file("res://scenes/select.tscn"))
		coach.append({"id": "prep", "rect": Rect2(prep_pos, prep_sz),
				"text": "여기서 직업을 갈아입을 수 있어요. 보안관으로 바꿔보세요!"})
		# 1-13: 동료 시스템(전투준비 > 동료 강조)
		if GameState.cleared_stages.has(13):
			coach.append({"id": "dove", "rect": Rect2(prep_pos, prep_sz),
					"text": "맥스에게 호루라기를 사서 동료를 장착하면, 전투 중 불러낼 수 있어요!"})

	# ── 우하단: 출격(CTA=빨강, "PLAY" 위치) ──
	_btn("출격 ▶", Vector2(vp.x - E - 256.0, vp.y - E - 84.0), Vector2(256, 84), "cta", Design.FS_DISPLAY_S,
			func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))

	# 코치마크: 해금됐는데 아직 안 본 버튼 1개(진행 순서대로 자연 안내)
	for cid in ["prep", "pearl", "max", "skill", "dove"]:
		var c = _coach_find(coach, cid)
		if c != null and not GameState.coachmark_seen.has(c["id"]):
			call_deferred("_show_coachmark", c)
			break

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


## 가방(인벤토리) 오버레이 ─ 크림 패널 + 잉크 외곽선(design.md 패널 규칙)
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
	vb.add_child(Design.label("가방 ─ 보유 현황", "title", Design.INK))
	_bag_section(vb, "◆ 전리품")
	var any_mat := false
	for id in GameState.MAT_ORDER:
		var n: int = GameState.mat_count(id)
		if n > 0:
			any_mat = true
			vb.add_child(Design.label("   %s  ×%d" % [String(GameState.MATERIALS[id]["name"]), n], "body"))
	if not any_mat:
		vb.add_child(Design.label("   (없음 ─ 전투에서 침입자 처치 시 드랍)", "caption", Design.PAPER_DEEP.darkened(0.2)))
	_bag_section(vb, "◆ 소모품")
	var any_item := false
	for id in ["bandage", "anchovy", "firecracker"]:
		var n: int = int(GameState.inventory.get(id, 0))
		if n > 0:
			any_item = true
			vb.add_child(Design.label("   %s  ×%d" % [String(GameState.CONSUMABLES[id]["name"]), n], "body"))
	if not any_item:
		vb.add_child(Design.label("   (없음 ─ 맥스 상점에서 구매)", "caption", Design.PAPER_DEEP.darkened(0.2)))
	_bag_section(vb, "◆ 보유 스킬")
	if GameState.owned_skills.is_empty():
		vb.add_child(Design.label("   (없음 ─ 맥스 상점 [스킬]에서 구매)", "caption", Design.PAPER_DEEP.darkened(0.2)))
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


# --- DEV 도구(홈에서 코인·스테이지·전리품 등 직접 조작, DEV 빌드 전용) ---
func _rebuild() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_toast = null
	_coin_lbl = null
	_build()


func _dev_add_coins(n: int) -> void:
	GameState.coins += n
	if is_instance_valid(_coin_lbl):
		_coin_lbl.text = "코인 " + _commafy(GameState.coins)
	_toast_msg("코인 +%s" % _commafy(n))


func _dev_set_stage(n: int) -> void:
	GameState.stage_minor = clampi(n, 1, 20)
	GameState.cleared_stages = []
	for s in range(1, GameState.stage_minor):   # 현재 스테이지 직전까지 클리어 처리(해금 반영)
		GameState.cleared_stages.append(s)
	GameState._check_stage_unlocks()             # 보안관/메이드/음악가 진행 해금 보강
	_rebuild()                                   # 홈 갱신(버튼 노출·스테이지 표기)


func _dev_add_materials() -> void:
	for mid in GameState.MATERIALS:
		GameState.add_material(mid, 20)
	_toast_msg("전리품·보석 전부 +20")


func _dev_add_consumables() -> void:
	for id in GameState.CONSUMABLES:
		GameState.inventory[id] = int(GameState.inventory.get(id, 0)) + 10
	_toast_msg("소모품 전부 +10")


func _dev_unlock_all() -> void:
	for j in ["sheriff", "maid", "jazz"]:
		if not GameState.unlocked_jobs.has(j):
			GameState.unlocked_jobs.append(j)
		GameState._add_grade(j, 1)
	GameState.dev_grant_skills()
	GameState.pearl_favor = maxi(GameState.pearl_favor, 50)
	_toast_msg("직업·스킬·펄 호감도 해금")


func _show_dev_panel() -> void:
	var vp := get_viewport().get_visible_rect().size
	var ov := Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(ov)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.add_child(dim)

	var pw := 560.0
	var ph := 470.0
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", Design.panel_box())
	panel.position = Vector2((vp.x - pw) * 0.5, (vp.y - ph) * 0.5)
	panel.size = Vector2(pw, ph)
	ov.add_child(panel)

	var y := 20.0
	var t := Design.label("개발 도구 (DEV)", "title", Design.INK)
	t.position = Vector2(24, y); panel.add_child(t); y += 50.0

	# 코인
	var rowy := y
	panel.add_child(_dev_lbl("코인", Vector2(24, rowy)))
	_dev_pbtn(panel, "+1만", Vector2(120, rowy), func(): _dev_add_coins(10000))
	_dev_pbtn(panel, "+10만", Vector2(232, rowy), func(): _dev_add_coins(100000))
	_dev_pbtn(panel, "+100만", Vector2(360, rowy), func(): _dev_add_coins(1000000))
	y += 64.0

	# 스테이지
	panel.add_child(_dev_lbl("스테이지 %d-%d" % [GameState.stage_major, GameState.stage_minor], Vector2(24, y)))
	_dev_pbtn(panel, "◀ 이전", Vector2(220, y), func(): _dev_set_stage(GameState.stage_minor - 1))
	_dev_pbtn(panel, "다음 ▶", Vector2(340, y), func(): _dev_set_stage(GameState.stage_minor + 1))
	_dev_pbtn(panel, "막끝(20)", Vector2(460, y), func(): _dev_set_stage(20))
	y += 64.0

	_dev_wbtn(panel, "전리품·보석 전부 +20", Vector2(24, y), func(): _dev_add_materials())
	y += 60.0
	_dev_wbtn(panel, "소모품 전부 +10", Vector2(24, y), func(): _dev_add_consumables())
	y += 60.0
	_dev_wbtn(panel, "직업·스킬·펄 전부 해금", Vector2(24, y), func(): _dev_unlock_all())
	y += 60.0

	var close := Design.button("닫기", "secondary", Design.FS_BODY)
	close.position = Vector2(pw - 140.0, ph - 60.0)
	close.size = Vector2(116, 44)
	close.custom_minimum_size = close.size
	close.pressed.connect(func(): ov.queue_free())
	panel.add_child(close)


func _dev_lbl(t: String, pos: Vector2) -> Label:
	var l := Design.label(t, "body", Design.INK)
	l.position = pos
	return l

func _dev_pbtn(parent: Control, t: String, pos: Vector2, fn: Callable) -> void:
	var b := Design.button(t, "paper", Design.FS_CAPTION)
	b.position = pos
	b.size = Vector2(108, 44); b.custom_minimum_size = b.size
	b.pressed.connect(fn)
	parent.add_child(b)

func _dev_wbtn(parent: Control, t: String, pos: Vector2, fn: Callable) -> void:
	var b := Design.button(t, "cheese", Design.FS_BODY)
	b.position = pos
	b.size = Vector2(280, 48); b.custom_minimum_size = b.size
	b.pressed.connect(fn)
	parent.add_child(b)


# --- 실내 배경 = Home_BG (세로 고정 · 가로 자동 블리딩 · 가운데) ---
const HOME_BG := preload("res://assets/backgrounds/home_bg.png")
func _room_placeholder(_vp: Vector2) -> void:
	var bg := _HomeBG.new()
	bg.tex = HOME_BG
	add_child(bg)   # 첫 자식 = 맨 뒤(치즈·버튼 등은 뒤에 add → 위에 그려짐)


## 홈 배경: 세로=화면높이로 스케일(고정), 가로는 자동(넘치면 양옆 블리딩)·가운데. 리사이즈 추종.
class _HomeBG extends Control:
	var tex: Texture2D
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		get_viewport().size_changed.connect(queue_redraw)
	func _draw() -> void:
		if tex == null:
			return
		var vp := size
		var ts := tex.get_size()
		if ts.y <= 0.0:
			return
		var sc := vp.y / ts.y               # 세로 고정
		var w := ts.x * sc
		var x := (vp.x - w) * 0.5           # 가로 가운데 → 넘치면 양옆 블리딩
		draw_texture_rect(tex, Rect2(x, 0.0, w, vp.y), false)


# --- 코치마크(전체 딤 + 버튼 위치만 원형 마스킹) ---
const COACH_SHADER := preload("res://assets/shaders/coachmark.gdshader")

func _coach_find(arr: Array, id: String):
	for c in arr:
		if c["id"] == id:
			return c
	return null


func _show_coachmark(c: Dictionary) -> void:
	var vp := get_viewport().get_visible_rect().size
	var rect: Rect2 = c["rect"]
	var center := rect.position + rect.size * 0.5
	var radius: float = maxf(rect.size.x, rect.size.y) * 0.62 + 14.0

	var ov := Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP   # 탭 가로채기(탭하면 닫힘)
	add_child(ov)

	# 딤 + 원형 구멍(셰이더)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = COACH_SHADER
	mat.set_shader_parameter("hole_center", center)
	mat.set_shader_parameter("hole_radius", radius)
	mat.set_shader_parameter("screen_size", vp)
	mat.set_shader_parameter("dim", 0.74)
	dim.material = mat
	ov.add_child(dim)

	# 강조 링
	var ring := CoachRing.new()
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.c = center
	ring.r = radius
	ov.add_child(ring)

	# 안내 문구(구멍 위쪽에 배치)
	var lbl := Design.label(String(c["text"]), "title", Design.CHEESE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size = Vector2(vp.x - 120.0, 120.0)
	lbl.position = Vector2(60.0, maxf(40.0, center.y - radius - 130.0))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(lbl)
	var hint := Design.label("▶ 탭하여 계속", "caption", Design.CHEESE_DEEP)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size = Vector2(vp.x, 30.0)
	hint.position = Vector2(0.0, vp.y - 56.0)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(hint)

	ov.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			if not GameState.coachmark_seen.has(c["id"]):
				GameState.coachmark_seen.append(c["id"])
				if GameState.AUTOSAVE:
					GameState.save_game()
			ov.queue_free())


class CoachRing extends Control:
	var c := Vector2.ZERO
	var r := 90.0
	func _draw() -> void:
		draw_arc(c, r, 0.0, TAU, 72, Color("F2B33D"), 5.0, true)
		draw_arc(c, r + 6.0, 0.0, TAU, 72, Color(0.14, 0.12, 0.10, 0.55), 3.0, true)


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
