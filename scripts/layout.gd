extends Node
## 화면 레이아웃 공용 모듈 (오토로드 싱글톤 "Layout")
##
## 스테이지 배경과 게임플레이의 "바닥 라인"을 한 곳에서 관리한다.
## 배경 이미지는 1920x1080(16:9) 기준으로 제작하고, 그 안에서 바닥 라인을
## "하단에서 GROUND_FROM_BOTTOM 픽셀 위"로 정한다. 모든 스테이지가 같은 값을 써야
## 어떤 기기(아이폰/아이패드/안드로이드)에서도 치즈·적의 발이 그림의 땅과 일치한다.
##
## 화면 채우기는 "커버(cover)": 비율을 유지한 채 화면을 꽉 채우고, 바닥을 아래에
## 정렬한 뒤 넘치는 부분(하늘 위/좌우)만 잘라낸다 → 찌그러짐 없음.

## 배경 제작 기준 해상도(16:9)
const REF_W: float = 1920.0
const REF_H: float = 1080.0

## 바닥 라인: 1920x1080 이미지 하단에서 이만큼 위(픽셀).
## 화면 아래쪽은 모바일 조작 버튼(조이스틱·소모품·스킬) 띠로 쓰므로, 전투가 그 위에서
## 벌어지도록 바닥선을 올려둔다. 이 값 하나만 바꾸면 전체 바닥 높이가 조절된다.
const GROUND_FROM_BOTTOM: float = 360.0


## 배경을 화면에 "커버"로 채울 때의 배율(비율 유지, 꽉 채움)
func cover_scale() -> float:
	var vis := get_viewport().get_visible_rect().size
	return maxf(vis.x / REF_W, vis.y / REF_H)


## 캐릭터가 서는 바닥 라인의 y좌표(화면 좌표). 배경의 땅 위치와 일치.
func ground_y() -> float:
	var vis := get_viewport().get_visible_rect().size
	return vis.y - GROUND_FROM_BOTTOM * cover_scale()


## 바닥선과 조작 띠(딤) 사이 간격 — 바닥선이 띠보다 살짝 위로 떠 보이게
const CONTROL_BAND_GAP: float = 22.0


## 조작 띠(하단 딤 + 버튼)의 윗변 y좌표. 바닥선보다 조금 아래.
func band_top() -> float:
	return ground_y() + CONTROL_BAND_GAP
