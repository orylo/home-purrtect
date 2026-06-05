extends Node
## 화면 레이아웃 공용 모듈 (오토로드 싱글톤 "Layout")
##
## 바닥선(캐릭터가 서는 선)과 조작 띠(하단 버튼 영역)를 한 곳에서 관리한다.
## 둘 다 "화면 아래에서 고정 픽셀"로 잡아, 어떤 기기 비율(아이폰 19.5:9 / 아이패드 4:3
## / 안드로이드 20:9 등)에서도 조작 띠 두께와 바닥선 위치가 일정하다.
##
## 배경 이미지는 1920x1080(16:9) 기준 제작 + 커버(cover)로 화면을 채운다.
## (배경의 땅과 바닥선 정밀 정렬은 실제 스테이지 아트가 들어올 때 맞춘다.)

# 배경 제작 기준 해상도(16:9)
const REF_W: float = 1920.0
const REF_H: float = 1080.0

# === iOS 안전영역(노치·홈인디케이터) 인셋 ─ 배경은 풀블리드, UI/조작/바닥만 안으로 ===
#   웹(iOS standalone)에서만 CSS env(safe-area-inset-*)를 읽어 채운다. 그 외엔 0(무변화).
#   값은 뷰포트 px 기준(CSS px × 뷰포트/innerW). left/top/right/bottom.
var _safe := Vector4.ZERO
const _SAFE_JS := "(function(){var s=getComputedStyle(document.documentElement);function v(n){return parseFloat(s.getPropertyValue(n))||0}return [v('--sail'),v('--sair'),v('--sait'),v('--saib'),window.innerWidth,window.innerHeight].join(',')})()"


func _ready() -> void:
	_refresh_safe()
	get_viewport().size_changed.connect(_refresh_safe)
	# env() 인셋·뷰포트가 로드 직후 한 박자 늦게 확정되는 경우 대비 재읽기
	get_tree().create_timer(0.6).timeout.connect(_refresh_safe)


func _refresh_safe() -> void:
	if not OS.has_feature("web"):
		_safe = Vector4.ZERO
		return
	var raw = JavaScriptBridge.eval(_SAFE_JS)
	if typeof(raw) != TYPE_STRING:
		return
	var p := String(raw).split(",")
	if p.size() < 6:
		return
	var vis := get_viewport().get_visible_rect().size
	var iw: float = maxf(float(p[4]), 1.0)
	var ih: float = maxf(float(p[5]), 1.0)
	_safe = Vector4(
		float(p[0]) * vis.x / iw,   # left
		float(p[2]) * vis.y / ih,   # top
		float(p[1]) * vis.x / iw,   # right
		float(p[3]) * vis.y / ih)   # bottom


func safe_left() -> float:   return _safe.x
func safe_top() -> float:    return _safe.y
func safe_right() -> float:  return _safe.z
func safe_bottom() -> float: return _safe.w

# 하단 조작 띠(조이스틱·소모품·스킬 버튼이 들어가는 어두운 띠) ─ 화면 아래에서 고정 픽셀(버튼 크기 일정)
const CONTROL_BAND_HEIGHT: float = 264.0   # 띠 높이(화면 px 고정)
const CONTROL_BAND_GAP: float = 22.0       # (구) 바닥선↔띠 간격 ─ 현재 ground_y는 비율식이라 미사용
const GROUND_DROP: float = 80.0            # (구) 바닥선 내림 ─ 현재 미사용(비율식 ground_y로 대체)

# 바닥선(캐릭터가 서는 선) = 화면 높이 × 이 비율(위에서). 배경이 height-fit(상하 꽉)이라
#   배경 바닥선도 화면높이 고정비율에 위치 → 발선을 같은 비율로 잡아야 폰(720)·PC(16:9 877) 등
#   어떤 뷰포트 높이에서도 발이 배경 바닥선에 유지된다. = 1 - 310/1080 (배경 설계: 바닥에서 310px).
#   폰(720)에서 ≈513 = 종전 값과 사실상 동일. ※ safe_bottom 안 뺌(배경 풀블리드라 바닥은 배경 비율 따름).
const GROUND_LINE_FRAC: float = 1.0 - 310.0 / 1080.0   # ≈ 0.7130

# 발밑 그림자를 "자기 가로반경 × 이 비율"만큼 위로 올림(접지점에 붙게 ─ '바닥 아래 유리판' 느낌 방지).
#   치즈·적·펑거스 그림자 공통. 키우면 더 위로. 0이면 종전(바닥선에 그대로).
const SHADOW_LIFT_FRAC: float = 0.18

# 버튼이 화면 가장자리(아래/오른쪽)에서 떨어지는 공통 마진
const CONTROL_EDGE_MARGIN: float = 34.0

# 공격 버튼(우하단 코너 1/4 원)의 반경 ─ 그림과 터치 판정이 공유
const ATTACK_BUTTON_RADIUS: float = 145.0

# === 하단 단일 행 버튼 배치 (그림=bottom_hud / 입력=attack_button 공유) ===
# 왼→오: 아이템1~3 / 동료 / 소모품4칸 / 스킬1~4 / 근접공격 / 원거리공격 (오른쪽 정렬)
const ACT_R: float = 58.0          # 동료/근접/원거리 버튼 반지름
const SKILL_BTN_R: float = 38.0    # 스킬 원 반지름
const CONSUM_SQ: float = 60.0      # 소모품 빈칸 한 변
const ITEM_SQ: float = 66.0        # 아이템 칸 한 변
const GROUP_GAP: float = 28.0      # 그룹 사이 간격
const SKILL_GAP: float = 14.0
const CONSUM_GAP: float = 12.0
const ITEM_GAP: float = 14.0

## 하단 행 전체 좌표를 한 번에 계산(오른쪽 끝에서 왼쪽으로). 그림·입력 공유.
##   반환: ranged/melee/companion(Vector2) · skills/consum/items([Vector2]) · row_y(float)
func bottom_row(s: Vector2) -> Dictionary:
	var row_y := s.y - CONTROL_EDGE_MARGIN - ACT_R - safe_bottom()   # 큰 버튼 중심 y(홈인디케이터 인셋만큼 위로)
	var cx := s.x - CONTROL_EDGE_MARGIN - safe_right()               # 커서: 우측 노치 인셋만큼 안으로

	var ranged := Vector2(cx - ACT_R, row_y)
	cx -= 2.0 * ACT_R + GROUP_GAP
	var melee := Vector2(cx - ACT_R, row_y)
	cx -= 2.0 * ACT_R + GROUP_GAP

	var skills_rev: Array = []                       # 스킬4,3,2,1 (오른쪽부터)
	for k in 4:
		skills_rev.append(Vector2(cx - SKILL_BTN_R, row_y))
		cx -= 2.0 * SKILL_BTN_R + SKILL_GAP
	cx -= GROUP_GAP - SKILL_GAP
	skills_rev.reverse()                             # 스킬1~4 (왼→오)

	var companion := Vector2(cx - ACT_R, row_y)
	cx -= 2.0 * ACT_R + GROUP_GAP

	var items_rev: Array = []                        # 아이템3,2,1 (오른쪽부터)
	for i in 3:
		items_rev.append(Vector2(cx - ITEM_SQ * 0.5, row_y))
		cx -= ITEM_SQ + ITEM_GAP
	items_rev.reverse()

	return {
		"ranged": ranged, "melee": melee, "companion": companion,
		"skills": skills_rev, "items": items_rev, "row_y": row_y,
	}


func _vis() -> Vector2:
	return get_viewport().get_visible_rect().size


## 배경을 화면에 "커버"로 채울 때의 배율(비율 유지, 꽉 채움)
func cover_scale() -> float:
	var v := _vis()
	return maxf(v.x / REF_W, v.y / REF_H)


## 조작 띠(하단 딤 + 버튼)의 윗변 y좌표 ─ 홈인디케이터 인셋만큼 위로(바닥선도 따라 올라감)
func band_top() -> float:
	return _vis().y - CONTROL_BAND_HEIGHT - safe_bottom()


## 캐릭터가 서는 바닥 라인의 y좌표 = 화면 높이 × GROUND_LINE_FRAC.
##   배경(height-fit)의 바닥선과 같은 비율 → 폰/PC 등 뷰포트 높이가 달라도 발이 배경 바닥선에 유지.
func ground_y() -> float:
	return _vis().y * GROUND_LINE_FRAC
