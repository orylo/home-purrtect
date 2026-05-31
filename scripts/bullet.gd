extends Area2D
## 치즈의 원거리 투사체. 직업마다 날아가는 방식이 다르다(player.gd가 setup으로 정해줌).
##   · straight : 오른쪽으로 곧게.
##        - max_range=0 → 끝까지(보안관 총알)
##        - max_range>0 → 그 거리까지 가며 fade_start 이후 점점 투명 → 소멸(음악가)
##        - wave_amp>0 → 좌우로 가되 위아래로 물결치며 전진(음악가 음표)
##        - 투명해지면(_alpha<0.4) 데미지 0
##   · lob      : 손으로 포물선 던지기(메이드/맨몸). 중력 받아 떨어지고,
##                바닥에 닿으면 소멸. 위로 던져지면 공중의 적도 맞출 수 있음.
## shape : dot(흰 동그라미) / note(음표 ♪)

@export var radius: float = 8.0

var mode: String = "straight"      # straight | lob
var shape: String = "dot"          # dot | note
var note_type: int = 0             # 음표 모양 종류(0=8분음표 1=잇단음표 2=4분음표)
var _velocity: Vector2 = Vector2.RIGHT * 700.0
var _base_speed: float = 700.0     # 잔상 방향/길이용
var grav: float = 0.0              # lob 중력 (Area2D 내장 gravity와 이름 충돌 피함)
var max_range: float = 0.0         # straight: 0=무제한, >0=이 거리까지(페이드 후 소멸)
var fade_start: float = 0.6        # 사거리의 이 비율부터 투명해지기 시작
var wave_amp: float = 0.0          # 물결 진폭(px) — 0이면 직선
var wave_freq: float = 0.0         # 물결 주파수(rad/px)
var damage: float = 8.0
var knockback: float = 70.0
var stun: float = 0.0
var crit: bool = false

var _start_x: float = 0.0
var _base_y: float = 0.0
var _dist: float = 0.0             # 진행한 가로 거리(물결 위상용)
var _alpha: float = 1.0
var _ground_y: float = 0.0


## 발사 정보를 dict로 받는다.
##   공통: mode/shape/dmg/kb/stun/crit
##   straight: dir, speed, max_range, fade_start, wave_amp, wave_freq
##   lob: vx, vy, gravity
func setup(cfg: Dictionary) -> void:
	mode = cfg.get("mode", "straight")
	shape = cfg.get("shape", "dot")
	note_type = cfg.get("note_type", 0)
	damage = cfg.get("dmg", 8.0)
	knockback = cfg.get("kb", 70.0)
	stun = cfg.get("stun", 0.0)
	crit = cfg.get("crit", false)
	max_range = cfg.get("max_range", 0.0)
	fade_start = cfg.get("fade_start", 0.6)
	wave_amp = cfg.get("wave_amp", 0.0)
	wave_freq = cfg.get("wave_freq", 0.0)
	if mode == "lob":
		grav = cfg.get("gravity", 1500.0)
		_velocity = Vector2(cfg.get("vx", 540.0), cfg.get("vy", -480.0))
		_base_speed = _velocity.length()
	else:
		_base_speed = cfg.get("speed", 700.0)
		var dir: Vector2 = cfg.get("dir", Vector2.RIGHT)
		_velocity = dir.normalized() * _base_speed


func _ready() -> void:
	# 적의 "몸 히트박스"(Area2D)에만 맞도록 area_entered 사용
	area_entered.connect(_on_area_entered)
	_start_x = global_position.x
	_base_y = global_position.y
	_ground_y = Layout.ground_y()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if mode == "lob":
		_velocity.y += grav * delta
	global_position += _velocity * delta

	# 음악가 음표: 좌우로 가되 위아래로 물결
	if mode == "straight" and wave_amp > 0.0:
		_dist += absf(_velocity.x) * delta
		global_position.y = _base_y + sin(_dist * wave_freq) * wave_amp
		queue_redraw()

	# 사거리 제한 + 끝에서 점점 투명(음악가)
	if mode == "straight" and max_range > 0.0:
		var traveled := absf(global_position.x - _start_x)
		var t := traveled / max_range
		if t <= fade_start:
			_alpha = 1.0
		else:
			_alpha = clampf(1.0 - (t - fade_start) / (1.0 - fade_start), 0.0, 1.0)
		queue_redraw()
		if traveled >= max_range:
			queue_free()
			return

	# 던지기: 바닥에 떨어지면 소멸(잔상도 갱신)
	if mode == "lob":
		queue_redraw()
		if global_position.y >= _ground_y:
			queue_free()
			return

	# 화면 밖으로 나가면 제거(메모리 정리)
	var sw := get_viewport_rect().size.x
	if global_position.x > sw + 40.0 or global_position.x < -40.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	# 투명해진 탄환(음악가 사거리 끝)은 데미지 없음
	if max_range > 0.0 and _alpha < 0.4:
		return
	var enemy := area.get_parent()
	if enemy and enemy.is_in_group("enemies"):
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage, knockback, stun, crit)
		queue_free()


func _draw() -> void:
	if shape == "note":
		_draw_note(_alpha, note_type)
	else:
		_draw_dot(_alpha)


func _draw_dot(a: float) -> void:
	# 진행 반대 방향으로 옅어지는 꼬리(잔상)
	var dir := _velocity.normalized()
	for i in range(1, 4):
		var p := -dir * (i * 7.0)
		draw_circle(p, radius * (1.0 - i * 0.22), Color(1, 1, 1, (0.32 - i * 0.07) * a))
	draw_circle(Vector2.ZERO, radius, Color(1, 1, 1, a))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 16, Color(0.1, 0.1, 0.1, a), 1.5, true)


func _draw_note(a: float, t: int) -> void:
	var col := Color(1, 1, 1, a)
	var edge := Color(0.12, 0.12, 0.15, a)
	match t:
		1:
			# 잇단음표(♫) — 머리 2개 + 기둥 2개 + 위쪽 빔(beam)
			_note_head(Vector2(-6, 4.0), col, edge)
			_note_head(Vector2(10, 1.0), col, edge)
			draw_line(Vector2(-0.5, 2.0), Vector2(-0.5, -24.0), col, 2.6)
			draw_line(Vector2(15.5, -1.0), Vector2(15.5, -27.0), col, 2.6)
			draw_line(Vector2(-1.5, -24.0), Vector2(16.5, -27.0), col, 3.2)  # 빔
		2:
			# 4분음표(♩) — 머리 + 기둥만(깃발 없음)
			_note_head(Vector2(0, 2.0), col, edge)
			draw_line(Vector2(6.5, 0.0), Vector2(6.5, -28.0), col, 2.6)
		_:
			# 8분음표(♪) — 머리 + 기둥 + 깃발
			_note_head(Vector2(0, 2.0), col, edge)
			var stem_top := Vector2(6.5, -28.0)
			draw_line(Vector2(6.5, 0.0), stem_top, col, 2.6)
			draw_line(stem_top, stem_top + Vector2(10.0, 9.0), col, 2.6)
			draw_line(stem_top + Vector2(0, 7.0), stem_top + Vector2(9.0, 13.0), col, 2.2)


func _note_head(c: Vector2, col: Color, edge: Color) -> void:
	draw_circle(c, 7.0, col)
	draw_arc(c, 7.0, 0.0, TAU, 18, edge, 1.5, true)
