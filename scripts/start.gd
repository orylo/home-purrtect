extends Control
## 게임 첫 화면 - 타이틀 아트 + [게임 시작] 버튼 + 버전 표시.
## 타이틀 이미지는 가로를 꽉 채우되 "위 정렬"로 그려 상단 텍스트가 안 잘리게 한다.

@onready var title: TextureRect = $Title

var _plate: Panel   # 버전 명판(물건화)


## 우하단 버전 명판 생성/재배치 (세이프영역 안쪽). 리사이즈마다 호출되므로 1개만 유지.
func _version_plate() -> void:
	var sz := Vector2(168, 44)
	if _plate == null or not is_instance_valid(_plate):
		_plate = Design.framed_plate(GameState.BUILD + " ver.", "caption")
		_plate.custom_minimum_size = sz
		_plate.size = sz
		add_child(_plate)
	var vp := get_viewport_rect().size
	_plate.position = Vector2(vp.x - sz.x - 40.0, vp.y - sz.y - 28.0)


func _ready() -> void:
	# [게임 시작] = 게임으로 "진입/수락" → 골드 브랜드 CTA(베벨). 전투 돌입 아니므로 빨강 아님(design.md §1 CTA규칙)
	Design.style_button($StartButton, "brand", Design.FS_DISPLAY_S)
	# 텍스트 = tr()(로컬라이즈 파이프라인 레퍼런스). 키→문구는 assets/i18n/ui.csv. 지금은 ko 고정.
	$StartButton.text = tr("ui.start.continue") if GameState.has_save() else tr("ui.start.play")
	$StartButton.pressed.connect(_on_start)
	# 버전 = 작은 금속 명판(물건화 데모, design.md §0-7). 원래 라벨은 숨김.
	$Version.visible = false
	_version_plate()
	get_viewport().size_changed.connect(_layout_title)
	get_viewport().size_changed.connect(_version_plate)
	_layout_title()
	# 개발자 모드 진입 = 우하단 작은 흰 동그라미(나만 인지). 호버 효과 없음. DEV 빌드만.
	$DevButton.visible = GameState.is_dev()
	if GameState.is_dev():
		$DevButton.pressed.connect(_on_dev)
		var circle := StyleBoxFlat.new()
		circle.bg_color = Color(1, 1, 1, 0.5)   # 흰색 반투명
		circle.set_corner_radius_all(40)
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			$DevButton.add_theme_stylebox_override(st, circle)   # 모든 상태 동일 → 호버 변화 없음


	# [처음부터] = 진행 초기화(세이브 있을 때만 노출, 확인 팝업 거침). 좌하단 앵커 고정(웹 리사이즈에도 안 밀림).
	if GameState.has_save():
		var fresh := Design.button(tr("ui.start.newgame"), "secondary", Design.FS_BODY)
		fresh.custom_minimum_size = Vector2(150, 52)
		fresh.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		fresh.offset_left = 40.0
		fresh.offset_top = -80.0
		fresh.offset_right = 40.0 + 150.0
		fresh.offset_bottom = -28.0
		fresh.pressed.connect(_confirm_new_game)
		add_child(fresh)
	# ※ 프롤로그 자동재생·[이야기] 다시보기 폐기 - 이제 [게임 시작](세이브 없을 때=새 게임)·[처음부터]를 눌렀을 때만 재생.


func _layout_title() -> void:
	if title.texture == null:
		return
	var vp := get_viewport_rect().size
	var tex := title.texture.get_size()
	# 가로를 꽉 채우는 커버 스케일(세로가 모자라면 세로 기준으로 키움)
	var sc := vp.x / tex.x
	if tex.y * sc < vp.y:
		sc = vp.y / tex.y
	var w := tex.x * sc
	var h := tex.y * sc
	title.size = Vector2(w, h)
	title.position = Vector2((vp.x - w) * 0.5, 0.0)   # 가로 가운데 + 위 정렬(상단 텍스트 보임)


func _on_start() -> void:
	GameState.mode = "player"
	_apply_player_run_flags()
	if GameState.AUTOSAVE and GameState.has_save():
		# 이어하기 = 세이브 로드 후 프롤로그 없이 바로 홈(개발자 세션 잔여 해금/코인 제거)
		GameState.load_game()
		get_tree().change_scene_to_file("res://scenes/home.tscn")
	else:
		# 세이브 없음 = 새 게임 → 프롤로그 1회 → 홈
		GameState.reset_progress()
		_play_prologue_then_home()


func _on_new_game() -> void:
	# [처음부터] = 진행 초기화 후 프롤로그 → 홈
	GameState.mode = "player"
	GameState.new_game()         # 진행·별점·올스타 초기화 + 세이브 덮어쓰기
	_apply_player_run_flags()
	_play_prologue_then_home()


## 플레이어 런 공통 플래그(치트 끔·난이도 1·일반 스테이지)
func _apply_player_run_flags() -> void:
	GameState.cheats = {"godmode": false, "enemy_oneshot": false, "enemy_count_mult": 1.0}
	GameState.difficulty = 1.0
	GameState.sandbox = false   # 플레이어 모드는 항상 일반 스테이지


## 새 게임 진입 = 프롤로그 컷씬 1회 재생 후 홈으로(프롤로그가 prologue_return 보고 이동)
func _play_prologue_then_home() -> void:
	GameState.prologue_return = "home"
	get_tree().change_scene_to_file("res://scenes/prologue.tscn")


## "처음부터" 확인 팝업(진행 삭제는 되돌릴 수 없어 한 번 묻는다)
func _confirm_new_game() -> void:
	var vp := get_viewport_rect().size
	var ov := Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(ov)
	var dim := ColorRect.new()
	dim.color = Color(Design.INK.r, Design.INK.g, Design.INK.b, 0.6)   # 모달 딤(§12)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.add_child(dim)
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", Design.panel_box())
	var pw := 520.0
	var ph := 220.0
	panel.position = Vector2((vp.x - pw) * 0.5, (vp.y - ph) * 0.5)
	panel.size = Vector2(pw, ph)
	ov.add_child(panel)
	var msg := Design.label("처음부터 시작할까요?\n지금까지의 진행·별점이 모두 사라집니다.", "title", Design.INK)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	msg.offset_top = 28.0; msg.offset_bottom = 120.0
	panel.add_child(msg)
	var no := Design.button(tr("ui.common.no"), "secondary", Design.FS_BODY)
	no.position = Vector2(40, ph - 76.0); no.size = Vector2(200, 56); no.custom_minimum_size = no.size
	no.pressed.connect(func(): ov.queue_free())
	panel.add_child(no)
	var yes := Design.button("처음부터", "danger", Design.FS_BODY)
	yes.position = Vector2(pw - 240.0, ph - 76.0); yes.size = Vector2(200, 56); yes.custom_minimum_size = yes.size
	yes.pressed.connect(_on_new_game)
	panel.add_child(yes)


func _on_dev() -> void:
	GameState.mode = "dev"
	get_tree().change_scene_to_file("res://scenes/dev_menu.tscn")
