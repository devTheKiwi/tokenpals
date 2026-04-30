// Codable structs matching Supabase tables.
// snake_case 컬럼명 → camelCase 매핑 (CodingKeys).

import Foundation

struct AccountRow: Codable {
    let id: String
    let label: String
    let colorHex: String?
    let configDirHint: String?

    enum CodingKeys: String, CodingKey {
        case id
        case label
        case colorHex = "color_hex"
        case configDirHint = "config_dir_hint"
    }
}

struct AccountLinkRow: Codable {
    let userId: String
    let accountId: String
    let role: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case accountId = "account_id"
        case role
    }
}

struct DeviceRow: Codable {
    let id: String
    let accountId: String
    let name: String
    let colorIndex: Int
    let hostname: String?
    let osVersion: String?
    let appVersion: String?
    let lastSeenAt: String?
    let isOnline: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case name
        case colorIndex = "color_index"
        case hostname
        case osVersion = "os_version"
        case appVersion = "app_version"
        case lastSeenAt = "last_seen_at"
        case isOnline = "is_online"
    }
}

// 미리 정의 — sync 단계(Phase 2.4)에서 사용 예정.
struct SessionRow: Codable {
    let id: String
    let deviceId: String
    let accountId: String
    let projectPath: String?
    let projectLabel: String?
    let startedAt: String
    let lastTurnAt: String?
    let primaryModel: String?
    let totalInput: Int
    let totalOutput: Int
    let totalCacheRead: Int
    let totalCacheWrite: Int
    let turnCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case deviceId = "device_id"
        case accountId = "account_id"
        case projectPath = "project_path"
        case projectLabel = "project_label"
        case startedAt = "started_at"
        case lastTurnAt = "last_turn_at"
        case primaryModel = "primary_model"
        case totalInput = "total_input"
        case totalOutput = "total_output"
        case totalCacheRead = "total_cache_read"
        case totalCacheWrite = "total_cache_write"
        case turnCount = "turn_count"
    }
}

struct TurnRow: Codable {
    let id: Int?
    let sessionId: String
    let accountId: String
    let turnIndex: Int
    let timestamp: String
    let model: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheReadTokens: Int
    let cacheWriteTokens: Int

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case accountId = "account_id"
        case turnIndex = "turn_index"
        case timestamp
        case model
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheReadTokens = "cache_read_tokens"
        case cacheWriteTokens = "cache_write_tokens"
    }
}
