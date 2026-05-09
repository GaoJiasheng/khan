import Foundation
import CoreFoundation

/// Cross-process notification kick using Darwin notify center via CoreFoundation.
public enum DarwinNotify {
    public static func post(_ name: String) {
        guard let center = CFNotificationCenterGetDarwinNotifyCenter() else { return }
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName(name as CFString),
            nil,
            nil,
            true
        )
    }

    public final class Subscription {
        let observer: UnsafeMutableRawPointer
        let name: String
        init(observer: UnsafeMutableRawPointer, name: String) {
            self.observer = observer
            self.name = name
        }
        deinit {
            guard let center = CFNotificationCenterGetDarwinNotifyCenter() else { return }
            CFNotificationCenterRemoveObserver(center, observer, CFNotificationName(name as CFString), nil)
            Unmanaged<Box>.fromOpaque(observer).release()
        }
    }

    public static func subscribe(_ name: String, handler: @escaping () -> Void) -> Subscription? {
        guard let center = CFNotificationCenterGetDarwinNotifyCenter() else { return nil }
        let box = Box(handler: handler)
        let observer = Unmanaged.passRetained(box).toOpaque()
        let callback: CFNotificationCallback = { _, observer, _, _, _ in
            guard let observer else { return }
            let box = Unmanaged<Box>.fromOpaque(observer).takeUnretainedValue()
            DispatchQueue.main.async { box.handler() }
        }
        CFNotificationCenterAddObserver(
            center,
            observer,
            callback,
            name as CFString,
            nil,
            .deliverImmediately
        )
        return Subscription(observer: observer, name: name)
    }

    private final class Box {
        let handler: () -> Void
        init(handler: @escaping () -> Void) { self.handler = handler }
    }
}
