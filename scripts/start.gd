extends Control
## 게임 첫 화면 — 타이틀 아트 + [게임 시작] 버튼 + 버전 표시.
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


	# [이야기] = 프롤로그 컷씬 다시보기(좌하단)
	var vp := get_viewport_rect().size
	var story := Design.button("이야기", "secondary", Design.FS_BODY)
	story.custom_minimum_size = Vector2(150, 52)
	story.position = Vector2(40, vp.y - 80)
	story.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/prologue.tscn"))
	add_child(story)
	# 첫 실행이면 프롤로그 자동 재생(본 뒤엔 prologue_seen=true → 안 뜸)
	if not GameState.prologue_seen:
		get_tree().change_scene_to_file.call_deferred("res://scenes/prologue.tscn")


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
	GameState.reset_progress()   # 항상 1-1부터(개발자 세션 잔여 해금 방지)
	if GameState.AUTOSAVE:
		GameState.load_game()    # (출시 빌드) 세이브 있으면 진행·해금 이어받기
	GameState.cheats = {"godmode": false, "enemy_oneshot": false, "enemy_count_mult": 1.0}
	GameState.difficulty = 1.0
	GameState.sandbox = false   # 플레이어 모드는 항상 일반 스테이지
	get_tree().change_scene_to_file("res://scenes/home.tscn")   # 홈 허브로


func _on_dev() -> void:
	GameState.mode = "dev"
	get_tree().change_scene_to_file("res://scenes/dev_menu.tscn")
