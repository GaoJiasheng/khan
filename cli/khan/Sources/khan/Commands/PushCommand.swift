import ArgumentParser
import Foundation
import KhanIPC

struct PushCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "push",
        abstract: "Cross-device push (alias for notify --to <device> --mode fix)."
    )

    @Option(name: .shortAndLong, help: "Notification title.")
    var title: String

    @Option(name: .shortAndLong, help: "Notification body.")
    var body: String?

    @Option(name: .customLong("to"), help: "Target device name or id; omit for all devices.")
    var toDevice: String?

    @Flag(name: .customLong("all-devices"))
    var allDevices: Bool = false

    @Flag(name: .shortAndLong)
    var quiet: Bool = false

    func run() async throws {
        var args: [String] = ["notify", "--title", title, "--mode", "fix"]
        if let body { args.append(contentsOf: ["--body", body]) }
        if allDevices { args.append("--all-devices") }
        if let toDevice { args.append(contentsOf: ["--to", toDevice]) }
        if quiet { args.append("--quiet") }

        var notify = try NotifyCommand.parse(Array(args.dropFirst()))
        try await notify.run()
    }
}
