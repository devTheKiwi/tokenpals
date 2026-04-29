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

### 결정 2: 여러 `.claude*` 폴더 모두 스캔

사용자 환경에 다음과 같은 디렉토리가 공존할 수 있음:
```
~/.claude/
~/.claude-alt/
~/.claude-account2/
~/.claude-other/
~/.claude_alt/
```

**전략**:
- 첫 실행시 `~/.claude*` 패턴으로 모두 탐색
- 각 폴더가 어떤 계정에 매핑되는지 사용자에게 확인
- `config.json` 또는 keychain에서 계정 정보 추출 시도
- 폴더별로 별도 워처 등록

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

## 멀티 디바이스 동기화 모델

### 디바이스 등록 (최초 1회)

```
앱 첫 실행
   ↓
Google 로그인 → account_id 획득
   ↓
device_id = UUID 생성, Keychain에 저장
   ↓
"이 디바이스 이름 + 캐릭터 선택"
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

## 멀티 계정 모델 (Phase 2)

```
Supabase Auth: 단일 사용자(나) 로그인
   ↓
account_links 테이블:
  user_id (나의 Supabase user id)
   ├─ account_a (내 메인 Claude 계정)
   ├─ account_b (동료 1, 초대 수락시)
   └─ account_c (동료 2, 초대 수락시)
   ↓
Row Level Security:
  "나는 내가 권한 있는 account_id의 데이터만 read 가능"
```

**동료 초대 흐름** (Phase 2):
1. 동료가 TokenPals 설치
2. 동료의 앱이 자기 계정의 데이터를 자기 Supabase 영역에 저장
3. 내가 동료에게 "팀 보기 권한" 요청
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
