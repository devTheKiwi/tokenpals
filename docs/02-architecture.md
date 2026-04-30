# 02. 아키텍처

## 전체 그림

```
┌─────────────── 각 Mac 디바이스 ───────────────┐
│                                                 │
│  Claude Code (CLI, 그냥 평소처럼 사용)         │
│        ↓ 자동 기록                              │
│  ~/.claude/projects/*.jsonl                     │
│  ~/.claude-alt/projects/*.jsonl                 │
│  ~/.claude-account2/projects/*.jsonl   ← 멀티   │
│        ↑ FSEvents 워처                          │
│  ┌──────────── TokenPals 앱 (AppKit/SPM) ─┐    │
│  │  1. JSONL 파일 워처 (FSEvents)          │    │
│  │  2. 토큰/모델/캐시 파싱 (TokenTracker)  │    │
│  │  3. 로컬 SQLite (오프라인 대비)         │ ───┼───> Supabase
│  │  4. Supabase 동기화 (큐 기반)           │ <──┼──── Realtime
│  │  5. AppKit 메뉴바 (보조)                │    │     구독
│  │  6. AppKit 방 윈도우 (메인 UX)          │    │
│  │     ├─ RoomView + 다수 PetActor         │    │
│  │     └─ 캐릭터 상태 머신/애니메이션      │    │
│  │  7. UserNotifications 알림              │    │
│  └─────────────────────────────────────────┘    │
└─────────────────────────────────────────────────┘
                        │
                        ↓
              ┌────── Supabase ──────┐
              │  • Auth (Google)     │
              │  • Postgres (저장)   │
              │  • Realtime (PubSub) │
              │  • RLS (계정별 격리) │
              └──────────────────────┘
                        ↑
                        │
       (다른 Mac 디바이스에서도 동일 앱이 푸시/수신)
```

## 주요 설계 결정

### 결정 1: OpenTelemetry 안 씀, JSONL 직접 파싱

**선택**: JSONL 파일 워처
**이유**:
- 앱이 어차피 Mac에서 돌고 있음 — 파일 보면 됨
- OTel collector 운영 부담 없음
- 더 풍부한 데이터 추출 가능 (도구 호출, 파일 경로 등)
- 모델 변경시 OTel 스키마 변경에 안 휘말림

**대안 검토**: OTel은 멀티 사용자 SaaS 만들 때 다시 검토. 지금은 오버엔지니어링.

### 결정 2: Phase 1은 `~/.claude/` 단일 폴더만 추적

사용자 환경에 다음과 같은 디렉토리가 공존할 수 있음:
```
~/.claude/             ← Phase 1 추적 대상
~/.claude-alt/         ← Phase 3+ (멀티 계정)
~/.claude-account2/    ← Phase 3+
~/.claude-other/       ← Phase 3+
~/.claude_alt/         ← Phase 3+
```

**Phase 1 전략 (현재)**:
- `~/.claude/projects` 만 스캔 (단일 주 계정 가정)
- 다른 `.claude*` 폴더는 무시 (멀티 계정 기능에서 다룸)

**Phase 3+ 멀티 계정 확장 시**:
- 첫 실행시 또는 설정에서 발견된 폴더 사용자에게 매핑 요청
- "이 폴더는 어떤 계정으로 인식할지" 라벨링
- 계정마다 별도 펫 그룹 (또는 별도 방)

### 결정 3: 로컬 SQLite + Supabase 이중화

| 데이터 | 로컬 SQLite | Supabase |
|---|---|---|
| 매 턴 raw 이벤트 | ✅ | ✅ |
| 집계 (일/주) | ✅ | ✅ |
| 디바이스 메타 | ✅ | ✅ |
| 프롬프트 본문 | ❌ | ❌ |
| 파일 경로 | ✅ | 옵션 (개인정보) |

**왜 이중화**:
- 오프라인에서도 동작
- Supabase 일시 장애시 로컬에서 표시
- 동기화 큐로 신뢰성 확보 (실패시 재전송)

### 결정 4: Supabase 매니지드 사용

- **Auth**: Google OAuth (한 줄 셋업)
- **Postgres**: RLS로 계정별 자동 격리
- **Realtime**: WebSocket 기반 PubSub, 디바이스간 즉시 반영
- **Storage**: 안 씀 (필요시 캐릭터 커스텀 이미지 등에 활용 가능)
- **무료 티어**: 500MB DB, 동시 연결 200개 → 개인 + 동료 10명 영구 무료

## 데이터 흐름

### 1. Claude Code 사용 → 우리 앱이 감지

```
사용자가 Claude Code에서 명령 실행
   ↓
Claude Code가 ~/.claude/projects/{session-id}.jsonl 에 append
   ↓
FSEvents가 우리 앱에 변경 알림
   ↓
앱이 새 라인만 파싱 (마지막 offset 기억)
   ↓
   ├─> 로컬 SQLite에 INSERT
   └─> Supabase로 비동기 push
        ↓
        Realtime이 다른 디바이스에 broadcast
```

### 2. 다른 디바이스 사용량 수신

```
Supabase Realtime 구독
   ↓
다른 디바이스에서 새 이벤트 발생
   ↓
WebSocket으로 우리 앱에 푸시
   ↓
캐릭터 상태 업데이트 (애니메이션)
   ↓
필요시 메뉴바 아이콘 갱신
```

### 3. 캐릭터 상태 결정

매 N초마다 (또는 이벤트 트리거시):
```
device_status = compute_status(
    last_active_at,
    current_session_active,
    five_hour_window_usage,
    weekly_usage,
    cache_hit_rate
)
   ↓
character_mood = map(device_status)
   ↓
UI 갱신 (표정 + 말풍선 + 색상)
```

## Identity 모델 (TokenPals 로그인 = 사용자 식별)

**핵심 원칙**: TokenPals는 **TokenPals 로그인**으로 사용자를 식별한다. Claude Code의 내부 인증 정보(이메일/토큰 등)를 직접 읽지 않는다.

```
[Mac A]                       [Mac B]
TokenPals 앱                   TokenPals 앱
  ↓ Google OAuth                ↓ Google OAuth
me@gmail.com                  me@gmail.com
  ↓                             ↓
같은 Supabase Auth user_id → 같은 사람으로 인식 → 데이터 합산
```

**왜 Claude 계정을 직접 감지하지 않나**:
- Claude Code의 `~/.claude/.credentials.json` / Keychain 파싱은 내부 포맷 변경에 취약
- OAuth 토큰 등 민감 정보 다루기 부담 (보안)
- TokenPals 로그인이 더 깔끔하고 안정적

**가정 (Phase 1)**: 사용자가 자기 모든 머신에서 같은 Claude 계정을 쓴다고 가정. 이 가정이 깨지는 케이스(같은 사용자가 머신마다 다른 Claude 계정 사용)는 Phase 3+에서 명시적 매핑 UI로 해결.

**검증 강화 (Phase 3+ 옵션)**: `.credentials.json`에서 이메일 해시만 추출 → 디바이스간 비교 → 일치하지 않으면 경고. 지금은 과한 엔지니어링.

## 멀티 디바이스 동기화 모델

### 디바이스 등록 (최초 1회)

```
앱 첫 실행
   ↓
Google 로그인 → Supabase Auth user_id 획득
   ↓
device_id = UUID 생성, Keychain에 저장
   ↓
"이 디바이스 이름 + 캐릭터 선택" (옵션, 기본은 hostname + 색상 자동)
   ↓
Supabase devices 테이블에 INSERT
```

### 평상시 동기화

- **Push**: 우리 앱이 매 턴 이벤트를 Supabase로 INSERT
- **Pull**: Realtime 구독으로 다른 디바이스 이벤트 수신
- **Heartbeat**: 30초마다 `devices.last_seen` 갱신 → 오프라인 감지

### 충돌 처리

- 같은 디바이스 ID는 한 머신에 고정 → 충돌 가능성 낮음
- 모든 INSERT는 idempotent (`session_id + turn_index` 유니크 제약)
- 네트워크 끊겼다 복구되면 큐에 쌓인 이벤트 재전송

## 멀티 계정 모델 (Phase 3+)

```
Supabase Auth: TokenPals 사용자(나) 로그인
   ↓
account_links 테이블:
  user_id (나의 Supabase user id)
   ├─ account_a (내 메인 Claude 계정 = ~/.claude/)
   ├─ account_b (내 사이드 계정 = ~/.claude-alt/) ← 본인이 추가
   ├─ account_c (동료 1의 계정, 초대 수락시) ← 동료가 본인 데이터 공유
   └─ account_d (동료 2의 계정, 초대 수락시)
   ↓
Row Level Security:
  "나는 내가 권한 있는 account_id의 데이터만 read 가능"
```

**본인 멀티 계정 흐름** (Phase 3):
1. 설정에서 "계정 추가" → 폴더 매핑 (`~/.claude-alt` → "사이드 계정")
2. 새 account 레코드 생성, 내 user_id에 link
3. 별도 펫 그룹/방으로 시각화

**동료 초대 흐름** (Phase 3):
1. 동료가 TokenPals 설치 + 자기 Google 로그인
2. 동료의 앱이 자기 계정의 데이터를 자기 Supabase 영역에 저장
3. 내가 동료에게 "팀 보기 권한" 요청 (초대 코드/링크)
4. 동료가 승인하면 내 앱에서 그의 데이터 read 가능 (write는 절대 X)

## 보안 / 프라이버시

| 데이터 | 저장 위치 | 외부 전송 |
|---|---|---|
| 프롬프트 본문 | 로컬만 (Claude Code가 저장한 그대로) | ❌ 절대 X |
| 토큰 수, 모델, 타임스탬프 | 로컬 + Supabase | ✅ |
| 파일 경로 | 로컬 + Supabase (선택) | ⚠️ 옵션 |
| 도구 이름 (Bash, Read 등) | 로컬 + Supabase | ✅ |
| 사용자 이메일 | Supabase Auth | ✅ (인증 목적) |

- HTTPS only (Supabase 기본)
- RLS로 다른 계정 데이터 격리
- 로컬 SQLite는 macOS Keychain으로 보호된 데이터 디렉토리에

## UI 아키텍처 (AppKit)

```
NSApplication (.accessory) ─ Dock 아이콘 숨김
  ├─ NSStatusItem (메뉴바 아이콘 + 작은 메뉴)
  ├─ RoomWindow: NSWindow (메인 UX, 핀 가능, 리사이즈)
  │   └─ RoomView: NSView
  │       ├─ 배경 드로잉 (방)
  │       ├─ PetActor[] (디바이스마다 1개)
  │       │   ├─ 좌표/상태/색상
  │       │   ├─ NSBezierPath 캐릭터 드로잉 (ClaudePet 차용)
  │       │   └─ 15fps Timer 애니메이션
  │       └─ MiniSpeechBubble (캐릭터 머리 위)
  ├─ DetailWindow: NSWindow (디바이스 더블클릭시)
  └─ SettingsWindow: NSWindow (설정)
```

**핵심 차용 (ClaudePet)**:
- `PetView.draw(_:)` → `PetActor.draw()` 거의 그대로
- `PetState` enum + `tick()` 애니메이션
- 6색 `PetColor.palette`
- `TokenTracker.swift` JSONL 파싱
- `L10n` i18n 구조

**핵심 신규**:
- `RoomView`: 여러 PetActor를 한 NSView 안에 호스팅
- 좌표계가 화면 전체 → 방 영역으로 제한
- Supabase 클라이언트 + Realtime 구독
- 멀티 `.claude*` 폴더 동시 워칭

## 외부 의존성

- **macOS 13+ Apple Silicon**: AppKit, FSEvents, UserNotifications, WidgetKit 사용
- **Swift Package Manager**: 빌드 시스템. `swift build` / `swift run`
- **Supabase**: 매니지드 BaaS — 무료 티어 제한 도달시 대안 (Self-hosted, Firebase) 검토
- **Anthropic Claude Code**: JSONL 포맷 변경시 파서 업데이트 필요
- **ClaudePet (참고 레포)**: MIT 라이센스, 캐릭터/애니메이션/JSONL 파싱 패턴 차용 (자세한 정책은 [06-tech-decisions.md ADR-010](06-tech-decisions.md))
