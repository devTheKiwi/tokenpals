// First-run setup: ensure account + account_link + device exist for current user.
// Phase 2.3: registration only. Sync는 Phase 2.4.

import Foundation
import Supabase

struct LocalDeviceInfo {
    let id: String
    let accountId: String
    let name: String
    let colorIndex: Int
}

enum DeviceManagerError: Error, LocalizedError {
    case notAuthenticated
    case accountCreationFailed
    case deviceCreationFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "로그인이 필요합니다."
        case .accountCreationFailed: return "계정 생성 실패"
        case .deviceCreationFailed: return "디바이스 등록 실패"
        }
    }
}

class DeviceManager {
    private let client: SupabaseClient
    private let deviceIdKey = "tokenpals.device.id"

    init(client: SupabaseClient) {
        self.client = client
    }

    private var localDeviceId: String? {
        get { UserDefaults.standard.string(forKey: deviceIdKey) }
        set { UserDefaults.standard.set(newValue, forKey: deviceIdKey) }
    }

    /// 로그인된 상태에서 호출. account/account_link/device 자동 생성/조회.
    /// 결과: 이 머신을 대표하는 LocalDeviceInfo.
    func ensureSetup() async throws -> LocalDeviceInfo {
        guard client.auth.currentSession != nil else {
            throw DeviceManagerError.notAuthenticated
        }
        let accountId = try await ensureAccount()
        return try await ensureDevice(accountId: accountId)
    }

    /// 계정의 모든 디바이스 조회 (Phase 2.5: 다중 펫).
    func allDevices(accountId: String) async throws -> [LocalDeviceInfo] {
        let rows: [DeviceRow] = try await client
            .from("devices")
            .select()
            .eq("account_id", value: accountId)
            .execute()
            .value

        return rows.map { row in
            LocalDeviceInfo(
                id: row.id,
                accountId: row.accountId,
                name: row.name,
                colorIndex: row.colorIndex
            )
        }
    }

    // MARK: - Account

    private func ensureAccount() async throws -> String {
        // 본인 account_link 조회.
        // 트리거(on_auth_user_created)가 가입시 자동으로 account + link 생성하므로
        // 정상 가입된 사용자는 항상 1개 이상 link 보유.
        let links: [AccountLinkRow] = try await client
            .from("account_links")
            .select()
            .execute()
            .value

        guard let link = links.first else {
            // 트리거 못 동작했거나 backfill 누락 — 운영상 거의 발생 X
            throw DeviceManagerError.accountCreationFailed
        }
        return link.accountId
    }

    // MARK: - Device

    private func ensureDevice(accountId: String) async throws -> LocalDeviceInfo {
        // 로컬 device_id가 있으면 그걸로 fetch
        if let storedId = localDeviceId {
            let rows: [DeviceRow] = try await client
                .from("devices")
                .select()
                .eq("id", value: storedId)
                .execute()
                .value

            if let row = rows.first {
                return LocalDeviceInfo(
                    id: row.id,
                    accountId: row.accountId,
                    name: row.name,
                    colorIndex: row.colorIndex
                )
            }
            // device_id 있는데 row 없음 (다른 머신/삭제됨) → 새로 생성
        }

        // 새 device 생성
        let name = Host.current().localizedName ?? (L10n.isKorean ? "이 맥" : "This Mac")
        let colorIndex = abs(name.utf8.reduce(0) { Int($0) + Int($1) }) % PetColor.palette.count
        let hostname = ProcessInfo.processInfo.hostName
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString

        struct DeviceInsert: Encodable {
            let account_id: String
            let name: String
            let color_index: Int
            let hostname: String
            let os_version: String
        }
        let inserted: [DeviceRow] = try await client
            .from("devices")
            .insert(DeviceInsert(
                account_id: accountId,
                name: name,
                color_index: colorIndex,
                hostname: hostname,
                os_version: osVersion
            ))
            .select()
            .execute()
            .value

        guard let row = inserted.first else {
            throw DeviceManagerError.deviceCreationFailed
        }

        localDeviceId = row.id

        return LocalDeviceInfo(
            id: row.id,
            accountId: row.accountId,
            name: row.name,
            colorIndex: row.colorIndex
        )
    }
}
