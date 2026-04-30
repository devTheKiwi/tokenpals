-- TokenPals 초기 스키마
-- Supabase Dashboard → SQL Editor 에 전체 붙여넣고 한 번 실행.
-- (재실행 X — 정책 충돌 발생 가능)

-- ============================================================
-- 1. 테이블
-- ============================================================

-- 계정 (Claude 계정 단위)
CREATE TABLE accounts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    label           TEXT NOT NULL DEFAULT '메인',
    color_hex       TEXT,
    config_dir_hint TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 사용자 ↔ 계정 연결 (RLS의 핵심)
CREATE TABLE account_links (
    user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    account_id  UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    role        TEXT NOT NULL DEFAULT 'owner' CHECK (role IN ('owner', 'viewer')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, account_id)
);

-- 디바이스 (한 계정의 한 머신)
CREATE TABLE devices (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id    UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    name          TEXT NOT NULL,
    color_index   INT NOT NULL DEFAULT 0,
    hostname      TEXT,
    os_version    TEXT,
    app_version   TEXT,
    last_seen_at  TIMESTAMPTZ,
    is_online     BOOLEAN NOT NULL DEFAULT FALSE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(account_id, hostname)  -- Phase 2.6: 중복 디바이스 생성 방지
);

-- 디바이스 조회 인덱스
CREATE INDEX idx_devices_account_hostname ON devices(account_id, hostname);

-- 세션 (Claude Code의 한 JSONL 파일 단위)
CREATE TABLE sessions (
    id                UUID PRIMARY KEY,
    device_id         UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    account_id        UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    project_path      TEXT,
    project_label     TEXT,
    started_at        TIMESTAMPTZ NOT NULL,
    last_turn_at      TIMESTAMPTZ,
    primary_model     TEXT,
    total_input       BIGINT NOT NULL DEFAULT 0,
    total_output      BIGINT NOT NULL DEFAULT 0,
    total_cache_read  BIGINT NOT NULL DEFAULT 0,
    total_cache_write BIGINT NOT NULL DEFAULT 0,
    turn_count        INT NOT NULL DEFAULT 0
);

-- 턴 (한 사용자 ↔ 모델 왕복)
CREATE TABLE turns (
    id                  BIGSERIAL PRIMARY KEY,
    session_id          UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    account_id          UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    turn_index          INT NOT NULL,
    timestamp           TIMESTAMPTZ NOT NULL,
    model               TEXT NOT NULL,
    input_tokens        INT NOT NULL DEFAULT 0,
    output_tokens       INT NOT NULL DEFAULT 0,
    cache_read_tokens   INT NOT NULL DEFAULT 0,
    cache_write_tokens  INT NOT NULL DEFAULT 0,
    UNIQUE (session_id, turn_index)
);

-- 디바이스 현재 상태 (Realtime 구독 대상, 캐시)
CREATE TABLE device_status (
    device_id                  UUID PRIMARY KEY REFERENCES devices(id) ON DELETE CASCADE,
    mood                       TEXT,
    speech_bubble              TEXT,
    current_session_id         UUID,
    current_session_tokens     BIGINT NOT NULL DEFAULT 0,
    five_hour_total_tokens     BIGINT NOT NULL DEFAULT 0,
    five_hour_billable_tokens  BIGINT NOT NULL DEFAULT 0,
    cache_hit_rate             REAL,
    updated_at                 TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- 2. 인덱스
-- ============================================================

CREATE INDEX idx_turns_account_time   ON turns(account_id, timestamp DESC);
CREATE INDEX idx_turns_session        ON turns(session_id, turn_index);
CREATE INDEX idx_sessions_device_recent ON sessions(device_id, last_turn_at DESC);
CREATE INDEX idx_devices_account      ON devices(account_id);
CREATE INDEX idx_account_links_user   ON account_links(user_id);

-- ============================================================
-- 3. RLS 활성화
-- ============================================================

ALTER TABLE accounts        ENABLE ROW LEVEL SECURITY;
ALTER TABLE account_links   ENABLE ROW LEVEL SECURITY;
ALTER TABLE devices         ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions        ENABLE ROW LEVEL SECURITY;
ALTER TABLE turns           ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_status   ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 4. RLS 정책
-- 원칙: 사용자는 자기에게 link 된 account의 데이터만 read.
--       write는 owner role만.
-- ============================================================

-- accounts
CREATE POLICY accounts_read ON accounts FOR SELECT
    USING (id IN (SELECT account_id FROM account_links WHERE user_id = auth.uid()));

-- INSERT는 trigger(handle_new_user)에서 SECURITY DEFINER로 자동 처리.
-- 클라이언트는 직접 accounts INSERT 안 하므로 정책 불필요.

CREATE POLICY accounts_update ON accounts FOR UPDATE
    USING (id IN (SELECT account_id FROM account_links WHERE user_id = auth.uid() AND role = 'owner'));

-- account_links (본인 거만)
CREATE POLICY account_links_read ON account_links FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY account_links_insert ON account_links FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY account_links_delete ON account_links FOR DELETE
    USING (user_id = auth.uid());

-- devices
CREATE POLICY devices_read ON devices FOR SELECT
    USING (account_id IN (SELECT account_id FROM account_links WHERE user_id = auth.uid()));

CREATE POLICY devices_write ON devices FOR ALL
    USING (account_id IN (
        SELECT account_id FROM account_links
        WHERE user_id = auth.uid() AND role = 'owner'
    ))
    WITH CHECK (account_id IN (
        SELECT account_id FROM account_links
        WHERE user_id = auth.uid() AND role = 'owner'
    ));

-- sessions
CREATE POLICY sessions_read ON sessions FOR SELECT
    USING (account_id IN (SELECT account_id FROM account_links WHERE user_id = auth.uid()));

CREATE POLICY sessions_write ON sessions FOR ALL
    USING (account_id IN (
        SELECT account_id FROM account_links
        WHERE user_id = auth.uid() AND role = 'owner'
    ))
    WITH CHECK (account_id IN (
        SELECT account_id FROM account_links
        WHERE user_id = auth.uid() AND role = 'owner'
    ));

-- turns
CREATE POLICY turns_read ON turns FOR SELECT
    USING (account_id IN (SELECT account_id FROM account_links WHERE user_id = auth.uid()));

CREATE POLICY turns_write ON turns FOR ALL
    USING (account_id IN (
        SELECT account_id FROM account_links
        WHERE user_id = auth.uid() AND role = 'owner'
    ))
    WITH CHECK (account_id IN (
        SELECT account_id FROM account_links
        WHERE user_id = auth.uid() AND role = 'owner'
    ));

-- device_status
CREATE POLICY device_status_read ON device_status FOR SELECT
    USING (device_id IN (
        SELECT id FROM devices
        WHERE account_id IN (SELECT account_id FROM account_links WHERE user_id = auth.uid())
    ));

CREATE POLICY device_status_write ON device_status FOR ALL
    USING (device_id IN (
        SELECT id FROM devices
        WHERE account_id IN (
            SELECT account_id FROM account_links
            WHERE user_id = auth.uid() AND role = 'owner'
        )
    ))
    WITH CHECK (device_id IN (
        SELECT id FROM devices
        WHERE account_id IN (
            SELECT account_id FROM account_links
            WHERE user_id = auth.uid() AND role = 'owner'
        )
    ));

-- ============================================================
-- 5. 신규 사용자 가입시 자동 account+link 생성 트리거
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $func$
DECLARE
    v_account_id uuid;
BEGIN
    INSERT INTO public.accounts (label) VALUES ('메인') RETURNING id INTO v_account_id;
    INSERT INTO public.account_links (user_id, account_id, role)
    VALUES (NEW.id, v_account_id, 'owner');
    RETURN NEW;
END;
$func$;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
