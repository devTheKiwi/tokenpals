// Character color palette for TokenPals.
// Adapted from ClaudePet (https://github.com/devTheKiwi/ClaudePet) MIT.

import Cocoa

struct PetColor {
    let body: NSColor
    let bodyDark: NSColor
    let foot: NSColor

    static let palette: [PetColor] = [
        // 0: Claude 오렌지 (기본)
        PetColor(
            body: NSColor(red: 0.85, green: 0.47, blue: 0.34, alpha: 1.0),
            bodyDark: NSColor(red: 0.72, green: 0.38, blue: 0.26, alpha: 1.0),
            foot: NSColor(red: 0.65, green: 0.33, blue: 0.22, alpha: 1.0)
        ),
        // 1: 블루
        PetColor(
            body: NSColor(red: 0.38, green: 0.58, blue: 0.85, alpha: 1.0),
            bodyDark: NSColor(red: 0.28, green: 0.45, blue: 0.72, alpha: 1.0),
            foot: NSColor(red: 0.22, green: 0.38, blue: 0.62, alpha: 1.0)
        ),
        // 2: 그린
        PetColor(
            body: NSColor(red: 0.40, green: 0.75, blue: 0.45, alpha: 1.0),
            bodyDark: NSColor(red: 0.30, green: 0.60, blue: 0.35, alpha: 1.0),
            foot: NSColor(red: 0.24, green: 0.50, blue: 0.28, alpha: 1.0)
        ),
        // 3: 퍼플
        PetColor(
            body: NSColor(red: 0.65, green: 0.45, blue: 0.82, alpha: 1.0),
            bodyDark: NSColor(red: 0.52, green: 0.34, blue: 0.68, alpha: 1.0),
            foot: NSColor(red: 0.42, green: 0.28, blue: 0.58, alpha: 1.0)
        ),
        // 4: 핑크
        PetColor(
            body: NSColor(red: 0.85, green: 0.42, blue: 0.58, alpha: 1.0),
            bodyDark: NSColor(red: 0.72, green: 0.32, blue: 0.46, alpha: 1.0),
            foot: NSColor(red: 0.60, green: 0.26, blue: 0.38, alpha: 1.0)
        ),
        // 5: 틸
        PetColor(
            body: NSColor(red: 0.32, green: 0.72, blue: 0.70, alpha: 1.0),
            bodyDark: NSColor(red: 0.24, green: 0.58, blue: 0.56, alpha: 1.0),
            foot: NSColor(red: 0.18, green: 0.48, blue: 0.46, alpha: 1.0)
        ),
    ]
}
