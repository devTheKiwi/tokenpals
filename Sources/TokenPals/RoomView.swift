// Room view: pixel-art themed canvas hosting multiple PetActors.

import Cocoa

class RoomView: NSView {
    private(set) var pets: [PetActor] = []

    /// 픽셀 테마 배경 색 (벽/바닥 두 톤)
    private static let wallLight = NSColor(red: 0.94, green: 0.91, blue: 0.86, alpha: 1.0)   // 따뜻한 크림
    private static let floorLight = NSColor(red: 0.86, green: 0.81, blue: 0.74, alpha: 1.0)  // 살짝 진한 크림
    private static let horizonLight = NSColor(red: 0.70, green: 0.62, blue: 0.52, alpha: 1.0)

    private static let wallDark = NSColor(red: 0.18, green: 0.20, blue: 0.24, alpha: 1.0)
    private static let floorDark = NSColor(red: 0.12, green: 0.14, blue: 0.17, alpha: 1.0)
    private static let horizonDark = NSColor(red: 0.30, green: 0.32, blue: 0.36, alpha: 1.0)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setShouldAntialias(false)

        let isDark = (effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)
        let wall = isDark ? RoomView.wallDark : RoomView.wallLight
        let floor = isDark ? RoomView.floorDark : RoomView.floorLight
        let horizon = isDark ? RoomView.horizonDark : RoomView.horizonLight

        // 벽 (위쪽 절반)
        let floorTopY = bounds.minY + bounds.height * 0.5
        wall.setFill()
        NSRect(x: bounds.minX, y: floorTopY, width: bounds.width, height: bounds.maxY - floorTopY).fill()

        // 바닥 (아래쪽 절반)
        floor.setFill()
        NSRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: floorTopY - bounds.minY).fill()

        // 수평선 (1픽셀)
        horizon.setFill()
        NSRect(x: bounds.minX, y: floorTopY, width: bounds.width, height: 1).fill()

        // 바닥에 미세 픽셀 도트 (픽셀 테마 강조)
        let dotColor = horizon.withAlphaComponent(0.25)
        dotColor.setFill()
        let stride: CGFloat = 16
        var y = bounds.minY + 6
        while y < floorTopY - 4 {
            var x = bounds.minX + 8
            while x < bounds.maxX - 2 {
                NSRect(x: x, y: y, width: 2, height: 2).fill()
                x += stride
            }
            y += stride
        }
    }

    /// 새 PetActor 추가. 바닥 영역 안 랜덤 위치에 스폰.
    @discardableResult
    func addPet(color: PetColor, deviceId: String = "", name: String) -> PetActor {
        let pet = PetActor(color: color, deviceId: deviceId, deviceName: name)

        let margin: CGFloat = 12
        let floorTopY = bounds.minY + bounds.height * 0.5
        let xRange = (bounds.minX + margin)...(max(bounds.minX + margin + 1, bounds.maxX - PetActor.petSize.width - margin))
        let yRange = (bounds.minY + margin)...(max(bounds.minY + margin + 1, floorTopY - PetActor.petSize.height - margin))

        pet.frame.origin = NSPoint(
            x: CGFloat.random(in: xRange),
            y: CGFloat.random(in: yRange)
        )

        pet.onClicked = { [weak pet] in
            pet?.setState(.happy)
        }
        pet.onDoubleClicked = { [weak pet] in
            pet?.setState(.jumping)
        }

        addSubview(pet)
        pet.startAnimating()
        pets.append(pet)
        return pet
    }

    func removeAllPets() {
        for pet in pets {
            pet.stopAnimating()
            pet.removeFromSuperview()
        }
        pets.removeAll()
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        let floorTopY = bounds.minY + bounds.height * 0.5
        for pet in pets {
            var origin = pet.frame.origin
            let maxX = bounds.maxX - pet.frame.width
            let maxY = floorTopY - pet.frame.height
            if origin.x > maxX { origin.x = max(0, maxX) }
            if origin.x < bounds.minX { origin.x = bounds.minX }
            if origin.y > maxY { origin.y = max(bounds.minY, maxY) }
            if origin.y < bounds.minY { origin.y = bounds.minY }
            pet.frame.origin = origin
        }
        needsDisplay = true
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}
