// Pixel-art ball actor that lives inside a RoomView.
// Cute ball with face: round eyes + ㅅ mouth, ^^ smile when happy.

import Cocoa

enum PetState {
    case idle
    case walking
    case happy
    case jumping
}

class PetActor: NSView {
    // 12×12 공 본체 (얼굴 X, 광택만 포함).
    // 0=투명 / 1=outline / 2=body / 3=highlight (광택).
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

    private(set) var state: PetState = .idle
    private var animationFrame: Int = 0
    private var animationTimer: Timer?
    private var stateTimer: Timer?
    private var behaviorTimer: Timer?

    private var targetPoint: NSPoint?
    private let walkSpeed: CGFloat = 0.6

    var deviceName: String = ""
    var onClicked: (() -> Void)?
    var onDoubleClicked: (() -> Void)?

    private let bodyColor: NSColor
    private let bodyHighlightColor: NSColor
    private let outlineColor: NSColor
    private let eyeColor = NSColor(white: 0.10, alpha: 1.0)
    private let blushColor = NSColor(red: 1.0, green: 0.55, blue: 0.65, alpha: 0.55)

    init(color: PetColor, deviceName: String = "", origin: NSPoint = .zero) {
        self.bodyColor = color.body
        self.bodyHighlightColor = PetActor.lighten(color.body, by: 0.18)
        self.outlineColor = color.foot
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

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleClicked?()
        } else {
            onClicked?()
        }
    }

    // MARK: - Animation lifecycle

    func startAnimating() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 15.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        scheduleNextBehavior()
    }

    func stopAnimating() {
        animationTimer?.invalidate()
        behaviorTimer?.invalidate()
        stateTimer?.invalidate()
        animationTimer = nil
        behaviorTimer = nil
        stateTimer = nil
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

    // MARK: - Behavior

    private func scheduleNextBehavior() {
        behaviorTimer?.invalidate()
        let delay = TimeInterval.random(in: 1.5...4.0)
        behaviorTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.pickRandomBehavior()
        }
    }

    private func pickRandomBehavior() {
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

        // 바닥 영역 (아래 절반)에서만 활동
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

        // 부드러운 위아래 바운스 (스쿼시/스트레치 X)
        let bounce: CGFloat
        switch state {
        case .idle:
            bounce = sin(Double(animationFrame) * 0.15) * 1.0
        case .walking:
            // 작게 통통 튀는 느낌 (몸 변형 X)
            let phase = Double(animationFrame % 14) / 14.0
            bounce = abs(sin(phase * .pi)) * 2.5
        case .happy:
            bounce = abs(sin(Double(animationFrame) * 0.45)) * 4.0
        case .jumping:
            let phase = Double(animationFrame % 30) / 30.0
            bounce = sin(phase * .pi) * 18.0
        }

        let labelArea = PetActor.labelGap + PetActor.labelHeight
        let spriteY = labelArea + bounce

        // 공 본체 그리기
        for row in 0..<rows {
            for col in 0..<cols {
                let v = PetActor.ballSprite[row][col]
                guard v != 0 else { continue }

                let px = spriteX + CGFloat(col) * scale
                let py = spriteY + CGFloat(rows - 1 - row) * scale // sprite top-down → view bottom-up

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

        // 얼굴 (눈 + 입 + 볼터치)
        drawFace(spriteX: spriteX, spriteY: spriteY, scale: scale)

        // 디바이스 라벨
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

    /// 얼굴 (눈/입/볼터치)을 sprite 좌표 기준으로 그림.
    /// sprite는 top-down (row 0이 위), NSView는 bottom-up이라 row 뒤집어서 그림.
    private func drawFace(spriteX: CGFloat, spriteY: CGFloat, scale: CGFloat) {
        let rows = PetActor.spriteRows

        let drawPx = { (col: Int, row: Int, color: NSColor) in
            let px = spriteX + CGFloat(col) * scale
            let py = spriteY + CGFloat(rows - 1 - row) * scale
            color.setFill()
            NSRect(x: px, y: py, width: scale, height: scale).fill()
        }

        // 볼터치 (양쪽, 항상 표시)
        drawPx(2, 6, blushColor)
        drawPx(9, 6, blushColor)

        // 눈 — happy일 땐 ^^, 그 외엔 점
        if state == .happy {
            // 왼쪽 ^ : apex (col 3, row 4) + base (cols 2, 4 / row 5)
            drawPx(3, 4, eyeColor)
            drawPx(2, 5, eyeColor)
            drawPx(4, 5, eyeColor)
            // 오른쪽 ^ : apex (col 8, row 4) + base (cols 7, 9 / row 5)
            drawPx(8, 4, eyeColor)
            drawPx(7, 5, eyeColor)
            drawPx(9, 5, eyeColor)
        } else {
            // 일반 눈 (1px 도트)
            drawPx(3, 4, eyeColor)
            drawPx(8, 4, eyeColor)
        }

        // 입 ㅅ (항상 표시) — apex (col 5, row 7) + slopes (cols 4, 6 / row 8)
        drawPx(5, 7, eyeColor)
        drawPx(4, 8, eyeColor)
        drawPx(6, 8, eyeColor)
    }
}
