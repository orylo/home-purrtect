extends Control
## 게임 첫 화면 — 타이틀 아트 + [게임 시작] 버튼 + 버전 표시.
## 타이틀 이미지는 가로를 꽉 채우되 "위 정렬"로 그려 상단 텍스트가 안 잘리게 한다.

@onready var title: TextureRect = $Title


func _ready() -> void:
	$Version.text = GameState.BUILD + " ver."
	$StartButton.pressed.connect(_on_start)
	get_viewport().size_changed.connect(_layout_title)
	_layout_title()


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
	get_tree().change_scene_to_file("res://scenes/select.tscn")
