// TokenPals entry point.

import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Dock 아이콘 숨김 — 메뉴바 + 방 윈도우만 사용하는 액세서리 앱
app.setActivationPolicy(.regular)
app.run()
