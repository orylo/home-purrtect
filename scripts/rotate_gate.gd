extends Node
## 세로 모드 안내 오버레이 (오토로드 "RotateGate")
## 웹/모바일에서 화면이 세로면 "가로로 돌려주세요" 전체화면을 덮어 표시.
## (웹은 브라우저가 강제 회전을 막아서, 안내 + 게임은 가로일 때만 보이게 하는 게 표준)

var _panel: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # 일시정지 중에도 동작
	var layer := CanvasLayer.new()
	layer.layer = 100                         # 항상 최상단
	add_child(layer)

	_panel = ColorRect.new()
	_panel.color = Color(0.08, 0.09, 0.12, 1)
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_panel)

	var label := Label.new()
	label.text = "휴대폰을 가로로 돌려주세요\n\nRotate your device"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 52)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(label)

	_panel.visible = false


func _process(_delta: float) -> void:
	var v := get_viewport().get_visible_rect().size
	_panel.visible = v.y > v.x   # 세로(높이>너비)면 안내 표시
