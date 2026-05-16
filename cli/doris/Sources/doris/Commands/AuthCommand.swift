import ArgumentParser
import Foundation
import DorisIPC

struct AuthCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "auth",
        abstract: "Manage the CLI ↔ app shared HMAC secret.",
        subcommands: [Status.self, Init.self, Path.self]
    )

    struct Status: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "status", abstract: "Show whether the CLI can read the shared secret.")
        func run() async throws {
            do {
                _ = try KeychainSecretStore.loadSecret()
                print("ok: shared secret reachable from this CLI binary")
            } catch {
                print("error: secret not reachable. (run doris auth init while the app is running)")
                throw ExitCode(DorisExit.permission)
            }
        }
    }

    struct Init: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "init", abstract: "Generate a new shared secret in the Keychain.")
        func run() async throws {
            do {
                let secret = DorisHMAC.generateSecret()
                try KeychainSecretStore.saveSecret(secret)
                print("ok: secret rotated (\(secret.count * 8) bits)")
            } catch {
                FileHandle.standardError.write(Data("error: \(error)\n".utf8))
                throw ExitCode(DorisExit.permission)
            }
        }
    }

    struct Path: AsyncParsableCommand {
        static let configuration = CommandConfiguration(commandName: "path", abstract: "Print the App Group IPC queue directory path.")
        func run() async throws {
            do {
                let url = try IPCDirectory.inboxDir()
                print(url.path)
            } catch {
                FileHandle.standardError.write(Data("error: app group container not available\n".utf8))
                throw ExitCode(DorisExit.ioError)
            }
        }
    }
}
