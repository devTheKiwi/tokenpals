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
    /// 자동 감지된 모든 .claude* 폴더의 projects 경로
    let claudeProjectsDirs: [String]

    init() {
        self.claudeProjectsDirs = TokenTracker.discoverClaudeProjectDirs()
    }

    /// `~/.claude*` 패턴으로 모든 Claude 설정 폴더 탐색
    static func discoverClaudeProjectDirs() -> [String] {
        let home = NSHomeDirectory()
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: home) else {
            return []
        }

        var found: [String] = []
        for entry in entries {
            // .claude / .claude-alt / .claude_alt / .claude-account2 등
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

    // MARK: - JSONL Parsing

    private func parseJSONL(at path: String) -> TokenUsage {
        var usage = TokenUsage()

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
}
