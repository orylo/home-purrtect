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
	# 적의 "몸 히트박스"(Area2D)에만 맞도록 area_entered 사용
	area_entered.connect(_on_area_entered)
	queue_redraw()


func _physics_process(delta: float) -> void:
	global_position += _velocity * delta
	# 화면 밖으로 나가면 제거(메모리 정리)
	var sw := get_viewport_rect().size.x
	if global_position.x > sw + 40.0 or global_position.x < -40.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	var enemy := area.get_parent()
	if enemy and enemy.is_in_group("enemies"):
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage)
		queue_free()


func _draw() -> void:
	# 진행 반대 방향으로 옅어지는 꼬리(잔상)
	var dir := _velocity.normalized()
	for i in range(1, 4):
		var p := -dir * (i * 7.0)
		draw_circle(p, radius * (1.0 - i * 0.22), Color(1, 1, 1, 0.32 - i * 0.07))
	draw_circle(Vector2.ZERO, radius, Color(1, 1, 1, 1))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 16, Color(0.1, 0.1, 0.1, 1), 1.5, true)
