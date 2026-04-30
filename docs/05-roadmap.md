# 05. 로드맵

## 마일스톤 요약

| Phase | 상태 | 기간 | 목표 |
|---|---|---|---|
| **0. 셋업** | ✅ 완료 | 1일 | SPM, 메뉴바, 빈 방, 첫 픽셀 펫 |
| **1. 단일 계정 단일 디바이스** | ✅ 완료 | 1주 | 실 토큰 데이터 + mood + 알림 + 설정 |
| **1.5. 다듬기** | ⏸ 대기 | 1주 | 실시간 워처, 위젯, 말풍선, 깜빡 |
| **2. 단일 계정 멀티 디바이스 (Supabase)** | 🟡 진행중 | 2~3일 | Email OTP 로그인 + 디바이스 등록 + DB 스키마 |
| **2.4 Realtime 동기화** | ⏸ 대기 | 1주 | 다른 머신과 실시간 합산 |
| **3. 멀티 계정 / 팀 / 방 꾸미기** | ⏸ 대기 | 2~3주 | 본인 다른 계정, 동료 초대, 가구·존 |

## Phase 0: 개발 환경 셋업 ✅ 완료

- [x] **`Package.swift` 생성** — SPM, macOS 13+, executableTarget
- [x] **AppKit 메뉴바 보일러플레이트** (`NSStatusItem`)
- [x] **빈 방 윈도우** (RoomWindow, 480×360, 핀/리사이즈)
- [x] **방 픽셀 테마 배경** (벽/바닥 두 톤 + 도트 패턴)
- [x] **첫 픽셀 캐릭터** — 12×12 공, 6색, ㅅ 입, ^^ 웃음, 볼터치
- [x] **2D 자유 이동** (목적지 기반 walk, 바닥 영역 한정)
- [x] **ClaudePet 차용 파일 임포트**:
  - `TokenTracker.swift` (JSONL 파싱) — 멀티 폴더 지원으로 확장
  - `PetColor.palette` 6색
  - L10n 패턴 (Strings.swift)
- [ ] **Supabase 프로젝트 생성** — Phase 2에서 (사용자 액션 필요)

## Phase 1: 단일 계정 단일 디바이스 🟡 진행중

### 데이터 파이프라인

- [x] **JSONL 파일 워처** — 30초 폴링 (Phase 1 단순)
  - `~/.claude/projects/*.jsonl` 만 (Phase 1 단일 계정)
  - 멀티 `.claude*` 지원 코드는 보관, 미사용
- [x] **JSONL 파서 + timestamp 필터링** (5h 윈도우)
  - `usageInLast(seconds:)` — line timestamp 기반
  - `lastActivityDate()` — 최신 활동 추적
  - mtime으로 파일 빠른 스킵
- [x] **UsageEngine** (백그라운드 파싱, 메인 큐 콜백)
- [x] **UsageSummary 타입** (todayTotal/Billable, fiveHour총합/실청구, cacheHitRate, mood)
- [x] **billable tokens** = input + output + cache_creation (mood 기준)
- [ ] **실시간 파일 워처 (FSEvents)** — 30초 폴링 → 즉시 갱신 (다음 작업 후보)

### UI / 캐릭터 / Mood

- [x] **메뉴바 아이콘 동적 갱신** — `🥔 234K`
- [x] **메뉴 요약** — 오늘 / 5시간 / 캐시 / 마지막 활동
- [x] **펫 1마리** — 시스템 hostname 기반 이름 + 색상 자동
- [x] **호버 툴팁** — 픽셀풍 미니박스 (디바이스/오늘/5h/캐시)
- [x] **mood 자동 반영**:
  - normal: 자유 산책
  - working ✨: 5분 내 활동 → 스파클
  - sleepy 😴: 30분+ 유휴 → 감은 눈
  - alarm 🚨: 5h billable ≥ 95% → 빨간 글로우 + 흔들
- [x] **5h 임계치 UserDefaults override** (`tokenpals.fiveHourBudget`)
- [ ] **말풍선 컴포넌트** (Phase 1.5)
- [ ] **눈 깜빡 애니메이션** (Phase 1.5)
- [ ] **첫 실행시 환영 멘트** (Phase 1.5)

### 알림 + 설정 (다음 작업)

- [ ] **알림 (UserNotifications)**:
  - 5h billable 80% 도달
  - 5h billable 95% (alarm)
  - 캐시 효율 < 20% & 토큰 > 100K
- [ ] **설정 윈도우**:
  - 5h budget 조정
  - 알림 토글 (종류별)
  - 핀 기본값
  - 캐릭터 속도

### 종료 조건 (Phase 1)
- 매일 사용해도 부담 없음 (앱이 안정적, 정확)
- 사용량 보고 토큰 절약 행동 변화 가능
- "방 컨셉이 매력적이다" 반응 자가 평가

## Phase 1.5: 다듬기

- [ ] **실시간 파일 워처 (FSEvents)** — Phase 1에서 분리 가능
- [ ] **말풍선 (MiniSpeechBubble)**:
  - 작업 시작/종료시 멘트
  - 45~90초마다 랜덤 멘트 (ClaudePet 차용)
- [ ] **데스크톱 위젯 (WidgetKit)**:
  - 작은 / 중간 사이즈
  - App Group으로 메인과 데이터 공유
- [ ] **상세 화면 (DetailWindow)**:
  - 캐릭터 더블클릭 → 별도 윈도우
  - 시간대별 그래프
  - 최근 세션 리스트
- [ ] **방 시간대별 조명**:
  - 새벽 어두침 / 오후 햇살 (배경 그라데이션 변화)
- [ ] **시스템 모션 감도 대응** (`accessibilityShouldReduceMotion`)

## Phase 2: 단일 계정 멀티 디바이스 (Supabase) 🟡 진행중

### Phase 2.1: Supabase 클라이언트 통합 ✅ 완료

- [x] **Supabase Swift SDK 통합** (`supabase-swift`)
- [x] **클라이언트 초기화** (URL + Publishable Key)
- [x] **세션 상태 확인** (`currentSessionEmail()`)

### Phase 2.2: Email OTP 로그인 ✅ 완료

- [x] **SignInWindow UI** (2-step: 이메일 → 6자리 코드)
- [x] **AuthManager** (`sendOTP` / `verifyOTP` / `signOut`)
- [x] **로컬 세션 저장** (Keychain via Supabase SDK)
- [x] **메뉴바 로그인/로그아웃 표시**

### Phase 2.3: 디바이스 등록 + DB 스키마 ✅ 거의 완료

- [x] **DB 마이그레이션** (`supabase/migrations/0001_initial_schema.sql`)
  - accounts, account_links, devices, sessions, turns, device_status
  - RLS 정책 포함
- [x] **DeviceManager** (첫 실행시 account + device 자동 생성)
- [x] **Models.swift** (Supabase 테이블 Codable 매핑)
- [x] **AppDelegate 통합** (로그인 → 자동 디바이스 등록)
- [ ] **Supabase 마이그레이션 수동 실행** ← 다음 스텝 (사용자 액션)

### Phase 2.4: Realtime 동기화 ⏸ 대기

- [ ] **로컬 SQLite 셋업** (`GRDB.swift`)
- [ ] **동기화 큐** (오프라인 대비, 큐 → 백그라운드 워커)
- [ ] **Supabase Realtime 구독** (다른 디바이스 새 turn → 즉시 UI 갱신)
- [ ] **multi-pet UI** (방에 디바이스마다 1마리, 같은 계정 공유)
- [ ] **Heartbeat** (`devices.last_seen` 갱신 → 오프라인 감지)

### 종료 조건
- 두 머신에서 같은 계정으로 로그인 → 자동 동기화
- 한 머신 메뉴바 클릭 → 다른 머신 사용량까지 보임

## Phase 3: 멀티 계정 / 팀 / 방 꾸미기 ⏸ 대기

### 본인 멀티 계정 (`.claude*` 폴더 추가)

- [ ] **계정 관리 UI** — 설정에서 계정 추가
- [ ] **폴더 매핑** — `~/.claude-alt` → "사이드 계정"
- [ ] **계정별 펫 그룹화** — 같은 계정 펫끼리 묶음
- [ ] **다중 계정 표시 옵션**:
  - A: 계정마다 별도 방 윈도우
  - B: 한 방, 색상으로 구분
  - C: 한 방, 탭으로 전환

### 동료 초대 / 팀

- [ ] **계정 데이터 모델 분리** — `account_id` 모든 쿼리에 적용 + RLS
- [ ] **팀 초대 흐름** — 초대 링크/코드, 동료가 수락 → `account_links` INSERT
- [ ] **권한 관리** — viewer는 read-only, 자기 계정 데이터만 write
- [ ] **팀 합산 대시보드**

### 분석 / 지능형

- [ ] **사용 패턴 분석** — 시간대별 burn rate, 비싼 세션 TOP 10
- [ ] **자동 제안** — "이 패턴이면 한도 X시간 후 도달", "/clear 권장"
- [ ] **업적 시스템** — 캐시 마스터, 효율왕 등
- [ ] **연속 사용 streak**

### 방 꾸미기

- [ ] **존(zone) 시스템** — 책상 / 침대 / 부엌 / 창문
- [ ] **가구 / 장식** — 사용 토큰으로 코인 적립 → 가구 구매
- [ ] **계절 테마** — 봄 에디션 (꽃잎 파티클, ClaudePet 차용)
- [ ] **Lottie 애니메이션** — 정적 NSBezierPath → 살아있는 캐릭터

## Phase 4+: 미래 가능성

- iOS/iPadOS 컴패니언 앱 (외부에서 한도 확인)
- Slack 연동 (한도 임박시 본인 채널 알림)
- 멀티 인공지능 (Claude / Codex / Cursor) 통합
- 공개 앱스토어 출시
- 팀 단위 비용 분석 / 예산 관리
- ClaudePet과 양방향 통합 (떠다니는 펫 모드 토글)

## 일정 추정 가정

- 1주 = 풀타임 5일 기준
- Swift/AppKit 학습 곡선 별도 (기존 경험 무 → +1주)
- ClaudePet 코드 차용으로 Phase 0+1 약 30~40% 시간 단축 효과 확인됨
- 캐릭터 디자인 = ClaudePet 패턴 + 픽셀 어댑팅, 디자인 비용 0

## 위험 요소

| 위험 | 영향 | 대응 |
|---|---|---|
| Claude Code JSONL 포맷 변경 | 파싱 깨짐 | 버전 감지 + fallback 파서 |
| Supabase 무료 한도 초과 | 동료 늘면 발생 가능 | 압축/요약 정책, 유료 검토 |
| Apple 코드 사이닝 / 공증 | 배포 마찰 | Phase 2 전에 Apple Dev 가입 검토 |
| FSEvents 누락 이벤트 | 일부 데이터 미반영 | 주기적 풀스캔으로 보완 |
| 같은 사용자가 머신마다 다른 Claude 계정 | 잘못된 합산 | Phase 3에서 명시 매핑으로 해결 |
| 5h budget 추정 부정확 | mood 오작동 | UserDefaults override 가능, Phase 3 자동 학습 검토 |
| ClaudePet 코드 라이브 변경 | 차용 코드 동기화 부담 | 차용 시점 명시 + 필요시만 갱신 |

## 의사결정 체크포인트

각 Phase 종료시 점검:
- ✅ 이대로 다음 단계 가도 되나?
- ✅ 우선순위 바꿔야 하나?
- ✅ 발견한 새 요구사항이 있나?
- ✅ ClaudePet과의 차별화 충분한가?
- ✅ 픽셀 테마 일관성 유지중인가?

## 진행 로그

### Phase 0 + 1
- 2026-04-29 Phase 0 시작 — 기획 문서 7개 작성, 컨셉 결정
- 2026-04-30 Phase 0 완료 — SPM + 픽셀 공 + 빈 방 동작
- 2026-04-30 Phase 1 일부 — 실 토큰 데이터, mood, 호버 툴팁, 메뉴 요약
- 2026-04-30 Phase 1 완료 — FSEvents, 말풍선, 눈 깜빡, 알림 + 설정
- 2026-04-30 단일 계정(`~/.claude/`) 모델로 정착 — 멀티 계정은 Phase 3+

### Phase 2
- 2026-04-30 Phase 2.1 완료 — Supabase SDK 통합, 클라이언트 초기화
- 2026-04-30 Phase 2.2 완료 — Email OTP 로그인 (SignInWindow + AuthManager)
- 2026-04-30 Phase 2.3 구현 완료 — DeviceManager + DB 스키마 (RLS 포함)
  - 마이그레이션 파일 준비 (수동 실행 대기)
  - 다음: Supabase Dashboard에서 마이그레이션 실행 후 Phase 2.4로
