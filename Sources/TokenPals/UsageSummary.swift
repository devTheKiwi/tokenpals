// Aggregated token usage summary + character mood mapping.

import Foundation

/// 캐릭터의 행동을 결정하는 무드 (사용량 기반).
enum PetMood {
    case normal      // 평소: 자유롭게 산책
    case working     // 활성 세션: 제자리에서 통통 + 반짝
    case sleepy      // 30분+ 유휴: 멈춤, 눈 감음
    case alarm       // 사용량 임박: 빨간 글로우 + 흔들
}

struct UsageSummary {
    var todayTotal: Int = 0           // 오늘 합계 (캐시 read 포함)
    var todayBillable: Int = 0        // 오늘 실 청구 (캐시 read 제외)
    var fiveHourTotal: Int = 0        // 5시간 합계 (캐시 read 포함)
    var fiveHourBillable: Int = 0     // 5시간 실 청구
    var cacheReadToday: Int = 0
    var inputToday: Int = 0
    var cacheCreationToday: Int = 0
    /// 캐시 적중률 (0.0 ~ 1.0)
    var cacheHitRate: Double = 0
    /// 마지막으로 활동(JSONL 라인 timestamp)이 있던 시각
    var lastActivityAt: Date?

    var minutesSinceLastActivity: Int {
        guard let last = lastActivityAt else { return Int.max }
        return Int(Date().timeIntervalSince(last) / 60)
    }
}

extension UsageSummary {
    /// Phase 1 임시 한도 — **실 청구 토큰 (캐시 read 제외)** 기준.
    /// Max 5x 헤비 유저: 5시간에 청구 토큰 ~5~10M 흔함. 여유로 20M 잡음.
    /// UserDefaults `tokenpals.fiveHourBudget` 으로 override 가능.
    static var fiveHourBudget: Int {
        let stored = UserDefaults.standard.integer(forKey: "tokenpals.fiveHourBudget")
        return stored > 0 ? stored : 20_000_000
    }

    /// 5h 실 청구 사용률 (mood 계산에 사용)
    var fiveHourPercent: Double {
        Double(fiveHourBillable) / Double(UsageSummary.fiveHourBudget)
    }

    var mood: PetMood {
        // 1순위: 한도 임박 (95% 이상)
        if fiveHourPercent >= 0.95 { return .alarm }
        // 2순위: 활성 세션 (5분 이내 활동)
        if minutesSinceLastActivity <= 5 { return .working }
        // 3순위: 30분+ 유휴
        if minutesSinceLastActivity >= 30 { return .sleepy }
        // 기본
        return .normal
    }
}
