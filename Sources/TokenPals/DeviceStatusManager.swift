// Heartbeat: device_status 테이블을 30초마다 업데이트.
// mood, tokens, cache_hit_rate, last_seen_at 저장.

import Foundation
import Supabase

class DeviceStatusManager {
    private let client: SupabaseClient
    private var deviceId: String
    private var accountId: String
    private var heartbeatTimer: Timer?

    init(client: SupabaseClient, deviceId: String, accountId: String) {
        self.client = client
        self.deviceId = deviceId
        self.accountId = accountId
    }

    /// 시작 — 30초마다 heartbeat.
    func start() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task {
                await self?.sendHeartbeat()
            }
        }
        NSLog("[TokenPals] DeviceStatusManager 시작")
    }

    func stop() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        NSLog("[TokenPals] DeviceStatusManager 중지")
    }

    /// device_status 업데이트 (현재 상태).
    func updateStatus(mood: String, fiveHourTokens: Int, cacheHitRate: Double, currentSessionTokens: Int = 0) async {
        do {
            struct StatusUpdate: Encodable {
                let mood: String
                let five_hour_total_tokens: Int
                let five_hour_billable_tokens: Int  // Phase 2.4: 캐시 read 제외
                let cache_hit_rate: Double
                let current_session_tokens: Int
                let updated_at: String
            }

            let now = ISO8601DateFormatter().string(from: Date())
            let update = StatusUpdate(
                mood: mood,
                five_hour_total_tokens: fiveHourTokens,
                five_hour_billable_tokens: fiveHourTokens,  // 임시 (추후 정확히 계산)
                cache_hit_rate: cacheHitRate,
                current_session_tokens: currentSessionTokens,
                updated_at: now
            )

            try await client
                .from("device_status")
                .upsert([update])
                .eq("device_id", value: deviceId)
                .execute()

            NSLog("[TokenPals] device_status 업데이트: mood=\(mood), tokens=\(fiveHourTokens), cache=\(String(format: "%.0f%%", cacheHitRate * 100))")
        } catch {
            NSLog("[TokenPals] device_status 업데이트 실패: \(error.localizedDescription)")
        }
    }

    /// 30초 heartbeat — last_seen_at 갱신.
    private func sendHeartbeat() async {
        do {
            struct Heartbeat: Encodable {
                let updated_at: String
            }

            let now = ISO8601DateFormatter().string(from: Date())
            try await client
                .from("device_status")
                .update(Heartbeat(updated_at: now))
                .eq("device_id", value: deviceId)
                .execute()

            NSLog("[TokenPals] Heartbeat 전송")
        } catch {
            NSLog("[TokenPals] Heartbeat 전송 실패: \(error.localizedDescription)")
        }
    }
}
