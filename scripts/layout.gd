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

# 하단 조작 띠(조이스틱·소모품·스킬 버튼이 들어가는 어두운 띠)
const CONTROL_BAND_HEIGHT: float = 264.0   # 띠 높이(화면 px 고정)
const CONTROL_BAND_GAP: float = 22.0       # 바닥선과 띠 윗변 사이 간격
const GROUND_DROP: float = 80.0            # 바닥선(캐릭터가 서는 선)을 이만큼 아래로 내림

# 버튼이 화면 가장자리(아래/오른쪽)에서 떨어지는 공통 마진
const CONTROL_EDGE_MARGIN: float = 34.0

# 공격 버튼(우하단 코너 1/4 원)의 반경 — 그림과 터치 판정이 공유
const ATTACK_BUTTON_RADIUS: float = 145.0


func _vis() -> Vector2:
	return get_viewport().get_visible_rect().size


## 배경을 화면에 "커버"로 채울 때의 배율(비율 유지, 꽉 채움)
func cover_scale() -> float:
	var v := _vis()
	return maxf(v.x / REF_W, v.y / REF_H)


## 조작 띠(하단 딤 + 버튼)의 윗변 y좌표
func band_top() -> float:
	return _vis().y - CONTROL_BAND_HEIGHT


## 캐릭터가 서는 바닥 라인의 y좌표 — 조작 띠보다 위 + GROUND_DROP만큼 아래로
func ground_y() -> float:
	return band_top() - CONTROL_BAND_GAP + GROUND_DROP
