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
	spawner.wave_started.connect(_on_wave_for_timing)
	spawner.stage_cleared.connect(_on_stage_cleared)
	if spawner.has_signal("battle_starting"):
		spawner.battle_starting.connect(_on_battle_starting)   # "전투 시작!" 큐(적 등장 선행)
	player.died.connect(_on_player_died)
	if hud.has_signal("inscene_event_requested"):
		hud.inscene_event_requested.connect(_on_inscene_event)
	_spawn_event_chars()   # 1-5 펄·1-7 맥스 플레이스홀더 상주


var _battle_time: float = 0.0   # 전투 실시간(별점용). 일시정지·이벤트 중엔 _process가 안 돌아 자동 제외.
var _timing: bool = false


func _on_wave_for_timing(current: int, _total: int) -> void:
	if current == 1:                # 첫 웨이브 스폰 = 측정 시작(인트로 등은 이미 끝난 뒤)
		_battle_time = 0.0
		_timing = true


## 전투 시작 큐 — 첫 웨이브 대기 시작 시(적 등장보다 ~1.5s 먼저) 배너+팡파르
func _on_battle_starting() -> void:
	Music.clear_override()                  # 인트로 전용 BGM(보스 등) 해제 → 씬 기준 battle BGM 복귀
	if hud.has_method("show_battle_start"):
		hud.show_battle_start()


func _process(delta: float) -> void:
	# 별점 시간 누적 (이 _process는 트리 일시정지 중엔 안 돌아 이벤트·일시정지 자동 제외)
	if _timing:
		_battle_time += delta
		if hud.has_method("set_battle_time"):
			hud.set_battle_time(_battle_time)
	# 화면 흔들림 — 월드(Main)와 배경(BG)을 같이 흔들고 HUD는 고정
	var off := Vector2.ZERO
	if Fx.shake > 0.0:
		Fx.shake = move_toward(Fx.shake, 0.0, 45.0 * delta)
		off = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * Fx.shake
	position = off
	bg.offset = off


func _on_stage_cleared() -> void:
	# ★ 별점 판정 — 클리어 시점(전투 시간)으로 확정
	_timing = false
	var stg := GameState.stage_minor
	var stars := GameState.rate_stars(stg, _battle_time)
	var is_first := not GameState.cleared_stages.has(stg)
	var prev_best := GameState.best_star(stg)         # 신기록 판정용(갱신 전 기록)
	GameState.record_star(stg, stars)                 # 별 최고기록 max 갱신
	var first_gem := ""
	if is_first:
		first_gem = GameState.first_clear_star_gem(stars)   # ★2/★3 첫클리어 보석
		if first_gem != "":
			GameState.add_material(first_gem)
	# 구간 올스타 보석은 자동 지급 안 함 — 스테이지 맵 [받기]로 수동 수령(claim_allstar).
	var star_info := {
		"stars": stars, "time": _battle_time, "first_gem": first_gem,
		"is_first": is_first, "new_best": stars > prev_best,
		"t2": GameState.star_time_t2(stg), "t3": GameState.star_time_t3(stg),
	}

	if stg == 5 and is_first:
		GameState.add_material("gem_pebble")          # 1-5 펄 해금: 빛나는 조약돌 고정 지급(헌납 튜토, 첫 클리어만 — 재도전 파밍 중복 방지)
	var bonus := GameState.award_stage_clear(stars)   # 첫 클리어 보너스 코인(별 차등, 파밍은 0)
	if GameState.mode != "dev" and GameState.AUTOSAVE:
		GameState.save_game()                         # 별·보석 즉시 저장
	var si := get_node_or_null("StageIntro")          # 클리어 퇴장 이벤트(있으면)가 먼저
	if si != null and si.has_method("has_outro") and si.has_outro():
		await si.play_outro()
	# 점프 중 마지막 적을 처치한 경우, 공중에서 결과창이 뜨지 않게 착지까지 대기(아웃트로 없을 때 포함)
	var pl := get_node_or_null("Player")
	var guard := 0
	while pl != null and pl.has_method("is_airborne") and pl.is_airborne() and guard < 180:
		await get_tree().process_frame
		guard += 1
	get_tree().paused = true
	hud.show_clear(bonus, star_info)


func _on_player_died() -> void:
	get_tree().paused = true
	hud.visible = false
	_play_gameover_cutscene()


# 게임오버 = 영감의 전보 컷씬(플레이스홀더) → 같은 스테이지 재도전(자산·코인 유지).
func _play_gameover_cutscene() -> void:
	if not GameState.cheats.get("skip_events", false):   # DEV 이벤트스킵: 게임오버 컷씬 생략
		await _play_cutscene(CUT_GAMEOVER)
	# 같은 스테이지 재도전(보유 자산·코인·전리품 유지)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")


# ── 전투 씬 내 컷씬(케이스 A 해금형: 1-3 보안관 / 1-5 펄 / 1-7 맥스) ──────────
#   결과창 [확인] 후 씬전환 없이 이어서: 대상에 다가감/상호작용 → 화면 줌인 → 컷씬(플레이스홀더) → 홈.
const CRATE_X_FRAC := 0.25   # 1-3 나무 궤짝 화면 x(뷰포트 비율, 좌측). 필요 시 조정.
const FONT := preload("res://assets/fonts/Pretendard-Regular.ttf")
var _event_char: Node2D = null   # 펄/맥스 플레이스홀더(전투 내내 상주)

# ── 컷씬 페이지 데이터(대본 `기획_이벤트대본_1막.md` 충실) — 장 수 맞춰 플레이스홀더 ─────
#   각 페이지 = {"img": 그릴 그림 설명, "line": 대사(없으면 무대사)}. 실제 아트는 추후 교체.
const CUT_SHERIFF := [   # 1-3 보안관 획득(⑤-b, 4장·사일런트+해금)
	{"img": "햇빛 아래, 나무 궤짝이 끼익— 열리며 먼지가 폭 인다.", "line": ""},
	{"img": "궤짝 안, 카우보이 모자·별 배지·권총집 한 벌이 반짝인다. (★)", "line": ""},
	{"img": "치즈가 장비를 걸치고 별 배지가 반짝 — 변신 완료(보안관).", "line": ""},
	{"img": "보안관이 된 치즈, 늠름한 포즈.", "line": ""},
	{"img": "보안관이 된 치즈, 늠름한 포즈.", "line": "보안관 획득!", "sys": true},
]
const CUT_PEARL := [   # 1-5 펄 첫 만남(④, 6장)
	{"img": "옆집 2층 창가의 펄, 우아한 미소. 치즈와 오묘한 눈빛을 주고받는다.", "line": "펄 : …드디어, 이쪽을 봐주셨군요."},
	{"img": "창가의 펄, 차분히 치즈를 내려다본다.", "line": "펄 : 줄곧 지켜보고 있었답니다. 당신이 이 집을 지키는 모습을…"},
	{"img": "치즈, 완전히 반한 표정(♥)으로 빛나는 돌을 슥 내민다.", "line": "(치즈, 빛나는 돌을 건넨다)", "narr": true},
	{"img": "펄, 받아들고 저도 모르게 환하게 활짝 웃는다(♥) — 진짜 모습.", "line": "펄 : 어머…! 저에게…?"},
	{"img": "펄, 아차 하고 크흠— 헛기침하며 다시 고고한 여신 표정.", "line": "펄 : …크흠. 나쁘진 않네요. 그럭저럭, 봐줄 만해요."},
	{"img": "펄, 아차 하고 크흠— 헛기침하며 다시 고고한 여신 표정.", "line": "펄의 호감도가 1 올랐다 ♥", "sys": true},
	{"img": "펄, 창틀에 기대며 우아하게 손을 내민다.", "line": "펄 : 답례로… 저는 늘 이곳, 집에 있을게요. 싸우러 나서기 전 절 찾아주신다면, 작은 힘을 빌려드리죠."},
	{"img": "펄, 창틀에 기대며 우아하게 손을 내민다.", "line": "펄의 축복 해금!", "sys": true},
]
const CUT_MAX := [   # 1-7 맥스 첫 거래(③, 7장)
	{"img": "맥스(한쪽 눈 흉터, 입에 성냥개비). 치즈를 알아본 듯 피식.", "line": "맥스 : 요즘 동네가 시끌시끌하길래 누군가 했더니… 너였구만, 응?"},
	{"img": "성냥개비를 까딱, 능글맞은 표정.", "line": "맥스 : 이 형님이 말이야~ 싸움에 쓸 만한 물건을 아주 그냥 잔뜩 쟁여놨거든."},
	{"img": "수레 덮개를 휙 젖히면 소모품들이 좌르륵.", "line": "맥스 : 자, 봐봐. 상처엔 붕대, 힘 딸리면 멸치 한 입, 떼거리로 몰려오면 폭죽 한 방이면 끝이지. — 싸게싸게 줄게!"},
	{"img": "목소리를 쫙 낮추며 뜸을 들인다.", "line": "맥스 : 근데 말이야, 진짜배기는 따로 있다 이거야… 두구두구두구—"},
	{"img": "짠, 하고 장비를 꺼내 보인다.", "line": "맥스 : 바로~ 장비 되시겠다! 거리 악사에 초급 메이드까지. 어이, 군침 좀 도는데?"},
	{"img": "손가락을 까딱, 약 올리듯.", "line": "맥스 : 뭐, 이건 특별 주문이라 네가 재료를 좀 긁어모아 와야 하지만 말이야. 공짜가 어딨어, 안 그래?"},
	{"img": "엄지로 골목 쪽을 가리킨다.", "line": "맥스 : 요 앞 골목에 죽치고 있을 테니까, 살 거 있으면 언제든 찾아오라구. 어흠!"},
	{"img": "엄지로 골목 쪽을 가리킨다.", "line": "맥스 상점 · 메이드·음악가 제작 해금!", "sys": true},
]
const CUT_DOVE := [   # 1-13 비둘기 치료(③, 4장)
	{"img": "치즈가 비둘기의 다친 다리를 조심스레 감싸 치료해준다.", "line": "비둘기 : 고, 고맙슴다…! 이 은혜 잊지 않겠슴다!"},
	{"img": "다리를 까딱여보고 멀쩡해지자 푸드덕 일어선다.", "line": "비둘기 : 저 너머에서 쥐떼가 우글우글 훈련하고 있길래, 하늘에서 정찰 좀 하던 참이었슴다."},
	{"img": "비둘기, 분한 듯 다친 다리를 내려다본다.", "line": "비둘기 : 근데 돌 던지는 녀석 하나가… 제 다리를 정통으로 맞혀버렸지 뭡니까. 으윽, 분함다…!"},
	{"img": "비둘기, 날개를 펴고 치즈 어깨에 앉으며 경례하듯.", "line": "비둘기 : 은혜는 갚는 법! 부르시면 언제든 날아오겠슴다. 똥 폭격으로 적들을 묶어드리겠슴다!"},
	{"img": "비둘기, 날개를 펴고 치즈 어깨에 앉으며 경례하듯.", "line": "동료 시스템 해금!", "sys": true},
]
const CUT_CHIHUAHUA := [   # 1-16 치와와 해방(③, 3장)
	{"img": "치즈가 케이지 빗장을 척 열어준다.", "line": "치와와 : 으르르… 드디어! 야, 너 때문에 나온 거 아니다, 내가 나온 거야, 알겠냐?!"},
	{"img": "씩씩대며 폴짝 뛰어나온다.", "line": "치와와 : 낮잠 한숨 자는 사이에 그 빌어먹을 쥐새끼들이! 감히! 이 몸을! 우리에 처넣어?!"},
	{"img": "분이 안 풀린 채 치즈를 째려보다 흥— 콧방귀.", "line": "치와와 : …뭐, 꺼내준 건 인정한다. 갚아주지. 그 쥐새끼들 싹 다 오른쪽으로 처박아줄 테니까, 부르기나 해!"},
	{"img": "분이 안 풀린 채 치즈를 째려보다 흥— 콧방귀.", "line": "동료 치와와 합류!", "sys": true},
]
const CUT_GAMEOVER := [   # 게임오버 영감의 전보(3장)
	{"img": "치즈가 문밖으로 뻥— 쫓겨나 빗속에 나뒹군다. (비)", "line": ""},
	{"img": "골드의 전보가 클로즈업된다.", "line": "골드 : 침입 발생! 넌 해고— …아니다. 마지막 기회를 주마. 정신 차려라! — G", "voice": "gold"},
	{"img": "치즈가 닫힌 문 앞에서 무릎 꿇고 싹싹 빈다 → 벌떡 일어나 주먹 불끈!", "line": "치즈가 싹싹 빈 덕분에 한 번 더 기회를 얻었다! 이번엔 진짜 잘 지켜보자."},
]


## 펄/맥스 플레이스홀더(동그라미)를 전투 시작 시 배치(1-5·1-7 상주, 전투 무관).
func _spawn_event_chars() -> void:
	var vp := get_viewport_rect().size
	match GameState.stage_minor:
		5: _event_char = _make_char("펄", Color(0.95, 0.55, 0.78), Vector2(vp.x * 0.07, Layout.ground_y() - 360.0), 34.0)
		7: _event_char = _make_char("맥스", Color(0.72, 0.52, 0.32), Vector2(vp.x * 0.66, Layout.ground_y() - 60.0), 40.0)
		13: _event_char = _make_char("비둘기", Color(0.7, 0.72, 0.78), Vector2(vp.x * 0.30, Layout.ground_y() - 30.0), 30.0)
		16: _event_char = _make_char("치와와", Color(0.85, 0.7, 0.4), Vector2(vp.x * 0.30, Layout.ground_y() - 34.0), 32.0)


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
	if not GameState.cheats.get("skip_events", false):   # DEV 이벤트스킵(전투만): 클리어 컷씬 생략
		Music.set_override("menu")   # 클리어 후 컷씬 = 전투 BGM 종료, 비전투 트랙(테스트로 menu). 컷씬 끝→홈도 menu라 끊김 없음. (추후 컷씬 전용곡 생기면 교체)
		match GameState.stage_minor:
			3: await _event_crate()
			5: await _event_pearl()
			7: await _event_max()
			13: await _event_rescue(CUT_DOVE)
			16: await _event_rescue(CUT_CHIHUAHUA)
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
	await _zoom_and_cutscene(Vector2((crate_x + stand_x) * 0.5, Layout.ground_y() - 70.0), CUT_SHERIFF)


## 1-5 펄: 치즈가 화면 맨 왼쪽으로 걸어가 → 창가 펄을 줌인 → 컷씬.
func _event_pearl() -> void:
	var vp := get_viewport_rect().size
	await _walk_cat_to(vp.x * 0.16)
	await get_tree().create_timer(0.3).timeout
	var focus: Vector2 = _event_char.position if is_instance_valid(_event_char) else Vector2(vp.x * 0.1, Layout.ground_y() - 320.0)
	await _zoom_and_cutscene(focus, CUT_PEARL, "pearl")


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
	await _zoom_and_cutscene(Vector2((cat_x + target) * 0.5, Layout.ground_y() - 90.0), CUT_MAX, "max")


## 1-13/1-16 구출형: 치즈가 동료(다친/갇힌)에게 다가가 → 줌인 → 컷씬(다중 페이지).
func _event_rescue(pages: Array) -> void:
	var cx: float = _event_char.position.x if is_instance_valid(_event_char) else get_viewport_rect().size.x * 0.30
	var cat_x: float = (player as Node2D).global_position.x
	var stand_x: float = cx + (90.0 if cat_x > cx else -90.0)
	await _walk_cat_to(stand_x)
	await get_tree().create_timer(0.35).timeout
	await _zoom_and_cutscene(Vector2((cx + stand_x) * 0.5, Layout.ground_y() - 70.0), pages)


## 치즈를 x로 자동 도보(왼쪽이면 flip).
func _walk_cat_to(x: float) -> void:
	if player.has_method("event_walk_to"):
		player.event_walk_to(x)
		while player.is_event_walking():
			await get_tree().process_frame


## ★화면 전체(배경+치즈) 줌인. 배경은 CanvasLayer라 Camera2D가 안 먹음 →
##   현재 렌더 프레임을 통째로 캡처해 focus(화면좌표) 기준으로 확대.
func _zoom_and_cutscene(focus: Vector2, pages: Array, voice: String = "") -> void:
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
	await _play_cutscene(pages, voice)


## 컷씬 화자(voice) → 대화창 이름·초상화 색(스프라이트 없는 NPC 플레이스홀더 색).
const CUT_VOICE_NAME := {"pearl": "펄", "max": "맥스"}
const CUT_VOICE_COL := {"pearl": Color(0.95, 0.55, 0.78), "max": Color(0.72, 0.52, 0.32)}

## 다중 페이지 컷씬(플레이스홀더) — 각 페이지 = {"img": 그림 설명, "line": 대사}. 탭으로 넘김.
##   voice = NPC 재잘 보이스 프로필("pearl"/"max"/""=무음). 화자가 한 명일 때 전 페이지 동일.
func _play_cutscene(pages: Array, voice: String = "") -> void:
	for i in pages.size():
		var p: Dictionary = pages[i]
		var is_sys: bool = bool(p.get("sys", false))    # 시스템 알림(호감도·해금) → 합성 시스템음·초상화/이름표 없음·가운데 정렬
		var is_narr: bool = bool(p.get("narr", false))  # 내레이션/지문(화자 아님) → 초상화/이름표 없음·가운데·무음
		var pv: String = ""
		if is_sys:
			pv = "system"
		elif not is_narr:
			pv = String(p.get("voice", voice))          # 페이지별 voice 지정(예: 게임오버 골드) > 컷씬 기본 voice
		await _cut_page(String(p.get("img", "")), String(p.get("line", "")), i + 1, pages.size(), pv, is_sys or is_narr)


## 컷씬 한 페이지: 어두운 바탕 + 회색 "이미지 플레이스홀더([그림] 설명)" + 대사 + 페이지수 + 탭.
func _cut_page(img: String, line: String, idx: int, total: int, voice: String = "", sys: bool = false) -> void:
	var vp := get_viewport_rect().size
	var layer := CanvasLayer.new()
	layer.layer = 80
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.03, 0.95)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	# 회색 이미지 플레이스홀더(중앙 상단) + 그릴 그림 설명
	var iw := vp.x * 0.72
	var ih := vp.y * 0.44
	var box := ColorRect.new()
	box.color = Color(0.34, 0.33, 0.31)
	box.position = Vector2((vp.x - iw) * 0.5, vp.y * 0.08)
	box.size = Vector2(iw, ih)
	layer.add_child(box)
	var imglbl := Label.new()
	imglbl.add_theme_font_override("font", FONT)
	imglbl.add_theme_font_size_override("font_size", 24)
	imglbl.add_theme_color_override("font_color", Color(0.93, 0.91, 0.87))
	imglbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	imglbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	imglbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	imglbl.text = "[ 그림 ]\n" + img
	imglbl.position = box.position + Vector2(28.0, 0.0)
	imglbl.size = Vector2(iw - 56.0, ih)
	layer.add_child(imglbl)
	# 페이지 카운터(우상단)
	var pc := Label.new()
	pc.add_theme_font_override("font", FONT)
	pc.add_theme_font_size_override("font_size", 20)
	pc.add_theme_color_override("font_color", Color("D4912A"))
	pc.text = "%d / %d" % [idx, total]
	pc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pc.size = Vector2(120.0, 26.0)
	pc.position = Vector2(vp.x - 150.0, 28.0)
	layer.add_child(pc)
	# ── 대화창 = 공용 DialoguePanel(인게임 이벤트 펑거스 대화창과 동일 스타일) ──
	#   sys=시스템 알림: 초상화·이름표 없이 박스 전체폭 가운데 정렬(화자 대사와 분리).
	var portrait: Texture2D = null
	if not sys and CUT_VOICE_COL.has(voice):
		portrait = DialoguePanel.solid_portrait(CUT_VOICE_COL[voice])
	var dp := DialoguePanel.build(layer, vp, portrait)
	dp["name_lbl"].text = "" if sys else String(CUT_VOICE_NAME.get(voice, ""))
	dp["text_lbl"].text = line
	var tlbl: Label = dp["text_lbl"]
	if sys:
		var sbox: Control = dp["box"]
		tlbl.position = Vector2(24.0, 18.0)
		tlbl.size = Vector2(sbox.size.x - 48.0, sbox.size.y - 64.0)
		tlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tlbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 탭(전체) — 타이핑 중이면 스킵, 아니면 다음
	var tap := Button.new()
	tap.flat = true
	tap.focus_mode = Control.FOCUS_NONE
	tap.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(tap)
	var typing := [false]
	var done := [false]
	tap.pressed.connect(func() -> void:
		if typing[0]:
			typing[0] = false          # 타이핑 중 탭 = 스킵(전체표시)
		else:
			done[0] = true)            # 그 외 탭 = 다음 페이지
	# 보이스 있으면 한 글자씩 표시 + 재잘 블립
	if voice != "" and VoiceBlip.VOICE_PROFILES.has(voice) and line != "":
		typing[0] = true
		VoiceBlip.reset(voice)
		tlbl.visible_characters = 0
		var n := line.length()
		var dt := VoiceBlip.char_sec(voice)
		var k := 0
		while k < n and typing[0]:
			tlbl.visible_characters = k + 1
			VoiceBlip.blip(voice, line[k], k, n)
			k += 1
			await get_tree().create_timer(dt, true).timeout
		tlbl.visible_characters = -1
		typing[0] = false
	while not done[0]:
		await get_tree().process_frame
	layer.queue_free()
