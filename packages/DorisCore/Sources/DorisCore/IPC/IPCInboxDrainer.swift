import Foundation
import DorisIPC

@MainActor
public final class IPCInboxDrainer {
    private let router: NotificationRouter
    private let secret: Data?

    public init(router: NotificationRouter, secret: Data?) {
        self.router = router
        self.secret = secret
    }

    public func drain() async {
        let inbox: URL
        do {
            inbox = try IPCDirectory.inboxDir()
            try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        } catch {
            DorisLog.ipc.error("inbox unavailable: \(String(describing: error), privacy: .public)")
            return
        }
        let processed = (try? IPCDirectory.processedDir()) ?? inbox.deletingLastPathComponent().appendingPathComponent("processed")
        try? FileManager.default.createDirectory(at: processed, withIntermediateDirectories: true)

        let files = (try? FileManager.default.contentsOfDirectory(at: inbox, includingPropertiesForKeys: nil)) ?? []
        let sorted = files.filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        for url in sorted {
            await processOne(url, processedDir: processed)
        }
    }

    private func processOne(_ url: URL, processedDir: URL) async {
        do {
            let data = try Data(contentsOf: url)
            let request = try IPCEncoding.decoder.decode(IPCRequest.self, from: data)
            if let secret {
                do {
                    try DorisHMAC.verify(request, with: secret)
                } catch {
                    DorisLog.ipc.error("HMAC verification failed for \(url.lastPathComponent, privacy: .public)")
                    try? moveToProcessed(url, into: processedDir, suffix: ".rejected")
                    return
                }
            }
            await router.handle(request)
            try? moveToProcessed(url, into: processedDir, suffix: ".ok")
        } catch {
            DorisLog.ipc.error("failed to process \(url.lastPathComponent, privacy: .public): \(String(describing: error), privacy: .public)")
            try? moveToProcessed(url, into: processedDir, suffix: ".error")
        }
    }

    private func moveToProcessed(_ url: URL, into dir: URL, suffix: String) throws {
        let dest = dir.appendingPathComponent(url.lastPathComponent + suffix)
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: url, to: dest)
    }
}
