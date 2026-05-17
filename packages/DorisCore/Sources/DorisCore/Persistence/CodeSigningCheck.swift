import Foundation
#if os(macOS)
import Security
#endif

/// Runtime probe for whether the running binary has a code signature
/// with a non-empty team identifier. We use this to gate CloudKit:
/// SwiftData's CloudKit mirror traps the app (brk 1 on
/// `com.apple.coredata.cloudkit.queue`) when the running binary
/// declares CloudKit entitlements but isn't actually signed for them
/// — a common mode for dev builds compiled with
/// `CODE_SIGN_IDENTITY=""`. Synchronous `try? ModelContainer(...)`
/// can't catch that crash because it happens on a later background
/// queue tick.
///
/// `hasTeamIdentifier` is `true` for any build signed by Xcode with a
/// development team (debug Run, archived release) and `false` for
/// ad-hoc / unsigned builds. iOS bundles always carry a signing
/// identity in practice (App Store / TestFlight / sideload), so the
/// iOS path returns `true` without inspecting the keychain at all.
public enum CodeSigningCheck {
    public static var hasTeamIdentifier: Bool {
        #if os(macOS)
        var staticCode: SecStaticCode?
        let url = Bundle.main.bundleURL as CFURL
        guard SecStaticCodeCreateWithPath(url, [], &staticCode) == errSecSuccess,
              let code = staticCode else { return false }
        var info: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard SecCodeCopySigningInformation(code, flags, &info) == errSecSuccess,
              let dict = info as? [String: Any] else { return false }
        let teamID = dict[kSecCodeInfoTeamIdentifier as String] as? String ?? ""
        return !teamID.isEmpty
        #else
        return true
        #endif
    }
}
