extends Node2D
## 근경(Foreground) — 3중 배경의 가장 가까운 레이어. z_index로 캐릭터보다 "앞".
##   stage_background가 고른 near_pieces(0~2개)를 각자 해당 화면 모서리에 고정해 그린다.
##   바람: 각 식물을 뿌리(모서리)를 중심으로 살랑살랑 회전. 잘림 방지로 모서리 밖으로 살짝 깊이 박음.

const NEAR_REF_H := 768.0     # 근경 원본 세로(이 기준으로 화면에 스케일)
const SWAY_AMP := 0.05        # 바람 흔들림 최대 각(rad ≈ 2.9°)
const SWAY_SPD := 1.0         # 흔들림 속도 배율
const OVERSHOOT := 26.0       # 뿌리를 모서리 밖으로 밀어넣는 깊이(px) — 흔들려도 안 잘리게

var _t := 0.0


func _ready() -> void:
	get_viewport().size_changed.connect(queue_redraw)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var bg := get_tree().get_first_node_in_group("stage_bg")
	if bg == null:
		return
	var pieces: Array = bg.near_pieces
	if pieces.is_empty():
		return
	var vis := get_viewport().get_visible_rect().size
	var sc := vis.y / NEAR_REF_H
	for p in pieces:
		var tex: Texture2D = p["tex"]
		var corner: String = p["corner"]
		var w := tex.get_width() * sc
		var h := tex.get_height() * sc
		var ang := sin(_t * SWAY_SPD * float(p["spd"]) + float(p["phase"])) * SWAY_AMP
		# 모서리(뿌리=회전축) 위치 + 텍스처를 그 축 기준 어디에 둘지
		var pivot: Vector2
		var rect: Rect2
		match corner:
			"tl":
				pivot = Vector2(-OVERSHOOT, -OVERSHOOT)
				rect = Rect2(0, 0, w, h)
			"tr":
				pivot = Vector2(vis.x + OVERSHOOT, -OVERSHOOT)
				rect = Rect2(-w, 0, w, h)
			"bl":
				pivot = Vector2(-OVERSHOOT, vis.y + OVERSHOOT)
				rect = Rect2(0, -h, w, h)
			_:  # br
				pivot = Vector2(vis.x + OVERSHOOT, vis.y + OVERSHOOT)
				rect = Rect2(-w, -h, w, h)
		draw_set_transform(pivot, ang, Vector2.ONE)   # 뿌리(모서리) 중심 회전
		draw_texture_rect(tex, rect, false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)   # 변환 원복
