// AppDelegate: wires up the menu bar and the room window.
// Phase 0: spawn a few demo pets so we can visually verify the room works.

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var roomWindow: RoomWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        setupRoom()
    }

    // MARK: - Menu Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.title = "🥔"
        }
        rebuildStatusMenu()
    }

    private func rebuildStatusMenu() {
        let menu = NSMenu()

        // 헤더
        let header = NSMenuItem(title: "TokenPals", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(NSMenuItem.separator())

        // 방 토글
        let roomToggle = NSMenuItem(
            title: roomWindow?.isVisible == true ? L10n.menuHideRoom : L10n.menuOpenRoom,
            action: #selector(toggleRoom),
            keyEquivalent: "r"
        )
        roomToggle.target = self
        menu.addItem(roomToggle)

        // 핀 토글
        let pinToggle = NSMenuItem(
            title: L10n.menuPin,
            action: #selector(togglePin),
            keyEquivalent: "p"
        )
        pinToggle.target = self
        pinToggle.state = (roomWindow?.isPinned == true) ? .on : .off
        menu.addItem(pinToggle)

        menu.addItem(NSMenuItem.separator())

        // 종료
        let quit = NSMenuItem(title: L10n.menuQuit, action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    // MARK: - Room

    private func setupRoom() {
        roomWindow = RoomWindow()

        // Phase 0 데모: 3색 펫을 한 방에 띄움 (실제로는 등록된 디바이스 기반)
        roomWindow.roomView.addPet(color: PetColor.palette[0], name: "맥북프로")
        roomWindow.roomView.addPet(color: PetColor.palette[1], name: "데스크탑")
        roomWindow.roomView.addPet(color: PetColor.palette[2], name: "노트북")

        roomWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Actions

    @objc private func toggleRoom() {
        guard let win = roomWindow else { return }
        if win.isVisible {
            win.orderOut(nil)
        } else {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        rebuildStatusMenu()
    }

    @objc private func togglePin() {
        roomWindow?.togglePin()
        rebuildStatusMenu()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
