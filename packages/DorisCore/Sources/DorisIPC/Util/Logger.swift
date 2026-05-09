import Foundation
import os

public enum DorisLog {
    public static let subsystem = "com.gavin.doris"

    public static let app = Logger(subsystem: subsystem, category: "app")
    public static let ipc = Logger(subsystem: subsystem, category: "ipc")
    public static let router = Logger(subsystem: subsystem, category: "router")
    public static let sync = Logger(subsystem: subsystem, category: "sync")
    public static let push = Logger(subsystem: subsystem, category: "push")
    public static let ui = Logger(subsystem: subsystem, category: "ui")
    public static let voice = Logger(subsystem: subsystem, category: "voice")
}
