extends Node2D
## 게임 코디네이터 (Main) — 스포너/플레이어 신호를 받아 클리어·게임오버를 연출.

@onready var spawner: Node = $Spawner
@onready var player: Node = $Player
@onready var hud: Node = $HUD
@onready var bg: CanvasLayer = $BG


func _ready() -> void:
	randomize()   # 매 판 적의 리듬·등장이 달라지게
	GameState.start_battle_loot()   # 이번 판 전리품 집계 리셋(클리어 화면용)
	spawner.wave_started.connect(hud.set_wave)
	spawner.stage_cleared.connect(_on_stage_cleared)
	player.died.connect(_on_player_died)
	if hud.has_signal("inscene_event_requested"):
		hud.inscene_event_requested.connect(_on_inscene_event)
	_spawn_event_chars()   # 1-5 펄·1-7 맥스 플레이스홀더 상주


func _process(delta: float) -> void:
	# 화면 흔들림 — 월드(Main)와 배경(BG)을 같이 흔들고 HUD는 고정
	var off := Vector2.ZERO
	if Fx.shake > 0.0:
		Fx.shake = move_toward(Fx.shake, 0.0, 45.0 * delta)
		off = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * Fx.shake
	position = off
	bg.offset = off


func _on_stage_cleared() -> void:
	if GameState.stage_minor == 5:
		GameState.add_material("gem_pebble")     # 1-5 펄 해금: 💎빛나는(조약)돌 고정 지급(헌납 튜토)
	var bonus := GameState.award_stage_clear()   # 첫 클리어 보너스 코인(파밍은 0)
	var si := get_node_or_null("StageIntro")     # 클리어 퇴장 이벤트(있으면)가 먼저
	if si != null and si.has_method("has_outro") and si.has_outro():
		await si.play_outro()
	get_tree().paused = true
	hud.show_clear(bonus)


func _on_player_died() -> void:
	get_tree().paused = true
	hud.show_gameover()


# ── 전투 씬 내 컷씬(케이스 A 해금형: 1-3 보안관 / 1-5 펄 / 1-7 맥스) ──────────
#   결과창 [확인] 후 씬전환 없이 이어서: 대상에 다가감/상호작용 → 화면 줌인 → 컷씬(플레이스홀더) → 홈.
const CRATE_X_FRAC := 0.25   # 1-3 나무 궤짝 화면 x(뷰포트 비율, 좌측). 필요 시 조정.
const FONT := preload("res://assets/fonts/Pretendard-Regular.ttf")
var _event_char: Node2D = null   # 펄/맥스 플레이스홀더(전투 내내 상주)


## 펄/맥스 플레이스홀더(동그라미)를 전투 시작 시 배치(1-5·1-7 상주, 전투 무관).
func _spawn_event_chars() -> void:
	var vp := get_viewport_rect().size
	if GameState.stage_minor == 5:
		_event_char = _make_char("펄", Color(0.95, 0.55, 0.78), Vector2(vp.x * 0.07, Layout.ground_y() - 360.0), 34.0)
	elif GameState.stage_minor == 7:
		_event_char = _make_char("맥스", Color(0.72, 0.52, 0.32), Vector2(vp.x * 0.66, Layout.ground_y() - 60.0), 40.0)


func _make_char(label: String, col: Color, pos: Vector2, radius: float) -> Node2D:
	var n := EventChar.new()
	n.label = label
	n.col = col
	n.radius = radius
	n.position = pos
	add_child(n)
	return n


class EventChar extends Node2D:
	var label := ""
	var col := Color.WHITE
	var radius := 32.0
	func _draw() -> void:
		draw_circle(Vector2(0, radius * 0.18), radius * 1.05, Color(0, 0, 0, 0.22))   # 옅은 그림자
		draw_circle(Vector2.ZERO, radius, col)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(0.14, 0.12, 0.10), 3.0, true)
		var f := preload("res://assets/fonts/Pretendard-Regular.ttf")
		draw_string(f, Vector2(-radius, -radius - 10.0), label, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 22, Color(1, 1, 1))


func _on_inscene_event() -> void:
	# 트리는 일시정지 유지(치즈·플레이스홀더는 PROCESS_MODE_ALWAYS/직접 갱신).
	hud.visible = false                       # 깨끗한 컷씬(HP바 등 숨김)
	if player.has_method("set_event_idle"):
		player.set_event_idle(true)
	match GameState.stage_minor:
		3: await _event_crate()
		5: await _event_pearl()
		7: await _event_max()
		_: pass
	# 진행 저장 → 홈
	GameState.advance_stage()
	if GameState.mode != "dev" and GameState.AUTOSAVE:
		GameState.save_game()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/home.tscn")


## 1-3 보안관: 치즈가 궤짝 옆으로 걸어가 → 줌인 → 컷씬.
func _event_crate() -> void:
	var vp := get_viewport_rect().size
	var crate_x: float = vp.x * CRATE_X_FRAC
	var cat_x0: float = (player as Node2D).global_position.x
	var stand_x: float = crate_x + (90.0 if cat_x0 > crate_x else -90.0)
	await _walk_cat_to(stand_x)
	await get_tree().create_timer(0.35).timeout
	await _zoom_and_cutscene(Vector2((crate_x + stand_x) * 0.5, Layout.ground_y() - 70.0),
		"🎬 컷씬 (플레이스홀더)\n\n궤짝을 열어… 보안관으로 변신!\n\n[ 보안관 획득! ]")


## 1-5 펄: 치즈가 화면 맨 왼쪽으로 걸어가 → 창가 펄을 줌인 → 컷씬.
func _event_pearl() -> void:
	var vp := get_viewport_rect().size
	await _walk_cat_to(vp.x * 0.16)
	await get_tree().create_timer(0.3).timeout
	var focus: Vector2 = _event_char.position if is_instance_valid(_event_char) else Vector2(vp.x * 0.1, Layout.ground_y() - 320.0)
	await _zoom_and_cutscene(focus,
		"🎬 컷씬 (플레이스홀더)\n\n창가의 펄과 첫 만남.\n빛나는 돌을 건네자 활짝 웃는다…\n\n[ 펄의 축복 해금! ]")


## 1-7 맥스: 담벼락에 기대 있던 맥스가 치즈에게 다가옴 → 줌인 → 컷씬.
func _event_max() -> void:
	var cat_x: float = (player as Node2D).global_position.x
	var target: float = cat_x + 130.0
	if is_instance_valid(_event_char):
		while absf(_event_char.position.x - target) > 4.0:
			await get_tree().process_frame
			_event_char.position.x = move_toward(_event_char.position.x, target, 230.0 / 60.0)
			_event_char.position.y = Layout.ground_y() - 60.0
	await get_tree().create_timer(0.3).timeout
	await _zoom_and_cutscene(Vector2((cat_x + target) * 0.5, Layout.ground_y() - 90.0),
		"🎬 컷씬 (플레이스홀더)\n\n능글맞은 상인 맥스의 첫 거래.\n\n[ 맥스 상점 · 메이드·음악가 제작 해금! ]")


## 치즈를 x로 자동 도보(왼쪽이면 flip).
func _walk_cat_to(x: float) -> void:
	if player.has_method("event_walk_to"):
		player.event_walk_to(x)
		while player.is_event_walking():
			await get_tree().process_frame


## ★화면 전체(배경+치즈) 줌인. 배경은 CanvasLayer라 Camera2D가 안 먹음 →
##   현재 렌더 프레임을 통째로 캡처해 focus(화면좌표) 기준으로 확대.
func _zoom_and_cutscene(focus: Vector2, text: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	if img != null:
		var snap := ImageTexture.create_from_image(img)
		var zlayer := CanvasLayer.new()
		zlayer.layer = 70
		zlayer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(zlayer)
		var tr := TextureRect.new()
		tr.texture = snap
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.pivot_offset = focus
		zlayer.add_child(tr)
		var zt := 0.0
		while zt < 1.0:
			await get_tree().process_frame
			zt = minf(zt + 1.0 / 50.0, 1.0)
			var e := zt * zt * (3.0 - 2.0 * zt)
			tr.scale = Vector2.ONE * lerpf(1.0, 1.7, e)
	await _play_placeholder_cutscene(text)


func _play_placeholder_cutscene(text: String) -> void:
	var vp := get_viewport_rect().size
	var layer := CanvasLayer.new()
	layer.layer = 80
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.03, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var lbl := Label.new()
	lbl.add_theme_font_override("font", FONT)
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_color", Color("F2B33D"))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.text = text
	lbl.size = Vector2(vp.x - 120.0, 260.0)
	lbl.position = Vector2(60.0, vp.y * 0.5 - 150.0)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layer.add_child(lbl)
	var tap := Button.new()
	tap.flat = true
	tap.focus_mode = Control.FOCUS_NONE
	tap.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(tap)
	var hint := Label.new()
	hint.add_theme_font_override("font", FONT)
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color("D4912A"))
	hint.text = "▶ 탭하여 계속"
	hint.position = Vector2(vp.x * 0.5 - 70.0, vp.y - 80.0)
	layer.add_child(hint)
	var done := [false]
	tap.pressed.connect(func() -> void: done[0] = true)
	while not done[0]:
		await get_tree().process_frame
	layer.queue_free()
