extends CharacterBody2D
## 적 — 쥐 (1막 기본 지상 러셔)
##
## 오른쪽에서 등장해 왼쪽(집)으로 "걷고-멈추기"를 반복하며 전진한다.
## 치즈(살아있는 관문)에 닿으면 멈춘다 — 통과하지 못한다.
## 쥐끼리는 서로 부딪혀 줄을 선다.
## 탄환에 맞으면 hit 모션 → HP 0이면 ghost(유령) 연출 후 사라진다.
##
## ※ 쥐가 치즈를 "공격"하는 근접 전투는 다음 단계. 지금은 치즈가 부딪힐 때만
##   접촉 데미지(damage)를 준다(치즈 쪽 스크립트가 처리).

@export var move_speed: float = 120.0   # 걷는 단계 이동 속도(px/s) — 튜닝값
@export var walk_time: float = 1.5      # 걷는 시간(시스템밸런스 §1.1: 쥐 1.5s)
@export var stop_time: float = 1.0      # 멈추는 시간(쥐 1.0s)
@export var stop_gap: float = 85.0      # 치즈 앞 이 거리에서 멈춤(관문)
@export var max_health: float = 20.0    # 쥐 HP (시스템밸런스 §3.1)
@export var damage: float = 5.0         # 치즈에게 주는 접촉 데미지 (쥐 DMG 5)

var health: float
var dead: bool = false
var _phase_timer: float = 0.0
var _walking: bool = true
var _hit: bool = false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	anim.flip_h = false  # 쥐는 그림 자체가 왼쪽을 봄(진행 방향) — 뒤집지 않음
	anim.play("walk")
	_phase_timer = walk_time
	anim.animation_finished.connect(_on_anim_finished)


func _physics_process(delta: float) -> void:
	if dead:
		velocity = Vector2.ZERO
		return

	# 1) 걷고-멈추기 리듬 갱신
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		_walking = not _walking
		_phase_timer = walk_time if _walking else stop_time

	# 2) 치즈(관문) 앞에서 멈춤 — 통과 불가
	var blocked := false
	var player := get_tree().get_first_node_in_group("player")
	if player and global_position.x <= (player as Node2D).global_position.x + stop_gap:
		blocked = true

	# 3) 이동(걷는 단계 + 안 막힘 + 피격중 아님일 때만 전진)
	if _walking and not blocked and not _hit:
		velocity.x = -move_speed
	else:
		velocity.x = 0.0
	velocity.y = 0.0
	move_and_slide()


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
		anim.play("hit")


func _on_anim_finished() -> void:
	if dead:
		queue_free()              # ghost(유령) 애니가 끝나면 완전히 제거
	elif _hit and anim.animation == "hit":
		_hit = false
		anim.play("walk")          # 피격 모션 끝 → 다시 걷기


func _die() -> void:
	dead = true
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)  # 죽으면 충돌 끔
	anim.play("ghost")
