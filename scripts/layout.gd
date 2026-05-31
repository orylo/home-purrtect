extends Node
## 화면 레이아웃 공용 모듈 (오토로드 싱글톤 "Layout")
##
## 바닥선을 한 곳에서 관리한다 — 모든 기기(아이폰/아이패드/안드로이드)에서
## 화면 비율이 달라도 바닥이 항상 화면 맨 아래에 붙도록 "화면 아래에서 N픽셀"로 계산.
## 치즈·쥐·스포너·바닥 그림이 모두 이 값을 기준으로 한다.

## 바닥(땅) 띠의 높이(픽셀). main.tscn의 Floor 그림 높이와 같게 유지.
const FLOOR_HEIGHT: float = 100.0


## 캐릭터가 서는 바닥 라인의 y좌표 (화면 맨 아래에서 FLOOR_HEIGHT만큼 위)
func ground_y() -> float:
	return get_viewport().get_visible_rect().size.y - FLOOR_HEIGHT
