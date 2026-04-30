// Real-time directory watcher using FSEvents.
// Phase 1: replaces 30s polling with instant change detection.

import Foundation
import CoreServices

class FileWatcher {
    private var stream: FSEventStreamRef?
    private let paths: [String]
    private let onChange: () -> Void
    private let queue = DispatchQueue(label: "tokenpals.filewatcher", qos: .userInitiated)
    private let latency: CFTimeInterval

    /// - Parameters:
    ///   - paths: 감시할 디렉토리 경로들 (재귀 감시).
    ///   - latency: FSEvents 이벤트 묶음 대기 시간 (초). 너무 짧으면 한 글쓰기에 다발 콜백.
    ///   - onChange: 변경 발생시 호출 (메인 큐로 dispatch됨).
    init(paths: [String], latency: CFTimeInterval = 0.5, onChange: @escaping () -> Void) {
        self.paths = paths
        self.latency = latency
        self.onChange = onChange
    }

    deinit {
        stop()
    }

    func start() {
        guard stream == nil else { return }
        guard !paths.isEmpty else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info = info else { return }
            let watcher = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()
            DispatchQueue.main.async {
                watcher.onChange()
            }
        }

        let cfPaths = paths as CFArray

        let createdStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            cfPaths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            latency,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        )

        guard let createdStream = createdStream else { return }
        stream = createdStream
        FSEventStreamSetDispatchQueue(createdStream, queue)
        FSEventStreamStart(createdStream)
    }

    func stop() {
        guard let stream = stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }
}
