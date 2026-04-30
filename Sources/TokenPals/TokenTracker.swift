// JSONL token usage parser.
// Adapted from ClaudePet's TokenTracker (https://github.com/devTheKiwi/ClaudePet) MIT.
// Key change: scans all `~/.claude*` directories (multi-account support).

import Foundation

struct TokenUsage {
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheCreationTokens: Int = 0
    var cacheReadTokens: Int = 0

    var totalTokens: Int { inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens }

    /// 실제 청구되는 토큰 (캐시 read 제외) — 한도 추정에 사용.
    var billableTokens: Int { inputTokens + outputTokens + cacheCreationTokens }

    static func formatTokens(_ count: Int) -> String {
        if count < 1000 {
            return "\(count)"
        } else if count < 1_000_000 {
            let k = Double(count) / 1000.0
            return String(format: "%.1fK", k)
        } else {
            let m = Double(count) / 1_000_000.0
            return String(format: "%.1fM", m)
        }
    }
}

class TokenTracker {
    /// 추적 대상 projects 경로들.
    /// Phase 1: `~/.claude/projects` 단일 계정만. 멀티 계정은 Phase 2+에서 확장.
    let claudeProjectsDirs: [String]

    init() {
        self.claudeProjectsDirs = TokenTracker.primaryProjectDirs()
    }

    /// 주 계정 (~/.claude/projects) 만 반환.
    /// 다른 `.claude*` 폴더들은 향후 멀티 계정 기능에서 다룸.
    static func primaryProjectDirs() -> [String] {
        let home = NSHomeDirectory()
        let primary = "\(home)/.claude/projects"
        let fm = FileManager.default
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: primary, isDirectory: &isDir), isDir.boolValue {
            return [primary]
        }
        return []
    }

    /// (Phase 2+ 멀티 계정용) `~/.claude*` 패턴 모든 폴더 탐색.
    /// 현재 미사용 — primaryProjectDirs() 가 대신 호출됨.
    static func discoverClaudeProjectDirs() -> [String] {
        let home = NSHomeDirectory()
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: home) else {
            return []
        }

        var found: [String] = []
        for entry in entries {
            guard entry.hasPrefix(".claude") else { continue }
            let projectsPath = "\(home)/\(entry)/projects"
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: projectsPath, isDirectory: &isDir), isDir.boolValue {
                found.append(projectsPath)
            }
        }
        return found
    }

    /// 특정 세션의 토큰 사용량 (모든 등록 폴더 검색)
    func usageForSession(_ sessionId: String) -> TokenUsage {
        let fm = FileManager.default
        for base in claudeProjectsDirs {
            guard let projectDirs = try? fm.contentsOfDirectory(atPath: base) else { continue }
            for dir in projectDirs {
                let jsonlPath = "\(base)/\(dir)/\(sessionId).jsonl"
                if fm.fileExists(atPath: jsonlPath) {
                    return parseJSONL(at: jsonlPath)
                }
            }
        }
        return TokenUsage()
    }

    /// 세션의 모델명 감지
    func modelForSession(_ sessionId: String) -> String? {
        let fm = FileManager.default
        for base in claudeProjectsDirs {
            guard let projectDirs = try? fm.contentsOfDirectory(atPath: base) else { continue }
            for dir in projectDirs {
                let jsonlPath = "\(base)/\(dir)/\(sessionId).jsonl"
                guard fm.fileExists(atPath: jsonlPath),
                      let data = fm.contents(atPath: jsonlPath),
                      let content = String(data: data, encoding: .utf8) else { continue }
                for line in content.components(separatedBy: "\n").reversed() {
                    if line.contains("\"model\""),
                       let lineData = line.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                       let message = json["message"] as? [String: Any],
                       let model = message["model"] as? String {
                        return model
                    }
                }
            }
        }
        return nil
    }

    /// 오늘 전체 토큰 사용량 (모든 등록 폴더 합산)
    func todayUsage() -> TokenUsage {
        let fm = FileManager.default
        var total = TokenUsage()
        let today = Calendar.current.startOfDay(for: Date())

        for base in claudeProjectsDirs {
            guard let projectDirs = try? fm.contentsOfDirectory(atPath: base) else { continue }
            for dir in projectDirs {
                let projectPath = "\(base)/\(dir)"
                guard let files = try? fm.contentsOfDirectory(atPath: projectPath) else { continue }

                for file in files {
                    guard file.hasSuffix(".jsonl") else { continue }
                    let filePath = "\(projectPath)/\(file)"

                    if let attrs = try? fm.attributesOfItem(atPath: filePath),
                       let modDate = attrs[.modificationDate] as? Date,
                       modDate >= today {
                        let usage = parseJSONL(at: filePath)
                        total.inputTokens += usage.inputTokens
                        total.outputTokens += usage.outputTokens
                        total.cacheCreationTokens += usage.cacheCreationTokens
                        total.cacheReadTokens += usage.cacheReadTokens
                    }
                }
            }
        }

        return total
    }

    /// 최근 N초 이내 사용량 (line timestamp 기반)
    func usageInLast(seconds: TimeInterval) -> TokenUsage {
        let cutoff = Date().addingTimeInterval(-seconds)
        return parseAllJSONLs(filterFrom: cutoff)
    }

    /// 가장 최근 활동 시각 (모든 JSONL 라인의 가장 큰 timestamp)
    func lastActivityDate() -> Date? {
        var latest: Date?
        let formatter = TokenTracker.timestampFormatter
        let fm = FileManager.default

        for base in claudeProjectsDirs {
            guard let projectDirs = try? fm.contentsOfDirectory(atPath: base) else { continue }
            for dir in projectDirs {
                let projectPath = "\(base)/\(dir)"
                guard let files = try? fm.contentsOfDirectory(atPath: projectPath) else { continue }
                for file in files {
                    guard file.hasSuffix(".jsonl") else { continue }
                    let filePath = "\(projectPath)/\(file)"

                    // mtime이 latest보다 오래된 파일은 스킵
                    guard let attrs = try? fm.attributesOfItem(atPath: filePath),
                          let modDate = attrs[.modificationDate] as? Date else { continue }
                    if let cur = latest, modDate < cur { continue }

                    // 마지막 라인부터 역순으로 timestamp 찾기 (최적화)
                    if let data = fm.contents(atPath: filePath),
                       let content = String(data: data, encoding: .utf8) {
                        for line in content.components(separatedBy: "\n").reversed() {
                            guard !line.isEmpty,
                                  let lineData = line.data(using: .utf8),
                                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                                continue
                            }
                            if let ts = json["timestamp"] as? String,
                               let date = formatter.date(from: ts) {
                                if latest == nil || date > latest! {
                                    latest = date
                                }
                                break // 파일 내 가장 최근 라인이면 충분
                            }
                        }
                    }
                }
            }
        }
        return latest
    }

    // MARK: - JSONL Parsing

    /// 단일 파일의 토큰 사용량 (전체).
    private func parseJSONL(at path: String) -> TokenUsage {
        return parseJSONL(at: path, filterFrom: nil)
    }

    /// 단일 파일 파싱. cutoff 지정시 그 이후 timestamp만 합산.
    private func parseJSONL(at path: String, filterFrom cutoff: Date?) -> TokenUsage {
        var usage = TokenUsage()
        let formatter = TokenTracker.timestampFormatter

        guard let data = FileManager.default.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else {
            return usage
        }

        for line in content.components(separatedBy: "\n") {
            guard !line.isEmpty,
                  let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            // cutoff 필터
            if let cutoff = cutoff {
                guard let ts = json["timestamp"] as? String,
                      let date = formatter.date(from: ts),
                      date >= cutoff else { continue }
            }

            if let message = json["message"] as? [String: Any],
               let usageData = message["usage"] as? [String: Any] {
                usage.inputTokens += usageData["input_tokens"] as? Int ?? 0
                usage.outputTokens += usageData["output_tokens"] as? Int ?? 0
                usage.cacheCreationTokens += usageData["cache_creation_input_tokens"] as? Int ?? 0
                usage.cacheReadTokens += usageData["cache_read_input_tokens"] as? Int ?? 0
            }
        }

        return usage
    }

    /// 모든 등록된 폴더의 JSONL 합산. cutoff 지정시 그 이후만.
    private func parseAllJSONLs(filterFrom cutoff: Date?) -> TokenUsage {
        let fm = FileManager.default
        var total = TokenUsage()

        for base in claudeProjectsDirs {
            guard let projectDirs = try? fm.contentsOfDirectory(atPath: base) else { continue }
            for dir in projectDirs {
                let projectPath = "\(base)/\(dir)"
                guard let files = try? fm.contentsOfDirectory(atPath: projectPath) else { continue }

                for file in files {
                    guard file.hasSuffix(".jsonl") else { continue }
                    let filePath = "\(projectPath)/\(file)"

                    // cutoff가 있으면 mtime 기반 빠른 스킵
                    if let cutoff = cutoff,
                       let attrs = try? fm.attributesOfItem(atPath: filePath),
                       let modDate = attrs[.modificationDate] as? Date,
                       modDate < cutoff {
                        continue
                    }

                    let usage = parseJSONL(at: filePath, filterFrom: cutoff)
                    total.inputTokens += usage.inputTokens
                    total.outputTokens += usage.outputTokens
                    total.cacheCreationTokens += usage.cacheCreationTokens
                    total.cacheReadTokens += usage.cacheReadTokens
                }
            }
        }

        return total
    }

    // MARK: - Helpers

    private static let timestampFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
