extends Node2D
## 적의 placeholder 발사체 — 직선(grav=0) / 포물선(grav>0)으로 날아가
## 치즈(player)에 닿으면 데미지 + 상태이상(독/둔화). 아트 나오면 _draw만 교체.

var _vel := Vector2.ZERO
var _grav := 0.0
var damage := 5.0
var status := ""           # ""/"poison"/"slow"
var color := Color(0.8, 0.3, 0.2)
var shape := "dot"              # dot(원) / stone(회색 돌-투척쥐) / cone(원뿔 독침-벌)
var hit_y_offset := -90.0       # 치즈 어디 높이를 맞히는지(기본 몸통 -90 / 박쥐 머리 -180)
var dodge_by_crouch := false    # 박쥐 음파: 앉으면(crouching) 회피
var _ground_y := 0.0
var _life := 4.0


func setup(vel: Vector2, dmg: float, st: String, col: Color, grav: float) -> void:
	_vel = vel
	damage = dmg
	status = st
	color = col
	_grav = grav


func _ready() -> void:
	# 클리어(트리 일시정지) 중에도 계속 날아 바닥에 떨어지게(허공 정지 방지).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ground_y = Layout.ground_y()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _grav > 0.0:
		_vel.y += _grav * delta
	global_position += _vel * delta
	_life -= delta
	if shape == "stone":
		rotation += delta * 6.0            # 돌멩이: 날아가며 빙글
	elif shape == "cone":
		rotation = _vel.angle()            # 원뿔 독침: 진행 방향 향함
	queue_redraw()

	# 트리 일시정지(클리어·일시정지 메뉴) 중엔 날아가되 데미지는 주지 않음(시각적으로만 낙하).
	var p := get_tree().get_first_node_in_group("player") if not get_tree().paused else null
	if p and is_instance_valid(p):
		if global_position.distance_to((p as Node2D).global_position + Vector2(0, hit_y_offset)) < 70.0:
			if dodge_by_crouch and bool(p.get("crouching")):
				pass   # 앉아서 음파 회피 → 그냥 통과(맞지 않음)
			else:
				if p.has_method("take_damage"):
					p.take_damage(damage)
				if status != "" and p.has_method("apply_status"):
					p.apply_status(status)
				queue_free()
				return

	if _grav > 0.0 and global_position.y >= _ground_y:
		queue_free()
	elif global_position.x < -60.0 or global_position.x > get_viewport_rect().size.x + 60.0 or _life <= 0.0:
		queue_free()


func _draw() -> void:
	# 바닥 그림자 — 높이(바닥과의 거리)에 따라 크기·농도 변화(치즈/적 그림자와 동일 로직).
	var gy: float = _ground_y - global_position.y    # 바닥 위 높이(로컬 y)
	if gy > 4.0:
		var t: float = clampf(1.0 - gy / 460.0, 0.22, 1.0)
		var sr := 13.0 if shape == "stone" else (12.0 if shape == "cone" else 10.0)
		draw_set_transform(Vector2(0, gy), -rotation, Vector2(1.0, 0.3))   # 회전 보정해 바닥에 평평
		draw_circle(Vector2.ZERO, sr * t, Color(0, 0, 0, 0.24 * t))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	match shape:
		"stone": _draw_stone()
		"cone":  _draw_cone()
		_:
			draw_circle(Vector2.ZERO, 11.0, color)
			draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 14, Color(0, 0, 0, 0.5), 1.5, true)


## 밝은 회색 돌멩이 — 너무 까맣지 않게(따뜻한 톤).
func _draw_stone() -> void:
	var r := 16.0
	var body := Color(0.68, 0.66, 0.62)
	var edge := Color(0.40, 0.38, 0.34)
	var shade := Color(0.55, 0.53, 0.49)
	var hi := Color(0.88, 0.86, 0.82)
	draw_circle(Vector2.ZERO, r, body)
	draw_circle(Vector2(r * 0.28, r * 0.3), r * 0.55, shade)   # 아래쪽 그림자
	draw_circle(Vector2(-r * 0.32, -r * 0.32), r * 0.28, hi)   # 위쪽 하이라이트
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, edge, 2.0, true)


## 원뿔 독침 — 벌 전용(진행 방향 +X로 그리고 rotation으로 정렬).
func _draw_cone() -> void:
	var body := color                                # 벌 노란 몸
	var tip := Color(0.30, 0.22, 0.05)               # 어두운 침 끝
	var pts := PackedVector2Array([Vector2(15, 0), Vector2(-11, -8), Vector2(-11, 8)])
	draw_colored_polygon(pts, body)
	var outline := PackedVector2Array([Vector2(15, 0), Vector2(-11, -8), Vector2(-11, 8), Vector2(15, 0)])
	draw_polyline(outline, Color(0, 0, 0, 0.55), 1.6, true)
	draw_circle(Vector2(13, 0), 2.6, tip)            # 침 끝 강조
	draw_circle(Vector2(-6, 0), 3.2, Color(1, 1, 1, 0.5))   # 몸 하이라이트
