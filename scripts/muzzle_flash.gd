extends Node2D
## 총구 이펙트 ─ 사격 순간 번쩍(flash) / 불발 시 연기(smoke).

const DUR: float = 0.07          # 화염 지속
const SMOKE_DUR: float = 0.55    # 연기 지속
var _t: float = 0.0
var _smoke: float = 0.0


func flash() -> void:
	_t = DUR


## 불발 ─ 총구에서 회색 연기가 피어오름
func smoke() -> void:
	_smoke = SMOKE_DUR


func _process(delta: float) -> void:
	if _t > 0.0:
		_t -= delta
	if _smoke > 0.0:
		_smoke -= delta
	queue_redraw()


func _draw() -> void:
	# 발사 화염 ─ 크고 밝게(불발과 확 차이)
	if _t > 0.0:
		var a := _t / DUR
		# 앞으로 뻗는 화염 줄기(머즐 플래시)
		draw_line(Vector2.ZERO, Vector2(34.0 * a, 0), Color(1, 0.85, 0.3, 0.85 * a), 7.0 * a)
		# 별 모양 스파크(네 갈래)
		var spark := 30.0 * a
		for d in [Vector2(1, 0), Vector2(-0.4, 0), Vector2(0, 1), Vector2(0, -1)]:
			draw_line(Vector2.ZERO, d * spark, Color(1, 0.95, 0.6, 0.8 * a), 2.5)
		draw_circle(Vector2.ZERO, 9.0 + 26.0 * a, Color(1, 0.9, 0.4, 0.9 * a))
		draw_circle(Vector2.ZERO, 4.0 + 13.0 * a, Color(1, 1, 1, a))
	# 불발 연기 ─ 위로 피어오르며 옅어짐
	if _smoke > 0.0:
		var p := 1.0 - _smoke / SMOKE_DUR   # 0 → 1 진행
		for i in range(3):
			var off := Vector2(2.0 + i * 4.0, -p * 26.0 - i * 8.0)
			var r := (5.0 + i * 3.0) * (0.6 + p * 0.9)
			var al := (1.0 - p) * 0.5
			draw_circle(off, r, Color(0.62, 0.62, 0.66, al))
