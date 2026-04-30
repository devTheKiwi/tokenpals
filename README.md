# 🐾 TokenPals

> 다마고치 + Claude Code 토큰 모니터.
> 디바이스마다 귀여운 캐릭터를 붙이고, 한 방에 모아 한눈에 본다.

## 한 줄 소개

Claude Code Max 구독 사용자를 위한 **macOS 네이티브 앱**. 핀 가능한 작은 방 윈도우 안에 디바이스마다 캐릭터가 모여 살아있고, 토큰 사용량과 상태를 귀엽게 표현한다. 멀티 디바이스/멀티 계정 합산을 실시간으로 본다.

## 왜 만드나

- Claude Code Max는 5h 윈도우·주간 한도가 있는데, **여러 디바이스에서 쓰면 합산이 안 보임**
- 기존 OSS 도구는 단일 디바이스만 지원하거나 UI가 너무 기술적
- 토큰 절약하려면 "어디서 얼마나 쓰고 있는지"가 한눈에 보여야 함
- 결정적으로 — **귀여워야 매일 봄**

## 핵심 컨셉: 방 안의 픽셀 공 가족

핀 가능한 작은 윈도우 안에 캐릭터(픽셀 공)가 살아 움직임.
상태에 따라 위치/행동이 변함:

```
┌─ TokenPals ──────────[📌][−][×]┐
│  성랑의 맥 · 오늘 234K · 5h 11%  │
├──────────────────────────────┤
│         (벽 — 위쪽 절반)          │
│  ─────────────────────────────  │
│        🥔 ✨ "코딩중!"            │  ← working: 머리 위 스파클
│         (바닥 — 픽셀 도트 패턴)    │
├──────────────────────────────┤
│  💰 234K  📊 통계  ⚙️ 설정         │
└──────────────────────────────┘
```

**픽셀 공 캐릭터**: ㅅ 입 + 핑크 볼터치 + 클릭하면 ^^ 웃음 + 6색 팔레트.

**Phase 1 모델 (현재)**: 1 Claude 계정 = 1 펫 가족. 멀티 계정은 Phase 2+에서 다른 방으로 확장.

**ClaudePet과의 차이**: [ClaudePet](https://github.com/devTheKiwi/ClaudePet)은 데스크톱 위를 떠다니는 펫, TokenPals는 핀 가능한 방 윈도우 안 픽셀 공. 영역과 미감이 다르고 의미가 보완적이라 **공존 가능**.

## 진행 상태

🟢 **Phase 2.6 완료** — 설치 자동화 + 설정 통합 + 디바이스 중복 방지! 이제 누구나 한 줄 명령어로 설치 가능하고, 같은 디바이스는 중복으로 생성되지 않습니다.
- ✅ Phase 0: SPM 셋업, 메뉴바, 빈 방 윈도우, 픽셀 공 캐릭터
- ✅ Phase 1: 실 토큰 사용량, mood, 호버 툴팁, 메뉴 요약, FSEvents 워처, 말풍선, 눈 깜빡, 알림 + 설정
- ✅ Phase 2.1~2.3: Supabase SDK + Email OTP 로그인 + 이메일 필터링 + DeviceManager + DB 스키마 (RLS 포함)
- ✅ Phase 2.4: DeviceStatusManager (30sec heartbeat) + SessionSyncManager (JSONL→DB) + RealtimeManager (구독 인프라)
- ✅ Phase 2.5: 다중 디바이스 펫 UI (각 디바이스마다 펫 표시 + Realtime 무드 업데이트)
- ✅ Phase 2.6: 자동 설치 스크립트 + Supabase 설정 git 통합 + 디바이스 유니크 제약
- 🔜 다음: Realtime API 완전 구현, Phase 3 멀티 계정 / 팀

자세한 상태는 [docs/05-roadmap.md](docs/05-roadmap.md) 참고.

## 문서

- [01. 프로젝트 개요](docs/01-overview.md)
- [02. 아키텍처](docs/02-architecture.md)
- [03. 데이터 모델](docs/03-data-model.md)
- [04. UI & 캐릭터 시스템](docs/04-ui-and-characters.md)
- [05. 로드맵](docs/05-roadmap.md)
- [06. 기술 결정](docs/06-tech-decisions.md)

## 기술 스택 (요약)

- **앱**: AppKit/Cocoa, Swift Package Manager (`Package.swift`), macOS 13+
- **UI**: 핀 가능한 NSWindow + NSStatusItem 메뉴바 (보조)
- **캐릭터**: NSBezierPath 직접 드로잉 + 15fps Timer 애니메이션 (ClaudePet 패턴 차용)
- **인증**: Supabase Auth (Email OTP, 비밀번호 없음)
- **백엔드**: Supabase (Postgres + Realtime, 매니지드)
  - 스키마: accounts, account_links, devices, sessions, turns, device_status
  - RLS: 계정별 자동 격리
- **데이터 소스**: `~/.claude/projects/*.jsonl` 파일 워처 (FSEvents)
- **로컬 캐시**: SQLite (GRDB.swift, 향후)
- **배포**: 우선 `curl | bash` 자동 설치 (ClaudePet 패턴) → 동료 반응 좋으면 Apple Developer

## ClaudePet과의 관계

[ClaudePet](https://github.com/devTheKiwi/ClaudePet)의 캐릭터 드로잉, JSONL 파싱, 메뉴바 패턴, 설치 스크립트를 적극 차용 (MIT 라이센스). 컨셉과 영역은 다름 — 자세한 차용 정책은 [`docs/06-tech-decisions.md` ADR-010](docs/06-tech-decisions.md) 참고.

## 미정 사항

- [ ] 캐릭터 ClaudePet 그대로 vs 살짝 변형 (귀 추가 등으로 차별화)
- [ ] 첫 릴리즈 시점
