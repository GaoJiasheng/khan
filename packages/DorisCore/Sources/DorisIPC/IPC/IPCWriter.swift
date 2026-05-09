import Foundation

public enum IPCWriter {
    public enum WriteError: Error {
        case directoryUnavailable
        case keychainUnavailable(Error)
        case encodingFailed(Error)
        case writeFailed(Error)
    }

    /// Write a request to the inbox queue, signed with the shared HMAC secret if available.
    /// Returns the URL of the file we wrote.
    @discardableResult
    public static func enqueue(_ request: IPCRequest) throws -> URL {
        let inbox: URL
        do {
            inbox = try IPCDirectory.inboxDir()
        } catch {
            throw WriteError.directoryUnavailable
        }
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)

        var signed = request
        if let secret = try? KeychainSecretStore.loadSecret() {
            signed = (try? DorisHMAC.sign(request, with: secret)) ?? request
        }
        let data: Data
        do {
            data = try IPCEncoding.encoder.encode(signed)
        } catch {
            throw WriteError.encodingFailed(error)
        }

        let filename = IPCDirectory.newRequestFilename(for: signed.id)
        let target = inbox.appendingPathComponent(filename)
        do {
            try data.write(to: target, options: .atomic)
        } catch {
            throw WriteError.writeFailed(error)
        }
        return target
    }

    /// Post the Darwin notification that wakes the running app.
    public static func kick() {
        DarwinNotify.post(DorisIdentifiers.darwinKickName)
    }
}
