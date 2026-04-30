// L10n strings for TokenPals
// Adapted from ClaudePet (https://github.com/devTheKiwi/ClaudePet) MIT.

import Foundation

/// 시스템 언어 감지 기반 한/영 자동 전환
struct L10n {
    static let isKorean: Bool = {
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("ko")
    }()

    // MARK: - 인사

    static let greeting = isKorean ? "안녕! 나는 TokenPal이야!" : "Hi! I'm a TokenPal!"

    // MARK: - 클릭 메시지

    static let clickIdle = isKorean
        ? ["뭐~ 심심해?", "놀아줄 거야?", "왜왜왜~ 뭐 필요해?", "여기 살아있어!"]
        : ["Bored?", "Wanna play?", "What do you need?", "I'm right here!"]

    static let clickWorking = isKorean
        ? ["지금 열심히 일하는 중!", "거의 다 됐어!", "코드 작성 중~"]
        : ["Working hard!", "Almost done!", "Coding right now~"]

    static let doubleClick = isKorean ? "우왕! 신난다~!" : "Woah! So fun~!"

    // MARK: - 랜덤 말걸기

    static let idleMessages = isKorean
        ? ["오늘 코딩 많이 했어?", "잠깐 스트레칭 어때?", "커피 한잔 어때요~",
           "버그 없는 하루 되길!", "git commit 했어?", "오늘도 화이팅!",
           "토큰 잘 쓰고 있지?", "여기서 지켜보고 있을게~"]
        : ["Done much coding today?", "How about a stretch?", "Coffee break?",
           "Bug-free day!", "Did you git commit?", "You got this!",
           "Using tokens wisely?", "I'm watching over you~"]

    static let workingMessages = isKorean
        ? ["열심히 작업 중이야!", "잘 되고 있어!", "곧 끝날 거야!"]
        : ["Working hard!", "Going well!", "Almost done!"]

    // MARK: - 메뉴

    static let menuOpenRoom = isKorean ? "방 열기" : "Open Room"
    static let menuHideRoom = isKorean ? "방 숨기기" : "Hide Room"
    static let menuQuit = isKorean ? "종료" : "Quit"
    static let menuSettings = isKorean ? "설정..." : "Settings..."
    static let menuStats = isKorean ? "통계..." : "Stats..."
    static let menuPin = isKorean ? "항상 위에 표시" : "Always on Top"
}
