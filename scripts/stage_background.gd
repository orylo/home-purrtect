extends Node2D
## 스테이지 배경 — 1920x1080 이미지를 "커버"로 채우고 바닥에 정렬해 그린다.
##
## · stage_texture 에 1920x1080 배경 그림을 넣으면 그걸 사용.
## · 비어 있으면 임시 배경(하늘 + 땅 + 바닥선)을 그려 동작을 확인할 수 있다.
## · 바닥 라인은 Layout.ground_y()와 항상 일치 → 캐릭터 발이 그림의 땅에 딱 맞음.

@export var stage_texture: Texture2D
## 바닥선 정렬 확인용 디버그 선(빨강). 그림의 땅과 맞으면 끄면 됨.
@export var show_ground_line: bool = true
## 배경 추가 확대 배율(1.0 = 기본, 비율 유지 커버). 필요 시만 키움.
@export var bg_zoom: float = 1.0
## 배경을 아래로 내리는 양(px). 양수면 그림이 내려가 위쪽이 더 보인다.
@export var offset_y: float = 0.0


func _ready() -> void:
	# 화면 크기가 바뀌면(회전·창 크기) 다시 그림
	get_viewport().size_changed.connect(queue_redraw)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var vis := get_viewport().get_visible_rect().size
	var s := Layout.cover_scale()

	if stage_texture != null:
		# 그림 원본 비율 그대로 화면을 "커버"(꽉 채움) + 가로 가운데 + 바닥 고정.
		# 가로/세로 비율 중 더 큰 쪽으로 맞춰 빈틈 없이 채우고, 넘치는 부분만 크롭.
		var tex := stage_texture.get_size()
		var sc := maxf(vis.x / tex.x, vis.y / tex.y) * bg_zoom
		var art_w := tex.x * sc
		var art_h := tex.y * sc
		var art_x := (vis.x - art_w) * 0.5         # 가로 가운데
		var art_y := vis.y - art_h + offset_y      # 바닥 고정 + offset_y만큼 아래로
		draw_texture_rect(stage_texture, Rect2(Vector2(art_x, art_y), Vector2(art_w, art_h)), false)
	else:
		# 임시 배경: 하늘 + 땅 + 바닥선 (실제 그림이 들어오면 위 분기로 교체됨)
		var gy := Layout.ground_y()
		draw_rect(Rect2(0.0, 0.0, vis.x, vis.y), Color(0.12, 0.14, 0.2, 1))            # 하늘(전체)
		draw_rect(Rect2(0.0, gy, vis.x, vis.y - gy), Color(0.32, 0.28, 0.24, 1))        # 땅
		draw_line(Vector2(0.0, gy), Vector2(vis.x, gy), Color(0.55, 0.48, 0.4, 1), 2.0) # 바닥선

	# 디버그: 게임 바닥선을 빨간 선으로 표시(정렬 확인용)
	if show_ground_line:
		var line_y := Layout.ground_y()
		draw_line(Vector2(0.0, line_y), Vector2(vis.x, line_y), Color(1, 0, 0, 0.7), 3.0)
