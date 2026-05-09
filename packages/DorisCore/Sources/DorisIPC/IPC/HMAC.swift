import Foundation
import CryptoKit

public enum DorisHMAC {
    public enum HMACError: Error {
        case missingHMAC
        case verificationFailed
    }

    public static func sign(_ request: IPCRequest, with secret: Data) throws -> IPCRequest {
        var copy = request
        copy.hmac = nil
        let canonical = try IPCEncoding.encoder.encode(copy)
        let mac = HMAC<SHA256>.authenticationCode(for: canonical, using: SymmetricKey(data: secret))
        copy.hmac = Data(mac).hexString
        if ProcessInfo.processInfo.environment["DORIS_DEBUG_HMAC"] == "1" {
            let canonicalString = String(data: canonical, encoding: .utf8) ?? "?"
            let line = "[DorisHMAC sign] canonical=\(canonicalString) hmac=\(copy.hmac ?? "?")\n"
            FileHandle.standardError.write(Data(line.utf8))
        }
        return copy
    }

    public static func verify(_ request: IPCRequest, with secret: Data) throws {
        guard let provided = request.hmac, let providedData = Data(hexString: provided) else {
            throw HMACError.missingHMAC
        }
        var stripped = request
        stripped.hmac = nil
        let canonical = try IPCEncoding.encoder.encode(stripped)
        let expected = HMAC<SHA256>.authenticationCode(for: canonical, using: SymmetricKey(data: secret))
        let expectedHex = Data(expected).hexString
        if !Data(expected).timingSafeEquals(providedData) {
            let canonicalString = String(data: canonical, encoding: .utf8) ?? "?"
            let line = "[DorisHMAC verify FAIL] canonical=\(canonicalString) expected=\(expectedHex) provided=\(provided)\n"
            FileHandle.standardError.write(Data(line.utf8))
            throw HMACError.verificationFailed
        }
    }

    public static func generateSecret() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status != errSecSuccess {
            return SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        }
        return Data(bytes)
    }
}

extension Data {
    public var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }

    public init?(hexString: String) {
        let str = hexString.lowercased()
        guard str.count % 2 == 0 else { return nil }
        var data = Data(capacity: str.count / 2)
        var index = str.startIndex
        while index < str.endIndex {
            let next = str.index(index, offsetBy: 2)
            guard let byte = UInt8(str[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        self = data
    }

    fileprivate func timingSafeEquals(_ other: Data) -> Bool {
        guard count == other.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<count {
            diff |= self[i] ^ other[i]
        }
        return diff == 0
    }
}
