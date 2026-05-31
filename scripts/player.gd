extends CharacterBody2D
## 치즈(주인공) — Phase 1: 좌우 이동
##
## 기획서 원칙: 치즈는 "살아있는 관문". 화면 왼쪽~2/3 구간에서만 좌우로 움직인다.
## (위아래 이동 없음. 점프=회피는 다음 단계에서 추가.)

## 기준 이동 속도(픽셀/초). 실제 손맛은 플레이테스트로 튜닝하는 값.
@export var base_speed: float = 300.0

## 직업별 이동속도 배율. 맨몸 치즈 = 1.0 (시스템밸런스 §4.1)
@export var move_multiplier: float = 1.0

## 화면 왼쪽 끝에서 얼마나 띄울지(여백, 픽셀)
@export var left_margin: float = 40.0

## 치즈가 갈 수 있는 오른쪽 한계 = 화면 너비의 몇 %인지 (기획: 왼쪽~2/3)
@export var right_limit_ratio: float = 2.0 / 3.0


func _physics_process(_delta: float) -> void:
	# move_left = -1, move_right = +1, 아무것도 안 누르면 0
	var direction := Input.get_axis("move_left", "move_right")

	velocity.x = direction * base_speed * move_multiplier
	velocity.y = 0.0
	move_and_slide()

	# 화면 왼쪽~2/3 구간 밖으로 못 나가게 가두기
	var screen_width := get_viewport_rect().size.x
	var right_limit := screen_width * right_limit_ratio
	position.x = clampf(position.x, left_margin, right_limit)
