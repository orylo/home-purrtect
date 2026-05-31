extends Control
## 가상 조이스틱 (왼손) — 모바일 이동 + 점프
##
## · 화면 왼쪽-아래 영역을 누르면 그 자리에 조이스틱이 생긴다(동적).
## · 드래그하면 좌우로 이동(Touch.move_axis 갱신).
## · 거의 안 움직이고 떼면 = 탭 = 점프(Touch.request_jump).
## 키보드(←→/스페이스)도 그대로 쓸 수 있다.

@export var base_radius: float = 90.0   # 베이스(바깥 링) 크기
@export var knob_radius: float = 46.0   # 노브(손잡이) 크기
@export var tap_threshold: float = 18.0 # 이만큼 안 움직이고 떼면 '탭(점프)'

var _active: bool = false
var _center: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO
var _moved: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # 입력을 가로채지 않음(버튼 정상 동작)
	resized.connect(queue_redraw)
	get_viewport().size_changed.connect(queue_redraw)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_press(event.pressed, event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_press(event.pressed, event.position)
	elif event is InputEventScreenDrag and _active:
		_handle_drag(event.position)
	elif event is InputEventMouseMotion and _active:
		_handle_drag(event.position)


func _handle_press(pressed: bool, pos: Vector2) -> void:
	if pressed:
		# 왼쪽 + 조작 띠 안에서 시작한 터치만 조이스틱으로
		if not _active and pos.x < size.x * 0.5 and pos.y > Layout.band_top():
			_active = true
			_center = pos
			_knob = pos
			_moved = 0.0
			queue_redraw()
	else:
		if _active:
			if _moved < tap_threshold:
				Touch.request_jump()   # 거의 안 움직였으면 탭 = 점프
			_active = false
			Touch.move_axis = 0.0
			queue_redraw()


func _handle_drag(pos: Vector2) -> void:
	var off := pos - _center
	_moved = maxf(_moved, off.length())
	if off.length() > base_radius:
		off = off.normalized() * base_radius
	_knob = _center + off
	Touch.move_axis = clampf(off.x / base_radius, -1.0, 1.0)
	queue_redraw()


func _draw() -> void:
	if _active:
		draw_circle(_center, base_radius, Color(1, 1, 1, 0.12))
		draw_arc(_center, base_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.45), 3.0)
		draw_circle(_knob, knob_radius, Color(1, 1, 1, 0.40))
		draw_arc(_knob, knob_radius, 0.0, TAU, 32, Color(1, 1, 1, 0.8), 3.0)
	else:
		# 쉬는 위치 — 조작 띠의 왼쪽 세로 중앙에 흐릿하게 표시
		var band_cy := (Layout.band_top() + size.y) * 0.5
		var rest := Vector2(50.0 + base_radius, band_cy)
		draw_circle(rest, base_radius, Color(1, 1, 1, 0.08))
		draw_arc(rest, base_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.25), 2.0)
		draw_circle(rest, knob_radius, Color(1, 1, 1, 0.15))
