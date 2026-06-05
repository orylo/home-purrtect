extends Node2D
## 처치 "펑!" 이펙트 - 노란 링이 커지며 사라진다. 끝나면 스스로 제거.

const DUR: float = 0.28
var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= DUR:
		queue_free()


func _draw() -> void:
	var k := clampf(_t / DUR, 0.0, 1.0)
	var r := lerpf(12.0, 76.0, k)
	var a := 1.0 - k
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(1, 1, 0.6, a * 0.9), 5.0)
	draw_arc(Vector2.ZERO, r * 0.6, 0.0, TAU, 28, Color(1, 1, 1, a * 0.7), 3.0)
