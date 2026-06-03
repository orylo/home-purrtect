extends Node2D
## 배경 레이어링 테스트 — far(원경) 뒤 + ground(전경, 마젠타 제거) 앞 + 치즈가 돌길에 섬.
##   탭/클릭하면 시작화면으로. 빨간 선 = 게임 바닥선(Layout.ground_y) 정렬 확인용.
##   GROUND_SURF / FAR_DROP 으로 정렬 미세조정.

const FAR := preload("res://assets/backgrounds/bgtest/far.jpg")
const GROUND := preload("res://assets/backgrounds/bgtest/ground.png")
const GROUND_SURF := 0.86   # ground 이미지에서 '서는 면(돌길/잔디)'의 세로 위치(0~1)
const FAR_DROP := 0.0       # far를 아래로 내리는 양(px)

var _cat: AnimatedSprite2D
var _surf := 0.86


func _ready() -> void:
	_surf = GROUND_SURF
	_cat = AnimatedSprite2D.new()
	var frames := load("res://assets/sprites/cheese/base/cheese_base.tres")
	if frames:
		_cat.sprite_frames = frames
		_cat.play("idle")
	add_child(_cat)
	get_viewport().size_changed.connect(queue_redraw)
	set_process(true)


func _process(_delta: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	_cat.position = Vector2(vp.x * 0.42, Layout.ground_y())   # 발이 원점 → 바닥선에 섬
	queue_redraw()


func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		get_tree().change_scene_to_file("res://scenes/start.tscn")


func _draw() -> void:
	var vp := get_viewport().get_visible_rect().size
	# 1) far — 화면 커버(비율 유지), 바닥 고정
	var ft := FAR.get_size()
	var fsc := maxf(vp.x / ft.x, vp.y / ft.y)
	var fw := ft.x * fsc
	var fh := ft.y * fsc
	draw_texture_rect(FAR, Rect2(Vector2((vp.x - fw) * 0.5, vp.y - fh + FAR_DROP), Vector2(fw, fh)), false)
	# 2) ground — '서는 면'이 바닥선(ground_y)에 오도록 세로 정렬
	var gt := GROUND.get_size()
	var gsc := maxf(vp.x / gt.x, vp.y / gt.y)
	var gw := gt.x * gsc
	var gh := gt.y * gsc
	var gx := (vp.x - gw) * 0.5
	var gy := Layout.ground_y() - _surf * gh       # 서는 면 row를 바닥선에 맞춤
	draw_texture_rect(GROUND, Rect2(Vector2(gx, gy), Vector2(gw, gh)), false)
	# 3) 바닥선(빨강, 정렬 확인용)
	var ly := Layout.ground_y()
	draw_line(Vector2(0, ly), Vector2(vp.x, ly), Color(1, 0, 0, 0.6), 3.0)
