# 06. 기술 결정 (ADR — Architecture Decision Records)

각 결정의 **맥락 / 옵션 / 선택 / 근거**를 기록.

---

## ADR-001: 앱 프레임워크는 AppKit (Cocoa) 베이스 ⚠️ 갱신

### 맥락
macOS에서 메뉴바 + 핀 가능한 방 윈도우 + 캐릭터 애니메이션 + 알림을 갖춘 귀여운 네이티브 앱이 필요. 참고 레포 ClaudePet이 이미 같은 도메인에서 AppKit으로 잘 동작중.

### 옵션
| 옵션 | 장점 | 단점 |
|---|---|---|
| **AppKit (Cocoa)** | NSWindow 자유 제어, NSBezierPath 캐릭터 드로잉, ClaudePet 코드 그대로 차용 가능 | SwiftUI 대비 코드량 약간 많음 |
| SwiftUI | 모던 UI 빠름, 위젯·차트 내장 | 캐릭터 자유 드로잉/애니메이션이 까다로움, ClaudePet 코드 재활용 어려움 |
| 하이브리드 (AppKit + SwiftUI) | 양쪽 장점 | 두 프레임워크 학습/연동 비용 |
| Tauri / Electron | 크로스플랫폼 | 네이티브 느낌 떨어짐, 무거움 |

### 선택
**AppKit (Cocoa) 단일 스택**. macOS 13+.

### 근거
- ClaudePet의 캐릭터 드로잉(`NSBezierPath` 기반 PetView)·애니메이션(`Timer 15fps`)·말풍선·메뉴바 패턴을 **거의 그대로 차용 가능** → 개발 속도 ↑
- 핀 가능 윈도우, 리사이즈, 항상 위, 모든 Space에서 보이기 등을 `NSWindow.level` / `collectionBehavior`로 직접 제어 (SwiftUI는 `NSWindow` 다시 다뤄야 함)
- 캐릭터가 방 안에서 자유롭게 위치/움직이는 컨셉은 명령형 드로잉(`draw(_:)`)이 자연스러움 — SwiftUI의 선언형은 오히려 부담
- 위젯(WidgetKit)과 알림(UserNotifications)은 어느 프레임워크 쓰든 따라옴

### 대가
- SwiftUI Charts를 못 씀 — 차트는 직접 NSView로 그리거나, 통계 화면만 SwiftUI로 부분 도입 검토 (필요시)
- 모던 SwiftUI 사례·라이브러리 풍부함은 활용 못 함

### 변경 이력
- 2026-04-29: 기존 SwiftUI에서 AppKit으로 변경. ClaudePet 레포(`Package.swift` 기반 SPM + AppKit) 분석 후 동일 스택 채택.

---

## ADR-002: 백엔드는 Supabase (매니지드)

### 맥락
멀티 디바이스 + 멀티 계정 동기화 필요. 자가 호스팅은 부담.

### 옵션
| 옵션 | 비용 | 적합도 |
|---|---|---|
| **Supabase** | 무료 → $25/월 | ⭐⭐⭐⭐⭐ Postgres+Auth+Realtime 다 있음 |
| Firebase | 무료 → 사용량 기반 | ⭐⭐⭐ NoSQL이라 집계 쿼리 불리 |
| 자가 호스팅 (Postgres+자작) | 무료 | ⭐ 운영 부담 큼 |
| AWS DynamoDB + Cognito | 무료 → 사용량 | ⭐⭐ 셋업 복잡 |
| PlanetScale + Clerk | 무료 → 유료 | ⭐⭐⭐ 좋지만 Realtime 별도 |

### 선택
**Supabase**

### 근거
- Postgres = 우리 데이터 모델(관계형)에 자연스러움
- Realtime = 멀티 디바이스 동기화에 즉시 활용
- Auth = Google 로그인 한 줄 셋업
- RLS = 멀티 계정 보안을 SQL로 표현 가능 (앱 코드 단순화)
- Swift SDK 공식 지원
- 무료 티어가 개인 + 동료 10명 영구 충당
- 필요시 자가 호스팅 가능 (오픈소스)

### 대가
- 무료 티어 한계 도달시 유료 (월 $25 부담은 작음)
- Supabase 중단/정책 변경 위험 (낮지만 있음)

---

## ADR-003: 데이터 소스는 JSONL 직접 파싱 (OTel 안 씀)

### 맥락
Claude Code 사용량을 어떻게 수집할 것인가.

### 옵션
| 옵션 | 장점 | 단점 |
|---|---|---|
| **JSONL 파일 워처** | 가장 풍부한 데이터, 의존성 0 | 파일 포맷 변경 위험 |
| Claude Code OTel | 표준 프로토콜, 미래 호환성 | collector 운영 필요, 데이터 적음 |
| Claude Code Hooks | 실시간성 좋음 | 설정 분산, 사용자가 매번 hook 설정 |
| 모두 (다중 소스) | 안정성 ↑ | 복잡도 ↑ |

### 선택
**JSONL 파일 워처 (단일 소스)** — ClaudePet의 `TokenTracker.swift` 패턴 차용.

### 근거
- 앱이 어차피 Mac에서 돌고 있으니 파일 보면 됨 (네트워크 불필요)
- 도구 호출, 파일 경로 등 OTel에 없는 정보 추출 가능
- 사용자가 별도 설정할 게 없음 (Hook 방식의 단점)
- collector 운영 부담 없음
- 단점인 "포맷 변경 위험"은 버전 감지 + fallback 파서로 대응
- ClaudePet의 `TokenTracker.swift`가 이미 검증된 JSONL 파싱 코드 → 그대로 차용 가능

### 대가
- 멀티 사용자 SaaS로 확장하려면 OTel 다시 검토 필요 (Phase 4+)
- macOS 외 플랫폼 추가시 워처 재구현

---

## ADR-004: 로컬 SQLite + Supabase 이중화

### 맥락
오프라인 대응 + 빠른 응답 + 신뢰성.

### 옵션
- A) Supabase만 사용
- B) 로컬 SQLite만 사용 (디바이스간 sync는 별도 메커니즘)
- C) **이중화 (로컬 = 캐시 + 큐, Supabase = 단일 진실)**

### 선택
**C** (이중화)

### 근거
- 메뉴바 앱은 100ms 안에 응답해야 함 → 로컬 캐시 필수
- 네트워크 끊겨도 동작해야 함 → 동기화 큐 필요
- Supabase가 단일 진실이라 충돌 처리 단순화

### 대가
- 두 곳 동기화 로직 작성 필요
- 디스크 공간 약간 더 씀 (수십 MB 수준이라 무시)

---

## ADR-005: Swift Package Manager (SPM) 단일 패키지 ⚠️ 갱신

### 맥락
프로젝트 구성 방식. Xcode 프로젝트 (`.xcodeproj`) vs Swift Package Manager.

### 옵션
| 옵션 | 장점 | 단점 |
|---|---|---|
| **SPM (`Package.swift`)** | 가벼움, 텍스트 기반(Git 친화), 빠른 빌드, ClaudePet과 동일 | Storyboard·xib 못 씀 (코드만), 최신 GUI는 일부 제약 |
| Xcode 프로젝트 | Storyboard·Assets.xcassets·인터페이스 빌더 풀 지원 | `.pbxproj` Git 충돌 잦음, 무거움 |

### 선택
**SPM 단일 `Package.swift`** — ClaudePet과 동일.

### 근거
- 이미 ClaudePet이 SPM으로 잘 돌아감
- 캐릭터·UI 모두 코드(NSBezierPath·NSView)로 만들 거라 Storyboard 불필요
- Git 친화적 (텍스트 기반 manifest)
- `swift build` / `swift run`으로 단순한 빌드 명령
- macOS 13+ executableTarget로 단일 실행파일

### 패키지 (예정)

| 용도 | 패키지 | 라이센스 |
|---|---|---|
| Supabase 클라이언트 | `supabase-swift` | MIT |
| 로컬 SQLite | `GRDB.swift` | MIT |
| 키체인 | `KeychainAccess` | MIT |
| 알림 | `UserNotifications` (내장) | Apple |
| 위젯 | `WidgetKit` (내장) | Apple |
| 로깅 | `OSLog` (내장) | Apple |

### 미정
- Lottie 도입 시점 (Phase 3 캐릭터 애니메이션 강화시)

### 대가
- Storyboard/Interface Builder 기반 사례 활용 어려움 (어차피 안 쓸 예정이라 무관)
- Xcode UI 검사기 일부 제약

---

## ADR-006: 캐릭터는 NSBezierPath 직접 드로잉 (ClaudePet 패턴) ⚠️ 갱신

### 맥락
귀여운 캐릭터 표현. ClaudePet은 이미 NSBezierPath로 감자형 캐릭터를 그림.

### 옵션
- A) **NSBezierPath 직접 드로잉** (ClaudePet 차용)
- B) Apple Color Emoji
- C) 커스텀 일러스트 PNG/SVG
- D) Lottie 애니메이션 에셋

### 선택
**A로 시작** (ClaudePet의 PetView 차용) → Phase 3에 D(Lottie) 검토.

### 근거
- ClaudePet의 검증된 드로잉 코드 (몸통 + 머리 + 발 + 눈 + 동공이 이동방향 따라감) 그대로 차용
- 6색 팔레트(PetColor)도 그대로 → 디바이스마다 색상 다르게
- 이모지보다 표정·움직임 자유도 높음
- 일러스트 에셋 제작 비용 0
- 메뉴바 아이콘은 이모지 + 텍스트 조합으로 별도 (예: `🥔 67%`)

### 대가
- 진짜 IP급 캐릭터 만들려면 한계 있음 → Phase 3에 일러스트/Lottie 도입

### 변경 이력
- 2026-04-29: 기존 "이모지 베이스" 전략에서 "NSBezierPath 드로잉"으로 변경. ClaudePet 차용 결정에 따른 자연스러운 귀결.

---

## ADR-007: 배포는 ad-hoc 서명 .dmg부터

### 맥락
동료에게 어떻게 배포할 것인가.

### 옵션
| 옵션 | 비용 | 마찰 |
|---|---|---|
| **ad-hoc 서명 .dmg** | $0 | 동료가 우클릭 → 열기 한 번 |
| Apple Developer Program | $99/년 | 더블클릭으로 즉시 실행 |
| Mac App Store | $99/년 + 심사 | 사용자에게 가장 쉬움, 심사 마찰 |
| Homebrew Cask | $0 | `brew install` 명령 |
| **`curl | bash` 자동 설치** (ClaudePet 패턴) | $0 | 한 줄로 빌드+설치+자동시작 |

### 선택
**Phase 1: `curl | bash` 자동 설치 (ClaudePet 패턴 차용)** → 동료 반응 좋으면 Apple Developer 가입.

### 근거
- ClaudePet에 이미 `install.sh`, `remote-install.sh` 검증된 스크립트가 있음 → 차용
- 한 줄로 빌드+설치+자동시작+업데이트 체크까지 됨
- 검증되지 않은 단계에 $99 쓰는 거 비효율
- 동료 1~3명이면 충분
- "확장하고 싶다"는 신호 (10명+) 보이면 그때 정식 서명

### 변경 이력
- 2026-04-29: ClaudePet의 install.sh 패턴 채택 결정.

---

## ADR-008: 멀티 `.claude*` 폴더 자동 감지

### 맥락
사용자가 여러 Claude 계정용으로 다음과 같은 폴더를 가질 수 있음:
- `~/.claude/`
- `~/.claude-alt/`
- `~/.claude-account2/`
- `~/.claude-other/`
- `~/.claude_alt/`

### 결정
첫 실행시 **자동 탐색** + 사용자 매핑 확인 UI.

```
"이 디바이스에서 다음 Claude 폴더를 찾았어요!"
  ┌─────────────────────────────────┐
  │ ☑ .claude          → 메인 계정  │
  │ ☑ .claude-alt      → 메인 계정  │
  │ ☑ .claude-account2 → 사이드     │
  │ ☐ .claude-other    → 무시       │
  └─────────────────────────────────┘
```

각 폴더가 어떤 account에 매핑되는지 사용자가 결정.

> 참고: ClaudePet의 `TokenTracker.swift`는 `~/.claude/projects` 단일 폴더만 봄. TokenPals는 이를 확장해서 글로빙(`~/.claude*/projects`) 패턴으로 처리.

---

## ADR-009: 메인 UI는 핀 가능한 방 윈도우 (NEW)

### 맥락
멀티 디바이스 캐릭터를 한 눈에 보는 방법. 메뉴바 팝오버는 정보 밀도는 좋지만 "살아있는 느낌"이 약하고, 떠다니는 펫(ClaudePet)은 다른 디바이스 합산을 못 보여줌.

### 옵션
- A) 메뉴바 팝오버에 디바이스 카드 리스트
- B) ClaudePet처럼 데스크톱 위에 떠다니는 펫
- C) **핀 가능한 작은 "방" 윈도우 안에 디바이스 캐릭터들이 모여 있음** ⭐
- D) 메뉴바 + 떠다니는 펫 (둘 다)

### 선택
**C** (방 윈도우)

### 근거
- 메뉴바 팝오버 대비: 캐릭터들이 방 안에서 살아 움직임 → 매일 보고 싶어짐
- ClaudePet 펫 대비: 한 화면에 여러 디바이스 캐릭터 모여 → 합산 한눈에
- ClaudePet과 영역 침범 X (ClaudePet은 데스크톱 전체, TokenPals는 자기 방 안에서만 활동)
- 핀 켜면 항상 위·모든 Space에 → 곁눈질로 모니터링
- 리사이즈로 디바이스 많아져도 대응
- Phase 3에서 가구·존(zone) 시스템으로 확장 자연스러움

### 대가
- 메뉴바만 쓰는 사람보다 화면 공간 차지함 (해결: 메뉴바도 같이 유지, 방은 사용자 토글)
- 방 안 캐릭터 위치 충돌 방지 로직 필요

### 윈도우 사양
- 기본 480×360, 최소 320×240, 리사이즈 가능
- 핀 토글: `window.level = .floating` + `[.canJoinAllSpaces, .stationary]`
- 메뉴바도 유지 (보조)

---

## ADR-010: ClaudePet 코드 차용 정책 (NEW)

### 맥락
참고 레포 [`devTheKiwi/ClaudePet`](https://github.com/devTheKiwi/ClaudePet)이 동일한 도메인에서 검증된 패턴을 다수 보유. MIT 라이센스라 자유 차용 가능.

### 결정
**모듈 단위로 코드를 가져오되, 컨셉이 다른 부분(데스크톱 펫 → 방 윈도우)은 어댑팅**.

### 차용 / 어댑팅 / 신규 분류

| 영역 | 분류 | 출처 / 비고 |
|---|---|---|
| 캐릭터 드로잉 (몸통/머리/발/눈) | ✅ **차용** | `PetView.draw(_:)` 거의 그대로 |
| 6색 팔레트 (PetColor) | ✅ **차용** | 그대로 |
| 애니메이션 상태 머신 (idle/walking/jumping/...) | ✅ **차용** | `PetState` enum + `tick()` |
| Working effect (반짝임) | ✅ **차용** | `drawWorkingEffect` |
| 봄 에디션 / 꽃잎 파티클 | ⏸ **나중** | Phase 3 스킨 시스템에서 |
| 시간 뱃지 | ⏸ **나중** | 디바이스 상세 화면에서만 활용 |
| Coffee 컵 (Desktop 모드) | ✅ **차용** | Phase 3 zone 시스템 도입시 |
| JSONL 파싱 (TokenTracker) | ✅ **차용 + 확장** | 멀티 `.claude*` 폴더 지원 추가 |
| Hook 시스템 (`/tmp/claudepet-*.json`) | 🔄 **어댑팅** | TokenPals용으로 별도 파일명, hook 스크립트 별도 |
| ClaudeMonitor 상태 분류 | ✅ **차용** | working/idle/permission/notRunning 매핑 |
| L10n / Strings 패턴 | ✅ **차용** | 한/영 i18n 구조 |
| Speech Bubble | 🔄 **어댑팅** | NSWindow → NSView (방 윈도우 내부 미니 컴포넌트) |
| install.sh / remote-install.sh | 🔄 **어댑팅** | TokenPals 명칭으로 변경 + Supabase 설정 추가 |
| UpdateChecker | ✅ **차용** | 버전 체크 패턴 |
| HookSetup | 🔄 **어댑팅** | Claude Code의 Hook 시스템 활용 |
| **PetWindow (떠다니는 펫)** | ❌ **사용 안 함** | TokenPals는 방 안 캐릭터, 컨셉 다름 |
| **Per-session pet** | ❌ **사용 안 함** | TokenPals는 디바이스 단위 |
| Multi-pet 충돌 회피 | 🆕 **신규 작성** | 방 안 좌표계 기반 |
| Supabase 연동 | 🆕 **신규** | ClaudePet에 없음 |
| 멀티 계정 (RLS) | 🆕 **신규** | ClaudePet에 없음 |
| Realtime 구독 | 🆕 **신규** | ClaudePet에 없음 |

### 라이센스 처리
- ClaudePet은 MIT — 차용 자유, 저작권 표기 필요
- TokenPals 저장소 README에 "Built on patterns from [ClaudePet](https://github.com/devTheKiwi/ClaudePet) — MIT" 크레딧 추가
- 차용한 파일에는 헤더 주석으로 출처 명시

### 운영 원칙
- ClaudePet은 별도 프로젝트로 계속 운영. TokenPals는 동일 사용자(devTheKiwi)의 별도 진화형
- ClaudePet의 버그 수정/개선은 가능한 양방향 동기화 (단방향 의존 X)

---

## 미정 결정 (TBD)

### 텔레메트리 / 분석
- 우리 앱 자체 사용 분석을 할 것인가?
- 옵션: 안 함 / Plausible (오픈소스 + 프라이버시) / Mixpanel
- 결정 시점: Phase 1.5 (지금은 무관)

### 업적 시스템 디테일
- 어떤 업적을 정의할지
- 결정 시점: Phase 3 (필요시)

### 가격 모델
- 무료 / 동료까지만 무료 / Pro 티어
- 결정 시점: Phase 2 종료 후 동료 반응 보고

### 다른 AI 코드 도구 통합
- Codex, Cursor, Cline 등 합산 — 가능하지만 범위 폭증
- 결정 시점: Phase 3+

### 방 꾸미기 / 가구 / 존 시스템
- Phase 1은 빈 방
- Phase 3에 도입할 첫 가구/존 구성: 책상, 침대, 부엌, 창문 후보
- 결정 시점: Phase 2 후반 또는 Phase 3 시작시

### 캐릭터 차별화 (vs ClaudePet)
- ClaudePet과 동일하게 갈지, 살짝 변형 (귀 추가, 색상 톤 변경 등)으로 구분할지
- 결정 시점: Phase 1 구현 진행하면서 자연스럽게
