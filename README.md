# 🐈 Home Purrtect (홈 퍼르텍트)

고양이 보안관 **치즈**가 저택을 지키는 1930년대 카툰풍 횡스크롤 액션 디펜스 게임.
가로 모드 · 2D · **Godot 4.6** · iOS 먼저 → 안드로이드.

▶ **지금 플레이(웹)**: https://orylo.github.io/home-purrtect/

---

## 📚 문서 (docs/)

| 문서 | 역할 | 주인 |
|---|---|---|
| **[docs/STATUS.md](docs/STATUS.md)** | **현재 구현 현황 · 기획 대비 변경점 · 앞으로 할 것** | 개발(코드 반영) |
| [docs/기획_브리프.md](docs/기획_브리프.md) | 큰 그림(세계관·5막·시스템 개요·BM) | 기획 |
| [docs/기획_시스템밸런스_1막.md](docs/기획_시스템밸런스_1막.md) | 1막 상세 수치(전투·스탯·적·직업·보스) | 기획 |
| [docs/기획_개발가이드.md](docs/기획_개발가이드.md) | 개발 순서·원칙 | 기획 |

> **읽는 순서**: 지금 무엇이 실제로 돌아가는지 / 무엇이 남았는지는 **STATUS.md** 부터.
> 기획 의도·배경은 `기획_*.md`.

## 🔄 운영 방식
- **기획**(claude.ai 챗): `기획_*.md` 를 디벨롭 — "무엇을 왜"
- **개발**(Claude Code): 코드 + `STATUS.md` 갱신 — "현재 현실"
- 둘 다 이 GitHub 레포에 모여 항상 최신 유지.

## 🛠️ 기술 메모
- 웹 배포: push → GitHub Actions(`.github/workflows/deploy.yml`)가 Godot 웹 export → GitHub Pages (~2분)
- 파일명 캐시버스트 적용 → 새로고침만 해도 최신 빌드
