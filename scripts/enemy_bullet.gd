extends Node2D
## 적의 placeholder 발사체 — 직선(grav=0) / 포물선(grav>0)으로 날아가
## 치즈(player)에 닿으면 데미지 + 상태이상(독/둔화). 아트 나오면 _draw만 교체.

var _vel := Vector2.ZERO
var _grav := 0.0
var damage := 5.0
var status := ""           # ""/"poison"/"slow"
var color := Color(0.8, 0.3, 0.2)
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
	_ground_y = Layout.ground_y()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _grav > 0.0:
		_vel.y += _grav * delta
	global_position += _vel * delta
	_life -= delta
	queue_redraw()

	var p := get_tree().get_first_node_in_group("player")
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
	draw_circle(Vector2.ZERO, 11.0, color)
	draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 14, Color(0, 0, 0, 0.5), 1.5, true)
