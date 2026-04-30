// Pinnable, resizable room window.

import Cocoa

class RoomWindow: NSWindow {
    static let defaultSize = NSSize(width: 480, height: 360)
    static let minSize = NSSize(width: 320, height: 240)

    let roomView: RoomView

    private(set) var isPinned: Bool = false

    init() {
        let contentRect = NSRect(origin: .zero, size: RoomWindow.defaultSize)

        roomView = RoomView(frame: contentRect)

        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        title = "TokenPals"
        contentMinSize = RoomWindow.minSize
        contentView = roomView

        // 화면 중앙에 위치
        center()

        // 기본은 일반 레벨
        level = .normal
        isReleasedWhenClosed = false
    }

    /// 핀 토글: 항상 위 + 모든 Space에서 보임
    func setPinned(_ pinned: Bool) {
        isPinned = pinned
        if pinned {
            level = .floating
            collectionBehavior = [.canJoinAllSpaces, .stationary]
        } else {
            level = .normal
            collectionBehavior = []
        }
    }

    func togglePin() {
        setPinned(!isPinned)
    }
}
