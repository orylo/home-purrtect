extends CharacterBody2D
## 적 — 쥐 (1막 기본 지상 러셔)
##
## 오른쪽에서 등장해 왼쪽(집)으로 "걷고-멈추기"를 반복하며 전진한다.
## 치즈(살아있는 관문)에 닿으면 멈춘다 — 통과하지 못한다.
## 쥐끼리는 서로 부딪혀 줄을 선다(앞 쥐가 막히면 뒤 쥐도 멈춤).
##
## ※ 이번 단계는 "등장 + 전진 + 관문에서 멈춤"까지.
##   HP·공격·사격(전투)은 다음 단계에서 추가.

@export var move_speed: float = 120.0   # 걷는 단계 이동 속도(px/s) — 튜닝값
@export var walk_time: float = 1.5      # 걷는 시간(시스템밸런스 §1.1: 쥐 1.5s)
@export var stop_time: float = 1.0      # 멈추는 시간(쥐 1.0s)
@export var stop_gap: float = 80.0      # 치즈 앞 이 거리에서 멈춤(관문)

var _phase_timer: float = 0.0
var _walking: bool = true

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	anim.flip_h = false  # 쥐는 그림 자체가 왼쪽을 봄(진행 방향) — 뒤집지 않음
	anim.play("walk")
	_phase_timer = walk_time


func _physics_process(delta: float) -> void:
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

	# 3) 이동(걷는 단계 + 안 막혔을 때만 전진). 막히면 제자리.
	if _walking and not blocked:
		velocity.x = -move_speed
	else:
		velocity.x = 0.0
	velocity.y = 0.0

	# move_and_slide로 이동 — 쥐끼리는 충돌해서 자연스럽게 줄을 선다
	move_and_slide()
