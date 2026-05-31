extends CharacterBody2D
## 치즈(주인공) — 좌우 이동 + 점프(회피) + 원거리 자동사격 + 피격/넉백
##
## ★핵심 규칙: 치즈는 "살아있는 관문"이고, 적은 항상 오른쪽에서 온다.
##   그래서 치즈는 절대 좌우 반전하지 않는다 — 언제나 오른쪽을 본다.
##   · 오른쪽 이동 = 앞으로 걸음(walk) / 왼쪽 이동 = 뒷걸음질(back)
##   · 정지 = idle / 공중 = jump / 피격·넉백 = hit

## --- 이동 ---
@export var base_speed: float = 300.0
@export var move_multiplier: float = 1.0      # 직업 이동속도 배율 (맨몸 치즈 = 1.0)
@export var left_margin: float = 40.0
@export var right_margin: float = 70.0

## --- 점프(회피) ---
@export var jump_force: float = 700.0
@export var gravity: float = 1800.0

## --- 체력 ---
@export var max_health: float = 100.0         # 맨몸 치즈 체력(시스템밸런스 §4.1)

## --- 원거리 사격 ---
@export var bullet_scene: PackedScene
@export var ranged_damage: float = 8.0        # 맨몸 치즈 원거리공격력(돌) 8
@export var attack_interval: float = 1.0      # 공격속도 1.0/s → 1초에 1발
@export var muzzle_offset: Vector2 = Vector2(40, -70)  # 총구 위치(치즈 기준)

## --- 접촉 피해/넉백 ---
@export var contact_distance: float = 70.0    # 적과 이 거리 안이면 밟은 것으로 간주
@export var knockback_speed: float = 420.0    # 왼쪽으로 튕기는 속도
@export var knockback_time: float = 0.22      # 튕겨나가는 시간
@export var invuln_time: float = 0.8          # 피격 후 무적 시간

var health: float
var ground_y: float
var on_ground: bool = true

var _fire_timer: float = 0.0
var _knockback_timer: float = 0.0
var _invuln_timer: float = 0.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	ground_y = position.y
	health = max_health
	anim.flip_h = false  # 절대 좌우 반전 안 함 — 치즈는 항상 오른쪽을 본다
	add_to_group("player")
	_update_hp_bar()


func _physics_process(delta: float) -> void:
	# 타이머 감소
	_fire_timer -= delta
	if _knockback_timer > 0.0:
		_knockback_timer -= delta
	if _invuln_timer > 0.0:
		_invuln_timer -= delta

	var direction := Input.get_axis("move_left", "move_right")

	# 좌우 이동 (넉백 중이면 입력 무시하고 왼쪽으로 튕김)
	if _knockback_timer > 0.0:
		velocity.x = -knockback_speed
		direction = 0.0
	else:
		velocity.x = direction * base_speed * move_multiplier

	# 점프(회피) — 땅에 있고 넉백 중이 아닐 때만
	if on_ground and _knockback_timer <= 0.0 and Input.is_action_just_pressed("jump"):
		velocity.y = -jump_force
		on_ground = false

	if not on_ground:
		velocity.y += gravity * delta

	move_and_slide()

	# 바닥 라인 착지
	if position.y >= ground_y:
		position.y = ground_y
		velocity.y = 0.0
		on_ground = true

	# 화면 안에서만 (왼쪽 끝 ~ 오른쪽 끝)
	var screen_width := get_viewport_rect().size.x
	position.x = clampf(position.x, left_margin, screen_width - right_margin)

	# 원거리 자동 사격
	_handle_shooting()

	# 적과 접촉 시 피해 + 넉백
	_handle_contact()

	# 무적 동안 깜빡임
	anim.modulate.a = 0.45 if _invuln_timer > 0.0 else 1.0

	_update_animation(direction)


## --- 사격 ---
func _handle_shooting() -> void:
	if _fire_timer > 0.0 or bullet_scene == null:
		return
	var target := _nearest_enemy()
	if target == null:
		return
	_fire_timer = attack_interval
	_fire_at(target)


func _fire_at(target: Node2D) -> void:
	var bullet := bullet_scene.instantiate()
	var muzzle := global_position + muzzle_offset
	var dir := (target.global_position - muzzle).normalized()
	if bullet.has_method("setup"):
		bullet.setup(dir, ranged_damage)
	bullet.global_position = muzzle
	get_parent().add_child(bullet)


## 살아있는 가장 가까운 적을 찾는다.
func _nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var best := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if e.has_method("is_dead") and e.is_dead():
			continue
		var d := global_position.distance_to((e as Node2D).global_position)
		if d < best:
			best = d
			nearest = e
	return nearest


## --- 접촉 피해 + 왼쪽 넉백 ---
func _handle_contact() -> void:
	if _invuln_timer > 0.0:
		return
	var e := _nearest_enemy()
	if e == null:
		return
	if global_position.distance_to(e.global_position) <= contact_distance:
		var dmg = e.get("damage")
		if dmg == null:
			dmg = 5.0
		_take_hit(float(dmg))


func _take_hit(amount: float) -> void:
	health -= amount
	_knockback_timer = knockback_time
	_invuln_timer = invuln_time
	_update_hp_bar()
	if health <= 0.0:
		# 게임오버 — 지금은 임시로 스테이지 재시작(연출은 나중에)
		get_tree().reload_current_scene()


func _update_hp_bar() -> void:
	var bar := get_tree().get_first_node_in_group("hp_bar")
	if bar:
		bar.max_value = max_health
		bar.value = health


## 상황에 맞는 애니메이션 재생
func _update_animation(direction: float) -> void:
	var next := "idle"
	if _knockback_timer > 0.0:
		next = "hit"
	elif not on_ground:
		next = "jump"
	elif direction > 0.0:
		next = "walk"
	elif direction < 0.0:
		next = "back"

	if anim.animation != next:
		anim.play(next)
