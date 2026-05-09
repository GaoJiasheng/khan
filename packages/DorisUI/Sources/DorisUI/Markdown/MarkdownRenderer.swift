import SwiftUI

/// Lightweight markdown renderer using SwiftUI's built-in `AttributedString(markdown:)` parser.
public struct MarkdownText: View {
    public let raw: String

    public init(_ raw: String) {
        self.raw = raw
    }

    public var body: some View {
        if let attributed = try? AttributedString(markdown: raw, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Text(attributed)
        } else {
            Text(raw)
        }
    }
}
