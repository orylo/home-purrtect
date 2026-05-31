extends Area2D
## 치즈의 원거리 탄환 — 임시 비주얼(흰색 동그라미).
## 오른쪽(타겟 방향)으로 날아가 적에 맞으면 데미지를 주고 사라진다.
## 나중에 직업별 진짜 발사체 그림으로 교체 예정.

@export var speed: float = 700.0
@export var radius: float = 8.0

var _velocity: Vector2 = Vector2.RIGHT * 700.0
var damage: float = 8.0


## 치즈가 발사할 때 방향과 데미지를 정해준다.
func setup(direction: Vector2, dmg: float) -> void:
	_velocity = direction.normalized() * speed
	damage = dmg


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _physics_process(delta: float) -> void:
	global_position += _velocity * delta
	# 화면 밖으로 나가면 제거(메모리 정리)
	var sw := get_viewport_rect().size.x
	if global_position.x > sw + 40.0 or global_position.x < -40.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(1, 1, 1, 1))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 16, Color(0.1, 0.1, 0.1, 1), 1.5, true)
