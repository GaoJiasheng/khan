import Foundation
import KhanIPC

public enum AttachmentStore {
    public enum AttachmentError: Error {
        case sourceNotReadable
    }

    public static func store(data: Data, suggestedFilename: String) throws -> (relativePath: String, absoluteURL: URL) {
        let dir = try IPCDirectory.attachmentsDir()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let id = UUID().uuidString
        let ext = (suggestedFilename as NSString).pathExtension
        let filename = ext.isEmpty ? "\(id)" : "\(id).\(ext)"
        let url = dir.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return ("Attachments/\(filename)", url)
    }

    public static func absoluteURL(forRelative path: String) throws -> URL {
        let root = try IPCDirectory.containerURL()
        return root.appendingPathComponent(path)
    }

    public static func remove(relativePath: String) throws {
        let url = try absoluteURL(forRelative: relativePath)
        try? FileManager.default.removeItem(at: url)
    }
}
