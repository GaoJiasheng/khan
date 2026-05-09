import Foundation
import Security

public enum KeychainSecretStore {
    public enum KeychainError: Error {
        case osStatus(OSStatus)
        case dataConversion
        case disabled
    }

    /// When `DORIS_DISABLE_KEYCHAIN=1`, the secret store falls back to a per-user file in the
    /// IPC dev container. This lets unsigned dev builds avoid Keychain prompts that block
    /// indefinitely on macOS when the binary isn't entitled.
    private static var keychainDisabled: Bool {
        ProcessInfo.processInfo.environment["DORIS_DISABLE_KEYCHAIN"] == "1"
    }

    public static func keychainAccessGroup() -> String? {
        guard let prefix = teamIDPrefix() else { return nil }
        return "\(prefix)\(DorisIdentifiers.appGroup)"
    }

    public static func loadSecret() throws -> Data {
        if keychainDisabled {
            return try loadSecretFromFile()
        }
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: DorisIdentifiers.keychainService,
            kSecAttrAccount as String: DorisIdentifiers.keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail
        ]
        if let group = keychainAccessGroup() {
            query[kSecAttrAccessGroup as String] = group
        }
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.osStatus(status)
        }
        return data
    }

    public static func saveSecret(_ data: Data) throws {
        if keychainDisabled {
            try saveSecretToFile(data)
            return
        }
        var attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: DorisIdentifiers.keychainService,
            kSecAttrAccount as String: DorisIdentifiers.keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        if let group = keychainAccessGroup() {
            attributes[kSecAttrAccessGroup as String] = group
        }

        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: DorisIdentifiers.keychainService,
            kSecAttrAccount as String: DorisIdentifiers.keychainAccount
        ]
        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if updateStatus == errSecSuccess { return }

        let addStatus = SecItemAdd(attributes as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError.osStatus(addStatus)
        }
    }

    public static func deleteSecret() throws {
        if keychainDisabled {
            let url = try fileURL()
            try? FileManager.default.removeItem(at: url)
            return
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: DorisIdentifiers.keychainService,
            kSecAttrAccount as String: DorisIdentifiers.keychainAccount
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.osStatus(status)
        }
    }

    public static func ensureSecret() throws -> Data {
        if let existing = try? loadSecret() { return existing }
        let new = DorisHMAC.generateSecret()
        try saveSecret(new)
        return new
    }

    private static func teamIDPrefix() -> String? {
        if keychainDisabled { return nil }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "doris-team-probe",
            kSecAttrAccount as String: "probe",
            kSecReturnAttributes as String: true,
            kSecUseDataProtectionKeychain as String: true,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail
        ]
        var result: CFTypeRef?
        _ = SecItemCopyMatching(query as CFDictionary, &result)
        if let attrs = result as? [String: Any], let group = attrs[kSecAttrAccessGroup as String] as? String,
           let dot = group.firstIndex(of: ".") {
            return String(group[..<dot]) + "."
        }
        return nil
    }

    // MARK: - Dev fallback (file-backed)

    private static func fileURL() throws -> URL {
        let dir = try IPCDirectory.containerURL()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(".doris-hmac-secret")
    }

    private static func loadSecretFromFile() throws -> Data {
        let url = try fileURL()
        return try Data(contentsOf: url)
    }

    private static func saveSecretToFile(_ data: Data) throws {
        let url = try fileURL()
        try data.write(to: url, options: [.atomic, .completeFileProtection])
    }
}
