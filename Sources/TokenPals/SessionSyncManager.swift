// SessionSyncManager: JSONL 파일을 읽어 Supabase sessions/turns 테이블에 동기화.
// Phase 2.4: 각 세션의 턴을 DB에 저장. 오프라인 대비 로컬 큐 예정.

import Foundation
import Supabase

class SessionSyncManager {
    private let client: SupabaseClient
    private let tokenTracker: TokenTracker
    private let deviceId: String
    private let accountId: String
    private var syncTimer: Timer?
    private var lastSyncedSessionIds: Set<String> = []

    init(client: SupabaseClient, tokenTracker: TokenTracker, deviceId: String, accountId: String) {
        self.client = client
        self.tokenTracker = tokenTracker
        self.deviceId = deviceId
        self.accountId = accountId
    }

    /// 시작 — 60초마다 새 세션 동기화.
    func start() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task {
                await self?.syncNewSessions()
            }
        }
        NSLog("[TokenPals] SessionSyncManager 시작")
    }

    func stop() {
        syncTimer?.invalidate()
        syncTimer = nil
        NSLog("[TokenPals] SessionSyncManager 중지")
    }

    /// 새로운 세션만 동기화 (중복 방지).
    private func syncNewSessions() async {
        let fm = FileManager.default

        // 모든 프로젝트 폴더의 JSONL 파일 스캔
        for base in tokenTracker.claudeProjectsDirs {
            guard let projectDirs = try? fm.contentsOfDirectory(atPath: base) else { continue }

            for projectDir in projectDirs {
                let jsonlPath = "\(base)/\(projectDir)"
                guard let files = try? fm.contentsOfDirectory(atPath: jsonlPath) else { continue }

                for file in files where file.hasSuffix(".jsonl") {
                    let sessionId = file.replacingOccurrences(of: ".jsonl", with: "")

                    // 이미 동기화된 세션은 스킵
                    guard !lastSyncedSessionIds.contains(sessionId) else { continue }

                    let fullPath = "\(jsonlPath)/\(file)"
                    await syncSessionFile(sessionId: sessionId, filePath: fullPath)
                    lastSyncedSessionIds.insert(sessionId)
                }
            }
        }
    }

    /// 단일 JSONL 파일의 세션/턴 동기화.
    private func syncSessionFile(sessionId: String, filePath: String) async {
        let fm = FileManager.default
        guard let fileData = fm.contents(atPath: filePath),
              let content = String(data: fileData, encoding: .utf8) else {
            NSLog("[TokenPals] JSONL 파일 읽기 실패: \(filePath)")
            return
        }

        var turns: [(index: Int, timestamp: String, model: String, inputTokens: Int, outputTokens: Int, cacheReadTokens: Int, cacheWriteTokens: Int)] = []
        var startedAt: String?
        var lastTurnAt: String?
        var primaryModel: String?
        var totalInput = 0, totalOutput = 0, totalCacheRead = 0, totalCacheWrite = 0, turnCount = 0

        // JSONL 파싱
        for (lineIndex, line) in content.components(separatedBy: "\n").enumerated() where !line.isEmpty {
            guard let jsonData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let message = json["message"] as? [String: Any],
                  let usage = message["usage"] as? [String: Any] else {
                continue
            }

            guard let timestamp = json["timestamp"] as? String,
                  let model = message["model"] as? String else {
                continue
            }

            let inputTokens = usage["input_tokens"] as? Int ?? 0
            let outputTokens = usage["output_tokens"] as? Int ?? 0
            let cacheReadTokens = usage["cache_read_input_tokens"] as? Int ?? 0
            let cacheWriteTokens = usage["cache_creation_input_tokens"] as? Int ?? 0

            if startedAt == nil {
                startedAt = timestamp
            }
            lastTurnAt = timestamp
            primaryModel = model
            totalInput += inputTokens
            totalOutput += outputTokens
            totalCacheRead += cacheReadTokens
            totalCacheWrite += cacheWriteTokens
            turnCount += 1

            turns.append((
                index: lineIndex,
                timestamp: timestamp,
                model: model,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                cacheReadTokens: cacheReadTokens,
                cacheWriteTokens: cacheWriteTokens
            ))
        }

        guard !turns.isEmpty, let startedAt = startedAt else {
            NSLog("[TokenPals] JSONL 파싱 완료 (턴 0개): \(sessionId)")
            return
        }

        // sessions 테이블에 INSERT/UPDATE
        do {
            struct SessionInsert: Encodable {
                let id: String
                let device_id: String
                let account_id: String
                let started_at: String
                let last_turn_at: String?
                let primary_model: String?
                let total_input: Int
                let total_output: Int
                let total_cache_read: Int
                let total_cache_write: Int
                let turn_count: Int
            }

            let session = SessionInsert(
                id: sessionId,
                device_id: deviceId,
                account_id: accountId,
                started_at: startedAt,
                last_turn_at: lastTurnAt,
                primary_model: primaryModel,
                total_input: totalInput,
                total_output: totalOutput,
                total_cache_read: totalCacheRead,
                total_cache_write: totalCacheWrite,
                turn_count: turnCount
            )

            try await client
                .from("sessions")
                .upsert([session])
                .execute()

            NSLog("[TokenPals] session 저장: \(sessionId) (\(turnCount) turns)")
        } catch {
            NSLog("[TokenPals] session 저장 실패: \(error.localizedDescription)")
            return
        }

        // turns 테이블에 INSERT (idempotent: session_id + turn_index 유니크)
        do {
            struct TurnInsert: Encodable {
                let session_id: String
                let account_id: String
                let turn_index: Int
                let timestamp: String
                let model: String
                let input_tokens: Int
                let output_tokens: Int
                let cache_read_tokens: Int
                let cache_write_tokens: Int
            }

            var turnsToInsert: [TurnInsert] = []
            for turn in turns {
                turnsToInsert.append(TurnInsert(
                    session_id: sessionId,
                    account_id: accountId,
                    turn_index: turn.index,
                    timestamp: turn.timestamp,
                    model: turn.model,
                    input_tokens: turn.inputTokens,
                    output_tokens: turn.outputTokens,
                    cache_read_tokens: turn.cacheReadTokens,
                    cache_write_tokens: turn.cacheWriteTokens
                ))
            }

            try await client
                .from("turns")
                .upsert(turnsToInsert)
                .execute()

            NSLog("[TokenPals] \(turns.count)개 turn 저장 완료: \(sessionId)")
        } catch {
            NSLog("[TokenPals] turn 저장 실패: \(error.localizedDescription)")
        }
    }
}
