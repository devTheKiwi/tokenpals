// AppDelegate: wires up the menu bar, room window, and live usage data.

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var roomWindow: RoomWindow!
    var tokenTracker: TokenTracker!
    var usageEngine: UsageEngine!
    var fileWatcher: FileWatcher?
    var pet: PetActor!
    var notificationManager: NotificationManager!
    var settingsWindow: SettingsWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Settings.registerDefaults()
        setupStatusBar()
        setupRoom()
        setupUsageEngine()
        setupNotifications()
    }

    func applicationWillTerminate(_ notification: Notification) {
        fileWatcher?.stop()
        usageEngine?.stop()
    }

    private func setupNotifications() {
        notificationManager = NotificationManager()
        notificationManager.requestAuthorization()
    }

    // MARK: - Menu Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
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

        // 사용량 요약 (UsageEngine.current 기반)
        let s = usageEngine?.current ?? UsageSummary()
        let todayItem = NSMenuItem(
            title: usageLine(label: L10n.isKorean ? "오늘" : "Today", value: TokenUsage.formatTokens(s.todayTotal)),
            action: nil, keyEquivalent: ""
        )
        todayItem.isEnabled = false
        menu.addItem(todayItem)

        let fivehItem = NSMenuItem(
            title: usageLine(label: L10n.isKorean ? "5시간" : "5h", value: TokenUsage.formatTokens(s.fiveHourTotal)),
            action: nil, keyEquivalent: ""
        )
        fivehItem.isEnabled = false
        menu.addItem(fivehItem)

        let cachePct = Int(s.cacheHitRate * 100)
        let cacheItem = NSMenuItem(
            title: usageLine(label: L10n.isKorean ? "캐시" : "Cache", value: "\(cachePct)%"),
            action: nil, keyEquivalent: ""
        )
        cacheItem.isEnabled = false
        menu.addItem(cacheItem)

        let activityText = lastActivityDescription(for: s)
        let activityItem = NSMenuItem(title: activityText, action: nil, keyEquivalent: "")
        activityItem.isEnabled = false
        menu.addItem(activityItem)

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

        // 새로고침 (즉시)
        let refreshItem = NSMenuItem(
            title: L10n.isKorean ? "지금 새로고침" : "Refresh now",
            action: #selector(refreshUsage),
            keyEquivalent: ""
        )
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(NSMenuItem.separator())

        // 설정
        let settingsItem = NSMenuItem(
            title: L10n.isKorean ? "설정..." : "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quit = NSMenuItem(title: L10n.menuQuit, action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    /// "label  value" 형태로 좌우 정렬 비슷하게 (모노스페이스 가정).
    private func usageLine(label: String, value: String) -> String {
        return "\(label)\t\(value)"
    }

    private func lastActivityDescription(for s: UsageSummary) -> String {
        guard let last = s.lastActivityAt else {
            return L10n.isKorean ? "마지막 활동: -" : "Last activity: -"
        }
        let mins = Int(Date().timeIntervalSince(last) / 60)
        if L10n.isKorean {
            if mins < 1 { return "마지막 활동: 방금" }
            if mins < 60 { return "마지막 활동: \(mins)분 전" }
            let hours = mins / 60
            return "마지막 활동: \(hours)시간 전"
        } else {
            if mins < 1 { return "Last activity: just now" }
            if mins < 60 { return "Last activity: \(mins)m ago" }
            let hours = mins / 60
            return "Last activity: \(hours)h ago"
        }
    }

    private func updateStatusBarTitle(with summary: UsageSummary) {
        guard let button = statusItem.button else { return }
        if summary.todayTotal > 0 {
            button.title = "🥔 \(TokenUsage.formatTokens(summary.todayTotal))"
        } else {
            button.title = "🥔"
        }
    }

    // MARK: - Room

    private func setupRoom() {
        roomWindow = RoomWindow()

        // 핀 기본값 적용
        if UserDefaults.standard.bool(forKey: SettingsKey.pinDefault) {
            roomWindow.setPinned(true)
        }

        // 현재 머신을 대표하는 단일 펫.
        let name = Host.current().localizedName ?? (L10n.isKorean ? "이 맥" : "This Mac")
        let colorIndex = abs(name.utf8.reduce(0) { Int($0) + Int($1) }) % PetColor.palette.count
        pet = roomWindow.roomView.addPet(color: PetColor.palette[colorIndex], name: name)

        roomWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Usage Engine

    private func setupUsageEngine() {
        tokenTracker = TokenTracker()
        usageEngine = UsageEngine(tokenTracker: tokenTracker)
        usageEngine.onUpdate = { [weak self] summary in
            self?.handleUsageUpdate(summary)
        }
        // 폴링은 60초 안전망 (실시간 워처가 대부분 처리)
        usageEngine.start(interval: 60)

        // FSEvents 기반 실시간 워처
        let watchPaths = tokenTracker.claudeProjectsDirs
        if !watchPaths.isEmpty {
            fileWatcher = FileWatcher(paths: watchPaths) { [weak self] in
                self?.usageEngine.triggerRefresh()
            }
            fileWatcher?.start()
        }
    }

    private func handleUsageUpdate(_ summary: UsageSummary) {
        pet?.summary = summary // PetActor가 mood/tooltip 자동 갱신
        updateStatusBarTitle(with: summary)
        rebuildStatusMenu()
        notificationManager?.handleUsageUpdate(summary)
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

    @objc private func refreshUsage() {
        usageEngine?.refresh()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let win = SettingsWindow()
            win.onChange = { [weak self] in
                // 설정 변경시 mood 즉시 재계산 (5h budget 변경 등)
                self?.usageEngine?.refresh()
            }
            settingsWindow = win
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
