// Email OTP authentication via Supabase.
// Phase 2.2: 로그인 흐름. 비밀번호 없이 이메일 + 6자리 코드.

import Foundation
import Supabase
import Auth

class AuthManager {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    /// 입력된 이메일로 6자리 인증 코드 발송. shouldCreateUser=true 라 신규 사용자도 생성됨.
    func sendOTP(email: String) async throws {
        try await client.auth.signInWithOTP(email: email, shouldCreateUser: true)
    }

    /// 이메일 + 코드 검증. 성공시 세션 자동 저장 (SDK가 Keychain에 보관).
    @discardableResult
    func verifyOTP(email: String, code: String) async throws -> User {
        let response = try await client.auth.verifyOTP(
            email: email,
            token: code,
            type: .email
        )
        return response.user
    }

    /// 로그아웃. 세션 토큰 폐기.
    func signOut() async throws {
        try await client.auth.signOut()
    }

    /// 현재 로그인된 사용자 (sync, 캐시된 세션 기반).
    var currentUserEmail: String? {
        return client.auth.currentSession?.user.email
    }

    var isAuthenticated: Bool {
        return client.auth.currentSession != nil
    }
}
