extends Control
const UI_FONT := preload("res://assets/fonts/Pretendard-Regular.ttf")
## 가상 조이스틱 (왼손) — 모바일 이동 + 점프
##
## · 화면 왼쪽-아래 영역을 누르면 그 자리에 조이스틱이 생긴다(동적).
## · 드래그하면 좌우로 이동(Touch.move_axis 갱신).
## · 거의 안 움직이고 떼면 = 탭 = 점프(Touch.request_jump).
## 키보드(←→/스페이스)도 그대로 쓸 수 있다.

@export var base_radius: float = 84.0   # 베이스(바깥 링) 크기
@export var knob_radius: float = 46.0   # 노브(손잡이) 크기
@export var tap_threshold: float = 18.0 # 이만큼 안 움직이고 떼면 '탭(점프)'

var _active: bool = false
var _touch_index: int = -99   # 멀티터치 구분(공격 버튼과 동시 사용 가능하게)
var _up_active: bool = false  # 위로 올려 점프한 상태(연속 점프 방지)
var _center: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO
var _moved: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # 입력을 가로채지 않음(버튼 정상 동작)
	resized.connect(queue_redraw)
	get_viewport().size_changed.connect(queue_redraw)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_press(event.pressed, event.position, event.index)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_press(event.pressed, event.position, -1)
	elif event is InputEventScreenDrag and _active and event.index == _touch_index:
		_handle_drag(event.position)
	elif event is InputEventMouseMotion and _active and _touch_index == -1:
		_handle_drag(event.position)


func _handle_press(pressed: bool, pos: Vector2, index: int) -> void:
	if pressed:
		# 왼쪽 + 조작 띠 안에서 시작한 터치만 조이스틱으로
		if not _active and pos.x < size.x * 0.5 and pos.y > Layout.band_top():
			_active = true
			_touch_index = index
			_center = pos
			_knob = pos
			_moved = 0.0
			queue_redraw()
	else:
		if _active and index == _touch_index:
			if _moved < tap_threshold:
				Touch.request_jump()   # 거의 안 움직였으면 탭 = 점프
			_active = false
			_touch_index = -99
			_up_active = false
			Touch.move_axis = 0.0
			Touch.crouch_held = false
			queue_redraw()


func _handle_drag(pos: Vector2) -> void:
	var off := pos - _center
	_moved = maxf(_moved, off.length())
	if off.length() > base_radius:
		off = off.normalized() * base_radius
	_knob = _center + off
	var thr := base_radius * 0.5
	if off.y < -thr:
		# 위로 올리면 점프(한 번만 — 내렸다 다시 올려야 또 점프)
		if not _up_active:
			Touch.request_jump()
			_up_active = true
		Touch.crouch_held = false
		Touch.move_axis = clampf(off.x / base_radius, -1.0, 1.0)
	elif off.y > thr:
		# 아래로 당기면 앉기(회피)
		_up_active = false
		Touch.crouch_held = true
		Touch.move_axis = 0.0
	else:
		# 가운데 영역: 좌우 이동
		_up_active = false
		Touch.crouch_held = false
		Touch.move_axis = clampf(off.x / base_radius, -1.0, 1.0)
	queue_redraw()


func _draw() -> void:
	if _active:
		_draw_pad(_center, 1.0)
		_draw_knob(_knob)
		_draw_wasd(_center, 1.0)
	else:
		# 쉬는 위치 — 조작 띠의 왼쪽 세로 중앙
		var band_cy := (Layout.band_top() + size.y) * 0.5
		var rest := Vector2(50.0 + base_radius, band_cy)
		_draw_pad(rest, 0.85)
		_draw_knob(rest)
		_draw_wasd(rest, 0.85)


const TEX_BASE := preload("res://assets/ui/slots/slot2_act.png")   # 전투 HUD 슬롯 에셋

## 베이스 패드 — 전투 HUD 슬롯 텍스처(공격 버튼 아래 슬롯과 동일 톤)
func _draw_pad(c: Vector2, op: float) -> void:
	var s := base_radius * 2.3
	draw_texture_rect(TEX_BASE, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(1, 1, 1, op))


## 노브(손잡이) — 골든 + 잉크 외곽선 + 하이라이트
func _draw_knob(c: Vector2) -> void:
	draw_circle(c + Vector2(0, 3), knob_radius, _col(Design.INK, 0.25))         # 그림자
	draw_circle(c, knob_radius, Design.CHEESE)
	draw_arc(c, knob_radius, 0.0, TAU, 48, Design.INK, 5.0)
	draw_circle(c + Vector2(-knob_radius * 0.32, -knob_radius * 0.32), knob_radius * 0.26, _col(Color(1, 1, 1), 0.45))


## 상하좌우에 W S A D 키 힌트 — 잉크색(크림 위)
func _draw_wasd(c: Vector2, op: float) -> void:
	var font := UI_FONT
	if font == null:
		return
	var d := base_radius * 0.82   # 노브(노란 원) 바깥으로 밀어 겹침 방지
	_key_label(font, c + Vector2(0.0, -d), "W", op)
	_key_label(font, c + Vector2(0.0, d), "S", op)
	_key_label(font, c + Vector2(-d, 0.0), "A", op)
	_key_label(font, c + Vector2(d, 0.0), "D", op)


func _key_label(font: Font, center: Vector2, ch: String, op: float) -> void:
	var fs := 24
	var pos := center + Vector2(-15.0, 9.0)
	draw_string_outline(font, pos, ch, HORIZONTAL_ALIGNMENT_CENTER, 30.0, fs, 4, _col(Design.PAPER, 0.7 * op))
	draw_string(font, pos, ch, HORIZONTAL_ALIGNMENT_CENTER, 30.0, fs, _col(Design.INK, op))


func _col(base: Color, a: float) -> Color:
	return Color(base.r, base.g, base.b, a)
