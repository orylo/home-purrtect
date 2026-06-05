extends Control
## DEV 대화창 미리보기 ─ 대화창 폰트/정렬을 즉시 눈으로 확인하는 화면.
##   실행: 에디터에서 이 씬(scenes/dev_dlg_preview.tscn) 열고 F6(현재 씬 실행),
##         또는 터미널 `Godot res://scenes/dev_dlg_preview.tscn`.
##   화면 탭 = 짧은/중간/긴 대사 순환. 빨간 점선 = text_lbl 실제 칸(이 안에서 세로 가운데여야 정상).

const SAMPLES := [
	"짧은 대사.",
	"왠지 저 쿠키 앞에서는 원래의 칠리맛 쿠키가 아닌 것 같아.",
	"흥, 또 만났군 치즈! 이 위대한 펑거스가 새로운 비밀 병기를 준비했으니 각오하는 게 좋을 거다. 멀찍이서 깔끔하게 처리해주마, 네놈이 손도 못 대게 말이야!",
]
var _i := 0
var _dp: Dictionary
var _frame: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.27, 0.45, 0.33)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var vp := get_viewport_rect().size
	_dp = DialoguePanel.build(self, vp, DialoguePanel.solid_portrait(Color(0.9, 0.4, 0.3)))
	_dp["name_lbl"].text = "펑거스"
	# text_lbl 실제 칸 경계 표시(빨간 점선) ─ 이 칸 안에서 세로 가운데인지 확인용
	_frame = _RectOutline.new()
	var tl: Label = _dp["text_lbl"]
	_frame.target = tl
	(_dp["box"] as Control).add_child(_frame)
	_show(0)
	# 안내
	var help := Label.new()
	help.add_theme_font_override("font", preload("res://assets/fonts/SBAggro-Medium.ttf"))
	help.add_theme_font_size_override("font_size", 22)
	help.text = "화면 탭 = 짧은/중간/긴 대사 순환 · 빨간 점선 칸 안에서 세로 가운데면 정상"
	help.position = Vector2(40, 30)
	add_child(help)


func _show(idx: int) -> void:
	var tl: Label = _dp["text_lbl"]
	tl.visible_characters = -1
	tl.text = SAMPLES[idx % SAMPLES.size()]
	if is_instance_valid(_frame):
		_frame.queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
		_i += 1
		_show(_i)


## text_lbl의 실제 사각 칸을 빨간 점선으로 그려, 그 안에서 글이 세로 가운데인지 보이게.
class _RectOutline extends Control:
	var target: Control
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if target == null or not is_instance_valid(target):
			return
		var r := Rect2(target.position, target.size)
		var col := Color(0.9, 0.2, 0.2, 0.9)
		# 점선 테두리
		var step := 10.0
		for x in range(int(r.position.x), int(r.position.x + r.size.x), int(step * 2)):
			draw_line(Vector2(x, r.position.y), Vector2(minf(x + step, r.position.x + r.size.x), r.position.y), col, 2.0)
			draw_line(Vector2(x, r.position.y + r.size.y), Vector2(minf(x + step, r.position.x + r.size.x), r.position.y + r.size.y), col, 2.0)
		for y in range(int(r.position.y), int(r.position.y + r.size.y), int(step * 2)):
			draw_line(Vector2(r.position.x, y), Vector2(r.position.x, minf(y + step, r.position.y + r.size.y)), col, 2.0)
			draw_line(Vector2(r.position.x + r.size.x, y), Vector2(r.position.x + r.size.x, minf(y + step, r.position.y + r.size.y)), col, 2.0)
		# 가운데 가로 기준선
		draw_line(Vector2(r.position.x, r.position.y + r.size.y * 0.5), Vector2(r.position.x + r.size.x, r.position.y + r.size.y * 0.5), Color(0.2, 0.5, 0.9, 0.7), 1.5)
