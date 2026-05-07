import Foundation

enum KhanExit {
    static let ok: Int32 = 0
    static let usage: Int32 = 64
    static let dataError: Int32 = 65
    static let ioError: Int32 = 74
    static let tempFail: Int32 = 75
    static let permission: Int32 = 77
}

func dieIO(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(KhanExit.ioError)
}

func dieTempFail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(KhanExit.tempFail)
}

func dieUsage(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(KhanExit.usage)
}

func dieData(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(KhanExit.dataError)
}

func info(_ message: String, quiet: Bool = false) {
    if quiet { return }
    print(message)
}
