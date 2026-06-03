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


func _process(delta: float) -> void:
	# 화면 흔들림 — 월드(Main)와 배경(BG)을 같이 흔들고 HUD는 고정
	var off := Vector2.ZERO
	if Fx.shake > 0.0:
		Fx.shake = move_toward(Fx.shake, 0.0, 45.0 * delta)
		off = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * Fx.shake
	position = off
	bg.offset = off


func _on_stage_cleared() -> void:
	var bonus := GameState.award_stage_clear()   # 첫 클리어 보너스 코인(파밍은 0)
	var si := get_node_or_null("StageIntro")     # 클리어 퇴장 이벤트(있으면)가 먼저
	if si != null and si.has_method("has_outro") and si.has_outro():
		await si.play_outro()
	get_tree().paused = true
	hud.show_clear(bonus)


func _on_player_died() -> void:
	get_tree().paused = true
	hud.show_gameover()


# 전투 씬 내 컷씬(보안관 1-3): 결과창 [확인] 후 — 치즈가 궤짝까지 걸어가 → 확대 → 컷씬(플레이스홀더) → 홈.
const CRATE_X_FRAC := 0.25   # 1-3 배경 나무 궤짝 화면 x(뷰포트 비율, 좌측). 필요 시 조정.

func _on_inscene_event() -> void:
	# 트리는 일시정지 상태 유지(치즈는 PROCESS_MODE_ALWAYS라 이벤트 도보 가능)
	var vp := get_viewport().get_visible_rect().size
	hud.visible = false                       # 깨끗한 컷씬(HP바 등 숨김)
	if player.has_method("set_event_idle"):
		player.set_event_idle(true)
	# 1) 치즈가 궤짝 "옆"까지 자동 도보 — 궤짝 위에 겹치지 않게 근접면에 서서 궤짝을 바라봄.
	var crate_x: float = vp.x * CRATE_X_FRAC
	var cat_x0: float = (player as Node2D).global_position.x
	var stand_x: float = crate_x + (90.0 if cat_x0 > crate_x else -90.0)
	if player.has_method("event_walk_to"):
		player.event_walk_to(stand_x)
		while player.is_event_walking():
			await get_tree().process_frame
	await get_tree().create_timer(0.35).timeout   # 도착 후 한 박자

	# 2) ★화면 전체(배경+치즈) 줌인. 배경은 CanvasLayer라 Camera2D가 안 먹음 →
	#    현재 렌더 프레임을 통째로 캡처해 그 스냅샷을 궤짝+치즈 영역 기준으로 확대한다.
	var focus := Vector2((crate_x + stand_x) * 0.5, Layout.ground_y() - 70.0)
	await get_tree().process_frame            # 최신 상태(치즈 도착·HUD 숨김) 렌더 후 캡처
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
		tr.pivot_offset = focus                # 이 점을 중심으로 확대(궤짝+치즈)
		zlayer.add_child(tr)
		var zt := 0.0
		while zt < 1.0:
			await get_tree().process_frame
			zt = minf(zt + 1.0 / 50.0, 1.0)    # ~1초
			var e := zt * zt * (3.0 - 2.0 * zt)
			tr.scale = Vector2.ONE * lerpf(1.0, 1.7, e)

	# 3) 컷씬(플레이스홀더) — 풀스크린 패널 + [확인]
	await _play_placeholder_cutscene()

	# 4) 보상 확정 + 진행 → 홈
	GameState.advance_stage()
	if GameState.mode != "dev" and GameState.AUTOSAVE:
		GameState.save_game()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/home.tscn")


func _play_placeholder_cutscene() -> void:
	var vp := get_viewport().get_visible_rect().size
	var layer := CanvasLayer.new()
	layer.layer = 80
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.03, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var lbl := Label.new()
	lbl.add_theme_font_override("font", preload("res://assets/fonts/Pretendard-Regular.ttf"))
	lbl.add_theme_font_size_override("font_size", 34)
	lbl.add_theme_color_override("font_color", Color("F2B33D"))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.text = "🎬 컷씬 (플레이스홀더)\n\n궤짝을 열어… 보안관으로 변신!\n\n[ 보안관 획득! ]"
	lbl.size = Vector2(vp.x - 120.0, 240.0)
	lbl.position = Vector2(60.0, vp.y * 0.5 - 140.0)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layer.add_child(lbl)
	var tap := Button.new()
	tap.flat = true
	tap.focus_mode = Control.FOCUS_NONE
	tap.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(tap)
	var hint := Label.new()
	hint.add_theme_font_override("font", preload("res://assets/fonts/Pretendard-Regular.ttf"))
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
