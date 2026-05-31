extends Node2D
## 총구 화염 — 사격 순간 치즈 총구에서 잠깐 번쩍. flash()로 발동.

const DUR: float = 0.07
var _t: float = 0.0


func flash() -> void:
	_t = DUR


func _process(delta: float) -> void:
	if _t > 0.0:
		_t -= delta
	queue_redraw()


func _draw() -> void:
	if _t <= 0.0:
		return
	var a := _t / DUR
	draw_circle(Vector2.ZERO, 6.0 + 18.0 * a, Color(1, 0.9, 0.4, 0.9 * a))
	draw_circle(Vector2.ZERO, 3.0 + 9.0 * a, Color(1, 1, 1, a))
