extends CharacterBody2D
## 적 — 쥐 (1막 기본 지상 러셔)
##
## 오른쪽에서 등장해 왼쪽(집)으로 "걷고-멈추기"를 반복하며 전진한다.
## 치즈(살아있는 관문)에 막혀 통과하지 못하고, 키 큰 투명벽이라 점프로도 못 넘는다.
## 치즈에 닿아 있으면 attack_interval마다 공격(치즈에게 데미지).
## 치즈가 몸으로 밀면(receive_push) 오른쪽으로 밀린다. 쥐끼리도 부딪혀 줄을 선다.
## 탄환에 맞으면 hit 모션 → HP 0이면 ghost(유령) 연출 후 사라진다.

@export var move_speed: float = 120.0   # 걷는 단계 이동 속도(px/s) — 튜닝값
@export var walk_time: float = 1.5      # 걷는 시간(시스템밸런스 §1.1: 쥐 1.5s)
@export var stop_time: float = 1.0      # 멈추는 시간(쥐 1.0s)
@export var max_health: float = 20.0    # 쥐 HP (시스템밸런스 §3.1)
@export var damage: float = 5.0         # 치즈에게 주는 공격 데미지 (쥐 DMG 5)
@export var attack_interval: float = 1.0  # 공격 간격(쥐 1.0s)

var health: float
var dead: bool = false
var _phase_timer: float = 0.0
var _walking: bool = true
var _hit: bool = false
var _attack_timer: float = 0.0
var _push_vx: float = 0.0
var _flash: float = 0.0       # 피격 흰 번쩍 타이머
var _knockback: float = 0.0   # 피격 시 오른쪽으로 살짝 움찔

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	anim.flip_h = false  # 쥐는 그림 자체가 왼쪽을 봄(진행 방향) — 뒤집지 않음
	# 개체마다 속도·리듬을 살짝 다르게 + 시작 박자를 흩어 로봇처럼 안 보이게
	move_speed *= randf_range(0.85, 1.18)
	walk_time *= randf_range(0.8, 1.25)
	stop_time *= randf_range(0.75, 1.25)
	_walking = randf() > 0.3
	_phase_timer = randf_range(0.15, walk_time if _walking else stop_time)
	anim.play("walk")
	anim.animation_finished.connect(_on_anim_finished)


func _physics_process(delta: float) -> void:
	if dead:
		velocity = Vector2.ZERO
		_push_vx = 0.0
		return

	# 1) 걷고-멈추기 리듬
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		_walking = not _walking
		_phase_timer = walk_time if _walking else stop_time

	# 2) 이동: 밀리는 중이면 오른쪽, 아니면 전진(왼쪽). + 피격 넉백(오른쪽 살짝 움찔)
	var base_vx := 0.0
	if _push_vx > 0.0:
		base_vx = _push_vx
	elif _walking and not _hit:
		base_vx = -move_speed
	_knockback = move_toward(_knockback, 0.0, 280.0 * delta)
	velocity.x = base_vx + _knockback
	velocity.y = 0.0
	move_and_slide()
	_push_vx = 0.0   # 매 프레임 리셋(치즈가 계속 밀면 다시 설정됨)

	# 피격 흰 번쩍
	if _flash > 0.0:
		_flash -= delta
		anim.modulate = Color(1.9, 1.9, 1.9)
	else:
		anim.modulate = Color(1, 1, 1)

	# 3) 치즈에 닿아 있으면 공격
	_attack_timer -= delta
	if _is_touching_player() and _attack_timer <= 0.0:
		_attack_timer = attack_interval
		var player := get_tree().get_first_node_in_group("player")
		if player and player.has_method("take_damage"):
			player.take_damage(damage)


func _is_touching_player() -> bool:
	for i in get_slide_collision_count():
		var other := get_slide_collision(i).get_collider()
		if other and other.is_in_group("player"):
			return true
	return false


## 치즈가 밀기 판단에 쓰는 "현재 전진 속도"(전진 중이면 양수, 멈췄으면 0)
func get_advance_speed() -> float:
	if _walking and not _hit and not dead:
		return move_speed
	return 0.0


## 치즈가 몸으로 밀 때 호출 — 이번 프레임 오른쪽으로 밀린다.
func receive_push(amount: float) -> void:
	if dead:
		return
	_push_vx = max(_push_vx, amount)


func is_dead() -> bool:
	return dead


## 탄환 등에서 호출 — 데미지를 받는다.
func take_damage(amount: float) -> void:
	if dead:
		return
	health -= amount
	if health <= 0.0:
		_die()
	else:
		_hit = true
		_flash = 0.12       # 흰 번쩍
		_knockback = 70.0   # 오른쪽으로 살짝 움찔
		anim.play("hit")


func _on_anim_finished() -> void:
	if dead:
		queue_free()              # ghost(유령) 애니가 끝나면 완전히 제거
	elif _hit and anim.animation == "hit":
		_hit = false
		anim.play("walk")


func _die() -> void:
	dead = true
	velocity = Vector2.ZERO
	anim.modulate = Color(1, 1, 1)  # 번쩍 중 죽어도 유령은 정상 색
	$CollisionShape2D.set_deferred("disabled", true)  # 죽으면 충돌 끔
	anim.play("ghost")
