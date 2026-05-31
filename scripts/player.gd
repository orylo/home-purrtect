extends CharacterBody2D
## 치즈(주인공) — 좌우 이동 + 점프(회피) + 애니메이션
##
## ★핵심 규칙: 치즈는 "살아있는 관문"이고, 적은 항상 오른쪽에서 온다.
##   그래서 치즈는 절대 좌우 반전하지 않는다 — 언제나 오른쪽을 본다.
##   · 오른쪽으로 이동 = 앞으로 걸음   → "walk"
##   · 왼쪽으로 이동   = 뒷걸음질      → "back"  (몸은 오른쪽 본 채 뒤로)
##   · 정지            = "idle"
##   · 공중(점프)      = "jump"

## --- 이동 ---
@export var base_speed: float = 300.0        # 기준 이동 속도(픽셀/초)
@export var move_multiplier: float = 1.0      # 직업 이동속도 배율 (맨몸 치즈 = 1.0)
@export var left_margin: float = 40.0         # 화면 왼쪽 여백(이만큼 띄움)
@export var right_margin: float = 70.0        # 화면 오른쪽 여백(치즈가 화면 밖으로 안 나가게)

## --- 점프(회피) ---
@export var jump_force: float = 700.0         # 점프 세기(클수록 높이 뜀)
@export var gravity: float = 1800.0           # 중력(클수록 빨리 떨어짐)

var ground_y: float                            # 바닥 높이(시작 y 기준)
var on_ground: bool = true

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	ground_y = position.y
	anim.flip_h = false  # 절대 좌우 반전 안 함 — 치즈는 항상 오른쪽을 본다
	add_to_group("player")  # 적(쥐)이 치즈를 찾을 수 있도록


func _physics_process(delta: float) -> void:
	# move_left = -1, move_right = +1, 안 누르면 0
	var direction := Input.get_axis("move_left", "move_right")

	# 좌우 이동
	velocity.x = direction * base_speed * move_multiplier

	# 점프(회피) — 땅에 있을 때만
	if on_ground and Input.is_action_just_pressed("jump"):
		velocity.y = -jump_force
		on_ground = false

	# 공중이면 중력 적용
	if not on_ground:
		velocity.y += gravity * delta

	move_and_slide()

	# 바닥 라인에 착지 처리(단일 화면 고정 — 바닥 아래로 안 내려감)
	if position.y >= ground_y:
		position.y = ground_y
		velocity.y = 0.0
		on_ground = true

	# 화면 안에서만 움직이게 가두기 (왼쪽 끝 ~ 오른쪽 끝, 화면 밖으로는 못 나감)
	# 참고: 왼쪽 2/3는 "주 무대"라는 게임적 의미일 뿐, 이동 자체는 오른쪽 끝까지 가능.
	var screen_width := get_viewport_rect().size.x
	position.x = clampf(position.x, left_margin, screen_width - right_margin)

	_update_animation(direction)


## 상황에 맞는 애니메이션 재생 (이미 그 애니면 다시 시작하지 않음)
func _update_animation(direction: float) -> void:
	var next := "idle"
	if not on_ground:
		next = "jump"
	elif direction > 0.0:
		next = "walk"
	elif direction < 0.0:
		next = "back"

	if anim.animation != next:
		anim.play(next)
