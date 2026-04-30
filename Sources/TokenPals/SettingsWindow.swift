// Settings window: 5h budget, alert toggles, pin default.
// Changes save to UserDefaults instantly and call onChange callback.

import Cocoa

class SettingsWindow: NSWindow {
    /// 설정이 변경될 때마다 호출됨 (UsageEngine refresh 등 트리거).
    var onChange: (() -> Void)?

    private var budgetSlider: NSSlider!
    private var budgetValueLabel: NSTextField!

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 360),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        title = L10n.isKorean ? "TokenPals 설정" : "TokenPals Settings"
        contentView = makeContent()
        isReleasedWhenClosed = false
        center()
    }

    private func makeContent() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        stack.translatesAutoresizingMaskIntoConstraints = false

        // 사용량 한도
        stack.addArrangedSubview(sectionHeader(L10n.isKorean ? "사용량 한도" : "Limits"))
        stack.addArrangedSubview(budgetRow())

        // 알림
        stack.addArrangedSubview(spacer(8))
        stack.addArrangedSubview(sectionHeader(L10n.isKorean ? "알림" : "Notifications"))
        stack.addArrangedSubview(checkbox(
            title: L10n.isKorean ? "알림 사용 (마스터)" : "Enable notifications",
            key: SettingsKey.alertMaster
        ))
        stack.addArrangedSubview(checkbox(
            title: L10n.isKorean ? "  80% 도달 알림" : "  Alert at 80%",
            key: SettingsKey.alertThreshold80
        ))
        stack.addArrangedSubview(checkbox(
            title: L10n.isKorean ? "  95% 도달 알림" : "  Alert at 95%",
            key: SettingsKey.alertThreshold95
        ))
        stack.addArrangedSubview(checkbox(
            title: L10n.isKorean ? "  캐시 효율 저하 알림" : "  Low cache hit alert",
            key: SettingsKey.alertCacheLow
        ))

        // 표시
        stack.addArrangedSubview(spacer(8))
        stack.addArrangedSubview(sectionHeader(L10n.isKorean ? "표시" : "Display"))
        stack.addArrangedSubview(checkbox(
            title: L10n.isKorean ? "항상 위에 표시 (방 기본값)" : "Always on top (default)",
            key: SettingsKey.pinDefault
        ))

        // 푸터 노트
        stack.addArrangedSubview(spacer(4))
        stack.addArrangedSubview(noteLabel(
            L10n.isKorean ? "변경사항은 즉시 적용됩니다." : "Changes apply instantly."
        ))

        // 컨테이너
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 360))
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
        ])
        return container
    }

    // MARK: - Builders

    private func sectionHeader(_ text: String) -> NSView {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.boldSystemFont(ofSize: 13)
        return label
    }

    private func noteLabel(_ text: String) -> NSView {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 11)
        label.textColor = NSColor.secondaryLabelColor
        return label
    }

    private func spacer(_ height: CGFloat) -> NSView {
        let v = NSView(frame: NSRect(x: 0, y: 0, width: 0, height: height))
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: height).isActive = true
        return v
    }

    private func budgetRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: L10n.isKorean ? "5시간 한도 (실 청구)" : "5h budget (billable)")
        label.font = NSFont.systemFont(ofSize: 12)

        let slider = NSSlider()
        slider.minValue = 5
        slider.maxValue = 50
        slider.numberOfTickMarks = 10
        slider.allowsTickMarkValuesOnly = true
        let current = UserDefaults.standard.integer(forKey: SettingsKey.fiveHourBudget)
        slider.doubleValue = max(5, Double(current) / 1_000_000.0)
        slider.target = self
        slider.action = #selector(budgetChanged(_:))
        slider.isContinuous = true
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: 180).isActive = true

        let value = NSTextField(labelWithString: "\(Int(slider.doubleValue))M")
        value.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        value.translatesAutoresizingMaskIntoConstraints = false
        value.widthAnchor.constraint(equalToConstant: 40).isActive = true

        budgetSlider = slider
        budgetValueLabel = value

        row.addArrangedSubview(label)
        row.addArrangedSubview(slider)
        row.addArrangedSubview(value)
        return row
    }

    private func checkbox(title: String, key: String) -> NSView {
        let button = NSButton(checkboxWithTitle: title, target: self, action: #selector(toggleChanged(_:)))
        button.state = UserDefaults.standard.bool(forKey: key) ? .on : .off
        button.identifier = NSUserInterfaceItemIdentifier(key)
        return button
    }

    // MARK: - Actions

    @objc private func budgetChanged(_ slider: NSSlider) {
        let m = Int(slider.doubleValue.rounded())
        let tokens = m * 1_000_000
        UserDefaults.standard.set(tokens, forKey: SettingsKey.fiveHourBudget)
        budgetValueLabel.stringValue = "\(m)M"
        onChange?()
    }

    @objc private func toggleChanged(_ button: NSButton) {
        guard let id = button.identifier?.rawValue else { return }
        UserDefaults.standard.set(button.state == .on, forKey: id)
        onChange?()
    }
}
