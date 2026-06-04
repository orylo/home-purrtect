extends Control
## 스테이지 맵 (별점 허브) — design.md 토큰(Design 오토로드)만 사용.
##   상단바(홈·막이름·별총합·코인) / 스테이지 그리드(1-1~1-20, best_star 표시·재도전) / 컬렉션 보상 띠(올스타 수령).
##   읽기: cleared_stages·stage_stars·allstar_claimed.  쓰기: [받기] 수령(claim_allstar)뿐.
##   게이팅 없음(BM) — 맵은 정보·수령·재도전용. 별로 본편 진행 막지 않음.

const COLS := 5
const ROWS := 4
const ACT_NAME := {1: "담벼락"}   # 막 부제(없으면 생략)

var _toast: Label
var _toast_t := 0.0


func _ready() -> void:
	GameState.replaying = false     # 맵에 있는 동안은 파밍 세션 아님(안전망)
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	var vp := get_viewport().get_visible_rect().size
	var E := float(Design.EDGE)

	# ── 배경 ──
	var bg := ColorRect.new()
	bg.color = Design.CANVAS
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_build_topbar(vp, E)
	var band_h := 150.0
	var grid_top := E + 76.0
	var grid_h := vp.y - grid_top - band_h - E - 12.0
	_build_grid(vp, E, grid_top, grid_h)
	_build_collection(vp, E, vp.y - E - band_h, band_h)

	# 토스트(수령 알림)
	_toast = Design.label("", "title", Design.CHEESE)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.size = Vector2(vp.x, 50)
	_toast.position = Vector2(0, vp.y * 0.42)
	_toast.visible = false
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0 and _toast:
			_toast.visible = false


# ── 상단 바 ───────────────────────────────────────────────────────────────
func _build_topbar(vp: Vector2, E: float) -> void:
	# [← 홈]
	var home := Design.button("← 홈", "paper", Design.FS_BODY)
	home.position = Vector2(E, E)
	home.custom_minimum_size = Vector2(132, 52); home.size = home.custom_minimum_size
	home.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/home.tscn"))
	add_child(home)

	# 막 이름(중앙)
	var sub: String = ACT_NAME.get(GameState.stage_major, "")
	var title_txt := "%d막 %s" % [GameState.stage_major, sub] if sub != "" else "%d막 스테이지" % GameState.stage_major
	var plate := Design.framed_plate(title_txt, "title")
	plate.size = Vector2(320, 52)
	plate.position = Vector2(vp.x * 0.5 - 160.0, E)
	add_child(plate)

	# 우측: 별 총합 + 코인
	var ap := GameState.allstar_progress()
	var star_lbl := Design.label("★ %d/%d" % [ap.x, ap.y], "num", Design.CHEESE)
	star_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	star_lbl.size = Vector2(180, 26); star_lbl.position = Vector2(vp.x - E - 180.0, E)
	add_child(star_lbl)
	var coin := Design.label("코인 " + _commafy(GameState.coins), "num", Design.CHEESE)
	coin.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	coin.size = Vector2(180, 26); coin.position = Vector2(vp.x - E - 180.0, E + 28.0)
	add_child(coin)


# ── 스테이지 그리드 (1-1 ~ 1-20) ───────────────────────────────────────────
func _build_grid(vp: Vector2, E: float, top: float, h: float) -> void:
	var gap := 14.0
	var cw := (vp.x - 2.0 * E - (COLS - 1) * gap) / COLS
	var ch := (h - (ROWS - 1) * gap) / ROWS
	for i in 20:
		var n := i + 1
		var col := i % COLS
		var row := i / COLS
		var pos := Vector2(E + col * (cw + gap), top + row * (ch + gap))
		_make_cell(n, pos, Vector2(cw, ch))


func _make_cell(n: int, pos: Vector2, sz: Vector2) -> void:
	var cleared := GameState.cleared_stages.has(n)
	var is_boss := n == 10 or n == 20
	var best := GameState.best_star(n)

	var kind := "paper"
	if cleared and is_boss:
		kind = "cheese"        # 보스 = 골든 강조
	var cell := Design.button("", kind, Design.FS_BODY)
	cell.position = pos
	cell.custom_minimum_size = sz; cell.size = sz
	cell.clip_contents = true
	add_child(cell)

	if cleared:
		cell.pressed.connect(func(): _replay(n))
	else:
		cell.disabled = true   # 미클리어 = 잠금(흐림, 비활성)

	# 스테이지 번호
	var idl := Design.label("%d-%d" % [GameState.stage_major, n], "title", Design.INK if cleared else Design.INK.lerp(Design.PAPER_DEEP, 0.45))
	idl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	idl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	idl.size = Vector2(sz.x, 34); idl.position = Vector2(0, sz.y * 0.16)
	cell.add_child(idl)

	# 별 또는 잠금
	if cleared:
		var stars := "★".repeat(best) + "·".repeat(3 - best)
		var stl := Design.label(stars, "num", Design.CHEESE)
		stl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stl.size = Vector2(sz.x, 30); stl.position = Vector2(0, sz.y * 0.50)
		cell.add_child(stl)
		var hint := Design.label("재도전", "caption", Design.INK.lerp(Design.PAPER_DEEP, 0.2))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint.size = Vector2(sz.x, 22); hint.position = Vector2(0, sz.y - 28.0)
		cell.add_child(hint)
	else:
		var lock := Design.label("잠김", "caption", Design.PAPER_DEEP)
		lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock.size = Vector2(sz.x, 24); lock.position = Vector2(0, sz.y * 0.54)
		cell.add_child(lock)

	# 보스 태그
	if is_boss:
		var tag := Design.label("BOSS", "caption", Design.RED if cleared else Design.PAPER_DEEP)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.size = Vector2(sz.x, 20); tag.position = Vector2(0, 4)
		cell.add_child(tag)


## [재도전] — 진행 포인터 격리(begin_replay) 후 해당 스테이지로 출격(파밍·별 갱신).
func _replay(n: int) -> void:
	GameState.begin_replay(n)
	get_tree().change_scene_to_file("res://scenes/main.tscn")


# ── 컬렉션 보상 띠 (구간 올스타 3칸) ────────────────────────────────────────
func _build_collection(vp: Vector2, E: float, top: float, h: float) -> void:
	var gap := 16.0
	var w := (vp.x - 2.0 * E - 2.0 * gap) / 3.0
	for i in GameState.ALLSTAR_SEGMENTS.size():
		var seg: Dictionary = GameState.ALLSTAR_SEGMENTS[i]
		var pos := Vector2(E + i * (w + gap), top)
		_make_segment(seg, pos, Vector2(w, h))


func _make_segment(seg: Dictionary, pos: Vector2, sz: Vector2) -> void:
	var seg_id := String(seg["id"])
	var gem_id := String(seg["gem"])
	var gem_name := String(GameState.MATERIALS.get(gem_id, {}).get("name", gem_id))
	var prog := GameState.allstar_segment_progress(seg_id)
	var claimed := GameState.allstar_claimed.has(seg_id)
	var ready := GameState.can_claim_allstar(seg_id)

	var panel := Panel.new()
	panel.position = pos; panel.size = sz; panel.custom_minimum_size = sz
	panel.add_theme_stylebox_override("panel", Design.card_box(Design.PAPER if ready else Design.PAPER_DEEP, 4, 12))
	add_child(panel)

	var rng := Design.label("%d-%d ~ %d-%d 올스타" % [GameState.stage_major, int(seg["from"]), GameState.stage_major, int(seg["to"])], "body", Design.INK)
	rng.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rng.size = Vector2(sz.x - 16, 26); rng.position = Vector2(8, 10)
	panel.add_child(rng)

	var reward := Design.label("%s ★%d/%d" % [gem_name, prog.x, prog.y], "num", Design.CHEESE)
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward.size = Vector2(sz.x - 16, 30); reward.position = Vector2(8, 44)
	panel.add_child(reward)

	var btn: Button
	if claimed:
		btn = Design.button("받음 ✓", "paper", Design.FS_BODY)
		btn.disabled = true
	elif ready:
		btn = Design.button("받기", "cheese", Design.FS_TITLE)
		btn.pressed.connect(func(): _claim(seg_id, gem_name))
	else:
		btn = Design.button("%d/%d" % [prog.x, prog.y], "paper", Design.FS_BODY)
		btn.disabled = true
	btn.size = Vector2(sz.x - 40, 48); btn.custom_minimum_size = btn.size
	btn.position = Vector2(20, sz.y - 60.0)
	panel.add_child(btn)


func _claim(seg_id: String, gem_name: String) -> void:
	var gem := GameState.claim_allstar(seg_id)
	if gem == "":
		return
	Sfx.play("buff")
	_toast.text = "%s ×1 획득!" % gem_name
	_toast.visible = true
	_toast_t = 2.0
	_build()    # 띠·별총합·코인 갱신


# ── helpers ──
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
