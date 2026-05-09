import ArgumentParser
import Foundation

struct InstallCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "install",
        abstract: "Symlink this binary into your PATH."
    )

    @Option(name: .customLong("to"), help: "Destination path. Default: /usr/local/bin/doris")
    var destination: String = "/usr/local/bin/doris"

    @Flag(name: .shortAndLong)
    var force: Bool = false

    func run() async throws {
        let source = ProcessInfo.processInfo.arguments[0]
        let resolved: String
        if source.hasPrefix("/") {
            resolved = source
        } else {
            let cwd = FileManager.default.currentDirectoryPath
            resolved = (cwd as NSString).appendingPathComponent(source)
        }
        let absolute = (resolved as NSString).standardizingPath

        let dest = (destination as NSString).standardizingPath
        let destURL = URL(fileURLWithPath: dest)
        let parent = destURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parent.path) {
            print("doris: parent directory \(parent.path) does not exist. Create it first or pass --to with another location.")
            throw ExitCode(DorisExit.ioError)
        }
        if FileManager.default.fileExists(atPath: dest) {
            if !force {
                print("doris: \(dest) already exists. Pass --force to replace.")
                throw ExitCode(DorisExit.ioError)
            }
            try? FileManager.default.removeItem(atPath: dest)
        }
        do {
            try FileManager.default.createSymbolicLink(atPath: dest, withDestinationPath: absolute)
            print("doris: symlinked \(absolute) -> \(dest)")
        } catch {
            FileHandle.standardError.write(Data("doris: install failed: \(error)\n".utf8))
            throw ExitCode(DorisExit.permission)
        }
    }
}
