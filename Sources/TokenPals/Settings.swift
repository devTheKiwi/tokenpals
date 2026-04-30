// User-facing settings keys + default registration.

import Foundation

enum SettingsKey {
    // 한도
    static let fiveHourBudget = "tokenpals.fiveHourBudget"

    // 알림
    static let alertMaster = "tokenpals.alert.master"
    static let alertThreshold80 = "tokenpals.alert.threshold80"
    static let alertThreshold95 = "tokenpals.alert.threshold95"
    static let alertCacheLow = "tokenpals.alert.cacheLow"

    // UI
    static let pinDefault = "tokenpals.pin.default"
    static let petWalkSpeed = "tokenpals.pet.walkSpeed"
    static let pollIntervalSec = "tokenpals.poll.intervalSec"
}

enum Settings {
    /// 첫 실행시 호출. 기본값 등록.
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            SettingsKey.fiveHourBudget: 20_000_000,
            SettingsKey.alertMaster: true,
            SettingsKey.alertThreshold80: true,
            SettingsKey.alertThreshold95: true,
            SettingsKey.alertCacheLow: false, // 디폴트 OFF (좀 시끄러울 수 있음)
            SettingsKey.pinDefault: false,
            SettingsKey.petWalkSpeed: 0.6,
            SettingsKey.pollIntervalSec: 60,
        ])
    }
}
