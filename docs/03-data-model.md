# 03. 데이터 모델

## ERD (관계도)

```
accounts ─┬─< account_links >─ users (Supabase Auth)
          │
          └─< devices ─┬─< sessions ─< turns
                       │
                       └─< device_status (1:1, 캐시)

achievements ─< user_achievements
```

## Supabase 테이블

### accounts

> Claude Code 계정 단위. 한 사람이 여러 계정 가질 수 있음 (.claude, .claude-alt 등).

```sql
CREATE TABLE accounts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    label           TEXT NOT NULL,         -- "메인", "사이드프로젝트" 등 사용자 지정
    color_hex       TEXT NOT NULL,         -- 시각화용 색상 (#FFB6C1 같은)
    config_dir_hint TEXT,                  -- ".claude-alt" 같은 힌트
    email           TEXT,                  -- Claude Code OAuth 이메일 (선택)
    created_at      TIMESTAMPTZ DEFAULT now()
);
```

### account_links

> 어떤 Supabase 사용자(나)가 어떤 account를 볼 수 있는지. RLS의 핵심.

```sql
CREATE TABLE account_links (
    user_id     UUID REFERENCES auth.users(id),
    account_id  UUID REFERENCES accounts(id) ON DELETE CASCADE,
    role        TEXT CHECK (role IN ('owner', 'viewer')),
    invited_by  UUID REFERENCES auth.users(id),
    created_at  TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (user_id, account_id)
);
```

### devices

> 한 account에 속한 물리적 머신.

```sql
CREATE TABLE devices (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id      UUID REFERENCES accounts(id) ON DELETE CASCADE,
    name            TEXT NOT NULL,             -- "맥북프로", "데스크탑"
    character_key   TEXT NOT NULL,             -- "cat", "dog", "fox"
    hostname        TEXT,                      -- 자동 감지값 (디버그용)
    os_version      TEXT,
    app_version     TEXT,
    last_seen_at    TIMESTAMPTZ,
    is_online       BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMPTZ DEFAULT now(),

    UNIQUE (account_id, name)
);
```

### sessions

> Claude Code의 한 세션 (JSONL 파일 하나).

```sql
CREATE TABLE sessions (
    id                UUID PRIMARY KEY,        -- Claude Code의 session_id 그대로
    device_id         UUID REFERENCES devices(id),
    account_id        UUID REFERENCES accounts(id),
    project_path      TEXT,                    -- "/Users/x/code/myapp"
    project_label     TEXT,                    -- 사용자 지정 별칭
    started_at        TIMESTAMPTZ NOT NULL,
    ended_at          TIMESTAMPTZ,
    last_turn_at      TIMESTAMPTZ,
    primary_model     TEXT,                    -- 주로 쓴 모델 (sonnet/opus)
    total_input       BIGINT DEFAULT 0,
    total_output      BIGINT DEFAULT 0,
    total_cache_read  BIGINT DEFAULT 0,
    total_cache_write BIGINT DEFAULT 0,
    turn_count        INT DEFAULT 0
);
```

### turns

> 사용자 ↔ 모델 한 번의 왕복 (JSONL의 한 라인 단위).

```sql
CREATE TABLE turns (
    id                  BIGSERIAL PRIMARY KEY,
    session_id          UUID REFERENCES sessions(id) ON DELETE CASCADE,
    turn_index          INT NOT NULL,
    timestamp           TIMESTAMPTZ NOT NULL,
    model               TEXT NOT NULL,           -- "claude-sonnet-4-5-20250929" 등
    input_tokens        INT NOT NULL,
    output_tokens       INT NOT NULL,
    cache_read_tokens   INT DEFAULT 0,
    cache_write_tokens  INT DEFAULT 0,
    tools_used          TEXT[],                  -- ["Read", "Edit", "Bash"]
    duration_ms         INT,                     -- 응답 받기까지

    UNIQUE (session_id, turn_index)              -- idempotent INSERT 보장
);

CREATE INDEX idx_turns_timestamp ON turns(timestamp DESC);
CREATE INDEX idx_turns_session ON turns(session_id, turn_index);
```

### device_status

> 캐시된 현재 상태 (UI 빠른 조회용). Realtime 구독 대상.

```sql
CREATE TABLE device_status (
    device_id              UUID PRIMARY KEY REFERENCES devices(id) ON DELETE CASCADE,
    mood                   TEXT NOT NULL,        -- "happy" | "working" | "sleepy" | ...
    speech_bubble          TEXT,                  -- "지금 코딩중!"
    current_session_id     UUID,
    current_session_tokens BIGINT DEFAULT 0,
    five_hour_used_tokens  BIGINT DEFAULT 0,
    weekly_opus_tokens     BIGINT DEFAULT 0,
    weekly_sonnet_tokens   BIGINT DEFAULT 0,
    cache_hit_rate         REAL,                  -- 0.0 ~ 1.0
    updated_at             TIMESTAMPTZ DEFAULT now()
);
```

### achievements & user_achievements

> 귀여움 강화용. Phase 1.5 이후.

```sql
CREATE TABLE achievements (
    key          TEXT PRIMARY KEY,           -- "cache_master", "streak_7d"
    title        TEXT NOT NULL,              -- "🏆 캐시 마스터"
    description  TEXT NOT NULL,
    icon         TEXT
);

CREATE TABLE user_achievements (
    account_id     UUID REFERENCES accounts(id),
    achievement_key TEXT REFERENCES achievements(key),
    unlocked_at    TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (account_id, achievement_key)
);
```

## RLS (Row Level Security) 정책

핵심 원칙: **사용자는 자기에게 link 된 account의 데이터만 read 가능. write는 owner만.**

```sql
-- accounts: read는 link 있을 때만
CREATE POLICY accounts_read ON accounts FOR SELECT
USING (id IN (SELECT account_id FROM account_links WHERE user_id = auth.uid()));

-- devices, sessions, turns 도 같은 패턴
CREATE POLICY devices_read ON devices FOR SELECT
USING (account_id IN (SELECT account_id FROM account_links WHERE user_id = auth.uid()));

-- write는 owner role만
CREATE POLICY devices_write ON devices FOR INSERT
WITH CHECK (account_id IN (
    SELECT account_id FROM account_links
    WHERE user_id = auth.uid() AND role = 'owner'
));
```

## 로컬 SQLite 미러

> Supabase 동일 스키마 + 동기화 보조 테이블.

```sql
-- 동기화 큐 (오프라인 대응)
CREATE TABLE sync_queue (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    table_name   TEXT NOT NULL,
    operation    TEXT NOT NULL,    -- 'insert' | 'update'
    payload      JSON NOT NULL,
    attempt_count INT DEFAULT 0,
    last_error   TEXT,
    created_at   DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 파일 워처 진행 상황
CREATE TABLE jsonl_cursors (
    file_path    TEXT PRIMARY KEY,
    last_offset  INTEGER NOT NULL,
    last_mtime   INTEGER NOT NULL,    -- 파일 mtime 변동 감지용
    last_synced  DATETIME
);
```

## 도메인 계산 로직

### 5h 윈도우 사용량

```
SELECT SUM(input_tokens + output_tokens)
FROM turns
WHERE account_id = ?
  AND timestamp > now() - interval '5 hours';
```

### 주간 모델별 사용량

```
SELECT model, SUM(input_tokens + output_tokens) AS total
FROM turns
WHERE account_id = ?
  AND timestamp >= date_trunc('week', now())
GROUP BY model;
```

### 캐시 효율

```
cache_hit_rate = cache_read / (cache_read + input)
```

낮으면 (e.g. < 30%) "/clear 권장" 신호.

### 디바이스 mood 결정 함수 (의사코드)

```swift
func computeMood(device: Device) -> Mood {
    if !device.isOnline { return .offline }
    if device.lastActiveAt < now() - 30.minutes { return .sleepy }
    if device.currentSessionActive { return .working }
    if fiveHourUsage > 0.85 { return .stressed }
    if cacheHitRate < 0.3 && currentSessionTokens > 50_000 { return .confused }
    return .happy
}
```

## 인덱스 전략

```sql
-- 시간 범위 쿼리 (대시보드)
CREATE INDEX idx_turns_account_time ON turns (account_id, timestamp DESC);

-- 디바이스별 최근 활동
CREATE INDEX idx_sessions_device_recent ON sessions (device_id, last_turn_at DESC);

-- 모델별 집계
CREATE INDEX idx_turns_model_time ON turns (model, timestamp);
```

## 데이터 양 추정

가정: 하루 100세션 × 20턴 = 2000 turns/day, 디바이스 3대 → 6000 turns/day/계정

- 1 turn ≈ 200 bytes (raw)
- 일일: ~1.2 MB
- 월간: ~36 MB
- 연간: ~430 MB

→ Supabase 무료 티어 (500MB) 안에서 1년 수용 가능. 구버전 압축/요약 정책으로 더 늘림.

## 마이그레이션 / 백필

기존 JSONL이 이미 잔뜩 쌓여 있음. 첫 실행시:
1. 모든 `~/.claude*/projects/**/*.jsonl` 스캔
2. 배치로 sessions/turns INSERT (idempotent하게)
3. 진행률 표시 — 사용자에게 "백필 중... 진행률"
