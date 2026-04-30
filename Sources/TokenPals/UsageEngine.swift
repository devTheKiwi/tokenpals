// Periodically polls TokenTracker, builds UsageSummary, notifies observers on main queue.

import Foundation

class UsageEngine {
    private let tokenTracker: TokenTracker
    private var pollTimer: Timer?
    private let parseQueue = DispatchQueue(label: "tokenpals.usage.parse", qos: .userInitiated)
    private var debounceWorkItem: DispatchWorkItem?

    private(set) var current: UsageSummary = UsageSummary()
    var onUpdate: ((UsageSummary) -> Void)?

    init(tokenTracker: TokenTracker) {
        self.tokenTracker = tokenTracker
    }

    /// 시작 — 폴링 + 즉시 1회 refresh.
    /// FSEvents 워처가 있으면 폴링은 fallback이라 인터벌을 길게 잡아도 됨.
    func start(interval: TimeInterval = 60) {
        refresh()
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
    }

    /// 외부 트리거 (FSEvents 워처 등) — 다발 호출을 디바운스로 묶어서 1회 refresh.
    /// FSEvents가 짧은 시간에 여러 콜백을 줄 수 있어서 필요.
    func triggerRefresh(debounce: TimeInterval = 0.3) {
        debounceWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.refresh()
        }
        debounceWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + debounce, execute: item)
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
