// Pixel-art ball actor that lives inside a RoomView.
// Phase 1: mood-driven behavior + hover tooltip.

import Cocoa

enum PetState {
    case idle
    case walking
    case happy      // 클릭 1.5초 (^^ 눈)
    case jumping    // 더블클릭 1.5초 (점프)
}

class PetActor: NSView {
    // 12×12 공 본체 (얼굴 X, 광택만 포함).
    static let ballSprite: [[Int]] = [
        [0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0],
        [0, 1, 1, 2, 2, 2, 2, 2, 2, 1, 1, 0],
        [0, 1, 2, 3, 3, 2, 2, 2, 2, 2, 1, 0],
        [1, 2, 3, 3, 2, 2, 2, 2, 2, 2, 2, 1],
        [1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1],
        [1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1],
        [1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1],
        [1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1],
        [1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1],
        [0, 1, 2, 2, 2, 2, 2, 2, 2, 2, 1, 0],
        [0, 1, 1, 2, 2, 2, 2, 2, 2, 1, 1, 0],
        [0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0],
    ]

    static let pixelScale: CGFloat = 5.0
    static let spriteCols: Int = 12
    static let spriteRows: Int = 12
    static let labelGap: CGFloat = 6
    static let labelHeight: CGFloat = 12

    static let petSize = NSSize(
        width: CGFloat(spriteCols) * pixelScale,
        height: CGFloat(spriteRows) * pixelScale + labelGap + labelHeight
    )

    // MARK: - State

    private(set) var state: PetState = .idle
    var mood: PetMood = .normal {
        didSet {
            if mood != oldValue { applyMoodChange() }
        }
    }

    /// 사용량 데이터. 갱신시 mood/툴팁 자동 반영.
    var summary: UsageSummary? {
        didSet {
            if let s = summary {
                mood = s.mood
            }
            tooltip?.lines = formatTooltipLines()
        }
    }

    private var animationFrame: Int = 0
    private var animationTimer: Timer?
    private var stateTimer: Timer?
    private var behaviorTimer: Timer?

    private var targetPoint: NSPoint?
    private let walkSpeed: CGFloat = 0.6

    var deviceId: String = ""       // Phase 2.5: Realtime 이벤트 매칭용
    var deviceName: String = ""
    var onClicked: (() -> Void)?
    var onDoubleClicked: (() -> Void)?

    // MARK: - Blink

    /// 다음 깜빡 frame (`animationFrame >= nextBlinkFrame` 이면 깜빡 시작)
    private var nextBlinkFrame: Int = 75   // ~5s @ 15fps
    /// 깜빡 종료 frame (그 frame까진 눈 감음)
    private var blinkUntilFrame: Int = -1

    // MARK: - Speech / Tooltip / Tracking

    private var speechBubble: SpeechBubble?
    private var randomMessageTimer: Timer?
    private var trackingArea: NSTrackingArea?
    private var tooltip: UsageTooltip?

    // MARK: - Colors

    private let bodyColor: NSColor
    private let bodyHighlightColor: NSColor
    private let outlineColor: NSColor
    private let eyeColor = NSColor(white: 0.10, alpha: 1.0)
    private let blushColor = NSColor(red: 1.0, green: 0.55, blue: 0.65, alpha: 0.55)
    private let sparkleColor = NSColor(red: 1.0, green: 0.85, blue: 0.30, alpha: 0.85)
    private let alarmColor = NSColor(red: 0.95, green: 0.30, blue: 0.30, alpha: 0.85)

    init(color: PetColor, deviceId: String = "", deviceName: String = "", origin: NSPoint = .zero) {
        self.bodyColor = color.body
        self.bodyHighlightColor = PetActor.lighten(color.body, by: 0.18)
        self.outlineColor = color.foot
        self.deviceId = deviceId
        self.deviceName = deviceName
        super.init(frame: NSRect(origin: origin, size: PetActor.petSize))
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    deinit {
        stopAnimating()
    }

    private static func lighten(_ color: NSColor, by amount: CGFloat) -> NSColor {
        guard let rgb = color.usingColorSpace(.deviceRGB) else { return color }
        return NSColor(
            red: min(1.0, rgb.redComponent + amount),
            green: min(1.0, rgb.greenComponent + amount),
            blue: min(1.0, rgb.blueComponent + amount),
            alpha: rgb.alphaComponent
        )
    }

    // MARK: - Mouse / Hover

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            showSpeech(L10n.doubleClick)
            onDoubleClicked?()
        } else {
            showRandomClickMessage()
            onClicked?()
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let opts: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: opts, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        showTooltip()
    }

    override func mouseExited(with event: NSEvent) {
        hideTooltip()
    }

    private func showTooltip() {
        guard let parent = superview, tooltip == nil else { return }
        let tt = UsageTooltip()
        tt.lines = formatTooltipLines()
        parent.addSubview(tt)
        positionTooltip(tt)
        tooltip = tt
    }

    private func hideTooltip() {
        tooltip?.removeFromSuperview()
        tooltip = nil
    }

    private func positionTooltip(_ tt: UsageTooltip) {
        let petFrame = self.frame
        var x = petFrame.midX - tt.frame.width / 2
        var y = petFrame.maxY + 4

        if let parent = superview {
            let pb = parent.bounds
            x = max(pb.minX + 2, min(pb.maxX - tt.frame.width - 2, x))
            // 펫이 위쪽에 있으면 툴팁이 잘릴 수 있으니 위 공간 부족시 아래 표시
            if y + tt.frame.height > pb.maxY - 2 {
                y = petFrame.minY - tt.frame.height - 4
            }
        }
        tt.frame.origin = NSPoint(x: x, y: y)
    }

    private func formatTooltipLines() -> [String] {
        var lines: [String] = []
        if !deviceName.isEmpty {
            lines.append(deviceName)
        }
        guard let s = summary else {
            lines.append(L10n.isKorean ? "데이터 없음" : "No data")
            return lines
        }
        let today = TokenUsage.formatTokens(s.todayTotal)
        let fiveh = TokenUsage.formatTokens(s.fiveHourTotal)
        let cachePct = Int(s.cacheHitRate * 100)
        if L10n.isKorean {
            lines.append("오늘  \(today)")
            lines.append("5시간 \(fiveh)")
            lines.append("캐시  \(cachePct)%")
        } else {
            lines.append("Today \(today)")
            lines.append("5h    \(fiveh)")
            lines.append("Cache \(cachePct)%")
        }
        return lines
    }

    // MARK: - Animation lifecycle

    func startAnimating() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 15.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        scheduleNextBehavior()
        scheduleNextRandomMessage()
    }

    func stopAnimating() {
        animationTimer?.invalidate()
        behaviorTimer?.invalidate()
        stateTimer?.invalidate()
        randomMessageTimer?.invalidate()
        animationTimer = nil
        behaviorTimer = nil
        stateTimer = nil
        randomMessageTimer = nil
    }

    func setState(_ newState: PetState) {
        state = newState
        stateTimer?.invalidate()

        switch newState {
        case .happy, .jumping:
            stateTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                self?.state = .idle
                self?.scheduleNextBehavior()
            }
        default:
            break
        }
    }

    // MARK: - Mood

    private func applyMoodChange() {
        // 산책 못 하는 mood로 바뀌면 즉시 정지
        if mood != .normal {
            targetPoint = nil
            if state != .happy && state != .jumping {
                state = .idle
            }
            behaviorTimer?.invalidate()
        } else {
            scheduleNextBehavior()
        }
        needsDisplay = true
    }

    // MARK: - Behavior

    private func scheduleNextBehavior() {
        behaviorTimer?.invalidate()
        guard mood == .normal else { return }
        let delay = TimeInterval.random(in: 1.5...4.0)
        behaviorTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.pickRandomBehavior()
        }
    }

    private func pickRandomBehavior() {
        guard mood == .normal else { return }
        let roll = Int.random(in: 0...10)
        if roll < 3 {
            state = .idle
            targetPoint = nil
        } else {
            chooseNewTarget()
            state = .walking
        }
        scheduleNextBehavior()
    }

    private func chooseNewTarget() {
        guard let parent = superview else { return }
        let bounds = parent.bounds
        let margin: CGFloat = 12
        let width = frame.width
        let height = frame.height

        let floorTopY = bounds.minY + bounds.height * 0.5

        let minX = bounds.minX + margin
        let maxX = bounds.maxX - width - margin
        let minY = bounds.minY + margin
        let maxY = floorTopY - height - margin

        guard maxX > minX, maxY > minY else { return }

        targetPoint = NSPoint(
            x: CGFloat.random(in: minX...maxX),
            y: CGFloat.random(in: minY...maxY)
        )
    }

    // MARK: - Per-frame

    private func tick() {
        animationFrame += 1
        if state == .walking {
            stepTowardTarget()
        }
        // 깜빡 스케줄
        if animationFrame >= nextBlinkFrame && state != .happy && mood != .sleepy {
            blinkUntilFrame = animationFrame + 2 // 2 프레임 눈 감음 (~133ms)
            nextBlinkFrame = animationFrame + Int.random(in: 75...150) // 5~10s 후 다음
        }
        // 툴팁/말풍선 위치 갱신 (펫이 움직이면 따라옴)
        if let tt = tooltip { positionTooltip(tt) }
        if let bubble = speechBubble, bubble.superview != nil {
            positionBubble(bubble)
        }
        needsDisplay = true
    }

    private func stepTowardTarget() {
        guard let target = targetPoint else {
            state = .idle
            return
        }
        var origin = frame.origin
        let dx = target.x - origin.x
        let dy = target.y - origin.y
        let dist = sqrt(dx * dx + dy * dy)

        if dist <= walkSpeed {
            origin = target
            targetPoint = nil
            state = .idle
        } else {
            origin.x += dx / dist * walkSpeed
            origin.y += dy / dist * walkSpeed
        }

        if let parent = superview {
            let b = parent.bounds
            let maxX = b.maxX - frame.width
            let maxY = b.maxY - frame.height
            origin.x = max(b.minX, min(maxX, origin.x))
            origin.y = max(b.minY, min(maxY, origin.y))
        }
        frame.origin = origin
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.clear(bounds)
        context.setShouldAntialias(false)
        NSGraphicsContext.current?.shouldAntialias = false

        let scale = PetActor.pixelScale
        let cols = PetActor.spriteCols
        let rows = PetActor.spriteRows

        let spriteWidth = CGFloat(cols) * scale
        let spriteX = (bounds.width - spriteWidth) / 2

        // 점프/바운스
        let bounce: CGFloat
        switch state {
        case .idle:
            bounce = sin(Double(animationFrame) * 0.15) * 1.0
        case .walking:
            let phase = Double(animationFrame % 14) / 14.0
            bounce = abs(sin(phase * .pi)) * 2.5
        case .happy:
            bounce = abs(sin(Double(animationFrame) * 0.45)) * 4.0
        case .jumping:
            let phase = Double(animationFrame % 30) / 30.0
            bounce = sin(phase * .pi) * 18.0
        }

        // mood 효과: working = 약간 빠른 통통 / sleepy = 거의 정지 / alarm = 흔들
        let moodBounceBoost: CGFloat
        let jitterX: CGFloat
        let jitterY: CGFloat
        switch mood {
        case .normal:
            moodBounceBoost = 0
            jitterX = 0
            jitterY = 0
        case .working:
            moodBounceBoost = abs(sin(Double(animationFrame) * 0.30)) * 1.5
            jitterX = 0
            jitterY = 0
        case .sleepy:
            moodBounceBoost = -bounce * 0.7 // 거의 멈춤
            jitterX = 0
            jitterY = 0
        case .alarm:
            moodBounceBoost = 0
            jitterX = sin(Double(animationFrame) * 1.2) * 1.5
            jitterY = cos(Double(animationFrame) * 1.5) * 0.8
        }

        let labelArea = PetActor.labelGap + PetActor.labelHeight
        let spriteY = labelArea + bounce + moodBounceBoost
        let spriteOriginX = spriteX + jitterX
        let spriteOriginY = spriteY + jitterY

        // 알람 글로우 (sprite 뒤에 그려서 덜 거슬리게)
        if mood == .alarm {
            drawAlarmBorder(spriteX: spriteOriginX, spriteY: spriteOriginY, scale: scale)
        }

        // 본체
        for row in 0..<rows {
            for col in 0..<cols {
                let v = PetActor.ballSprite[row][col]
                guard v != 0 else { continue }
                let px = spriteOriginX + CGFloat(col) * scale
                let py = spriteOriginY + CGFloat(rows - 1 - row) * scale
                let color: NSColor
                switch v {
                case 1: color = outlineColor
                case 2: color = bodyColor
                case 3: color = bodyHighlightColor
                default: continue
                }
                color.setFill()
                NSRect(x: px, y: py, width: scale, height: scale).fill()
            }
        }

        // 얼굴
        drawFace(spriteX: spriteOriginX, spriteY: spriteOriginY, scale: scale)

        // working 스파클 (머리 위 회전)
        if mood == .working {
            drawSparkles(spriteX: spriteOriginX, spriteY: spriteOriginY, scale: scale)
        }

        // 라벨
        if !deviceName.isEmpty {
            NSGraphicsContext.current?.shouldAntialias = true
            let font = NSFont.monospacedSystemFont(ofSize: 9, weight: .medium)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
            let textSize = (deviceName as NSString).size(withAttributes: attrs)
            let labelX = (bounds.width - textSize.width) / 2
            let labelY = PetActor.labelGap / 2
            (deviceName as NSString).draw(at: NSPoint(x: labelX, y: labelY), withAttributes: attrs)
        }
    }

    /// 얼굴 (눈 + 입 + 볼터치). state/mood 따라 변형.
    private func drawFace(spriteX: CGFloat, spriteY: CGFloat, scale: CGFloat) {
        let rows = PetActor.spriteRows

        let drawPx = { (col: Int, row: Int, color: NSColor) in
            let px = spriteX + CGFloat(col) * scale
            let py = spriteY + CGFloat(rows - 1 - row) * scale
            color.setFill()
            NSRect(x: px, y: py, width: scale, height: scale).fill()
        }

        // 볼터치 (항상)
        drawPx(2, 6, blushColor)
        drawPx(9, 6, blushColor)

        // 눈 우선순위: state.happy > mood.sleepy > blink > 기본
        let isBlinking = animationFrame <= blinkUntilFrame
        if state == .happy {
            // ^^ 양쪽
            drawPx(3, 4, eyeColor)
            drawPx(2, 5, eyeColor)
            drawPx(4, 5, eyeColor)
            drawPx(8, 4, eyeColor)
            drawPx(7, 5, eyeColor)
            drawPx(9, 5, eyeColor)
        } else if mood == .sleepy || isBlinking {
            // 감은 눈 (3px 가로선 양쪽)
            drawPx(2, 4, eyeColor); drawPx(3, 4, eyeColor); drawPx(4, 4, eyeColor)
            drawPx(7, 4, eyeColor); drawPx(8, 4, eyeColor); drawPx(9, 4, eyeColor)
        } else {
            // 기본 1px 도트
            drawPx(3, 4, eyeColor)
            drawPx(8, 4, eyeColor)
        }

        // ㅅ 입 (항상)
        drawPx(5, 7, eyeColor)
        drawPx(4, 8, eyeColor)
        drawPx(6, 8, eyeColor)
    }

    /// 머리 위 3개 스파클 (working mood).
    private func drawSparkles(spriteX: CGFloat, spriteY: CGFloat, scale: CGFloat) {
        sparkleColor.setFill()
        let centerX = spriteX + (CGFloat(PetActor.spriteCols) * scale) / 2
        let topY = spriteY + CGFloat(PetActor.spriteRows) * scale + 4
        let phase = Double(animationFrame) * 0.18
        for i in 0..<3 {
            let angle = phase + Double(i) * (2.0 * .pi / 3.0)
            let radius: CGFloat = 8
            let x = centerX + CGFloat(cos(angle)) * radius - scale / 2
            let y = topY + CGFloat(sin(angle)) * radius - scale / 2
            NSRect(x: x, y: y, width: scale, height: scale).fill()
        }
    }

    /// 알람 외곽 글로우 (alarm mood).
    private func drawAlarmBorder(spriteX: CGFloat, spriteY: CGFloat, scale: CGFloat) {
        alarmColor.setStroke()
        let pathRect = NSRect(
            x: spriteX - 3,
            y: spriteY - 3,
            width: CGFloat(PetActor.spriteCols) * scale + 6,
            height: CGFloat(PetActor.spriteRows) * scale + 6
        )
        let path = NSBezierPath(rect: pathRect)
        path.lineWidth = 2
        path.stroke()
    }

    // MARK: - Speech Bubble

    /// 말풍선 표시. 매번 새 SpeechBubble 만들고 기존 건 제거.
    private func showSpeech(_ text: String) {
        guard let parent = superview else { return }
        speechBubble?.removeFromSuperview()
        let bubble = SpeechBubble()
        parent.addSubview(bubble)
        bubble.show(text)
        positionBubble(bubble)
        speechBubble = bubble
    }

    private func positionBubble(_ bubble: SpeechBubble) {
        let petFrame = self.frame
        var x = petFrame.midX - bubble.frame.width / 2
        var y = petFrame.maxY + 2

        if let parent = superview {
            let pb = parent.bounds
            x = max(pb.minX + 2, min(pb.maxX - bubble.frame.width - 2, x))
            // 위 공간 부족시 펫 아래로 (포인터는 위 향하게 — 단순화: 그래도 위 두기)
            if y + bubble.frame.height > pb.maxY - 2 {
                y = max(pb.minY + 2, petFrame.minY - bubble.frame.height - 2)
            }
        }
        bubble.frame.origin = NSPoint(x: x, y: y)
    }

    // MARK: - Random Messages

    private func scheduleNextRandomMessage() {
        randomMessageTimer?.invalidate()
        let delay = TimeInterval.random(in: 45...90)
        randomMessageTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.showRandomMessage()
            self?.scheduleNextRandomMessage()
        }
    }

    private func showRandomMessage() {
        // 자고 있거나 알람 상태에선 메시지 X
        guard mood == .normal || mood == .working else { return }
        // 이미 말풍선 떠있으면 스킵 (덮어쓰기 X)
        if let bubble = speechBubble, bubble.superview != nil { return }

        let messages = (mood == .working) ? L10n.workingMessages : L10n.idleMessages
        if let msg = messages.randomElement() {
            showSpeech(msg)
        }
    }

    private func showRandomClickMessage() {
        let messages: [String] = (mood == .working) ? L10n.clickWorking : L10n.clickIdle
        if let msg = messages.randomElement() {
            showSpeech(msg)
        }
    }
}
