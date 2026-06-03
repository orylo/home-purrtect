extends Node2D
## 지면 레이어 — stage_background가 고른 ground_texture를 그린다.
##   하프톤 셰이더(ColorRect)보다 "앞"에 오도록 별도 노드로 분리(far → 하프톤 → 지면 순서).
##   그리기 규칙은 stage_background._draw_ground와 동일(발선을 길 구간 중앙에, 크롭 상한).

const GROUND_CROP_MAX := 200.0     # 발선을 길 중앙에 맞추려 키울 때 허용하는 좌우 크롭 상한(px)


func _ready() -> void:
	get_viewport().size_changed.connect(queue_redraw)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var bg := get_tree().get_first_node_in_group("stage_bg")
	if bg == null or bg.ground_texture == null:
		return
	var tex: Texture2D = bg.ground_texture
	var surf: float = bg._ground_surf
	var vis := get_viewport().get_visible_rect().size
	var t := tex.get_size()
	var below_frac := 1.0 - surf
	var sc := vis.x / t.x
	if below_frac > 0.02:
		var sc_center := 2.0 * (vis.y - Layout.ground_y()) / (below_frac * t.y)
		var sc_cap := (vis.x + 2.0 * GROUND_CROP_MAX) / t.x
		sc = clampf(sc_center, vis.x / t.x, sc_cap)
	var w := t.x * sc
	var h := t.y * sc
	draw_texture_rect(tex, Rect2(Vector2((vis.x - w) * 0.5, vis.y - h), Vector2(w, h)), false)  # 하단 고정
