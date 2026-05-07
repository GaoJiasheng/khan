import Foundation
import KhanIPC

/// Watches the App Group inbox directory for new request files.
final class IPCFSEventReader {
    private var stream: FSEventStreamRef?
    private let onChange: () -> Void
    private let queue = DispatchQueue(label: "com.gavin.khan.fsevents")

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    func start() {
        guard stream == nil else { return }
        guard let inbox = try? IPCDirectory.inboxDir() else { return }
        let path = inbox.path

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let me = Unmanaged<IPCFSEventReader>.fromOpaque(info).takeUnretainedValue()
            me.onChange()
        }
        let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            [path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents)
        )
        guard let stream else { return }
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    deinit {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
    }
}
