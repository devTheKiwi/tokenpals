# 06. 기술 결정 (ADR — Architecture Decision Records)

각 결정의 **맥락 / 옵션 / 선택 / 근거**를 기록.

---

## ADR-001: 앱 프레임워크는 SwiftUI

### 맥락
macOS에서 메뉴바 + 위젯 + 알림을 갖춘 귀여운 네이티브 앱이 필요.

### 옵션
| 옵션 | 장점 | 단점 |
|---|---|---|
| **SwiftUI** | 진짜 네이티브, 적은 바이너리(~5MB), macOS 위젯 무료, SF Symbols | Mac만, Swift 학습 |
| Tauri + React | 크로스플랫폼 가능, 웹 스택 친숙 | 네이티브 느낌 떨어짐, 메뉴바 통합 작업 필요 |
| Electron | 가장 익숙 | 무거움(~150MB), 배터리 영향, "예쁨"에 한계 |
| AppKit (Objective-C/Swift) | 완벽한 통제 | 코드량 많음, 모던 UI 불리 |

### 선택
**SwiftUI** (macOS 14+)

### 근거
- "귀엽게"가 핵심 가치 → 네이티브 애니메이션·SF Symbols·위젯이 압도적
- 5MB로 끝남 → 동료 배포시 부담 없음
- SwiftUI Charts, WidgetKit, UserNotifications 다 무료로 따라옴
- macOS 한정이지만 타겟 사용자도 macOS

### 대가
- Swift 학습 필요 (Claude Code가 보조 가능)
- Mac 외 플랫폼 확장은 별도 프로젝트가 됨

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
**JSONL 파일 워처 (단일 소스)**

### 근거
- 앱이 어차피 Mac에서 돌고 있으니 파일 보면 됨 (네트워크 불필요)
- 도구 호출, 파일 경로 등 OTel에 없는 정보 추출 가능
- 사용자가 별도 설정할 게 없음 (Hook 방식의 단점)
- collector 운영 부담 없음
- 단점인 "포맷 변경 위험"은 버전 감지 + fallback 파서로 대응

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

## ADR-005: SwiftUI Swift Package 선택

### 패키지 (예정)

| 용도 | 패키지 | 라이센스 |
|---|---|---|
| Supabase 클라이언트 | `supabase-swift` | MIT |
| 로컬 SQLite | `GRDB.swift` | MIT |
| 키체인 | `KeychainAccess` | MIT |
| 차트 (옵션) | SwiftUI Charts (내장, macOS 14+) | Apple |
| Lottie 애니메이션 (Phase 3) | `lottie-ios` | Apache 2.0 |

### 미정
- 로깅: `OSLog` (내장) vs `swift-log`
- 알림: `UserNotifications` (내장)으로 충분 — 외부 패키지 X

---

## ADR-006: 캐릭터는 이모지 베이스로 시작

### 맥락
귀여운 캐릭터 시스템 필요. 디자인 비용·일정 vs 결과물 퀄리티.

### 옵션
- A) **Apple Color Emoji** (이모지 그대로)
- B) 커스텀 일러스트 (직접 또는 외주)
- C) Lottie 애니메이션 에셋

### 선택
**A로 시작 → 인기 끌리면 C 검토**

### 근거
- 0원, 즉시 사용 가능
- macOS 다크/라이트 자동 대응
- 모든 사용자 머신에서 동일하게 보임 (폰트 의존성 없음)
- 16종으로 시작해도 충분히 다양함
- "정적이라 살아있는 느낌이 부족"은 SwiftUI 애니메이션으로 보완

### 대가
- 정말 캐릭터 IP 만들고 싶다면 한계 있음 → 그 단계 가면 일러스트 도입

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

### 선택
**Phase 1~2: ad-hoc 서명 → 동료 반응 좋으면 Apple Developer 가입**

### 근거
- 검증되지 않은 단계에 $99 쓰는 거 비효율
- 동료 1~3명이면 우클릭 한 번 가르쳐주면 됨
- "확장하고 싶다"는 신호 (10명+) 보이면 그때 정식 서명

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

---

## 미정 결정 (TBD)

### ~~정식 앱 이름~~ ✅ 결정됨
**TokenPals** 로 확정 (2026-04-29).
- 상표 안전 (Anthropic "Claude" 회피)
- 확장성 (다른 AI 도구 통합 여지)
- 번들 ID 후보: `com.tokenpals.app` 또는 `com.{사용자도메인}.tokenpals`

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
