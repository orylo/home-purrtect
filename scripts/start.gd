extends Control
## 게임 첫 화면 — 타이틀 아트 + [게임 시작] 버튼 + 버전 표시.
## 타이틀 이미지는 가로를 꽉 채우되 "위 정렬"로 그려 상단 텍스트가 안 잘리게 한다.

@onready var title: TextureRect = $Title


func _ready() -> void:
	$Version.text = GameState.BUILD + " ver."
	$StartButton.pressed.connect(_on_start)
	get_viewport().size_changed.connect(_layout_title)
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
