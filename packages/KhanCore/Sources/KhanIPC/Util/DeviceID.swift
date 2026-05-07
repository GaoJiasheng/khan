import Foundation
#if canImport(UIKit)
import UIKit
#endif

public enum DeviceIdentity {
    private static let idKey = "khan.deviceID"
    private static let nameKey = "khan.deviceName"

    public static func current() -> UUID {
        let defaults = UserDefaults(suiteName: KhanIdentifiers.appGroup) ?? .standard
        if let raw = defaults.string(forKey: idKey), let uuid = UUID(uuidString: raw) {
            return uuid
        }
        let id = UUID()
        defaults.set(id.uuidString, forKey: idKey)
        return id
    }

    public static func currentName() -> String {
        let defaults = UserDefaults(suiteName: KhanIdentifiers.appGroup) ?? .standard
        if let name = defaults.string(forKey: nameKey), !name.isEmpty {
            return name
        }
        return defaultName
    }

    public static func setName(_ name: String) {
        let defaults = UserDefaults(suiteName: KhanIdentifiers.appGroup) ?? .standard
        defaults.set(name, forKey: nameKey)
    }

    public static var platform: String {
        #if os(macOS)
        return "macOS"
        #elseif os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? "iPadOS" : "iOS"
        #else
        return "unknown"
        #endif
    }

    private static var defaultName: String {
        #if os(macOS)
        return Host.current().localizedName ?? ProcessInfo.processInfo.hostName
        #elseif canImport(UIKit)
        return UIDevice.current.name
        #else
        return "Khan Device"
        #endif
    }
}
