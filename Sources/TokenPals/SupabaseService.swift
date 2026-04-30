// Thin wrapper around the Supabase Swift client.
// Phase 2.1: 클라이언트 초기화 + 연결 검증만. 인증/스키마/sync는 다음 단계.

import Foundation
import Supabase

class SupabaseService {
    let client: SupabaseClient

    init() {
        guard let url = URL(string: SupabaseConfig.url) else {
            fatalError("[TokenPals] SupabaseConfig.url 잘못됨: \(SupabaseConfig.url)")
        }
        self.client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: SupabaseConfig.publishableKey
        )
    }

    /// 연결 검증용 — 인증 상태 확인. 미로그인이면 nil 반환.
    /// (오류는 일반적이라 throw 안 함, 로그만)
    func currentSessionEmail() async -> String? {
        do {
            let session = try await client.auth.session
            return session.user.email
        } catch {
            return nil
        }
    }
}
