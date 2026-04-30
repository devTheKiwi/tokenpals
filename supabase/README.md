# Supabase 설정

## 마이그레이션 실행 방법

1. Supabase Dashboard → 좌측 메뉴 **"SQL Editor"**
2. **"New query"** 클릭
3. `migrations/0001_initial_schema.sql` 전체 복사 → 붙여넣기
4. **"Run"** (또는 ⌘ Enter) 클릭
5. "Success. No rows returned." 메시지 확인

## 스키마 요약

| 테이블 | 용도 |
|---|---|
| `accounts` | Claude 계정 단위 (Phase 1: 사용자당 1개) |
| `account_links` | 사용자 ↔ 계정 연결 (RLS의 핵심) |
| `devices` | 물리적 머신 (한 계정에 여러 device 가능) |
| `sessions` | Claude Code 세션 (JSONL 파일 1개 = sessions row 1개) |
| `turns` | 사용자 ↔ 모델 한 번의 왕복 (JSONL 라인 1개 = turns row 1개) |
| `device_status` | 디바이스 현재 상태 (Realtime 구독 대상) |

## RLS 원칙

- 사용자는 본인에게 link 된 account의 데이터만 read 가능
- write는 owner role만 가능
- 동료 초대 (Phase 3+) 시 viewer role로 link → read-only 공유

## 재실행 주의

이 SQL은 **한 번만** 실행. 두 번 실행하면 정책 충돌 에러 발생.

테스트 중 초기화 필요시:
- 모든 테이블 DROP (각 정책도 자동 삭제됨)
- 또는 새 Supabase 프로젝트 생성
