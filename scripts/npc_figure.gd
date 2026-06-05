extends Control
## NPC 캐릭터 placeholder - 고양이풍 도형(머리+귀+몸+표정). 진짜 아트 나오면 교체.
## set_fig(색, 표정)로 색·기분 변경. 표정: neutral/happy/annoyed/shy

var body_color := Color(0.6, 0.5, 0.7)
var mood := "neutral"


func set_fig(c: Color, m: String) -> void:
	body_color = c
	mood = m
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var cx := w * 0.5
	var head_r := minf(w, h) * 0.20
	var head := Vector2(cx, h * 0.40)
	var body := Vector2(cx, head.y + head_r * 1.7)
	var ink := Color(0.12, 0.10, 0.14)

	# 몸(둥근 블롭)
	draw_circle(body, head_r * 1.5, body_color)
	# 귀(삼각형)
	for sx in [-1.0, 1.0]:
		var b := head + Vector2(sx * head_r * 0.55, -head_r * 0.55)
		var er := head_r * 0.6
		draw_colored_polygon(PackedVector2Array([
			b + Vector2(-er * 0.45, er * 0.25), b + Vector2(er * 0.45, er * 0.25), b + Vector2(sx * er * 0.1, -er)
		]), body_color.darkened(0.08))
	# 머리
	draw_circle(head, head_r, body_color.lightened(0.08))

	# 표정
	var ex := head_r * 0.42
	var ey := -head_r * 0.05
	if mood == "happy":
		for sx in [-1.0, 1.0]:
			draw_arc(head + Vector2(sx * ex, ey), head_r * 0.18, PI, TAU, 14, ink, 4.0)
	elif mood == "annoyed":
		for sx in [-1.0, 1.0]:
			draw_line(head + Vector2(sx * ex - head_r * 0.13, ey - head_r * 0.12),
					head + Vector2(sx * ex + head_r * 0.13, ey), ink, 4.0)
	else:
		for sx in [-1.0, 1.0]:
			draw_circle(head + Vector2(sx * ex, ey), head_r * 0.13, ink)
	# 입
	var mc := head + Vector2(0, head_r * 0.42)
	if mood == "annoyed":
		draw_line(mc + Vector2(-head_r * 0.18, 0), mc + Vector2(head_r * 0.18, 0), ink, 4.0)
	else:
		draw_arc(mc, head_r * 0.22, 0.12 * PI, 0.88 * PI, 14, ink, 4.0)
	# 볼터치(부끄/기쁨)
	if mood == "shy" or mood == "happy":
		var blush := Color(1.0, 0.5, 0.6, 0.5)
		for sx in [-1.0, 1.0]:
			draw_circle(head + Vector2(sx * head_r * 0.62, head_r * 0.22), head_r * 0.16, blush)
