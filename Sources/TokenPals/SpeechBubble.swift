// Pixel-styled speech bubble shown above a pet, auto-dismisses.
// Different from UsageTooltip (which sticks while hovering) — this one says one message and disappears.

import Cocoa

class SpeechBubble: NSView {
    private(set) var text: String = ""
    private var dismissTimer: Timer?

    private static let font = NSFont.systemFont(ofSize: 10.5, weight: .medium)
    private static let paddingX: CGFloat = 8
    private static let paddingY: CGFloat = 5
    private static let pointerSize: CGFloat = 5
    private static let cornerRadius: CGFloat = 4

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    deinit {
        dismissTimer?.invalidate()
    }

    /// 텍스트 갱신 + 자동 dismiss 타이머 시작.
    func show(_ newText: String, autoHideAfter seconds: TimeInterval = 3.5) {
        text = newText
        recomputeSize()
        needsDisplay = true

        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            self?.removeFromSuperview()
        }
    }

    private func recomputeSize() {
        let attrs: [NSAttributedString.Key: Any] = [.font: SpeechBubble.font]
        let textSize = (text as NSString).size(withAttributes: attrs)
        let width = ceil(textSize.width) + SpeechBubble.paddingX * 2
        let height = ceil(textSize.height) + SpeechBubble.paddingY * 2 + SpeechBubble.pointerSize
        frame.size = NSSize(width: width, height: height)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !text.isEmpty else { return }

        let isDark = (effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)
        let bg: NSColor = isDark
            ? NSColor(white: 0.16, alpha: 0.97)
            : NSColor(white: 1.0, alpha: 0.97)
        let outline: NSColor = isDark
            ? NSColor(white: 0.40, alpha: 1.0)
            : NSColor(white: 0.40, alpha: 1.0)
        let textColor: NSColor = isDark
            ? NSColor(white: 0.97, alpha: 1.0)
            : NSColor(white: 0.10, alpha: 1.0)

        let pointerSize = SpeechBubble.pointerSize
        let bubbleRect = NSRect(
            x: 0.5, y: pointerSize + 0.5,
            width: bounds.width - 1,
            height: bounds.height - pointerSize - 1
        )

        // 본체 (둥근 모서리, 픽셀 약간 부드러움)
        let bubblePath = NSBezierPath(
            roundedRect: bubbleRect,
            xRadius: SpeechBubble.cornerRadius,
            yRadius: SpeechBubble.cornerRadius
        )
        bg.setFill()
        bubblePath.fill()
        outline.setStroke()
        bubblePath.lineWidth = 1
        bubblePath.stroke()

        // 아래쪽 삼각 포인터
        let centerX = bounds.midX
        let triangle = NSBezierPath()
        triangle.move(to: NSPoint(x: centerX - pointerSize, y: pointerSize + 0.5))
        triangle.line(to: NSPoint(x: centerX, y: 0.5))
        triangle.line(to: NSPoint(x: centerX + pointerSize, y: pointerSize + 0.5))
        bg.setFill()
        triangle.fill()

        // 포인터 가장자리만 stroke (위쪽 가로선은 본체와 겹쳐서 빼야 함)
        outline.setStroke()
        let pointerEdge = NSBezierPath()
        pointerEdge.move(to: NSPoint(x: centerX - pointerSize, y: pointerSize + 0.5))
        pointerEdge.line(to: NSPoint(x: centerX, y: 0.5))
        pointerEdge.line(to: NSPoint(x: centerX + pointerSize, y: pointerSize + 0.5))
        pointerEdge.lineWidth = 1
        pointerEdge.stroke()

        // 본체 하단 가로선이 포인터와 겹치는 부분 가리기
        bg.setFill()
        NSRect(x: centerX - pointerSize + 1, y: pointerSize, width: pointerSize * 2 - 2, height: 1).fill()

        // 텍스트
        NSGraphicsContext.current?.shouldAntialias = true
        let attrs: [NSAttributedString.Key: Any] = [
            .font: SpeechBubble.font,
            .foregroundColor: textColor,
        ]
        let textSize = (text as NSString).size(withAttributes: attrs)
        let textX = (bounds.width - textSize.width) / 2
        let textY = pointerSize + SpeechBubble.paddingY
        (text as NSString).draw(at: NSPoint(x: textX, y: textY), withAttributes: attrs)
    }
}
