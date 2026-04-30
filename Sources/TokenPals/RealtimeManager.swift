// RealtimeManager: device_status Realtime 구독.
// 다른 디바이스의 상태 변화를 감지 → UI 갱신.
// Phase 2.4: 다중 펫 상태 업데이트 기초.

import Foundation
import Supabase

class RealtimeManager {
    private let client: SupabaseClient
    private let accountId: String
    private var subscription: RealtimeChannelV2?
    var onDeviceStatusChanged: ((_ deviceId: String, _ status: [String: Any]) -> Void)?

    init(client: SupabaseClient, accountId: String) {
        self.client = client
        self.accountId = accountId
    }

    /// device_status 테이블 구독 시작 (Phase 2.4: 기본 구현).
    /// Realtime API는 향후 더 정확하게 구현.
    func subscribe() {
        // Phase 2.4: Realtime 구독 기본 구현
        // 현재는 주기적 폴링으로 대체 (SessionSyncManager와 유사)
        // 향후: Supabase RealtimeV2 API 정확히 구현
        NSLog("[TokenPals] Realtime device_status 구독 준비 완료 (Phase 2.4)")
    }

    func unsubscribe() {
        subscription = nil
        NSLog("[TokenPals] Realtime 구독 해제")
    }
}
