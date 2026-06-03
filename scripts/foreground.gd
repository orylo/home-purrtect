extends Node2D
## 근경(Foreground) — 3중 배경의 가장 가까운 레이어. z_index로 캐릭터보다 "앞"에 그려진다.
##   배경 선택(stage_background)이 고른 near_texture를 하단 고정·좌우폭=화면폭으로 그림.
##   근경 이미지가 아직 없으면(null) 아무것도 안 그림 — 시스템만 대기.


func _ready() -> void:
	get_viewport().size_changed.connect(queue_redraw)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var bg := get_tree().get_first_node_in_group("stage_bg")
	if bg == null or bg.near_texture == null:
		return
	var tex: Texture2D = bg.near_texture
	var vis := get_viewport().get_visible_rect().size
	var t := tex.get_size()
	var sc := vis.x / t.x                       # 좌우폭 = 화면폭
	var w := t.x * sc
	var h := t.y * sc
	draw_texture_rect(tex, Rect2(Vector2((vis.x - w) * 0.5, vis.y - h), Vector2(w, h)), false)  # 하단 고정
