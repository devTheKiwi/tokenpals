// Periodically polls TokenTracker, builds UsageSummary, notifies observers on main queue.

import Foundation

class UsageEngine {
    private let tokenTracker: TokenTracker
    private var pollTimer: Timer?
    private let parseQueue = DispatchQueue(label: "tokenpals.usage.parse", qos: .userInitiated)

    private(set) var current: UsageSummary = UsageSummary()
    var onUpdate: ((UsageSummary) -> Void)?

    init(tokenTracker: TokenTracker) {
        self.tokenTracker = tokenTracker
    }

    func start(interval: TimeInterval = 30) {
        refresh()
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    /// 즉시 1회 갱신 (background queue에서 파싱, 결과는 main queue로 dispatch).
    func refresh() {
        parseQueue.async { [weak self] in
            guard let self else { return }
            let today = self.tokenTracker.todayUsage()
            let last5h = self.tokenTracker.usageInLast(seconds: 5 * 3600)
            let lastActivity = self.tokenTracker.lastActivityDate()

            var summary = UsageSummary()
            summary.todayTotal = today.totalTokens
            summary.todayBillable = today.billableTokens
            summary.fiveHourTotal = last5h.totalTokens
            summary.fiveHourBillable = last5h.billableTokens
            summary.cacheReadToday = today.cacheReadTokens
            summary.inputToday = today.inputTokens
            summary.cacheCreationToday = today.cacheCreationTokens
            summary.lastActivityAt = lastActivity

            let denom = today.cacheReadTokens + today.inputTokens + today.cacheCreationTokens
            summary.cacheHitRate = denom > 0 ? Double(today.cacheReadTokens) / Double(denom) : 0

            DispatchQueue.main.async {
                self.current = summary
                self.onUpdate?(summary)
            }
        }
    }
}
