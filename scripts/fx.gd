extends Node
## 연출 공용 모듈 (오토로드 "Fx") — 화면 흔들림 + 히트스톱
## 다른 스크립트가 request_shake / request_hitstop를 호출하면 발동.

var shake: float = 0.0          # 현재 흔들림 세기(px). game.gd가 읽어 화면에 적용.
var _hitstop_token: int = 0


## 화면 흔들림 요청(누적되지 않고 더 큰 값으로 갱신)
func request_shake(amount: float) -> void:
	shake = maxf(shake, amount)


## 히트스톱 — 아주 잠깐 시간을 멈췄다 복구(타격의 묵직함)
func request_hitstop(duration: float) -> void:
	_hitstop_token += 1
	var my := _hitstop_token
	Engine.time_scale = 0.05
	# ignore_time_scale=true 라 멈춘 동안에도 실제 시간으로 타이머가 흐름
	await get_tree().create_timer(duration, true, false, true).timeout
	if my == _hitstop_token:
		Engine.time_scale = 1.0
