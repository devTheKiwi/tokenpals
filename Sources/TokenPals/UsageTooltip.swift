// Small pixel-styled tooltip shown above a pet on hover.

import Cocoa

class UsageTooltip: NSView {
    var lines: [String] = [] {
        didSet {
            recomputeSize()
            needsDisplay = true
        }
    }

    private static let font = NSFont.monospacedSystemFont(ofSize: 10, weight: .medium)
    private static let paddingX: CGFloat = 6
    private static let paddingY: CGFloat = 4
    private static let lineHeight: CGFloat = 13

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    private func recomputeSize() {
        let attrs: [NSAttributedString.Key: Any] = [.font: UsageTooltip.font]
        var maxW: CGFloat = 0
        for line in lines {
            let w = (line as NSString).size(withAttributes: attrs).width
            if w > maxW { maxW = w }
        }
        let height = UsageTooltip.lineHeight * CGFloat(max(1, lines.count)) + UsageTooltip.paddingY * 2
        let width = maxW + UsageTooltip.paddingX * 2
        frame.size = NSSize(width: width, height: height)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !lines.isEmpty else { return }
        let isDark = (effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)
        let bgColor: NSColor = isDark
            ? NSColor(white: 0.13, alpha: 0.97)
            : NSColor(white: 1.0, alpha: 0.97)
        let outlineColor: NSColor = isDark
            ? NSColor(white: 0.30, alpha: 1.0)
            : NSColor(white: 0.55, alpha: 1.0)
        let textColor: NSColor = isDark
            ? NSColor(white: 0.95, alpha: 1.0)
            : NSColor(white: 0.15, alpha: 1.0)

        // 픽셀 테마: 둥글지 않은 사각 + 1px 외곽
        bgColor.setFill()
        bounds.fill()

        outlineColor.setStroke()
        let border = NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5))
        border.lineWidth = 1
        border.stroke()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UsageTooltip.font,
            .foregroundColor: textColor,
        ]
        for (i, line) in lines.enumerated() {
            // 위에서 아래로 표시 (lines[0] = 위)
            let y = bounds.height - UsageTooltip.paddingY - UsageTooltip.lineHeight * CGFloat(i + 1) + 2
            (line as NSString).draw(
                at: NSPoint(x: UsageTooltip.paddingX, y: y),
                withAttributes: attrs
            )
        }
    }
}
