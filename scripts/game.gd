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
	if player.has_method("set_event_idle"):
		player.set_event_idle(true)
	# 1) 치즈가 궤짝 위치까지 자동 도보(왼쪽이면 flip)
	var crate_x: float = vp.x * CRATE_X_FRAC
	if player.has_method("event_walk_to"):
		player.event_walk_to(crate_x)
		while player.is_event_walking():
			await get_tree().process_frame
	await get_tree().create_timer(0.35).timeout   # 도착 후 한 박자

	# 2) 궤짝+치즈를 확대(카메라 줌인). ★트리 일시정지 중이라 Tween은 안 돎 → 수동 lerp(process_frame는 pause에도 발신).
	var cam := Camera2D.new()
	cam.process_mode = Node.PROCESS_MODE_ALWAYS
	var focus_x: float = (crate_x + (player as Node2D).global_position.x) * 0.5
	cam.global_position = Vector2(focus_x, Layout.ground_y() - 110.0)
	add_child(cam)
	cam.make_current()
	var zt := 0.0
	while zt < 1.0:
		await get_tree().process_frame
		zt = minf(zt + 1.0 / 50.0, 1.0)         # ~1초
		var e := zt * zt * (3.0 - 2.0 * zt)     # smoothstep
		cam.zoom = Vector2.ONE.lerp(Vector2(2.3, 2.3), e)

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
