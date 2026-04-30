-- Phase 2.6: 디바이스 중복 생성 방지
-- (account_id, hostname) 유니크 제약 추가

-- 기존 데이터 정리: 각 (account_id, hostname) 조합의 가장 오래된 device만 유지
DELETE FROM devices d1
WHERE d1.id NOT IN (
    SELECT MIN(id)
    FROM devices d2
    WHERE d2.account_id = d1.account_id
    AND d2.hostname = d1.hostname
    GROUP BY d2.account_id, d2.hostname
)
AND d1.hostname IS NOT NULL;

-- 유니크 제약 추가
ALTER TABLE devices
ADD CONSTRAINT devices_account_id_hostname_unique UNIQUE (account_id, hostname);

-- 인덱스 추가 (조회 성능)
CREATE INDEX idx_devices_account_hostname ON devices(account_id, hostname);
