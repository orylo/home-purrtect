# 치즈 스프라이트 — 직업(클래스)별 폴더 구조

치즈는 **직업(클래스) 세트**별로 폴더를 둔다. 각 직업은 같은 **모션 8종 풀세트**를 가진다.

```
assets/sprites/cheese/
  base/                 ← 맨몸 치즈 (기본)
    idle/  walk/  back/  jump/  shoot/  hit/  sit/
    cheese_base.tres    ← SpriteFrames (게임이 읽는 애니메이션 묶음)
  sheriff/              ← (예정) 보안관
    idle/ ... 같은 8종 ...
    cheese_sheriff.tres
  maid/                 ← (예정) 메이드
  musician/             ← (예정) 음악가
  ...
```

## 모션 8종 (한 직업당)
| 폴더 | 용도 |
|------|------|
| idle | 대기 |
| walk | 앞으로(오른쪽 이동) |
| back | 뒷걸음질(왼쪽 이동) — 몸은 오른쪽 본 채 뒤로 |
| jump | 점프(회피) |
| shoot | 원거리 평타 (직업 무기) |
| melee | 근접 평타 (직업 무기) — ※ base에 아직 없음, 추가 예정 |
| hit | 피격 |
| sit | 앉기(아래 회피) |

## 규칙 (직업 간 정렬 일관성)
- 300×300, 투명 배경(단색이면 배경 제거 처리)
- **항상 오른쪽 바라봄, 안 뒤집음** → walk·back 둘 다 필요
- 발 높이(바닥) 모든 모션·모든 직업 통일 (지금 base는 발이 아래에서 ~18px 위)
- 화풍/외곽선/색 일관

## 새 직업 추가 방법
1. 원본 모션 그림을 받으면 `assets/sprites/cheese/<직업>/<모션>/` 로 정리
2. 그 직업의 SpriteFrames(`cheese_<직업>.tres`) 생성
3. 직업 데이터(스탯/무기)와 함께 게임에 연결
