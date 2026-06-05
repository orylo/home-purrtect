extends CanvasLayer
## 전투 HUD - 상단 정보바 + 일시정지/클리어/게임오버 패널
##   좌: ♥ 체력 + 숫자 / 우: 웨이브·남은 적 + 일시정지[II]

## 전투결과 [확인]을 눌렀고, 그 스테이지가 "전투 씬 내 컷씬"이면 발신(game.gd가 받아 처리).
signal inscene_event_requested

# 전투 씬 안에서(씬전환 없이) 컷씬 재생(케이스 A: 1-3 보안관·1-5 펄·1-7 맥스·1-13 비둘기·1-16 치와와)
const INSCENE_EVENT_STAGES := [3, 5, 7, 13, 16]
# 컷씬 없이 [확인]→홈+코치마크(케이스 D+: 1-9 스킬 판매)
const HOME_EVENT_STAGES := [9]

# 웹 export에서 테마 기본폰트가 한글을 못 그려서, 폰트를 직접 preload해 명시 지정
const UI_FONT := preload("res://assets/fonts/SBAggro-Medium.ttf")

@onready var hp_bar: ProgressBar = $HPBar
@onready var hp_value: Label = $HPBar/HPValue
@onready var enemy_label: Label = $EnemyLabel
@onready var pause_button: Button = $PauseButton
@onready var pause_panel: ColorRect = $PausePanel
@onready var resume_button: Button = $PausePanel/Center/Box/ResumeButton
@onready var to_select_button: Button = $PausePanel/Center/Box/ToSelectButton
@onready var stage_label: Label = $StageLabel
@onready var clear_panel: ColorRect = $ClearPanel
@onready var clear_title: Label = $ClearPanel/Center/Box/Title
@onready var clear_next: Button = $ClearPanel/Center/Box/Next
@onready var clear_restart: Button = $ClearPanel/Center/Box/Restart
@onready var gameover_panel: ColorRect = $GameOverPanel
@onready var gameover_restart: Button = $GameOverPanel/Center/Box/Restart

var _wave_cur: int = 0
var _wave_total: int = 0
var _event_pending: bool = false   # 클리어 이벤트 [확인] 대기 중
var _event_text: String = ""
var _inscene_event: bool = false   # 그 이벤트가 "전투 씬 내 컷씬"인지
var _home_event: bool = false      # 컷씬 없이 홈+코치마크(D+)
var coin_label: Label   # 상단 코인 표시(💰)
var _time_label: Label  # 별점용 전투 경과시간(상단 중앙, 작게)


## 전투 경과시간 표시(game._process가 매 프레임 호출). 라벨은 첫 호출 때 생성.
func set_battle_time(t: float) -> void:
	if _time_label == null:
		_time_label = Label.new()
		_time_label.add_theme_font_override("font", UI_FONT)
		_time_label.add_theme_font_size_override("font_size", 20)
		_time_label.add_theme_color_override("font_color", Color(1, 1, 1))
		_time_label.add_theme_color_override("font_outline_color", Color("241f1b"))
		_time_label.add_theme_constant_override("outline_size", 4)
		_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var vp := get_viewport().get_visible_rect().size
		_time_label.size = Vector2(140, 26)
		_time_label.position = Vector2(vp.x * 0.5 - 70, 58)   # 스테이지 표기 아래, 가운데
		add_child(_time_label)
	_time_label.text = "%.1f초" % t


func _ready() -> void:
	pause_button.pressed.connect(_on_pause_pressed)
	# 일시정지 = 빈티지 아이콘 뱃지(나노바나나, 자체 크림 원형이라 버튼 배경은 투명)
	pause_button.text = ""
	pause_button.icon = preload("res://assets/ui/icons/icon_pause.png")
	pause_button.expand_icon = true
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		pause_button.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	resume_button.pressed.connect(_on_resume_pressed)
	to_select_button.pressed.connect(_on_to_select_pressed)
	clear_next.pressed.connect(_on_clear_next)
	clear_restart.text = "홈으로"                  # 클리어 패널: 재시작 버튼을 홈으로 전환
	clear_restart.pressed.connect(_on_clear_home)
	gameover_restart.pressed.connect(_on_restart)
	stage_label.text = GameState.stage_label()   # 상단 스테이지 표시(1-1, 1-2…)
	pause_panel.visible = false
	clear_panel.visible = false
	gameover_panel.visible = false
	# Caldera 규정 버튼: 주요 액션=Digital Orange 알약 / 보조=고스트(흰 테두리)
	_style_primary(resume_button)
	_style_ghost(to_select_button)
	_style_primary(clear_next)
	_style_ghost(clear_restart)
	_style_primary(gameover_restart)
	_build_coin_label()
	# iOS 안전영역(노치)만큼 상단 HUD를 코너에서 안으로 - 배경은 풀블리드, HUD는 안 가리게.
	_apply_safe_hud()
	get_viewport().size_changed.connect(_apply_safe_hud)
	get_tree().create_timer(0.7).timeout.connect(_apply_safe_hud)   # env 인셋 늦게 확정 대비


# -- iOS 안전영역 상단 HUD 인셋 (적용 델타 추적 = 누적/리사이즈 안전) --
var _hud_applied := {}   # 노드 → 현재 적용된 인셋(Vector2)

func _safe_shift(n: Control, delta: Vector2) -> void:
	if n == null or not is_instance_valid(n):
		return
	var prev: Vector2 = _hud_applied.get(n, Vector2.ZERO)
	if delta.is_equal_approx(prev):
		return
	n.position += delta - prev
	_hud_applied[n] = delta

func _apply_safe_hud() -> void:
	var l := Layout.safe_left()
	var t := Layout.safe_top()
	var r := Layout.safe_right()
	for n in [get_node_or_null("Heart"), hp_bar, coin_label]:   # 좌상단 → 오른쪽·아래로
		_safe_shift(n, Vector2(l, t))
	for n in [enemy_label, pause_button]:                       # 우상단 → 왼쪽·아래로
		_safe_shift(n, Vector2(-r, t))
	for n in [stage_label, get_node_or_null("AutoInfo")]:       # 상단중앙/기타 → 아래로
		_safe_shift(n, Vector2(0, t))


## 상단 코인 표시 - 동전 이모지 대신 금색 "코인 N"으로(숫자는 항상 렌더)
func _build_coin_label() -> void:
	coin_label = Label.new()
	coin_label.add_theme_font_override("font", UI_FONT)
	coin_label.add_theme_font_size_override("font_size", 26)
	coin_label.add_theme_color_override("font_color", Design.CHEESE)
	coin_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
	coin_label.add_theme_constant_override("outline_size", 4)
	coin_label.position = Vector2(44, 62)   # HP바 아래 좌상단
	add_child(coin_label)


## 숫자 천 단위 콤마 (1240 → 1,240)
func _commafy(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out


## 초 → "MM:SS" (별점 클리어 시간 표기)
func _fmt_mmss(t: float) -> String:
	var sec := int(round(t))
	return "%02d:%02d" % [sec / 60, sec % 60]


## 알약(pill) 스타일 박스 - bw>0이면 테두리(고스트)
func _pill(bg: Color, bw: float, bc: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(100)
	sb.content_margin_left = 32.0
	sb.content_margin_right = 32.0
	sb.content_margin_top = 16.0
	sb.content_margin_bottom = 16.0
	if bw > 0.0:
		sb.set_border_width_all(int(bw))
		sb.border_color = bc
	return sb


func _style_primary(btn: Button) -> void:
	Design.style_button(btn, "cta", Design.FS_TITLE)   # 빨강 CTA(design.md)


func _style_ghost(btn: Button) -> void:
	Design.style_button(btn, "paper", Design.FS_TITLE)   # 보조 = 크림


func _process(_delta: float) -> void:
	if coin_label:
		coin_label.text = "코인 " + _commafy(GameState.coins)

	# 치즈 체력
	var player := get_tree().get_first_node_in_group("player")
	if player:
		hp_bar.max_value = player.max_health
		hp_bar.value = player.health
		hp_value.text = "%d / %d" % [int(round(player.health)), int(round(player.max_health))]

	# 웨이브 + 남은 적
	var alive := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if e.has_method("is_dead") and e.is_dead():
			continue
		alive += 1
	if _wave_total == 0:
		enemy_label.text = "준비 중..."
	else:
		enemy_label.text = "웨이브 %d/%d   남은 침입자 %d" % [_wave_cur, _wave_total, alive]


## 스포너가 새 웨이브 시작 시 호출
func set_wave(current: int, total: int) -> void:
	_wave_cur = current
	_wave_total = total


## 전투 시작 큐 - 첫 웨이브 시작 시 "전투 시작!" 배너를 짧게 띄운다.
##   인게임 이벤트(대화)→전투 전환을 명확히. 트럼펫 팡파르 + 팝인→유지→페이드.
func show_battle_start() -> void:
	var vp := get_viewport().get_visible_rect().size
	var banner := Design.label("전투 시작!", "display", Design.CHEESE)   # 잘난체 64·골든·INK 외곽(웹 안전)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.size = Vector2(vp.x, 130.0)
	banner.position = Vector2(0.0, vp.y * 0.42 - 65.0)
	banner.pivot_offset = Vector2(vp.x * 0.5, 65.0)   # 중앙 기준 스케일
	banner.z_index = 100
	add_child(banner)
	Sfx.play("trumpet", 1.0, -2.0)                    # 출정 팡파르
	banner.scale = Vector2(0.5, 0.5)
	banner.modulate.a = 0.0
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(banner, "scale", Vector2(1.0, 1.0), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(banner, "modulate:a", 1.0, 0.2)
	t.chain().tween_interval(1.5)                  # 읽을 시간 충분히(0.7→1.5s)
	t.chain().tween_property(banner, "modulate:a", 0.0, 0.45)
	t.chain().tween_callback(banner.queue_free)


func show_clear(bonus: int = 0, star_info: Dictionary = {}) -> void:
	Sfx.play("clear")
	# 깨끗한 결과 화면(쿠키런 톤) - 전투 HUD(체력·조이스틱·하단버튼 등) 숨기고 클리어 패널만.
	for c in get_children():
		if c != clear_panel and c is CanvasItem:
			c.visible = false
	var stg := GameState.stage_minor
	var ev := GameState.clear_event_for(stg)
	# 알림형(D/D+): 드랍 정산 결과창 하단에 해금 알림 한 줄(드랍과 사건 분리 - 가이드 §1-B).
	#   인스씬 컷씬(A)·보스(C)는 사건을 컷씬/별도 씬이 알리므로 결과창엔 안 얹음.
	var show_notice := ev != "" and not GameState.replaying and not (stg in INSCENE_EVENT_STAGES) and not (stg in [10, 20])

	# 타이틀 = 큰 "CLEAR!" (골든 + 잉크 외곽, §2.2 display)
	clear_title.text = "CLEAR!"
	clear_title.add_theme_font_size_override("font_size", 64)
	clear_title.add_theme_color_override("font_color", Design.CHEESE)
	clear_title.add_theme_color_override("font_outline_color", Design.INK)
	clear_title.add_theme_constant_override("outline_size", 12)

	_build_clear_content(star_info, bonus, show_notice, ev)
	# 라우팅: (파밍 재도전) 맵 복귀 / 인스씬 컷씬(A) / 홈+코치마크(D+) / 별도 알림씬(보스) / 일반(D·없음)
	if GameState.replaying:                   # 스테이지 맵 [재도전] 파밍 - 진행 안 올리고 맵 복귀(이벤트 생략)
		_event_pending = false; _inscene_event = false; _home_event = false
		clear_next.text = "지도로 ▶"
		clear_restart.visible = true; clear_restart.text = "다시 도전"
	elif stg in INSCENE_EVENT_STAGES:
		_event_pending = true; _inscene_event = true; _home_event = false
		clear_next.text = "확인 ▶"; clear_restart.visible = false
	elif stg in HOME_EVENT_STAGES:
		_event_pending = true; _inscene_event = false; _home_event = true
		clear_next.text = "확인 ▶"; clear_restart.visible = false
	elif ev != "" and (stg in [10, 20]):     # 보스(C) - 추후 컷씬, 현재 별도 알림 씬
		_event_pending = true; _inscene_event = false; _home_event = false
		_event_text = ev; clear_next.text = "확인 ▶"; clear_restart.visible = false
	else:                                    # D(알림만) 또는 이벤트 없음 - 일반 진행
		_event_pending = false; _inscene_event = false; _home_event = false
		clear_next.text = "다음 ▶"; clear_restart.visible = true
	clear_panel.visible = true


# -- 클리어 결과 콘텐츠(별·시간·보상 박스) 동적 구성 -------------------------
const LOOT_DIR := "res://assets/items/loot/"
## 전리품 id ↔ 아이콘 파일명 예외(나머지는 id.png 그대로). 출처: 기획_아이템도감.md
const ICON_ALIAS := {"sparrow_feather": "feather", "spider_silk": "cobweb", "wheel": "steel_wheel", "sack": "loot_sack"}
var _clear_dyn: Array = []   # show_clear가 만든 동적 노드(재호출 시 정리)


func _build_clear_content(star_info: Dictionary, bonus: int, show_notice: bool, ev: String) -> void:
	var box := clear_title.get_parent()
	for n in _clear_dyn:
		if is_instance_valid(n):
			n.queue_free()
	_clear_dyn.clear()
	_dismiss_loot_tip()
	_loot_entries.clear()
	var vp := get_viewport().get_visible_rect().size

	# ① 별 3개(채움/빈칸) - 큰 별 줄
	if not star_info.is_empty():
		var sr := StarRow.new()
		sr.got = int(star_info.get("stars", 1))
		sr.custom_minimum_size = Vector2(260, 84)
		_add_dyn(box, sr)

		# ② 클리어 시간 + 다음 목표시간
		var t2 := int(round(float(star_info.get("t2", 0.0))))
		var t3 := int(round(float(star_info.get("t3", 0.0))))
		var tt := "클리어 %s" % _fmt_mmss(float(star_info.get("time", 0.0)))
		if t2 > 0 and t3 > 0:
			tt += "      ★★ %ds · ★★★ %ds" % [t2, t3]
		_add_dyn(box, _center_label(tt, "body", Design.INK_CREAM))

		# ③ 신기록(재도전 별 갱신)
		if not bool(star_info.get("is_first", true)) and bool(star_info.get("new_best", false)):
			_add_dyn(box, _center_label("★ 신기록!  최고 ★%d 갱신" % int(star_info.get("stars", 1)), "title", Design.CHEESE))

	# ④ 보상 박스(코인 + 전리품) - 물건화 패널 안 타일 그리드
	var tiles: Array = []
	if GameState.run_coins > 0:
		tiles.append(_reward_tile(_coin_tex(), _commafy(GameState.run_coins), "coin", "코인"))
	for id in GameState.MAT_ORDER:
		var cnt := int(GameState.run_loot.get(id, 0))
		if cnt > 0:
			var nm := String(GameState.MATERIALS.get(id, {}).get("name", id))
			tiles.append(_reward_tile(_mat_tex(id), _commafy(cnt), id, nm))
	if tiles.size() > 0:
		_add_dyn(box, _center_label("획득", "caption", Design.INK_CREAM))
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", Design.panel_box())
		panel.custom_minimum_size = Vector2(minf(vp.x * 0.78, 880.0), 0)
		var mg := MarginContainer.new()
		for s in ["left", "right", "top", "bottom"]:
			mg.add_theme_constant_override("margin_" + s, 14)
		panel.add_child(mg)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 10)
		flow.alignment = FlowContainer.ALIGNMENT_CENTER
		mg.add_child(flow)
		for t in tiles:
			flow.add_child(t)
		_add_dyn(box, panel)

	# ⑤ 해금 알림(D/D+)
	if show_notice:
		_add_dyn(box, _center_label("✨ " + ev, "body", Design.CHEESE))

	# 버튼을 항상 맨 아래로
	box.move_child(clear_next, box.get_child_count() - 1)
	box.move_child(clear_restart, box.get_child_count() - 1)


## box에 자식 추가 + 동적노드 추적(다음 호출 때 정리)
func _add_dyn(box: Control, node: Control) -> void:
	box.add_child(node)
	_clear_dyn.append(node)


func _center_label(text: String, kind: String, color: Color) -> Label:
	var l := Design.label(text, kind, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_FILL
	return l


## 보상 타일 = 크림 칸(잉크 외곽) + 아이콘(칸 정중앙) + 우하단 개수 뱃지(코너에 걸침).
##   탭하면 아이템 설명 툴팁(아이템 도감 문구). id="coin" 또는 전리품 id.
const TILE_SZ := 88.0
func _reward_tile(tex: Texture2D, count_text: String, id: String, item_name: String) -> Control:
	# 칸 = 벡터 둥근네모(card_box) + 진한 크림(PAPER_DEEP) 채움 + 잉크 외곽
	var tile := Panel.new()
	tile.custom_minimum_size = Vector2(TILE_SZ, TILE_SZ)
	tile.clip_contents = false   # 뱃지가 코너 밖으로 살짝 걸치도록(클립 끔)
	tile.add_theme_stylebox_override("panel", Design.card_box(Design.PAPER_DEEP, 3, Design.RADIUS_CARD))
	if tex != null:
		var ic := TextureRect.new()
		ic.texture = tex
		# 아이콘은 칸 정중앙(비율유지 축소).
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		ic.offset_left = 8; ic.offset_top = 8; ic.offset_right = -8; ic.offset_bottom = -8
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(ic)
	# 개수 뱃지(크림 알약 + 잉크 외곽 + 잉크 숫자) - 우하단 코너에 걸침
	tile.add_child(_count_badge(count_text))
	# 탭 → 설명 툴팁. 빈 영역(IGNORE면 부모로 전달) 방지 위해 STOP.
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.set_meta("loot_id", id)
	tile.set_meta("loot_name", item_name)
	tile.gui_input.connect(_on_tile_input.bind(tile))
	_loot_entries.append(tile)
	return tile


## 개수 뱃지 = 크림 알약(잉크 외곽선) + 잉크 숫자. 글자수에 맞춰 가로폭 자동.
func _count_badge(text: String) -> Control:
	var bh := 30.0
	var fs := 18
	var tw: float = Design.FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs).x
	var bw: float = maxf(bh, tw + 18.0)
	var badge := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Design.PAPER
	sb.set_corner_radius_all(int(bh * 0.5))
	sb.set_border_width_all(3)
	sb.border_color = Design.INK
	badge.add_theme_stylebox_override("panel", sb)
	badge.custom_minimum_size = Vector2(bw, bh)
	badge.size = Vector2(bw, bh)
	# 우하단 코너에 걸치게(살짝 바깥으로)
	badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	badge.offset_left = -bw + 8.0
	badge.offset_top = -bh + 8.0
	badge.offset_right = 8.0
	badge.offset_bottom = 8.0
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Design.label(text, "caption", Design.INK)
	l.add_theme_font_size_override("font_size", fs)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(l)
	return badge


# -- 전리품 설명 툴팁 -------------------------------------------------------
var _loot_entries: Array = []   # 보상 타일들(탭 히트테스트용)
var _loot_tip: Control = null   # 현재 떠 있는 설명 툴팁
var _loot_tail: Control = null   # 말풍선 꼬리
var _loot_overlay: Control = null   # 화면 전체 클릭 캐처(다른 칸 전환/바깥 탭 닫기)
var _loot_tip_id: String = ""   # 현재 툴팁이 가리키는 id(같은 칸 다시 탭 = 닫기)


## 말풍선 꼬리 - 크림 채움 + 잉크 빗변. dir="down"(툴팁 위→꼬리 아래) / "up".
class _TipTail extends Control:
	var dir := "down"
	const COL := Color("f3e3be")   # PAPER
	const BRD := Color("241f1b")   # INK
	func _draw() -> void:
		var w := 26.0
		var h := 14.0
		var o := 4.0   # 박스 안으로 겹쳐 테두리 가림
		var pts: PackedVector2Array
		if dir == "down":
			pts = PackedVector2Array([Vector2(-w * 0.5, -o), Vector2(w * 0.5, -o), Vector2(0, h)])
		else:
			pts = PackedVector2Array([Vector2(-w * 0.5, o), Vector2(w * 0.5, o), Vector2(0, -h)])
		draw_colored_polygon(pts, COL)
		draw_line(pts[0], pts[2], BRD, 3.0)
		draw_line(pts[1], pts[2], BRD, 3.0)


## 타일 직접 탭(툴팁이 아직 없을 때 첫 진입)
func _on_tile_input(event: InputEvent, tile: Control) -> void:
	if _is_tap(event):
		var id := String(tile.get_meta("loot_id", ""))
		var nm := String(tile.get_meta("loot_name", ""))
		_open_loot_tip(id, nm, tile)
		tile.accept_event()


## 오버레이(툴팁 떠 있는 동안) 탭 - 칸 위면 전환/닫기, 바깥이면 닫기
func _on_overlay_input(event: InputEvent) -> void:
	if not _is_tap(event):
		return
	# 오버레이는 화면 전체(원점 앵커) → 이벤트 로컬좌표 == 전역좌표
	var pos: Vector2 = event.position
	for t in _loot_entries:
		if is_instance_valid(t) and t.get_global_rect().has_point(pos):
			var id := String(t.get_meta("loot_id", ""))
			if id == _loot_tip_id:
				_dismiss_loot_tip()   # 같은 칸 다시 탭 = 닫기
			else:
				_open_loot_tip(id, String(t.get_meta("loot_name", "")), t)
			return
	_dismiss_loot_tip()   # 바깥 영역 탭 = 닫기


func _is_tap(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return event.pressed
	return false


## 설명 툴팁 열기(기존 건 정리하고 새로). name 골든 + desc 본문.
func _open_loot_tip(id: String, item_name: String, tile: Control) -> void:
	_dismiss_loot_tip()
	# 화면 전체 캐처(타일 위에) - 다음 탭부터 여기서 처리
	var ov := Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	ov.gui_input.connect(_on_overlay_input)
	clear_panel.add_child(ov)
	_loot_overlay = ov
	# 툴팁 카드(텍스트 영역 상하좌우 마진)
	var card := PanelContainer.new()
	var cbox := Design.panel_box(Design.PAPER, 3, 12)
	cbox.content_margin_left = 18.0
	cbox.content_margin_right = 18.0
	cbox.content_margin_top = 14.0
	cbox.content_margin_bottom = 14.0
	card.add_theme_stylebox_override("panel", cbox)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vb)
	var title := Design.label(item_name, "title", Design.CHEESE_DEEP)
	title.add_theme_color_override("font_outline_color", Design.INK)
	title.add_theme_constant_override("outline_size", 6)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(title)
	var body := Design.label(_loot_desc(id), "body", Design.INK)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(300.0, 0.0)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(body)
	ov.add_child(card)
	_loot_tip = card
	_loot_tip_id = id
	# 말풍선 꼬리(어떤 아이템인지 가리킴)
	var tail := _TipTail.new()
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(tail)
	_loot_tail = tail
	_position_loot_tip.call_deferred(card, tile)


## 툴팁을 해당 칸 위(공간 없으면 아래)에 가운데 정렬, 화면 안으로 클램프
func _position_loot_tip(card: Control, tile: Control) -> void:
	if not (is_instance_valid(card) and is_instance_valid(tile)):
		return
	var vp := get_viewport().get_visible_rect().size
	var tr := tile.get_global_rect()
	var cs := card.get_combined_minimum_size()
	var tcx: float = tr.position.x + tr.size.x * 0.5   # 타일 가로 중심(꼬리가 가리킬 곳)
	var gap := 16.0   # 꼬리 길이만큼 타일과 띄움
	var above := true
	var x: float = tcx - cs.x * 0.5
	var y: float = tr.position.y - cs.y - gap
	if y < 8.0:
		above = false
		y = tr.position.y + tr.size.y + gap
	x = clampf(x, 8.0, vp.x - cs.x - 8.0)
	y = clampf(y, 8.0, vp.y - cs.y - 8.0)
	card.global_position = Vector2(x, y)
	# 꼬리: 카드 가장자리(위/아래)에서 타일 중심을 가리킴
	if is_instance_valid(_loot_tail):
		var t := _loot_tail as _TipTail
		var tx: float = clampf(tcx, x + 18.0, x + cs.x - 18.0)
		if above:
			t.dir = "down"
			t.global_position = Vector2(tx, y + cs.y)
		else:
			t.dir = "up"
			t.global_position = Vector2(tx, y)
		t.queue_redraw()


func _loot_desc(id: String) -> String:
	if id == "coin":
		return "맥스의 상점에서 쓰는 돈.\n전투에서 침입자를 막아낼수록 차곡차곡 쌓인다."
	return String(GameState.MAT_DESC.get(id, "아직 알려지지 않은 물건이다."))


func _dismiss_loot_tip() -> void:
	if is_instance_valid(_loot_overlay):
		_loot_overlay.queue_free()
	if is_instance_valid(_loot_tip):
		_loot_tip.queue_free()
	if is_instance_valid(_loot_tail):
		_loot_tail.queue_free()
	_loot_overlay = null
	_loot_tip = null
	_loot_tail = null
	_loot_tip_id = ""


func _mat_tex(id: String) -> Texture2D:
	var fn := String(ICON_ALIAS.get(id, id))
	var p := LOOT_DIR + fn + ".png"
	return load(p) if ResourceLoader.exists(p) else null


func _coin_tex() -> Texture2D:
	return load(LOOT_DIR + "coin.png")


## 별 3개(획득 채움=골든 / 미획득=빈 크림) - 가운데 별 살짝 크게(쿠키런 톤)
class StarRow extends Control:
	var got := 0
	func _draw() -> void:
		var cx := size.x * 0.5
		var cy := size.y * 0.5
		var spacing := 66.0
		for i in 3:
			var big: bool = (i == 1)
			var r := 30.0 if big else 24.0
			var c := Vector2(cx + (i - 1) * spacing, cy - (10.0 if big else 0.0))
			_star(c, r, i < got)
	func _star(c: Vector2, r: float, filled: bool) -> void:
		var pts := PackedVector2Array()
		for k in 10:
			var ang := -PI / 2.0 + k * PI / 5.0
			var rr := r if k % 2 == 0 else r * 0.45
			pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
		draw_colored_polygon(pts, Design.CHEESE if filled else Design.PAPER_DEEP)
		var loop := pts
		loop.append(pts[0])
		draw_polyline(loop, Design.INK, 3.0, true)


func show_gameover() -> void:
	gameover_panel.visible = true


func _on_pause_pressed() -> void:
	get_tree().paused = true
	pause_panel.visible = true


func _on_resume_pressed() -> void:
	get_tree().paused = false
	pause_panel.visible = false


func _on_to_select_pressed() -> void:
	get_tree().paused = false
	if GameState.mode == "dev":
		get_tree().change_scene_to_file("res://scenes/dev_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/home.tscn")   # 전투 포기 → 홈


## [다음 ▶ / 확인 ▶] - 이벤트 스테이지면 [확인]→이벤트 씬으로 랜딩, 아니면 다음 스테이지
func _on_clear_next() -> void:
	# 파밍 재도전(스테이지 맵): 진행 안 올리고 맵으로 복귀(프론티어 복원).
	if GameState.replaying:
		get_tree().paused = false
		GameState.finish_replay()
		if GameState.mode != "dev" and GameState.AUTOSAVE:
			GameState.save_game()
		get_tree().change_scene_to_file("res://scenes/stagemap.tscn")
		return
	# 전투 씬 내 컷씬(보안관 등): 씬전환·언포즈 없이 결과창만 닫고 game.gd에 위임
	if _inscene_event:
		_inscene_event = false
		_event_pending = false
		clear_panel.visible = false
		inscene_event_requested.emit()
		return
	get_tree().paused = false
	# D+(1-9 등): 컷씬 없이 홈으로 → 홈에서 코치마크.
	if _home_event:
		_home_event = false
		_event_pending = false
		GameState.advance_stage()
		if GameState.mode != "dev" and GameState.AUTOSAVE:
			GameState.save_game()
		get_tree().change_scene_to_file("res://scenes/home.tscn")
		return
	if _event_pending:
		_event_pending = false
		GameState.pending_event_stage = GameState.stage_minor   # 방금 깬 스테이지(이벤트 씬이 읽음)
		GameState.advance_stage()
		if GameState.mode != "dev" and GameState.AUTOSAVE:
			GameState.save_game()
		get_tree().change_scene_to_file("res://scenes/event.tscn")   # 이벤트 씬 랜딩
		return
	GameState.advance_stage()
	if GameState.mode != "dev" and GameState.AUTOSAVE:
		GameState.save_game()                                      # (출시 빌드) 진행 저장
	get_tree().change_scene_to_file("res://scenes/main.tscn")


## [홈으로 / 다시 도전] - 클리어 후 허브로 (개발자 모드는 개발자 메뉴로)
func _on_clear_home() -> void:
	get_tree().paused = false
	# 파밍 재도전: 같은 스테이지 한 번 더(진행·replaying 유지).
	if GameState.replaying:
		get_tree().reload_current_scene()
		return
	GameState.advance_stage()
	if GameState.mode != "dev" and GameState.AUTOSAVE:
		GameState.save_game()
	if GameState.mode == "dev":
		get_tree().change_scene_to_file("res://scenes/dev_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/home.tscn")


func _on_restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
