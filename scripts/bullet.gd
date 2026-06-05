extends Area2D
## 치즈의 원거리 투사체. 직업마다 날아가는 방식이 다르다(player.gd가 setup으로 정해줌).
##   · straight : 오른쪽으로 곧게.
##        - max_range=0 → 끝까지(보안관 총알)
##        - max_range>0 → 그 거리까지 가며 fade_start 이후 점점 투명 → 소멸(음악가)
##        - wave_amp>0 → 좌우로 가되 위아래로 물결치며 전진(음악가 음표)
##        - 투명해지면(_alpha<0.4) 데미지 0
##   · lob      : 손으로 포물선 던지기(메이드/맨몸). 중력 받아 떨어지고,
##                바닥에 닿으면 소멸. 위로 던져지면 공중의 적도 맞출 수 있음.
## shape : dot(흰 원) / stone(회색 돌) / plate(접시 타원) / note(음표 ♪)

@export var radius: float = 8.0
const SHATTER_DUR := 0.25          # 바닥에 닿아 깨지는 연출 시간(접시·돌)

var mode: String = "straight"      # straight | lob
var shape: String = "dot"          # dot | stone | plate | note
var note_type: int = 0             # 음표 모양 종류(0=8분음표 1=잇단음표 2=4분음표)
var _velocity: Vector2 = Vector2.RIGHT * 700.0
var _base_speed: float = 700.0     # 잔상 방향/길이용
var grav: float = 0.0              # lob 중력 (Area2D 내장 gravity와 이름 충돌 피함)
var max_range: float = 0.0         # straight: 0=무제한, >0=이 거리까지(페이드 후 소멸)
var fade_start: float = 0.6        # 사거리의 이 비율부터 투명해지기 시작
var wave_amp: float = 0.0          # 물결 진폭(px) - 0이면 직선
var wave_freq: float = 0.0         # 물결 주파수(rad/px)
var _trail: Array = []             # 음표 잔상용 과거 위치(글로벌)
var damage: float = 8.0
var knockback: float = 70.0
var stun: float = 0.0
var crit: bool = false

var _start_x: float = 0.0
var _base_y: float = 0.0
var _dist: float = 0.0             # 진행한 가로 거리(물결 위상용)
var _alpha: float = 1.0
var _ground_y: float = 0.0
var _shattering: bool = false      # 바닥에서 깨지는 중(접시·돌)
var _shatter_t: float = 0.0


## 모양별 바닥 그림자 반지름(시각 크기에 맞춤)
func _shadow_radius() -> float:
	match shape:
		"plate": return 22.0
		"stone": return 15.0
		"note":  return 9.0
		_:       return 9.0


## 모양별 히트박스 반지름(시각 크기에 맞춤)
func _hit_radius() -> float:
	match shape:
		"stone": return 14.0
		"plate": return 27.0   # 접시 1.7배에 맞춤
		"note":  return 9.0
		_:       return radius


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
	# 클리어·이벤트(대화 팝업) 등 트리 일시정지 중에도 탄환은 계속 날아가게(허공 정지 방지).
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 적의 "몸 히트박스"(Area2D)에만 맞도록 area_entered 사용
	area_entered.connect(_on_area_entered)
	_start_x = global_position.x
	_base_y = global_position.y
	_ground_y = Layout.ground_y()
	# 모양에 맞게 히트박스 크기 조정(공유 리소스 변형 방지 위해 복제)
	var cs := get_node_or_null("CollisionShape2D")
	if cs and cs.shape:
		cs.shape = cs.shape.duplicate()
		cs.shape.radius = _hit_radius()
	queue_redraw()


func _physics_process(delta: float) -> void:
	# 깨지는 중이면 연출만 진행
	if _shattering:
		_shatter_t -= delta
		queue_redraw()
		if _shatter_t <= 0.0:
			queue_free()
		return

	if mode == "lob":
		_velocity.y += grav * delta
		# 접시·돌은 날아가며 빙글 회전
		if shape == "plate":
			rotation += delta * 7.0
		elif shape == "stone":
			rotation += delta * 3.5
	global_position += _velocity * delta

	# 음악가 음표: 좌우로 가되 위아래로 물결
	if mode == "straight" and wave_amp > 0.0:
		_dist += absf(_velocity.x) * delta
		global_position.y = _base_y + sin(_dist * wave_freq) * wave_amp
		if shape == "note":
			_trail.append(global_position)
			if _trail.size() > 9:
				_trail.remove_at(0)
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

	# 던지기: 바닥에 떨어지면 - 접시·돌은 깨짐 연출 후 소멸, 그 외는 바로 소멸
	if mode == "lob":
		queue_redraw()
		if global_position.y >= _ground_y:
			global_position.y = _ground_y
			if shape == "plate" or shape == "stone":
				_shattering = true
				_shatter_t = SHATTER_DUR
				_velocity = Vector2.ZERO
				rotation = 0.0
			else:
				queue_free()
			return

	# 화면 밖으로 나가면 제거(메모리 정리)
	var sw := get_viewport_rect().size.x
	if global_position.x > sw + 40.0 or global_position.x < -40.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	# 트리 일시정지(클리어·대화 팝업) 중엔 날아가되 피격 판정은 보류(그냥 통과 → 시각적 비행만).
	if get_tree().paused:
		return
	# 깨지는 중이면 데미지 없음
	if _shattering:
		return
	# 불발(데미지 0)은 통과 - 그냥 바닥에 떨어짐
	if damage <= 0.0:
		return
	# 투명해진 탄환(음악가 사거리 끝)은 데미지 없음
	if max_range > 0.0 and _alpha < 0.4:
		return
	var enemy := area.get_parent()
	if enemy and enemy.is_in_group("enemies"):
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage, knockback, stun, crit)
		queue_free()


func _draw() -> void:
	if _shattering:
		var p := 1.0 - _shatter_t / SHATTER_DUR
		if shape == "plate":
			_draw_shatter(p, Color(0.96, 0.96, 0.92))   # 접시: 얇은 조각
		else:
			_draw_shatter_stone(p)                       # 돌: 회색 덩어리 + 먼지
		return
	# 바닥 그림자 - 모든 탄환. 회전(돌·접시)해도 바닥에 평평하게(역회전 보정).
	var dy := _ground_y - global_position.y
	if dy > 2.0:
		var t := clampf(1.0 - dy / 450.0, 0.3, 1.0)
		var sp := Vector2(0.0, dy).rotated(-rotation)   # 회전 보정한 바닥 위치
		draw_set_transform(sp, -rotation, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, _shadow_radius() * t, Color(0, 0, 0, 0.22 * t * _alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	match shape:
		"note":  _draw_note(_alpha, note_type)
		"stone": _draw_stone(_alpha)
		"plate": _draw_plate(_alpha)
		_:       _draw_dot(_alpha)


## 회색 돌멩이 - 흰 탄환의 약 2배 크기
func _draw_stone(a: float) -> void:
	var r := radius * 2.0   # ≈16
	var body := Color(0.55, 0.55, 0.58, a)
	var edge := Color(0.28, 0.28, 0.30, a)
	var shade := Color(0.42, 0.42, 0.45, a)
	var hi := Color(0.72, 0.72, 0.75, a)
	draw_circle(Vector2.ZERO, r, body)
	draw_circle(Vector2(r * 0.28, r * 0.3), r * 0.55, shade)   # 아래쪽 그림자
	draw_circle(Vector2(-r * 0.32, -r * 0.32), r * 0.28, hi)   # 위쪽 하이라이트
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, edge, 2.0, true)


## 접시 - 큰 타원형(가로로 납작)
func _draw_plate(a: float) -> void:
	var col := Color(0.96, 0.96, 0.92, a)   # 크림빛 도자기
	var edge := Color(0.5, 0.5, 0.55, a)
	var rim := Color(0.8, 0.8, 0.85, a)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.42))  # 세로로 눌러 타원
	draw_circle(Vector2.ZERO, 34.0, col)                       # 1.7배 크게
	draw_arc(Vector2.ZERO, 34.0, 0.0, TAU, 32, edge, 2.2, true)
	draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 28, rim, 1.6, true)  # 안쪽 테
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)         # 변환 원복


## 깨짐 - 얇은 파편이 사방으로 튀며 사라짐(접시용)
func _draw_shatter(p: float, base: Color) -> void:
	var a := 1.0 - p
	var dirs := [Vector2(-1, -0.5), Vector2(-0.4, -0.95), Vector2(0.3, -1.0), Vector2(0.9, -0.6), Vector2(1.1, -0.1)]
	for i in range(dirs.size()):
		var d: Vector2 = dirs[i]
		var pos := d * (p * 30.0) + Vector2(0, p * p * 40.0)   # 튀었다가 중력으로 떨어짐
		draw_circle(pos, 4.0 * a + 1.0, Color(base.r, base.g, base.b, a))


## 돌멩이 깨짐 - 회색 덩어리 6조각 + 먼지 퍼프
func _draw_shatter_stone(p: float) -> void:
	var a := 1.0 - p
	# 먼지 퍼프(연하게 퍼짐)
	draw_circle(Vector2(0, -3), 9.0 + p * 24.0, Color(0.6, 0.6, 0.62, 0.22 * a))
	var chunks := [
		[Vector2(-1.0, -0.6), 5.5], [Vector2(-0.3, -1.05), 4.0],
		[Vector2(0.5, -0.95), 6.0], [Vector2(1.05, -0.5), 4.5],
		[Vector2(-0.7, -0.25), 3.5], [Vector2(0.25, -0.4), 3.0],
	]
	for c in chunks:
		var d: Vector2 = c[0]
		var pos := d * (p * 30.0) + Vector2(0, p * p * 44.0)
		var rr: float = float(c[1]) * a + 1.0
		draw_circle(pos, rr, Color(0.5, 0.5, 0.53, a))
		draw_circle(pos + Vector2(-rr * 0.3, -rr * 0.3), rr * 0.42, Color(0.72, 0.72, 0.75, a))


func _draw_dot(a: float) -> void:
	var dir := _velocity.normalized()
	# ① 부드러운 외광(글로우) - 따뜻한 빛 번짐
	draw_circle(Vector2.ZERO, radius * 2.4, Color(1.0, 0.85, 0.5, 0.10 * a))
	draw_circle(Vector2.ZERO, radius * 1.6, Color(1.0, 0.9, 0.6, 0.18 * a))
	# ② 모션 스트릭(뒤로 길게 늘어지는 빛줄기)
	for i in range(1, 6):
		var p := -dir * (i * 6.0)
		draw_circle(p, radius * (1.0 - i * 0.16), Color(1.0, 0.88, 0.55, (0.30 - i * 0.05) * a))
	# ③ 본체 - 달궈진 탄알(가장자리 금속, 중심 흰빛)
	draw_circle(Vector2.ZERO, radius, Color(0.95, 0.82, 0.55, a))
	draw_circle(Vector2.ZERO, radius * 0.62, Color(1.0, 0.98, 0.9, a))
	draw_circle(Vector2(-radius * 0.3, -radius * 0.32), radius * 0.34, Color(1, 1, 1, a))  # 광택
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 16, Color(0.25, 0.18, 0.1, a), 1.2, true)


func _draw_note(a: float, t: int) -> void:
	# 잔상(트레일) - 지나온 물결 경로에 금빛 글로우. 오래된 것일수록 흐리고 작게.
	var n := _trail.size()
	for i in n:
		var age := float(i + 1) / float(n + 1)        # 0(오래)~1(최근)
		var lp: Vector2 = _trail[i] - global_position  # 로컬 좌표
		var ta := a * age * age
		if ta > 0.03:
			draw_circle(lp, 3.0 + 8.0 * age, Color(1.0, 0.86, 0.3, 0.22 * ta))   # 노란 헤일로
			draw_circle(lp, 1.5 + 4.0 * age, Color(1.0, 1.0, 0.8, 0.7 * ta))     # 흰 코어
	# 음표 본체 글로우(노랑→흰) + 따뜻한 흰색 채움 + 금빛 외곽
	draw_circle(Vector2.ZERO, 18.0, Color(1.0, 0.80, 0.20, 0.16 * a))
	draw_circle(Vector2.ZERO, 11.0, Color(1.0, 0.93, 0.55, 0.28 * a))
	var col := Color(1.0, 0.99, 0.88, a)
	var edge := Color(0.55, 0.40, 0.10, a)
	match t:
		1:
			# 잇단음표(♫) - 머리 2개 + 기둥 2개 + 위쪽 빔(beam)
			_note_head(Vector2(-6, 4.0), col, edge)
			_note_head(Vector2(10, 1.0), col, edge)
			draw_line(Vector2(-0.5, 2.0), Vector2(-0.5, -24.0), col, 2.6)
			draw_line(Vector2(15.5, -1.0), Vector2(15.5, -27.0), col, 2.6)
			draw_line(Vector2(-1.5, -24.0), Vector2(16.5, -27.0), col, 3.2)  # 빔
		2:
			# 4분음표(♩) - 머리 + 기둥만(깃발 없음)
			_note_head(Vector2(0, 2.0), col, edge)
			draw_line(Vector2(6.5, 0.0), Vector2(6.5, -28.0), col, 2.6)
		_:
			# 8분음표(♪) - 머리 + 기둥 + 깃발
			_note_head(Vector2(0, 2.0), col, edge)
			var stem_top := Vector2(6.5, -28.0)
			draw_line(Vector2(6.5, 0.0), stem_top, col, 2.6)
			draw_line(stem_top, stem_top + Vector2(10.0, 9.0), col, 2.6)
			draw_line(stem_top + Vector2(0, 7.0), stem_top + Vector2(9.0, 13.0), col, 2.2)


func _note_head(c: Vector2, col: Color, edge: Color) -> void:
	draw_circle(c, 11.0, Color(1.0, 0.9, 0.45, col.a * 0.22))   # 부드러운 금빛 글로우
	draw_circle(c, 7.0, col)
	draw_circle(c + Vector2(-2.2, -2.4), 2.6, Color(1, 1, 1, col.a))   # 광택 하이라이트
	draw_arc(c, 7.0, 0.0, TAU, 18, edge, 1.5, true)
