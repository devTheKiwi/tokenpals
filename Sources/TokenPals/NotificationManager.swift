// Token usage alerts via UserNotifications.

import Foundation
import UserNotifications

class NotificationManager {
    private var lastFiredAt: [String: Date] = [:]
    private var authorized: Bool = false
    private(set) var didRequestAuth: Bool = false

    /// `UNUserNotificationCenter`는 정식 .app 번들에서만 동작.
    /// `swift run`으로 raw 실행시 `bundleIdentifier == nil` → API 크래시.
    /// 우회: 번들 없으면 알림 자체를 비활성.
    private var isBundled: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    /// 권한 요청 (첫 실행시 1회).
    func requestAuthorization() {
        guard !didRequestAuth else { return }
        didRequestAuth = true
        guard isBundled else {
            NSLog("[TokenPals] 알림 비활성 — bundleIdentifier 없음. install.sh로 .app 패키지 빌드시 동작.")
            return
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.authorized = granted
            }
        }
    }

    /// UsageEngine 갱신마다 호출.
    func handleUsageUpdate(_ summary: UsageSummary) {
        guard isBundled else { return }
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: SettingsKey.alertMaster) else { return }
        guard authorized || !didRequestAuth else { return }

        let pct = summary.fiveHourPercent

        // 95% (위험) — 가장 우선
        if defaults.bool(forKey: SettingsKey.alertThreshold95) && pct >= 0.95 {
            fire(
                key: "alert95",
                title: L10n.isKorean ? "🚨 한도 임박!" : "🚨 Limit imminent!",
                body: L10n.isKorean
                    ? "5시간 한도 95% 도달했어요. 저장하고 잠시 멈춰주세요."
                    : "Reached 95% of 5h budget. Save and pause.",
                cooldownMinutes: 15
            )
        }
        // 80% — 95%와 따로 발사 (이미 95% 발사됐으면 cooldown으로 막힘)
        else if defaults.bool(forKey: SettingsKey.alertThreshold80) && pct >= 0.80 {
            fire(
                key: "alert80",
                title: L10n.isKorean ? "🥵 토큰 80% 사용" : "🥵 80% used",
                body: L10n.isKorean
                    ? "5시간 한도 80% 도달했어요. 잠깐 쉬어가는 거 어때요?"
                    : "80% of 5h budget reached. Time to take a break?",
                cooldownMinutes: 30
            )
        }

        // 캐시 효율 저하
        if defaults.bool(forKey: SettingsKey.alertCacheLow) {
            if summary.todayTotal > 100_000 && summary.cacheHitRate < 0.20 {
                fire(
                    key: "cacheLow",
                    title: L10n.isKorean ? "🤔 캐시 효율 낮음" : "🤔 Low cache hit",
                    body: L10n.isKorean
                        ? "/clear 명령어로 새 세션 시작 추천."
                        : "Try /clear to start fresh.",
                    cooldownMinutes: 60
                )
            }
        }
    }

    private func fire(key: String, title: String, body: String, cooldownMinutes: Double) {
        guard isBundled else { return }
        if let last = lastFiredAt[key] {
            if Date().timeIntervalSince(last) < cooldownMinutes * 60 { return }
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let req = UNNotificationRequest(identifier: "\(key)-\(Int(Date().timeIntervalSince1970))", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req) { _ in }

        lastFiredAt[key] = Date()
    }
}
