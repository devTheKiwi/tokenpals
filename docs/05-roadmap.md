# 05. 로드맵

## 마일스톤 요약

| Phase | 기간 (추정) | 목표 | 결과물 |
|---|---|---|---|
| **0. 셋업** | 1~2일 | 개발 환경, Supabase 프로젝트, ClaudePet 코드 차용 | 빈 메뉴바 앱 + 빈 방 윈도우 + DB 연결 |
| **1. 단일 계정 MVP** | 2주 | 멀티 디바이스, 캐릭터, 방 윈도우, 기본 모니터링 | 본인이 매일 쓰는 수준 |
| **1.5. 다듬기** | 1주 | Realtime, 알림, 위젯, 애니메이션 | 자랑하고 싶은 수준 |
| **2. 멀티 계정 / 팀** | 1주 | 동료 초대, 팀 뷰 | 동료에게 풀 수 있는 상태 |
| **3. 분석/지능형 + 방 꾸미기 (선택)** | 2~3주 | 패턴 분석, 자동 제안, 업적, 가구·존 시스템 | 토큰 진짜 절약되는 단계 |

총 **4~6주** 풀타임 기준. 부분 시간이면 2~3개월 예상.

## Phase 0: 개발 환경 셋업 (1~2일)

### 작업
- [ ] **`Package.swift` 생성** (SPM, macOS 13+, executableTarget)
- [ ] **AppKit 메뉴바 보일러플레이트** (`NSStatusItem` + 작은 메뉴) — ClaudePet `main.swift` + `AppDelegate.swift` 베이스 차용
- [ ] **빈 방 윈도우** (NSWindow, 480×360, 리사이즈/핀 가능, borderless or titled)
- [ ] **Supabase 프로젝트 생성** (무료 티어)
- [ ] **`supabase-swift` SDK 통합** (Package dependency)
- [ ] **Google OAuth 설정** (Supabase Auth)
- [ ] **로그인 화면** (NSWindow, 간단한 버튼 + 콜백)
- [ ] **로컬 SQLite 셋업** (`GRDB.swift`)
- [ ] **기본 스키마 마이그레이션** (Supabase + 로컬 동시)
- [ ] **ClaudePet 차용 파일 임포트**:
  - `TokenTracker.swift` (JSONL 파싱) — 거의 그대로
  - `Strings.swift` (L10n) — 거의 그대로
  - `PetView.swift` (캐릭터 드로잉) — `PetActor`로 리네이밍, RoomView 안에서 사용
  - `PetColor.palette` — 그대로

### 종료 조건
- `swift run` → 메뉴바 아이콘 + 빈 방 윈도우 표시
- 로그인 → Supabase에 사용자 기록
- ClaudePet 캐릭터 한 마리가 빈 방에 떠 있는 상태

## Phase 1: 단일 계정 MVP (2주)

### 1주차: 데이터 파이프라인

- [ ] **JSONL 파일 워처 구현**
  - `~/.claude*/projects/**/*.jsonl` 패턴 탐색 (멀티 폴더)
  - `FSEvents` 로 변경 감지
  - 마지막 offset 기억 (`jsonl_cursors` 테이블)
- [ ] **JSONL 파서 (TokenTracker 확장)**
  - ClaudePet의 `parseJSONL` 차용 + 멀티 폴더 지원
  - 모델, 토큰, 도구, 타임스탬프 추출
  - 새 라인만 처리 (idempotent)
- [ ] **로컬 DB 적재**
  - sessions, turns 테이블 채우기
  - UNIQUE 제약으로 중복 방지
- [ ] **백필 (기존 JSONL 전체 흡수)**
  - 첫 실행시 진행률 표시
  - 배치 INSERT
- [ ] **Supabase 동기화**
  - 동기화 큐 → 백그라운드 워커
  - 네트워크 끊김시 재시도

### 2주차: UI & 캐릭터 (방 윈도우)

- [ ] **디바이스 등록 플로우**
  - 첫 실행: 이름 + 캐릭터 색상 선택 (6색 팔레트)
  - hostname 자동 추천
  - Keychain에 device_id 저장
- [ ] **메뉴바 아이콘 동적 갱신**
  - 가장 활발한 디바이스 색상의 캐릭터 이모지 + 5h 진행률 %
  - 클릭시 작은 메뉴 (방 열기/숨기기, 요약, 설정, 종료)
- [ ] **방 윈도우 (RoomWindow + RoomView)**
  - NSWindow: 480×360, 리사이즈 가능, 핀 가능, borderless 또는 titled
  - RoomView: 배경(빈 방) + 다수 PetActor 호스팅
  - PetActor: ClaudePet PetView 차용, 방 영역 안에서만 이동
  - 상단 바: 디바이스 수 + 5h% + 주간%
  - 하단 바: 합계 토큰 + 통계/설정 진입점
- [ ] **캐릭터 상태 → 행동 매핑**
  - mood 계산 함수 (working/happy/sleepy/confused/stressed/danger/offline)
  - 각 mood 별 PetActor 행동 (정지/산책/수면/안절부절/...)
- [ ] **계정 디렉토리 자동 감지**
  - `.claude*` 패턴 스캔
  - 사용자에게 매핑 확인 UI
- [ ] **말풍선 (MiniSpeechBubble)**
  - RoomView 내부 NSView로 구현 (별도 NSWindow 안 씀, ClaudePet과 다름)
  - 캐릭터 머리 위에 표시 + 자동 페이드
  - 랜덤 발화 (45~90초 간격)

### 종료 조건 (Phase 1)
- 멀티 디바이스에서 앱 설치 → 자동 동기화
- 한 디바이스 방 윈도우에서 다른 디바이스 캐릭터까지 보임
- 캐릭터의 위치/행동이 실제 사용 패턴 따라 변화
- 핀 토글로 항상 위·모든 Space에서 보임

## Phase 1.5: 다듬기 (1주)

- [ ] **Supabase Realtime 구독**
  - 다른 디바이스 새 turn → 즉시 캐릭터 행동 갱신
- [ ] **알림 (UserNotifications framework)**
  - 5h 80% / 95% 임계치
  - 캐시 효율 저하 알림
  - 알림 설정 화면
- [ ] **데스크톱 위젯 (WidgetKit)**
  - 작은/중간 사이즈
  - App Group으로 메인 앱과 데이터 공유
- [ ] **애니메이션 정교화** (AppKit Timer + needsDisplay)
  - 숨쉬기, 깜빡, mood 전환 부드럽게
  - ClaudePet의 working effect 차용
- [ ] **상세 화면 (DetailWindow)**
  - 캐릭터 더블클릭 → 별도 윈도우
  - 시간대별 그래프 (NSView 직접 그리거나 부분적으로 SwiftUI Charts)
  - 최근 세션 리스트
- [ ] **설정 화면 (SettingsWindow)**
  - 알림 토글, 디바이스/색상 변경
  - 핀 기본값, 캐릭터 속도 조절
  - 데이터 내보내기
- [ ] **방 윈도우 시간대별 조명**
  - 새벽 어두침 / 오후 햇살 (배경 그라데이션 변화)

### 종료 조건 (1.5)
- 매일 켜놓고 봐도 부담스럽지 않음
- 한도 임박시 알림으로 행동 변화 가능
- 동료가 봤을 때 "오 이거 뭐야?" 반응

## Phase 2: 멀티 계정 / 팀 (1주)

- [ ] **계정 데이터 모델 분리**
  - `account_id` 모든 쿼리에 적용
  - RLS 정책 활성화
- [ ] **팀 초대 흐름**
  - 사용자 A: "동료에게 보기 권한 공유" 버튼
  - 초대 링크/코드 생성
  - 동료가 자기 앱에서 수락 → `account_links` INSERT
- [ ] **다중 계정 UI**
  - 옵션 A: 계정마다 별도 방 윈도우
  - 옵션 B: 한 방에 색상으로 구분
  - Phase 2 시작시 결정
- [ ] **권한 관리**
  - viewer는 read-only
  - 자기 계정 데이터만 write
- [ ] **팀 합산 대시보드**
  - 전체 팀 5h 사용량 시각화
  - 누가 한도 임박인지 한눈에

### 종료 조건 (Phase 2)
- 동료에게 설치 스크립트 공유 → 동료가 설치 → 각자 본인 계정 보면서 서로 권한 공유한 계정도 함께 보기 가능

## Phase 3: 분석/지능형 + 방 꾸미기 (선택, 2~3주)

### 분석/지능형

- [ ] **사용 패턴 분석**
  - 시간대별 평균 burn rate
  - 프로젝트별 토큰 효율
  - 비싼 세션 TOP 10
- [ ] **자동 제안 시스템**
  - "이 패턴이면 한도 X시간 후 도달"
  - "/compact 또는 /clear 권장 타이밍"
  - "Opus 대신 Sonnet 추천"
- [ ] **업적 시스템**
  - 캐시 마스터, 효율왕, 야근러 등
  - 해금 알림 + 캐릭터 옆에 배지
- [ ] **연속 사용 streak**
  - 디바이스별 streak 카운트
  - 1주년 / 100세션 등 마일스톤

### 방 꾸미기

- [ ] **존(zone) 시스템 도입**
  - 책상 (working zone): working 캐릭터가 모임
  - 침대 (sleeping zone): sleepy 캐릭터가 누움
  - 부엌 (coffee zone): Claude Desktop 켜진 캐릭터가 ☕와 함께
  - 창문 (window): 시간대별 풍경
- [ ] **가구 / 장식**
  - 사용 토큰으로 코인 적립 → 가구 구매
  - 다마고치 + 동물의 숲 컨셉
- [ ] **계절 테마**
  - ClaudePet의 봄 에디션 차용 (꽃잎 파티클)
  - 여름/가을/겨울 추가
- [ ] **Lottie 애니메이션 도입 (선택)**
  - 정적 NSBezierPath → 살아있는 캐릭터
  - 우선순위 낮음

## Phase 4+: 미래 가능성 (메모)

- iOS/iPadOS 컴패니언 앱 (외부에서 한도 확인용)
- Slack 연동 (한도 임박시 본인 채널에 알림)
- 멀티 인공지능 (Claude / Codex / Cursor) 통합
- 공개 앱스토어 출시
- 팀 단위 비용 분석 (예산 관리)
- ClaudePet과 양방향 통합 (떠다니는 펫 모드 토글로 두 컨셉 동시 사용)

## 일정 추정 가정

- 1주 = 풀타임 5일 기준 (또는 부업 10~15시간/주의 2배 시간)
- Swift/AppKit 학습 곡선 별도 (기존 경험 무 → +1주)
- ClaudePet 코드 차용으로 Phase 1 약 30% 단축 효과 예상
- 캐릭터 디자인은 ClaudePet 그대로 → 디자인 작업 0

## 위험 요소

| 위험 | 영향 | 대응 |
|---|---|---|
| Claude Code JSONL 포맷 변경 | 파싱 깨짐 | 버전 감지 + fallback 파서 |
| Supabase 무료 한도 초과 | 동료 늘면 발생 가능 | 압축/요약 정책, 유료 플랜 검토 |
| Apple 코드 사이닝 / 공증 | 배포 마찰 | Phase 2 전에 Apple Dev 가입 검토 |
| FSEvents 누락 이벤트 | 일부 데이터 미반영 | 주기적 풀스캔으로 보완 |
| 멀티 `.claude*` 폴더 스키마 차이 | 파싱 실패 | 폴더별 독립 파서 옵션 |
| 방 안 캐릭터 위치 충돌 | 시각적 어색 | 간단한 충돌 회피 / zone별 max 인원 |
| ClaudePet 코드 라이브 변경 | 차용 코드 동기화 부담 | 차용 시점 명시 + 필요시만 갱신 |

## 의사결정 체크포인트

각 Phase 종료시 점검:
- ✅ 이대로 다음 단계 가도 되나?
- ✅ 우선순위 바꿔야 하나?
- ✅ 발견한 새 요구사항이 있나?
- ✅ 동료 피드백 받아야 하나?
- ✅ ClaudePet과의 차별화 충분한가?
