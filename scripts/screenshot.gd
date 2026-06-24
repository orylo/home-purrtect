extends Node
## 전역 스크린샷 - 어느 화면에서든(전투/홈/메뉴 무관, DEV 무관) [ 키로 현재 화면 그대로 1장 캡처.
##   저장: res://screenshots/shot_<시각>.png (에디터 실행 시 프로젝트 폴더).
##   현재 씬에 [버그] 오버레이(DebugOverlay)가 있으면 잠깐 숨겨 캡처에서 제외.


func _ready() -> void:
	# 컷신·이벤트(get_tree().paused) 중에도 [ 캡처가 먹게 일시정지 무시.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_BRACKETLEFT:
		_capture()


func _capture() -> void:
	# 현재 씬의 [버그] 오버레이가 있으면 캡처 동안만 숨김
	var scene := get_tree().current_scene
	var dbg: Node = scene.get_node_or_null("DebugOverlay") if scene != null else null
	var dbg_was: bool = dbg.visible if dbg != null else false
	if dbg != null:
		dbg.visible = false
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	if dbg != null:
		dbg.visible = dbg_was
	DirAccess.make_dir_recursive_absolute("res://screenshots")
	var ts := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var p := "res://screenshots/shot_%s.png" % ts
	img.save_png(p)
	print("[SHOT] 전체화면 저장 → ", ProjectSettings.globalize_path(p), "  ", img.get_size())
